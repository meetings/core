package OpenInteract2::Action::DicoleSubgroupsJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleSubgroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );


sub create {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $parent_id = $gid;

    my $parent_setting = Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'default_parent_group_id',
        group_id => $gid,
    );
    $parent_id = $parent_setting if $parent_setting;

    # TODO: define group type and visibility by parent defaults???

    my $joinable = 1;
    my $visible = 1;
    my $type = 'usergroup';

    my $meta = {
        location => CTX->request->param('group_location'),
        facebook => CTX->request->param('group_facebook'),
        myspace => CTX->request->param('group_myspace'),
        twitter => CTX->request->param('group_twitter'),
        youtube => CTX->request->param('group_youtube'),
        webpage => CTX->request->param('group_webpage'),
    };

    my $new_group = CTX->lookup_action('groups_api')->e( add_group => {
        parent_group_id => $parent_id,
        domain_id => $domain_id,
        name => CTX->request->param('group_name'),
        description => CTX->request->param('group_description'),
        creator_id => CTX->request->auth_user_id,
        has_area => 1,
        joinable => $joinable,
        visible => $visible,
        type => $type,
        meta => $meta,
    } );

    my $tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    eval {
        my $tags_api = CTX->lookup_action('tagging');
        eval {
            $tags_api->execute( 'update_tags_from_json', {
                object => $new_group,
                group_id => 0,
                user_id => 0,
                json => $tags,
                json_old => '[]',
            } );
        };
        $self->log('error', $@ ) if $@;
    };

    if ( CTX->request->param('group_photo_draft_id') ) {
        my $attachment_id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
            draft_id => CTX->request->param('group_photo_draft_id'),
            object => $new_group,
            group_id => 0,
            user_id => 0,
        } );

        $meta->{image_attachment_id} = $attachment_id || 0;
    }

    $self->_group_data_to_meta( $new_group, $meta );
    $new_group->save;

    my $vis = CTX->request->param('group_visibility');
    if ( $vis eq 'none' ) {
        $new_group->joinable( 3 );
        $self->_set_visible( $new_group, 2 );
    }
    else {
        $new_group->joinable( 1 );
        $self->_set_visible( $new_group, 1 );
    }
    if ( $type eq 'usergroup' ) {
        my $groups_api = CTX->lookup_action( 'groups_api' );
        for my $toolid ( qw(
            groups_summary
            group_networking
            group_presentations
            group_wiki
            group_blogs
            group_events
            group_presentations_new_summary
            group_events_upcoming_summary
            group_discussions_summary
            group_wiki_front_page_summary
            group_online_members
            group_info_summary
        ) ) {
            $groups_api->execute( add_to_group_tools => {
                group => $new_group,
                toolid => $toolid,
            } );
        }

        CTX->lookup_action('wiki_api')->e( create_page => {
            group_id => $new_group->id,
            readable_title => $self->_msg('Front page (wiki automatic first page name)'),
        } );

        Dicole::Settings->store_single_setting(
            tool => 'summary', group_id => $new_group->id, attribute => 'layout',
            value => Dicole::Utils::JSON->encode(
                [
                    {
                        left_width => '50%',
                        left => [
                            {
                                box_id => 'group_discussions_summary',
                            },
                            {
                                box_id => 'wiki_summary_front_page',
                            },
                            {
                                box_id => 'group_online_summary',
                            },
                        ],
                        right => [
                            {
                                box_id => 'group_info_summary',
                            },
                            {
                                right_width => '50%',
                                left => [
                                    {
                                        box_id => 'events_upcoming_summary',
                                    },
                                ],
                                right => [
                                    {
                                        box_id => 'presentations_new_summary',
                                    },
                                ]
                            },
                        ],
                    },
                ]
            )
        );
    }

    return { result => { success => 1, url => $self->derive_url( action => 'groups', task => 'starting_page', target => $new_group->id ) } };
}

sub keyword_change {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = { tags => eval{ Dicole::Utils::JSON->decode( CTX->request->param('selected_keywords') ) } || [] };
    my $info = $self->_fetch_group_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    $state = $info->{state};
    my $links = $self->_fetch_group_filter_links( $gid, $domain_id, 50, $state );

    return {
        selected_tags_html => $self->generate_content(
            { links => [ map { { name => $_ } } @{ $state->{tags} || [] } ] },
            { name => 'dicole_groups::component_subgroups_browse_right_taglist' } 
        ),
        tags_html => $self->generate_content(
            { links => $links },
            { name => 'dicole_groups::component_subgroups_browse_right_tagcloud' } 
        ),
        results_html => $self->generate_content(
            { groups => $info->{object_info_list} },
            { name => 'dicole_groups::component_subgroups_browse_right_groups' }
        ),
        result_count => $info->{count},
        result_count_html => $info->{count} == 1 ? $self->_msg("1 group") : $self->_msg( "[_1] groups", $info->{count} ),
        state => Dicole::Utils::JSON->encode( $state ),
        end_of_pages => $info->{end_of_pages},
    };
}

sub more_groups {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = eval{ Dicole::Utils::JSON->decode( CTX->request->param('state') ) } || {};
    my $info = $self->_fetch_group_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    return {
        results_html => $self->generate_content(
            { groups => $info->{object_info_list} },
            { name => 'dicole_groups::component_subgroups_browse_right_groups' }
        ),
        state => Dicole::Utils::JSON->encode( $info->{state} ),
        end_of_pages => $info->{end_of_pages},
    };
}

1;

__END__
