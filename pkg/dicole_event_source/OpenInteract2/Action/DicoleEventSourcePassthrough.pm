package OpenInteract2::Action::DicoleEventSourcePassthrough;

use strict;

use base qw( OpenInteract2::Action::DicoleEventSourceCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub who_am_i {
    my ( $self ) = @_;

    my $auth_user = $self->param('auth_user');
    my $auth_domain_id = $self->param('auth_domain_id');


    return { result => {
#        name => Dicole::Utils::User->full_name( $auth_user ),
        user_id => $auth_user->id,
        domain_id => $auth_domain_id,
#         thumbnail => CTX->lookup_action('networking_api')->execute( user_portrait => {
#             domain_id => $auth_domain_id, user_id => $user_id, size => $self->param('thumbnail_size')
#         } ),
    } };

}

sub user_information {
    my ( $self ) = @_;

    my $auth_user = $self->param('auth_user');
    my $auth_domain_id = $self->param('auth_domain_id');
    my $user_id = $self->param('user') || $auth_user->id;

    return { result => {
        name => Dicole::Utils::User->full_name( $user_id ),
        thumbnail => CTX->lookup_action('networking_api')->execute( user_portrait => {
            domain_id => $auth_domain_id, user_id => $user_id, size => $self->param('thumbnail_size') || 50
        } ),
    } };
}

sub available_groups {
    my ( $self ) = @_;

    my $auth_user = $self->param('auth_user');
    my $auth_domain_id = $self->param('auth_domain_id');

    my $visible_info = CTX->lookup_action('groups_api')->execute( groups_infos_visible_to_user => {
        domain_id => $auth_domain_id,
        user_id => $auth_user->id,
    } );

    my $member_gids = CTX->lookup_action('groups_api')->execute( groups_ids_with_user_as_member => {
        domain_id => $auth_domain_id,
        user_id => $auth_user->id,
    } );

    my %member_hash = map { $_ => 1 } @$member_gids;

    my $groups = {};
    for my $key ( keys %$visible_info ) {
        $groups->{ $key } = {
            name => $visible_info->{ $key }->{name},
            is_member => $member_hash{ $key },
        };
    }

    return { result => {
        groups => $groups
    } };
}

sub data_for_users {
    my ( $self ) = @_;

    my $ids = $self->param('id_list');
    my $auth_domain_id = $self->param('auth_domain_id');

    my %data = ();

    for my $id ( @$ids ) {
        my $name = Dicole::Utils::User->name( $id );
        my $image = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $id,
            domain_id => $auth_domain_id,
            size => $self->param('contributor_image_size') || 50,
        } );

        my $aurl = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $id, domain_id => $auth_domain_id, group_id => $self->param('group_id')
        } );

        $data{ $id } = { name => $name, image => $image, url => $aurl };
    }

    return { result => {
        data_by_object_id => \%data,
    } };
}

sub _contributor_hashes_for_ids {
    my ( $self, $ids, $group_id, $auth_domain_id ) = @_;
    my $r = [];
    for my $c ( @$ids ) {
        my $name = Dicole::Utils::User->name( $c );
        my $image = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $c,
            domain_id => $auth_domain_id,
            size => $self->param('contributor_image_size') || 50,
        } );
        my $url = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $c, domain_id => $auth_domain_id, group_id => $group_id,
        } );
        push @$r, { name => $name, image => $image, id => $c, url => $url };
    }

    return $r;
}

sub data_for_blog_entries {
    my ( $self ) = @_;

    my $ids = $self->param('id_list');
    my $auth_domain_id = $self->param('auth_domain_id');

    my $datas = CTX->lookup_action('blogs_api')->e(
        data_for_entries => { ids => $ids, domain_id => $auth_domain_id }
    );

    my $result = ();

    for my $data ( @$datas ) {
        # TODO: add security checks here!

        my $group_id = $data->{entry}->group_id;

        my $info = {};

        $info->{$_} = $data->{$_} for ( qw (
            tags author_name comment_count
        ) );

        $info->{url} = $data->{show_url};
        $info->{comments_url} = $data->{show_comments_url};
        $info->{object_info_url} = Dicole::URL->from_parts(
            action => 'blogs_json', task => 'object_info',
            target => $group_id, domain_id => $auth_domain_id,
            additional => [ $data->{entry}->id ],
        );

        $info->{title} = $data->{post}->title;
        $info->{timestamp} = $data->{entry}->date;

        $info->{author_image} = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $data->{user}->id,
            domain_id => $auth_domain_id,
            size => $self->param('author_image_size') || 70,
        } );

        $info->{author_url} = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $data->{user}->id, domain_id => $auth_domain_id, group_id => $group_id,
        } );

        my $last_commenters = CTX->lookup_action('comments_api')->e( get_latest_commenters => {
            object => $data->{entry},
            group_id => $group_id,
            domain_id => $auth_domain_id,
            limit => $self->param('contributor_limit') || 5,
        } );

        $info->{contributors} = $self->_contributor_hashes_for_ids( $last_commenters, $group_id, $auth_domain_id );

        $result->{ $data->{entry}->id } = $info;
    }

    return { result => {
        data_by_object_id => $result,
    } };
}

