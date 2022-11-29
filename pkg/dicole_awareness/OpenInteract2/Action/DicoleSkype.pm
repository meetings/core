package OpenInteract2::Action::DicoleSkype;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Widget::Image;
use LWP::UserAgent;
use HTTP::Status             qw( RC_OK );
use XML::Simple;

use constant HTTP_REQUEST_TIMEOUT => 5; # seconds

use constant STATUS_URL_PREFIX => 'http://mystatus.skype.com/';
use constant STATUS_URL_SUFFIX => '.num'; # numerical representation of status

use constant STATUS_UNKNOWN => 0;

use constant STATUS_TEXT => {
    0 => 'Unknown',
    1 => 'Offline',
    2 => 'Online',
    3 => 'Away',
    4 => 'Not Available',
    5 => 'Do Not Disturb',
    6 => 'Invisible',
    7 => 'Skype Me'
};

use constant XML_ROOT_NAME  => 'skype_status';
use constant XML_KEY_PREFIX => 'user_';

our $VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub status {
    my ( $self ) = @_;

    my $group_id = CTX->request->active_group;

    $group_id || return undef; # XXX: is this needed?

    my $iter = CTX->lookup_object( 'user' )->fetch_iterator( {
        where => "dicole_group_user.groups_id = ? AND 
                  dicole_group_user.user_id = sys_user.user_id",
        value => [ $group_id ],
        from  => [ 'sys_user', 'dicole_group_user' ]
    } );

    my $status_data = {};
    
    while ( $iter->has_next ) {
        my $user = $iter->get_next;
        my $profile = CTX->lookup_object( 'profile' )->fetch_group( {
            where => 'user_id = ?',
            value => [ $user->{ user_id } ]
        } );
        defined( $profile->[0] ) ? $profile = $profile->[ 0 ] : next;

        $profile->{ skype } || next;
        
        my $url = STATUS_URL_PREFIX . $profile->{ skype } . STATUS_URL_SUFFIX;
        
        my $ua = LWP::UserAgent->new;
        $ua->timeout( HTTP_REQUEST_TIMEOUT );
        
        my $req = HTTP::Request->new( GET => $url );
        my $res = $ua->request( $req );
        
        my $status_code = STATUS_UNKNOWN;
        $res->is_success && ( $status_code = $res->content ); # XXX

        # Make sure contains only numbers       
        $status_code =~ tr/0-9//cd;

        my $status_text_key = STATUS_TEXT->{ $status_code };
        my $status_text     = $self->_msg( $status_text_key );
        
        my $params = {
            user_id     => $user->{ user_id },
            login_name  => $user->{ login_name },
            skype_name  => $profile->{ skype },
            status_code => $status_code,
            status_text => $status_text,
        };

        my $key = XML_KEY_PREFIX . $user->{ user_id };
        $status_data->{ $key } = $params;
    }

    my $xs  = XML::Simple->new;
    my $xml = $xs->XMLout( $status_data, RootName => XML_ROOT_NAME );

    CTX->response->content_type( 'text/xml' );
    CTX->response->status( RC_OK );
    CTX->controller->no_template( 'yes' );

    return $xml;
}

1;
