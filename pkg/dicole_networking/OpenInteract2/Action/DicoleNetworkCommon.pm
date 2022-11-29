package OpenInteract2::Action::DicoleNetworkCommon;
use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utility;
use Image::Magick;

use Dicole::MessageHandler qw( :message );

use constant MAX_IMAGE_SIZE => 240;
use constant MAX_THUMB_SIZE => 30;
sub DEFAULT_PROFILE_LIST_SIZE { 10 }

sub _generate_profile_list_script_data_json {
    my ( $self, $gid, $info ) = @_;

    my $script_data = {
        skip_data => Dicole::Utils::JSON->encode( $info->{skip} || {} ),
        more_url => Dicole::URL->from_parts(
            action => 'network_json', task => 'more_profiles', target => $gid,
        ),
    };

    return Dicole::Utils::JSON->encode( $script_data );
}

sub _search_to_like {
    my ( $self, $search ) = @_;

    my $like = $search;
    $like =~ s/[^a-z]/%/gi;
    $like =~ s/\%+/%/gi;
    return "%$like%";
}

sub _fetch_profile_list_info {
    my ( $self, $gid, $domain_id, $size, $state ) = @_;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];
    my $search = $state->{search} || '';

    my $shown_profiles = $state->{shown_profiles} || [];
    my $profiles = CTX->lookup_action('tagging')->execute( tag_limited_fetch_group => {
        object_class => CTX->lookup_object('networking_profile'),
        from => [ 'dicole_group_user', $search ? ( 'sys_user' ) : () ],
        where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
            'dicole_group_user.groups_id = ? AND dicole_networking_profile.domain_id = ?' .
            ( $search ? ' AND sys_user.user_id = dicole_group_user.user_id AND sys_user.name LIKE ?' : '' ).
            ' AND ' . Dicole::Utils::SQL->column_not_in( 'dicole_networking_profile.profile_id' => $shown_profiles ),
        value => [ $gid, $domain_id, $search ? ( $self->_search_to_like( $search ) ) : () ],
        tags => $tags,
        user_id => 0,
        group_id => 0,
        domain_id => $domain_id,
    } ) || [];

    my %profiles_by_uid = map { $_->user_id => $_ } @$profiles;

    my %uid_map = map { $_->user_id < 2 ? () : ( $_->user_id => 1 ) } @$profiles;
    my $uids = [ keys %uid_map ];

    my $users = CTX->lookup_object( 'user' )->fetch_group( {
        where => Dicole::Utils::SQL->column_in( 'sys_user.user_id', $uids ),
    } ) || [];

    my $object_info_list = [];
    for my $user ( sort { lc( $a->last_name ) cmp lc( $b->last_name ) } @$users ) {
        my $profile = $profiles_by_uid{ $user->id };
        push @$shown_profiles, $profile->id;
        my $hash = Dicole::Utils::User->icon_hash( $user, 55, $gid, $domain_id, $profile, $search ? { search => $search } : () );
        my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
            object => $profile,
            user_id => 0,
            group_id => 0,
        } );
        $hash->{tags} = [ map { {
            name => $_, link => $self->derive_url( action => 'networking', task => 'browse', additional => [ $_ ] )
        } } @$tags ];

        push @$object_info_list, $hash;
        last if scalar( @$object_info_list ) >= $size;
    }

    $state->{shown_profiles} = $shown_profiles;

    return {
        object_info_list => $object_info_list,
        state => $state,
        end_of_pages => ( scalar( @$users ) > scalar( @$object_info_list ) ? 0 : 1 ),
        count => scalar( @$users ),
    };
}

sub _fetch_profile_filter_links {
    my ( $self, $gid, $domain_id, $limit, $state ) = @_;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];
    my $search = $state->{search} || '';

    my $weighted_tags = CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group_weighted_tags', {
        object_class => CTX->lookup_object('networking_profile'),
        from => [ 'dicole_group_user', $search ? ( 'sys_user' ) : () ],
        tags => $tags,
        where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
            'dicole_group_user.groups_id = ? AND ' . 
            'dicole_networking_profile.user_id != ? AND ' .
            'dicole_networking_profile.domain_id = ?' . 
            ( $search ? ' AND sys_user.user_id = dicole_group_user.user_id AND sys_user.name LIKE ?' : '' ),
        value => [ $gid, 1, $domain_id, $search ? ( $self->_search_to_like( $search ) ) : () ],
        group_id => 0,
        user_id => 0,
    } );

    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => '#',
        limit => $limit,
    );

    my %tag_lookup = map { $_ => 1 } @$tags;
    $weighted_tags = [ map { $tag_lookup{$_->[0]} ? () : $_ } @$weighted_tags ];

    $cloud->add_weighted_tags_array( $weighted_tags );
    return $cloud->template_params->{links};
}

