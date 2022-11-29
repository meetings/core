package OpenInteract2::Action::DicoleInviteCommon;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::MessageHandler qw( :message );
use OpenInteract2::Context   qw( CTX );
use Dicole::Generictool;
use MIME::Lite ();
use Dicole::Tool;
use Dicole::Generictool::FakeObject;
use SPOPS::Utility;
use OpenInteract2::Action::UserManager;
use OpenInteract2::Action::DicoleRegister;
use Dicole::Pathutils;
use OpenInteract2::Util;
use Dicole::Utils::Mail;

use base qw( Dicole::Action );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use constant CODE_LENGTH      => 8;    # characters
use constant UMANAGER_PREFIX => '/usermanager/show/0/?uid=';
use constant DMANAGER_PREFIX => '/dusermanager/show/0/?uid=';

sub _generate_random_key {
    my ($self, $len) = @_;
    $len ||= CODE_LENGTH;

    return SPOPS::Utility->generate_random_code($len, 'mixed');
}

sub _current_user_can_invite_as_admin {
    my ( $self ) = @_;

    return $self->mchk_y('OpenInteract2::Action::Groups', 'users');
}

sub _create_invitation {
    my ( $self, $current_domain, $group, $email, $level ) = @_;
    
    my $random_key = $self->_generate_random_key;
    eval { $self->_send_invitation( $random_key, $current_domain, $group, $email ); };
    if ( $@ ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error sending email. Please contact your system administrator or try again later' )
        );
    }
    if ( 0 ) {}
    else {
        my $invite = CTX->lookup_object( 'invite' )->new;
        $invite->{user_id} = CTX->request->auth_user_id;
        $invite->{group_id} = $group->id;
        $invite->{domain_id} = $current_domain ? $current_domain->id : 0;
        $invite->{invite_date} = time;
        $invite->{disabled} = 0;
        $invite->{secret_code} = $random_key;
        $invite->{email} = $email;
        $invite->{level} = $level;
        $invite->save;
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Sent an invitation to [_1]', $email )
        );
    }
}

sub _send_invitation {
    my ( $self, $random_key, $current_domain, $group, $email ) = @_;

    # TODO: determine and send language as params

    my $language = eval { CTX->request->auth_user->language };
    if ( $group && ref( $group ) ) {
        my $data = eval { Dicole::Utils::JSON->decode( $group->meta || '{}' ) } || {};
        $language = $data->{language} if $data->{language};
    }

    my ( $subject_t, $content_t ) = @{ $self->_get_mail_templates( $language ) };
    
    my $message = CTX->request->param('greeting_message') || CTX->request->param('invite_message');
    undef $message if $message =~ /^[\n\s]*$/;
    $message = Dicole::Utils::HTML->text_to_html( $message ) if $message;

    my $host = Dicole::URL->get_server_url;
    my %params = (
        url => $host . $self->derive_url( action => 'invite', task => 'invited', additional => [], params => { k => $random_key } ),
        target => $group ? $group->name . ' @ ' . $host : $host,
        inviter => CTX->request->auth_user->{first_name} . ' ' . CTX->request->auth_user->{last_name},
        message => $message,
    );
    
    my $tt = Template->new;
    my $content;
    $tt->process( \$content_t, \%params, \$content );
    my $subject;
    $tt->process( \$subject_t, \%params, \$subject );
    
    my $text_content = Dicole::Utils::HTML->html_to_text( $content );

    Dicole::Utils::Mail->send(
        subject => CTX->request->param('greeting_subject') || $subject,
        to => $email,
        html => $content,
        text => $text_content,
    );
}

sub _get_mail_templates {
    my ( $self, $language ) = @_;
    
    my ( $subject, $content ) = @{ $self->_get_default_mail_templates( $language ) };
    
    my $d = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $tool = $d ? 'domain_user_manager_' . $d->id : 'user_manager';
    my $settings = Dicole::Settings->new_fetched_from_params( tool => $tool );

    $subject = $settings->setting('invite_email_subject') || $subject;
    $content = $settings->setting('invite_email') || $content;
    
    return [ $subject, $content ];
}

sub _get_default_mail_templates {
    my ( $self, $language ) = @_;
    
    if ( $language && lc ( $language ) eq 'fi' ) {
        return [
            '[% inviter %] haluaa kutsua sinut [% target %] työtilaan',
            <<FI_TEMPLATE,
<p>[% inviter %] on kutsunut sinut [% target %] työtilaan. Voit hyväksyä kutsun seuraavassa osoitteessa: <a href="[% url %]">[% url %]</a></p>[% IF message %]<p>Kutsun ohessa [% inviter %] lähetti seuraavan viestin:</p><p>[% message %]</p>[% END %]
FI_TEMPLATE
        ];
    }
    else {
        return [
            '[% inviter %] wants you to join [% target %]',
            <<EN_TEMPLATE,
<p>[% inviter %] has invited you to join [% target %]. You can accept the invite at <a href="[% url %]">[% url %]</a></p>[% IF message %]<p>To accompany the invite [% inviter %] sent you the following message:</p><p>[% message %]</p>[% END %]
EN_TEMPLATE
        ];
    }
    
}

sub _fetch_invite {
    my ( $self, $code, $group_id, $domain_id ) = @_;

    my $secure_codes = CTX->lookup_object( 'invite' )->fetch_group( {
        where => 'secret_code = ? AND disabled = 0',
        value => [ $code ]
    } ) || [];
    my $secure_code = shift @$secure_codes;

    return undef unless $secure_code;
    return undef unless ! $domain_id || $domain_id == $secure_code->domain_id;
    return undef unless ! $group_id || $group_id == $secure_code->group_id;
    return $secure_code;
}

sub _consume_invite {
    my ( $self, $secure_code, $user ) = @_;

    my $as_admin = ( $secure_code->level eq 'admin' ) ? 1 : 0;

    $self->_ensure_user_in_group_and_domain( $user, $secure_code->group_id, undef, $as_admin );

    # Automatically add a mutual contact info
    eval {
        my @uids = ( $secure_code->user_id, $user->id );
        CTX->lookup_action('networking_api')->execute( add_contact => {
            contacting_user_id => $_->[0],
            contacted_user_id => $_->[1],
        } ) for ( [ @uids ], [ reverse( @uids ) ] );
    };

    # Remove registration key
    $secure_code->disabled( 1 );
    $secure_code->save;
}

sub _ensure_user_in_group_and_domain {
    my ( $self, $user, $group_id, $domain_id, $as_admin ) = @_;

    CTX->lookup_action('add_user_to_group')->execute( {
        user_id => $user->id,
        group_id => $group_id,
        as_admin => $as_admin,
    } ) if $group_id;

    eval {
        CTX->lookup_action( 'dicole_domains' )->execute(
            'add_user_to_domain', { user_id => $user->id, domain_id => $domain_id }
        );
    };
}

1;

__END__
