package OpenInteract2::Action::DicoleNetworkingRaw;
use strict;
use base qw( OpenInteract2::Action::DicoleNetworkCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::MessageHandler qw( :message );
use Dicole::Widget::KVListing;
use Dicole::Widget::FancyContainer;
use HTML::Entities;
use List::Util;

use constant MAX_IMAGE_SIZE => 240;
use constant MAX_THUMB_SIZE => 30;

$OpenInteract2::Action::DicoleNetworkingRaw::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub image {
    my ( $self ) = @_;
    my $user_id = $self->param('user_id');

    my $profile = $self->_get_profile_object( $user_id );

    my $width = $self->param('width') || 240;
    my $height = $self->param('height') || 0;
    CTX->response->header( 'Cache-Control', 'private, max-age=300' );
    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $profile->portrait,
        group_id => 0,
        user_id => 0,
        thumbnail => 1,
        force_width => $width,
        force_height => $height,
    } );

    return ""
}

sub get_information_as_vcard {
    my ( $self ) = @_;

    my $uid = $self->param('user_id');
    my $usr = CTX->lookup_object('user')->fetch( $uid );
    my $profile = $self->_get_profile_object( $uid );
    die 'security error' unless $profile;

    my $params = {};
    $params = {
        fname => $usr->first_name,
        lname => $usr->last_name,
        organization => $profile->contact_organization,
        title => $profile->contact_title,
        professional_description => $profile->prof_description,
        tel_home =>  $profile->contact_phone,
        tel_work => $profile->employer_phone,,
        email => $profile->contact_email,
        home_address_1 => $profile->contact_address_1,
        home_address_2 => $profile->contact_address_2,
        skype =>  $profile->contact_skype,
        blog =>  $profile->personal_blog,
        facebook =>  $profile->personal_facebook,
        twitter =>  $profile->personal_twitter,
        linkedin =>  $profile->personal_linkedin,
        motto =>  $profile->personal_motto,
        about_me =>  $profile->about_me,
        employer_title => $profile->employer_title,
        employer_name => $profile->employer_name,
        employer_address_1 => $profile->employer_address_1,
        employer_address_2 => $profile->employer_address_2,
    };

    CTX->response->content_type( 'text/x-vcard' ); 
    return $self->generate_content(
        $params, { name => 'dicole_networking::generate_xml' }
    );

}


1;