sub _add_contact {
    my ( $self, $uid, $contacted_uid, $domain_id ) = @_;

    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    my $new = CTX->lookup_object('networking_contact')->new();
    $new->user_id( $uid );
    $new->contacted_user_id( $contacted_uid );
    $new->domain_id( $domain_id );
    $new->save;

    # clear duplicates.
    my $objects = $self->_get_contact_objects(
        $uid, $contacted_uid, $domain_id
    );

    pop @$objects;
    $_->remove for @$objects;
}

sub _remove_contact {
    my ( $self, $uid, $contacted_uid, $domain_id ) = @_;

    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    my $objects = $self->_get_contact_objects(
        $uid, $contacted_uid, $domain_id
    );

    $_->remove for @$objects;
}

sub _get_contact_objects {
    my ( $self, $uid, $cuid, $domain_id ) = @_;

    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    return CTX->lookup_object('networking_contact')->fetch_group( {
        where => 'user_id = ? AND contacted_user_id = ? AND domain_id = ?',
        value => [ $uid, $cuid, $domain_id ],
    } ) || [];
}

sub _init_tool {
    my ( $self, %args ) = @_;
    
    $self->init_tool( {
        tool_args => { no_tool_tabs => 1 },
        %args
    } );
    $self->tool->Container->column_width( '280px', 1 ) if $args{cols} > 1;
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( src => '/js/dicole_networking.js' ),
    );
    
}

sub _determine_targets_with_profile {
    my ( $self ) = @_;

    my ( $gid, $uid, $user ) = $self->_determine_targets;
    my $profile = $self->_get_profile_object( $uid );

    if ( ! $profile ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg("Requsted user was not found.") );
        die $self->redirect( $self->derive_url( task => 'explore', additional => [] ) );
    }

    return ( $gid, $uid, $user, $profile );
}

sub _determine_targets {
    my ( $self ) = @_;
    
    my $gid = 0;
    if ( $self->param('target_type') eq 'group' ) {
        $gid = $self->param('target_group_id');
        die "security error" unless $gid;
    }
    
    my $uid = $self->param('user_id');
    if ( $self->param('target_type') eq 'user' ) {
        $uid = $self->param('target_user_id');
    }
    
    if ( $uid && $gid && ! Dicole::Utility->user_belongs_to_group( $uid, $gid ) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg("Requested user was not found.") );
        die $self->redirect( $self->derive_url( task => 'explore', additional => [] ) );
    }
    
    my $user = $uid ? CTX->lookup_object('user')->fetch( $uid ) : 0;
    
    return ( $gid, $uid, $user );
}

# XXX: There is a problem with these if tool is not initiated...
sub _get_portrait {
    my ( $self, $profile, $no_default ) = @_;

    if ( $profile && $profile->portrait =~ /^\d+$/ ) {
        return Dicole::URL->from_parts(
            domain_id => $profile->domain_id,
            action => 'networking_raw',
            task => 'image',
            target => 0,
            additional => [ $profile->user_id, 200, 200, 'portrait.png' ],
        );
    }

    return $self->_get_portrait_thumb( $profile, 200, $no_default );

    return $profile->portrait if $profile && $profile->portrait;
    return $no_default ? undef : $self->_get_theme_images_base . 'unknown-user.gif';
}

