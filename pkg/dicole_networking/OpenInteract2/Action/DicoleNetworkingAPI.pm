package OpenInteract2::Action::DicoleNetworkingAPI;

use strict;
use base qw( OpenInteract2::Action::DicoleNetworkCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::MessageHandler qw( :message );
use Dicole::Widget::KVListing;
use HTML::Entities;
use List::Util;
use Dicole::URL;

sub user_profile_url {
    my ( $self ) = @_;


    my $params = $self->param('params');
    return Dicole::URL->create_from_parts(
        action => 'networking',
        task => 'show_profile',
        target => $self->param('group_id') || 0,
        additional => [ $self->param('user_id') ] ,
        domain_id => $self->param('domain_id'),
        $params ? ( params => $params ) : (),
    );

}

sub add_contact {
    my ( $self ) = @_;
    
    return 0 unless
        CTX->lookup_object('user')->fetch(
            $self->param('contacted_user_id')
        )
        &&
        CTX->lookup_object('user')->fetch(
            $self->param('contacting_user_id')
        );

    $self->_add_contact(
        $self->param('contacting_user_id'),
        $self->param('contacted_user_id'),
        $self->param('domain_id'),
    );

    return 1;
}

sub remove_contact {
    my ( $self ) = @_;
    
    $self->_remove_contact(
        $self->param('contacting_user_id'),
        $self->param('contacted_user_id'),
        $self->param('domain_id'),
    );
    
   return 1;
}

sub user_contact_ids {
    my ( $self ) = @_;

    return $self->_get_contact_id_list(
        $self->param('user_id'),
        $self->param('group_id'),
        $self->param('domain_id'),
    );
}

sub user_contacts {
    my ( $self ) = @_;

    my $ids = $self->user_contact_ids;

    return CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => $ids ),
    } ) || [];
}

sub is_user_contact {
    my ( $self ) = @_;

    my $contact_map = $self->_get_contact_id_map( $self->param('contacting_user_id'), 0, $self->param('domain_id'), );

    return $contact_map->{ $self->param('contacted_user_id') } ? 1 : 0
}

sub user_portrait {
    my ( $self ) = @_;
    
    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );
    return $self->_get_portrait( $profile, $self->param('no_default') );
}

sub user_portrait_thumb {
    my ( $self ) = @_;

    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );
    return $self->_get_portrait_thumb( $profile, $self->param('size'), $self->param('no_default') );
}

sub update_portrait_from_upload {
    my ( $self ) = @_;

    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );
    return $self->_update_portrait_from_upload( $profile, $self->param('upload_param') );
}

sub user_profile_attribute {
    my ( $self ) = @_;

    my $obj = $self->param('profile_object') || $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );

    if ( defined( $self->param('value') ) ) {
        $obj->set( $self->param('name'), $self->param('value') );
        $obj->save;
    }
    return $obj->get( $self->param('name') );
}

sub user_profile_attributes {
    my ( $self ) = @_;

    my $obj = $self->param('profile_object') || $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );

    my $attributes = $self->param('attributes') || {};

    my $save = 0;
    for ( keys %$attributes ) {
        if ( defined( $attributes->{$_} ) ) {
            $obj->set( $_, $attributes->{$_} );
            $save = 1;
        }
    }
    $obj->save if $save;

    for ( keys %$attributes ) {
        $attributes->{$_} = $obj->get( $_ );
    }

    return $attributes;
}

sub user_profile_object {
    my ( $self ) = @_;

    return $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );
}

sub user_profile_object_map {
    my ( $self ) = @_;

    return $self->_get_profile_object_map( scalar( $self->param('user_id_list') ), $self->param('domain_id') );
}

sub user_profile_tags {
    my ( $self ) = @_;

    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') );

    my $tags = CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
        object => $profile,
        group_id => 0,
        user_id => 0,
    } );

    return $tags;
}

sub add_tags_to_user_profile {
    my ( $self ) = @_;

    return CTX->lookup_action('tagging')->execute( attach_tags => {
        object => $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') ),
        group_id => 0,
        user_id => 0,
        domain_id => $self->param('domain_id'),
        values => [ $self->param('tags') ]
    } );
}

sub remove_tags_from_user_profile {
    my ( $self ) = @_;

    return CTX->lookup_action('tagging')->execute( detach_tags => {
        object => $self->_get_profile_object( $self->param('user_id'), $self->param('domain_id') ),
        group_id => 0,
        user_id => 0,
        domain_id => $self->param('domain_id'),
        values => [ $self->param('tags') ]
    } );
}

sub update_tags_for_user_profile_from_json {
    my ( $self ) = @_;
    
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );
    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $domain_id );

    return unless $profile;

    return CTX->lookup_action('tags_api')->execute( update_tags_from_json => {
        object => $profile,
        group_id => 0,
        user_id => 0,
        domain_id => $domain_id,
        json => $self->param('json'),
        json_old => $self->param('json_old'),
    } );
}

sub update_image_for_user_profile_from_draft {
    my ( $self ) = @_;

    my $draft_id = $self->param('draft_id');

    return unless $draft_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );
    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $domain_id );

    return unless $profile;

    if ( $draft_id > 0 ) {
        my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
            draft_id => $draft_id,
            object => $profile,
            group_id => 0,
            user_id => 0,
            domain_id => $domain_id,
        } ) || '';

        if ( $id ) {
            $profile->portrait( $id );
            $profile->save;
        }

        return $id;
    }

    $profile->portrait( '' );
    $profile->save;

    return '';
}

sub update_image_for_user_profile_from_url {
    my ( $self ) = @_;

    my $url = $self->param('url');

    return unless $url;

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );
    my $profile = $self->param('profile_object') ||
        $self->_get_profile_object( $self->param('user_id'), $domain_id );

    return unless $profile;

    my $image_bits = Dicole::Utils::HTTP->get( $url );

    return unless $image_bits;

    my @path = split /\//, $url;
    my $filename = $path[-1] || 'image.jpg';

    my $a = CTX->lookup_action('attachments_api')->e( store_from_bits => {
            bits => $image_bits,
            filename => $filename,
            object => $profile,
            group_id => 0,
            user_id => 0,
            domain_id => $domain_id,        
    } );

    if ( $a ) {
        $profile->portrait( $a->id );
        $profile->save;
    }

    return ();
}


1;
