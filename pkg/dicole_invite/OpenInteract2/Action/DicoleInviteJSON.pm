package OpenInteract2::Action::DicoleInviteJSON;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::MessageHandler qw( :message );
use OpenInteract2::Context   qw( CTX );

use base qw( OpenInteract2::Action::DicoleInviteCommon );

sub dialog_data {
    my ( $self ) = @_;

    my $data = CTX->lookup_action('invite_api')->e( dialog_data => {} );

    return { result => $data };
}

sub levels_dialog_data {
    my ( $self ) = @_;

    my $data = CTX->lookup_action('invite_api')->e( levels_dialog_data => {} );

    return { result => $data };
}

sub invite {
    my ( $self ) = @_;

    my $invite_emails = CTX->request->param('emails');
    my $invite_users = CTX->request->param('users');

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = $self->param('target_group_id');

    my $inviter_id = CTX->request->auth_user_id;

    my $uids = $invite_users || '';
    my $user_ids = [ map { ( $_ =~ /^\d+$/ ) ? $_ : () } split( /\s*,\s*/, $uids ) ];

    my $addresses = Dicole::Utils::Mail->string_to_addresses( $invite_emails );
    my %addresses = map { lc( $_ ) => 1 } @$addresses;

    my $users = CTX->lookup_object('user')->fetch_group( {
#         where => Dicole::Utils::SQL->column_in_strings( email => [ keys %addresses ] ) .
#             ' OR ' . Dicole::Utils::SQL->column_in( user_id => $user_ids ),
        where => Dicole::Utils::SQL->column_in( user_id => $user_ids ),
    } );

    # Add all user's emails to invite emails so that people who are stripped in the
    # following still get an email.

    my $user_emails = join ",", ( map { Dicole::Utils::User->email_with_name( $_ )} @$users );
    $invite_emails = join ",", ( $invite_emails || (), $user_emails || () );

    my $valid_domain_users = Dicole::Utils::User->filter_list_to_domain_users( $users, $domain_id );

    my $level = CTX->request->param('level');
    $level = 'user' if $level eq 'admin' && ! $self->_current_user_can_invite_as_admin;

    my %processed_addresses = ();
    for my $user ( @$valid_domain_users ) {
        if ( CTX->request->param('add_instantly') ) {
            next if $processed_addresses{ lc( Dicole::Utils::User->sanitized_email( $user ) ) }++;
            my $as_admin = ( $level eq 'admin' ) ? 1 : 0;
            $self->_ensure_user_in_group_and_domain( $user, $group_id, $domain_id, $as_admin );
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg( '[_1] added to area', $user->email )
            );
        }
    }

    my $address_objects = Dicole::Utils::Mail->string_to_address_objects( $invite_emails );
    for my $ao ( @$address_objects ) {
        next if $processed_addresses{ lc( Dicole::Utils::Text->ensure_utf8( $ao->address ) ) }++;
        my $address = Dicole::Utils::Text->ensure_utf8( $ao->original );

        $self->_create_invitation(
            Dicole::Utils::Domain->guess_current( $domain_id ),
            $self->param('target_group'),
            $address,
            $level,
        );
    }

    return { result => { success => 1 } };
}

1;

__END__