# XXX: There might be a problem with these if tool is not initiated...
sub _get_portrait_thumb {
    my ( $self, $profile, $size, $no_default ) = @_;

    if ( $profile && $profile->portrait =~ /^\d+$/ ) {
        return Dicole::URL->from_parts(
            domain_id => $profile->domain_id,
            action => 'networking_raw',
            task => 'image',
            target => 0,
            additional => [ $profile->user_id, $size || 90, $size || 90, 'portrait.png' ],
        );
    }

    if ( $size && $size =~ /^\d+$/ ) {
        my $portrait = $profile ? $profile->portrait : '';
        if ( ! $portrait ) {
            return $no_default ? undef : $self->_get_theme_images_base . 'unknown-user-mini.gif';
        }
        my ( $uid, $random ) = $portrait =~ /\/(\d+?)_(.+?)\.jpg$/;
        my $big_file = $self->_create_image_filename_path( $uid, $random );
        my $small_file = $self->_create_image_filename_path( $uid, $random, $size );
        unless ( -f $small_file ) {
            $self->_create_sized_profile_thumbnail( $big_file, $small_file, $size );
        }
        return $self->_create_image_url( $uid, $random, $size );
     }
    
    return $profile->portrait_thumb if $profile->portrait_thumb;
    return $no_default ? undef : $self->_get_theme_images_base . 'unknown-user-mini.gif';
}

sub _get_theme_images_base {
    my ( $self ) = @_;
    
    $self->init_tool unless $self->tool;
    my ( $css, $image ) = CTX->controller->_get_theme_css_params;
    
    return ( $image =~ /\/$/ ) ? $image : $image . '/';
}

sub _get_profile_objects_hash {
    my ( $self, $user_ids ) = @_;
    
    $user_ids ||= [];
    
    my $objects = CTX->lookup_object('networking_profile')->fetch_group( {
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( 'user_id', $user_ids ),
        value => [ $self->_current_domain_id ]
    } ) || [];
    
    my %lookup = map { $_->{user_id} => $_ } @$objects;
    for my $uid ( @$user_ids ) {
        $lookup{ $uid } ||= $self->_create_profile_object( $uid );
    }

    return \%lookup;
}

sub _get_profile_object {
    my ( $self, $user_id, $domain_id ) = @_;
    
    return undef unless $user_id;
    
    my $objects = CTX->lookup_object('networking_profile')->fetch_group( {
        where => 'user_id = ? AND domain_id = ?',
        value => [ $user_id, $domain_id || $self->_current_domain_id ],
        limit => 1,
    } ) || [];
    
    my $object = $objects->[0];
    
    unless ( $object ) {
        $object = $self->_create_profile_object( $user_id, $domain_id );
    }
    
    return $object;
}

sub _get_profile_object_map {
    my ( $self, $user_id_list, $domain_id ) = @_;
    
    my $objects = CTX->lookup_object('networking_profile')->fetch_group( {
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => $user_id_list ),
        value => [ $domain_id || $self->_current_domain_id ],
    } ) || [];

    my %map = map { $_->user_id => $_ } reverse( @$objects );
   
    for my $user_id ( @$user_id_list ) {
        $map{ $user_id } ||= $self->_create_profile_object( $user_id, $domain_id );
    }
    
    return \%map;
}

sub _create_profile_object {
    my ( $self, $user_id, $domain_id ) = @_;

    my $object = CTX->lookup_object('networking_profile')->new;
    $object->user_id( $user_id );
    $object->domain_id( $domain_id || $self->_current_domain_id );
    $object->save;
    
    return $object;
}

sub _get_contact_id_list {
    my ( $self, $user_id, $group_id, $domain_id ) = @_;

    $user_id ||= CTX->request->auth_user_id;
    $group_id = $self->param('target_group_id') unless defined( $group_id );
    $domain_id = $self->_current_domain_id unless defined( $domain_id );
    
    my $objects = $group_id ?
        CTX->lookup_object('networking_contact')->fetch_group( {
            from => ['dicole_networking_contact', 'dicole_group_user'],
            where => 'dicole_networking_contact.contacted_user_id = dicole_group_user.user_id AND ' .
                'dicole_networking_contact.user_id = ? AND dicole_group_user.groups_id = ? AND ' .
                'dicole_networking_contact.domain_id = ?',
            value => [ $user_id, $group_id, $domain_id ],
        } )
        :
        CTX->lookup_object('networking_contact')->fetch_group( {
            where => 'dicole_networking_contact.user_id = ? AND ' .
                'dicole_networking_contact.domain_id = ?',
            value => [ $user_id, $domain_id ],
        } );

    return [ sort map { $_->contacted_user_id } @$objects ];
}