sub data_for_wiki_pages {
    my ( $self ) = @_;

    my $ids = $self->param('id_list');
    my $auth_domain_id = $self->param('auth_domain_id');

    my $datas = CTX->lookup_action('wiki_api')->e(
        data_for_pages => { ids => $ids, domain_id => $auth_domain_id }
    );

    my $result = ();

    my $limit = $self->param('contributor_limit') || 5;

    for my $data ( @$datas ) {
        # TODO: add security checks here!
        my $group_id = $data->{page}->groups_id;

        my $info = {
            title => $data->{readable_title},
            timestamp => $data->{last_modified_time},
            url => $data->{show_url},
            comments_url => $data->{show_comments_url},
        };
        $info->{object_info_url} = Dicole::URL->from_parts(
            action => 'wiki_json', task => 'object_info',
            target => $group_id, domain_id => $auth_domain_id,
            additional => [ $data->{page}->id ],
        );

        my $comment_count = CTX->lookup_action('comments_api')->e( get_comment_count => {
            object => $data->{page},
            group_id => $group_id,
            domain_id => $auth_domain_id,
        } );

        $info->{comment_count} = $comment_count || 0;

        my $last_commenters_data = CTX->lookup_action('comments_api')->e( get_latest_commenters_data => {
            object => $data->{page},
            group_id => $group_id,
            domain_id => $auth_domain_id,
            limit => $limit,
        } );

        my $last_editors_data = CTX->lookup_action('wiki_api')->e( get_latest_editors_data => {
            page => $data->{page},
            domain_id => $auth_domain_id,
            limit => $limit,
        } );

        my %contributors = ();
        my @contributors = ();
        while ( scalar( @contributors ) < $limit - 1 && ( scalar( @$last_commenters_data ) || scalar( @$last_editors_data ) ) ) {
            my $commenter = $last_commenters_data->[0];
            my $editor = $last_editors_data->[0];

            if ( $editor && ( ( ! $commenter ) || ( $editor->{timestamp} >= $commenter->{timestamp} ) ) ) {
                push @contributors, $editor->{user_id} unless $contributors{ $editor->{user_id} }++;
                shift @$last_editors_data;
            }
            else {
                push @contributors, $commenter->{user_id} unless $contributors{ $commenter->{user_id} }++;
                shift @$last_commenters_data;
            }
        }

        $info->{contributors} = $self->_contributor_hashes_for_ids( \@contributors, $group_id, $auth_domain_id );

        $result->{ $data->{page}->id } = $info;
    }

    return { result => {
        data_by_object_id => $result,
    } };
}

sub data_for_media_objects {
    my ( $self ) = @_;

    my $ids = $self->param('id_list');
    my $auth_domain_id = $self->param('auth_domain_id');

    my $datas = CTX->lookup_action('presentations_api')->e(
        data_for_objects => { ids => $ids, domain_id => $auth_domain_id }
    );

    my $result = ();

    for my $data ( @$datas ) {
        # TODO: add security checks here!

        my $group_id = $data->{object}->group_id;

       my $info = {
            title => $data->{name},
            timestamp => $data->{creation_date},
            image => $data->{image},
            url => Dicole::URL->create_from_parts(
                action => 'presentations',
                task => 'show',
                target => $group_id,
                additional => [ $data->{object}->id ],
            ),
            comments_url => Dicole::URL->create_from_parts(
                action => 'presentations',
                task => 'show',
                target => $group_id,
                additional => [ $data->{object}->id ],
                anchor => 'comments',
            ),
        };
        $info->{object_info_url} = Dicole::URL->from_parts(
            action => 'presentations_json', task => 'object_info',
            target => $group_id, domain_id => $auth_domain_id,
            additional => [ $data->{object}->id ],
        );

        my $comment_count = CTX->lookup_action('comments_api')->e( get_comment_count => {
            object => $data->{object},
            group_id => $group_id,
            domain_id => $auth_domain_id,
        } );

        $info->{comment_count} = $comment_count || 0;

        $info->{author_image} = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $data->{object}->creator_id,
            domain_id => $auth_domain_id,
            size => $self->param('author_image_size') || 50,
        } );

        $info->{author_url} = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $data->{object}->creator_id, domain_id => $auth_domain_id, group_id => $group_id,
        } );

        my $last_commenters = CTX->lookup_action('comments_api')->e( get_latest_commenters => {
            object => $data->{object},
            group_id => $group_id,
            domain_id => $auth_domain_id,
            limit => $self->param('contributor_limit') || 5,
        } );

        $info->{contributors} = $self->_contributor_hashes_for_ids( $last_commenters, $group_id, $auth_domain_id );

        $result->{ $data->{object}->id } = $info;
    }

    return { result => {
        data_by_object_id => $result,
    } };
}

1;
