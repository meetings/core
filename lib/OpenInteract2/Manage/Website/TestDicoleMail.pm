package OpenInteract2::Manage::Website::TestDicoleMail;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use MIME::Lite ();

sub get_name {
    return 'test_dicole_mail';
}

sub get_brief_description {
    return "Testi mail sending from Dicole";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        address => {
       		description => 'Address to send mail to',
        	is_required => 'yes',
    	},
        content => {
            description => 'Content of the message',
            is_required => 'no',
        },
    };
}

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'address' ) {
        unless ( $value and $value =~ /\@/ ) {
            return "Must be a valid email address";
        }
    }
    return $self->SUPER::validate_param( $name, $value );
}

sub run_task {
    my ( $self ) = @_;
    
    my $smtp_host = OpenInteract2::Util->_get_smtp_host( {} );
    MIME::Lite->send( 'smtp', $smtp_host, Timeout => 10 );
    
    my $address = $self->param( 'address' );
    my $subject = 'Dicole mail testing message';
    my $content = $self->param( 'content' ) || 'Dicole has succesfully sent you this message :)';
    $content = Dicole::Utils::Text->ensure_utf8( $content );
    
    my $msg = MIME::Lite->new(
        OpenInteract2::Util->_build_header_info( {
            to => $address,
            subject => $subject,
        } ),
        Type =>'multipart/alternative',
    );
    $msg->attr( 'content-type.charset' => 'utf-8' );

    $msg->attach(
        Type => 'text/plain',
        Data => $content,
    );
    $msg->attach(
        Type => 'text/html',
        Data => '<p>' . $content . '</p>',
    );

    $msg->send || die "Cannot send message: $!";
    $self->notify_observers( progress => "Mail sent to $address" );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