sub _get_contact_id_list_for_users {
    my ( $self, $user_ids, $group_id ) = @_;
    
    $group_id ||= $self->param('target_group_id');

    my $objects = CTX->lookup_object('networking_contact')->fetch_group( {
        from => ['dicole_networking_contact', 'dicole_group_user'],
        where => Dicole::Utils::SQL->column_in( 'dicole_networking_contact.user_id', $user_ids ) . 
            'dicole_networking_contact.contacted_user_id = dicole_group_user.user_id AND '.
            'dicole_group_user.groups_id = ? AND dicole_networking_contact.domain_id = ?',
        value => [ $group_id, $self->_current_domain_id ],
    } );
    
    my %hash = map { $_->contacted_user_id => 1 } @$objects;
    
    return [ sort keys %hash ];
}

sub _get_contact_id_map_with_list {
    my ( $self, $user_id_list ) = @_;
    
    return { map { $_ => 1 } @$user_id_list };
}

sub _get_contact_id_map {
    my ( $self, $user_id, $group_id, $domain_id ) = @_;
    
    my $user_id_list = $self->_get_contact_id_list( $user_id, $group_id, $domain_id );
    
    return { map { $_ => 1 } @$user_id_list };
}

sub _get_add_remove_contact_widget_without_container {
    my ( $self, $user_id, $contact_map, $auth_id, $group_id ) = @_;
    
    $auth_id ||= CTX->request->auth_user_id;
    $group_id ||= $self->param('target_group_id');
    $contact_map ||= $self->_get_contact_id_map( $auth_id, $group_id );
    
    return $contact_map->{ $user_id } ?
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url(
                action => 'networking_json',
                task => 'remove_contact',
                target => $auth_id,
                additional => [ $user_id, $group_id ],
            ),
            content => $self->_msg( 'Remove contact' ),
            class => 'networking_remove_contact_button ' .
                'networking_toggle_contact_button ' .
                'networking_toggle_contact_button_id_' . $user_id,
        ) :
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url(
                action => 'networking_json',
                task => 'add_contact',
                target => $auth_id,
                additional => [ $user_id, $group_id ],
            ),
            content => $self->_msg( 'Add contact' ),
            class => 'networking_add_contact_button '.
                'networking_toggle_contact_button ' .
                'networking_toggle_contact_button_id_' . $user_id,
         );
}

sub _get_add_remove_contact_widget {
    my ( $self, $user_id, $contact_map, $auth_id, $group_id ) = @_;
    
    $group_id ||= $self->param('target_group_id');
    
    return Dicole::Widget::Container->new(
        class => 'networking_toggle_contact_container '.
            'networking_toggle_contact_button_id_' . $user_id . '_container',
        contents => [ $self->_get_add_remove_contact_widget_without_container(
            $user_id, $contact_map, $auth_id, $group_id
        ) ]
    );
}

sub _get_profile_card_list_widget {
    my ( $self, $gid, $users, $target_user_id, $contact_ids, $group_id ) = @_;
    
    my $auth_id = CTX->request->auth_user_id;
    $group_id ||= $self->param('target_group_id');
    $contact_ids ||= $self->_get_contact_id_list( $target_user_id );
    my $auth_contact_id_map = $self->_get_contact_id_map( $auth_id, $group_id );
    
    my $profiles = $self->_get_profile_objects_hash(
        [ map { $_->id } @$users ]
    );
    
    my $user_widgets = [];
    for my $user ( sort { lc($a->last_name) cmp lc($b->last_name) } @$users ) {
        my $profile = $profiles->{ $user->id };
        my @add_remove_widgets = ();
        
        if ( $self->schk_y(
                'OpenInteract2::Action::DicoleNetworking::manage_contacts',
                $auth_id
            ) ) {
            
            @add_remove_widgets = $self->_get_add_remove_contact_widget(
                $user->id, $auth_contact_id_map, $auth_id
            );
        }
        
        my $company_title = ();
        if ( CTX->request->auth_user_id ) {
            if ( $profile->contact_title || $profile->contact_organization ) {
                $company_title = join( ', ',
                    $profile->contact_title || (),
                    $profile->contact_organization || ()
                );
            }
            else {
                $company_title = join( ', ',
                    $profile->employer_title || (),
                    $profile->employer_name || ()
                );
            }
        }
        
        my $profile_link = $gid ? Dicole::URL->from_parts(
                action => 'networking',
                task => 'profile',
                target => $gid,
                additional => [ $user->id ],
            )
            :
            Dicole::URL->from_parts(
                action => 'community_networking',
                task => 'profile',
                target => $gid,
                additional => [ $user->id ],
            );
        
        push @$user_widgets, Dicole::Widget::Container->new(
            class => 'networking_profile_card',
            contents => [
                Dicole::Widget::Columns->new(
                    left => Dicole::Widget::Image->new(
                        src => $self->_get_portrait_thumb( $profile ),
                        width => '30px',
                        height => '30px',
                    ),
                    right => Dicole::Widget::Vertical->new( contents => [
                        Dicole::Widget::Vertical->new(
                            class => 'networking_profile_card_info',
                            contents => [
                                Dicole::Widget::Hyperlink->new(
                                    link => $profile_link,
                                    content => $user->last_name .
                                        ', ' . $user->first_name,
                                ),
                                $company_title,
                            ]
                        ),
                        @add_remove_widgets,
                    ] ),
                    left_class => 'networking_profile_card_left',
                    left_td_class => 'networking_profile_card_td_left',
                    right_class => 'networking_profile_card_right',
                    right_td_class => 'networking_profile_card_td_right',
                    padding => 0,
                )
            ]
        );
    }
    
    return Dicole::Widget::Container->new(
        contents => [
            @$user_widgets,
            Dicole::Widget::Container->new(
                class => 'float_clearing',
                contents => [ Dicole::Widget::Raw->new( raw => '<!-- -->' ) ],
            ),
        ],
    );
    
    my @lists = (
        Dicole::Widget::Container->new,
        Dicole::Widget::Container->new,
    );
    
    my $count = 0;
    for my $widget ( @$user_widgets ) {
        $lists[ $count++ % 2 ]->add_content( $widget );
    }
    
    return Dicole::Widget::Columns->new(
        left => $lists[0],
        right => $lists[1],
    );
}

sub _update_portrait_from_upload {
    my ( $self, $profile, $upload_param ) = @_;

    my $uid = $profile->user_id;

    my $upload_obj = CTX->request->upload( $upload_param );
    if ( ref( $upload_obj ) && $upload_obj->filename && $upload_obj->filehandle ) {

        my $random = int( rand() * 900000 + 100000 );
        $random = int( rand() * 900000 + 100000 ) while -e
            $self->_create_original_filename_path( $uid, $random );

        my $files = Dicole::Files::Filesystem->new;
        $files->mkfile(
            $self->_create_original_filename( $uid, $random ),
            $upload_obj->filehandle, 1,
            CTX->lookup_directory( 'dicole_profilepics' )
        );

        # Write image in the users profile picture directory
        # along with a thumbnail
        my $success = $self->_create_profile_images( $uid, $random );
        if ( $success ) {

            # Save URL in the profile
            $profile->portrait( $self->_create_image_url( $uid, $random ) );
            $profile->portrait_thumb( $self->_create_image_url( $uid, $random, 't' ) );
            $profile->save;

            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 0;
    }
}

sub _create_profile_images {
    my ( $self, $uid, $random ) = @_;

    my $image = Image::Magick->new;
    return undef if $self->_check_magick_error( $image->Read(
        $self->_create_original_filename_path( $uid, $random )
    ) );
    my $i_width = $image->Get( 'width' );
    my $i_height = $image->Get( 'height' );

    $i_height = int( $i_height * MAX_IMAGE_SIZE / $i_width );
    $i_width = MAX_IMAGE_SIZE;
    
    return undef if $self->_check_magick_error( $image->Scale(
        width => $i_width, height => $i_height
    ) );
    
    return undef if $self->_check_magick_error( $image->Write(
        $self->_create_image_filename_path( $uid, $random )
    ) );

    # we presume here that the image is bigger than the thumbnail
    my $xcrop = 0;
    my $ycrop = 0;
    if ( $i_height > $i_width ) {
        $i_height = int( $i_height * MAX_THUMB_SIZE / $i_width );
        $i_width = MAX_THUMB_SIZE;
        $ycrop = int( ( $i_height - $i_width ) / 2 );
    }
    elsif ( $i_width > $i_height ) {
        $i_width = int( $i_width * MAX_THUMB_SIZE / $i_height );
        $i_height = MAX_THUMB_SIZE;
        $xcrop = int( ( $i_width - $i_height ) / 2 );
    }
    else {
        $i_width = MAX_THUMB_SIZE;
        $i_height = MAX_THUMB_SIZE;
    }
    
    return undef if $self->_check_magick_error( $image->Scale(
        width => $i_width, height => $i_height
    ) );
    
    return undef if $self->_check_magick_error( $image->Crop(
        width => MAX_THUMB_SIZE, height => MAX_THUMB_SIZE,
        x => $xcrop, y => $ycrop
    ) );
    
    return undef if $self->_check_magick_error( $image->Write(
        $self->_create_image_filename_path( $uid, $random, 't' )
    ) );

    return 1;
}

sub _create_sized_profile_thumbnail {
    my ( $self, $image_file, $thumbnail_file, $size ) = @_;

    my $image = Image::Magick->new;

    return undef if $self->_check_magick_error( $image->Read(
        $image_file
    ) );

    my $i_width = $image->Get( 'width' );
    my $i_height = $image->Get( 'height' );

    my $xcrop = 0;
    my $ycrop = 0;
    if ( $i_height > $i_width ) {
        $i_height = int( $i_height * $size / $i_width );
        $i_width = $size;
        $ycrop = int( ( $i_height - $i_width ) / 2 );
    }
    elsif ( $i_width > $i_height ) {
        $i_width = int( $i_width * $size / $i_height );
        $i_height = $size;
        $xcrop = int( ( $i_width - $i_height ) / 2 );
    }
    else {
        $i_width = $size;
        $i_height = $size;
    }
    
    return undef if $self->_check_magick_error( $image->Scale(
        width => $i_width, height => $i_height
    ) );
    
    return undef if $self->_check_magick_error( $image->Crop(
        width => $size, height => $size,
        x => $xcrop, y => $ycrop
    ) );
    
    return undef if $self->_check_magick_error( $image->Write(
        $thumbnail_file
    ) );

    return 1;
}

sub _complete_external_service_links {
    my ( $self, $data ) = @_;

    my $link;

    if ( $link = $data->{user_facebook} ) {
        $link = 'http://www.facebook.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{user_facebook} = $link;
    }

    if ( $link = $data->{user_linkedin} ) {
        $link = 'http://www.linkedin.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{user_linkedin} = $link;
    }

    if ( $link = $data->{user_twitter} ) {
        $link = 'http://www.twitter.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{user_twitter} = $link;
    }

    if ( $link = $data->{user_webpage} ) {
        $link = 'http://' . $link unless $link =~ /^http\:\/\//;
        $data->{user_webpage} = $link;
    }

    return $data;
}

sub _create_image_url {
    my ( $self, @parts ) = @_;

    my $html = CTX->lookup_directory( 'html' );
    my $path = CTX->lookup_directory( 'dicole_profilepics' );
    $path =~ s/^$html//;

    return $path . '/' . $self->_create_image_filename( @parts );
}

sub _create_image_filename {
    my ( $self, @parts ) = @_;
    return join( '_', @parts) . '.jpg';
}

sub _create_image_filename_path {
    my ( $self, @parts ) = @_;
    return CTX->lookup_directory( 'dicole_profilepics' ) . '/' .
        $self->_create_image_filename( @parts );
}

sub _create_original_filename {
    my ( $self, @parts ) = @_;
    return join( '_', ( @parts, 'original' ));
}

sub _create_original_filename_path {
    my ( $self, @parts ) = @_;
    return CTX->lookup_directory( 'dicole_profilepics' ) . '/' .
        $self->_create_original_filename( @parts );
}

sub _check_magick_error {
    my ( $self, $error ) = @_;
    return undef unless $error;
    $error =~ /(\d+)/;
    # Status code less than 400 is a warning
    $self->log( 'error',
        "Image::Magick returned status $error while resizing profile image"
    );
    if ( $1 >= 400 ) {
        return 1;
    }
    return undef;
}

sub _current_domain_id {
    my ( $self ) = @_;

    return Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );
}

1;
