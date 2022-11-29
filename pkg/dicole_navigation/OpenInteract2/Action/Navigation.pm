package OpenInteract2::Action::Navigation;

use strict;
use base qw( Dicole::Action Dicole::Security::Checker );

use OpenInteract2::Config::Ini;
use Dicole::Tree::Creator::Hash;
use SPOPS::SQLInterface;
use Dicole::Utils::Text;

use Dicole::Widget::Inline;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Dropdown;
use Dicole::Settings;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.108 $ =~ /(\d+)\.(\d+)/);

# some documentation of how this monster works.
# NI = not implemented yet

# 0. (NI) check if the navigation has been cached for this user & action

# 1. create a tree of all navigation items. this tree includes all the
# navigation elements once - meaning that there is only one item
# corresponding to a group. when the real tree is formed this item
# is duplicated and its data is set corresponding to the group.
# (NI) this tree changes very seldomly. cache it. for each language.
# maybe in memory??

# 2. from this tree, fetch the id's of the active navigation elements.
# this is done finding the currently active item and the coming down
# the tree and marking all of its parents active. the index
# used by Dicole::Tree::Creator::Hash is usefull.
# (NI) the index should be cached along the tree since its used here.

# 3. then we collect some data like the users tools and users groups
# and their tools and then form some hashes from them.

# 4. after this we start building the actual personalized navi tree.
# among other things this splits the group branc into several
# group branches and names groups and the user area.

sub navigation_content {
    my ( $self ) = @_;

    if ( CTX->request->auth_is_logged_in ) {
        return $self->generate_content(
            { navigation => $self->_get_navigation_tree },
            { name => 'dicole_navigation::navigation' }
        );
    }
    else {
        my @params = CTX->request->param;
        my %query_params = map { $_ => CTX->request->param( $_ ) } @params;

        return $self->generate_content(
            {
                navigation => $self->_get_navigation_tree,
                url_after_login => CTX->controller->initial_action->derive_url(
                        params => \%query_params
                ),
            },
            { name => 'dicole_navigation::guest_navigation' }
        );
    }
}

sub _get_navigation_tree {
    my ( $self ) = @_;

    my $cached;
    # my $cached = CTX->cache->get(
    #     "navigation_data",
    #     user => CTX->request->auth_user_id,
    #     action => CTX->request->action tms..
    # );

    return $cached if $cached;

    my ( $initial_tree, $index ) = $self->_initial_tree;
##    get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($initial_tree ));

    my $personalized_tree = $self->_personalized_tree(
        $initial_tree,
        $index
    );

    # CTX->cache->set(
    #     $personalized_tree,
    #     "navigation_data",
    #     user => CTX->request->auth_user_id,
    #     action => CTX->request->action tms..
    # );

##    get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($personalized_tree ));

    return $personalized_tree;
}


sub _initial_tree {
    my ( $self ) = @_;

    # my $cached = CTX->cache->get(
    #     "initial_navigation_data",
    #     language => CTX->.... language
    # );

    my $cached;

    return @$cached if $cached;

    my $navi_items = eval {
        CTX->lookup_object( 'navigation_item' )->fetch_group
    };

    my $creator = new Dicole::Tree::Creator::Hash (

        id_key => 'navid',
        parent_id_key => 'navparent',

        order_key => 'ordering',

        parent_key => '',
        sub_elements_key => 'sub_tree',
    );

    foreach my $item ( @{ $navi_items } ) {
        next if ! $item->{name} || ! $item->{localize};
        $item->{name} = $self->_msg( $item->{name} );
    }

    # NOTE:: replaced with a iterator some day

    $creator->add_element_array( $navi_items );

    my $initial_tree = $creator->create;
    my $index = $creator->get_index;

    # CTX->cache->set(
    #     [ $initial_tree, $index ],
    #     "initial_navigation_data",
    #     user => CTX->request->auth_user_id,
    #     action => CTX->request->action tms..
    # );

    return ( $initial_tree, $index );

}


sub _personalized_tree {

    my ($self, $initial_tree, $index) = @_;


    # create checklist for user tools

    my $user_items;

## USER TOOL SELECTION DISABLED FOR NOW!
#   = CTX->lookup_object('user_tool')->fetch_group(
#        { where => 'user_id = ?', value => [ CTX->request->auth_user_id ] }
#    );

    my $user_tools = [];

    foreach my $tool ( @{ CTX->lookup_object('tool')
        ->fetch_group( { where => 'type = "personal"' } )
    } ) {
        if ( $tool->{users_ids} ) {
            next unless scalar(
                grep { $_ == CTX->request->auth_user_id }
                    split /\s*,\s*/, $tool->{users_ids}
            );
        }
        push @{ $user_tools }, $tool;
    }

    $user_items->{ CTX->request->auth_user_id } = $user_tools;

    my %user_check = ();
    foreach my $uid ( keys %$user_items ) {
        $user_check{$uid} = {};
        foreach my $item ( @{ $user_items->{$uid} } ) {
            $user_check{$uid}{ $item->{toolid} } = 1;
        }
    }


    # selected groups tools checklist

    my $group_check = {};

    foreach my $group ( @{ CTX->request->auth_user_groups } ) {
        my $gid = $group->id;
        next if $gid != CTX->request->active_group;

        $group_check->{ $gid } = {}; # used for checking existence
        foreach my $tool ( @{ $group->tool || [] } ) {
            $group_check->{ $gid }{ $tool->{toolid} } = 1;
        }
    }

    # form list of active navigation items based on the currently active item

    my $active_item = CTX->controller->initial_action->param('active_navigation');

    my $active_check = { $active_item => 1 };

    while ( my $parent = $index->{ $active_item }->{element}->{navparent} ) {

        $active_check->{ $parent } = 1;
        $active_item = $parent;
    }

    my $group_icons = OpenInteract2::Config::Ini->new({ filename =>
        File::Spec->catfile(
            CTX->repository->full_config_dir, 'dicole_groups', 'group_icons.ini'
        )
    });

    # variable for the new tree
    my $personal_tree = [];

    # do some amazing things to create the real navigation tree


    $self->_rec_create_custom_tree(
        initial_tree => $initial_tree,
        personal_tree => $personal_tree,
        current_group => 0,
        limited_groups => $self->_get_limited_groups,
        user_check => \%user_check,
        group_check => $group_check,
        active_check => $active_check,
        icons => $group_icons->{group_icons},
        current_item => '',
        descend => 1,
        level => 0,
    );

    return $personal_tree;
}

sub _get_limited_groups {
    my ( $self ) = @_;

    my $limited_groups = [];
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $dicole_domains->task( 'groups_by_domain' );
        $limited_groups = $dicole_domains->execute;
    }
    else {
        return undef;
    }
    # turn into hash
    return { map { $_ => 1 } @$limited_groups };
}

sub _rec_create_custom_tree {

    my $self = shift @_;
    my %p = @_;

    # Skipped in the first iteration
    if ( $p{current_item} ) {

        return unless $self->_item_allowed( $p{current_item}, $p{current_group} );

        my $item = $p{current_item};
        my $gid = $p{current_group};
        my $navid = $item->{navid};

        # If item is not persistent, don't show it if it isn't selected

        if ( ! $item->{persistent} ) {
            return if $gid == 0 && !
                $p{user_check}->{ CTX->request->auth_user_id }{ $navid };

            return if $gid != 0 && ! $p{group_check}->{ $gid }{ $navid };
        }

        my $new_item = {
            name => $item->{name},
            icons => [ split( /\s*,\s*/, $item->{icons} ) ],
            link => $item->{link},
            type => $item->{type},
            sub_tree => [],
        };


        if ( !$gid) {
            $new_item->{active} = 1 if $p{active_check}->{$navid};
            $self->_rename_user_item( $new_item );
        }
        else {
            $new_item->{active} = 1 if
                $gid == CTX->request->active_group && $p{active_check}->{$navid};
            $self->_rename_group_item( $new_item, $gid, $p{icons} );
        }

        push @{ $p{personal_tree} }, $new_item;

        $p{personal_tree} = $new_item->{sub_tree};
        $p{initial_tree} = $item->{sub_tree};
    }

    return unless $p{descend};

    my $active_group = CTX->request->active_group;

    foreach my $item ( @{ $p{initial_tree} } ) {

        $p{current_item} = $item;

        if ( $item->{navid} eq 'space_groups' ) {

            my $old_descend = $p{descend};
            my $old_gid = $p{current_group};

            $p{descend} = 0;

            my @groups = ();

            # Limit groups if groups are limited
            if ( $p{limited_groups} ) {
                foreach my $group ( @{ CTX->request->auth_user_groups } ) {
                    push @groups, $group if $p{limited_groups}{$group->id};
                }
            }
            else {
                @groups = @{ CTX->request->auth_user_groups };
            }

            if ( CTX->request->target_group &&
                 ! $p{group_check}{CTX->request->target_group_id} ) {
                push @groups, CTX->request->target_group;
            }

            for my $group ( sort { $a->{name} cmp $b->{name} } @groups ) {

	            next unless $group->{has_area} == 1;

                if ( $group->id == $active_group ) {
                    # descend only if user actually meber of group
                    # FIXME: fixed for group actions which don't have
                    #  'target_type = group' set. These should be eliminated!
                    # $p{descend} = 1 if
                    # $p{group_check}{CTX->request->target_group_id};
                    $p{descend} = 1 if $p{group_check}{CTX->request->target_id};

                    $p{current_group} = $group->id;
                    $self->_rec_create_custom_tree( %p );

                    $p{descend} = 0;
                }
                else {
                    $p{current_group} = $group->id;
                    $self->_rec_create_custom_tree( %p );
                }
            }

            $p{current_group} = $old_gid;
            $p{descend} = $old_descend;
        }
        elsif ( $item->{navid} eq 'space_recent_groups' ) {

            my $old_descend = $p{descend};
            my $old_gid = $p{current_group};

            $p{descend} = 0;

            for my $new_gid ( @{ $self->_fetch_recent_groups } ) {

                $p{current_group} = $new_gid;
                $self->_rec_create_custom_tree( %p );
            }

            $p{current_group} = $old_gid;
            $p{descend} = $old_descend;

        }
        else {
            $self->_rec_create_custom_tree( %p );
        }
    }

}

sub _fetch_recent_groups {
    my ( $self ) = @_;

    my $action = CTX->lookup_action( 'recent_groups_ids' );

    if ( $action ) {

        my $new_gids = $action->execute( {
            user_id => CTX->request->auth_user_id,
        } ) || [];

        my $target_group = CTX->request->target_group;

        if ( $target_group ) {

            my $gid = $target_group->id;
            my @new_gids = grep { $_ != $gid } @$new_gids;
            $new_gids = \@new_gids;
        }

        return $new_gids;
    }

    return [];
}


# This function is not used anymore but might be usefull in the future?

sub _fetch_subgroups {
    my ( $self, $gid ) = @_;

    my @groups = ();
    my %gc = map { $_ => 1 } @{ CTX->request->auth_user_groups_ids };

    foreach my $group ( @{ CTX->request->auth_user_groups } ) {
        if ( $gid ) {
            push @groups, $group->id if $group->{parent_id} == $gid;
        }
        else {
            if ( ! $group->{parent_id} || ! $gc{ $group->{parent_id} } ) {
                push @groups, $group->id;
            }
        }
    }

    return \@groups;
}


sub _rename_user_item {
    my ( $self, $item, $uid ) = @_;

    $uid ||= CTX->request->auth_user_id;
    if ( $item->{name} =~ /%%username%%/ ) {
        my $user = CTX->request->auth_user;
        if ( $user->id != $uid ) {
            $user = CTX->lookup_object('user')->fetch(
                $uid, { skip_secure => 1 }
            );
        }
        my $name = $user->{first_name}.' '.$user->{last_name};
        $item->{name} =~ s/%%username%%/$name/;
    }
    if ( $item->{link} =~ /%%userid%%/ ) {
        $item->{link} =~ s/%%userid%%/$uid/;
    }

}

sub _rename_group_item {
    my ( $self, $item, $gid, $icons ) = @_;

    my $group = CTX->request->auth_user_groups_by_id->{ $gid };
    if (! $group ) {
        $group = CTX->lookup_object('groups')->fetch( $gid );

        if ( $item->{link} =~ /%%groupid%%/ ) {
            $item->{link} = '';
        }
    }
    elsif ( $item->{link} =~ /%%groupid%%/ ) {
        $item->{link} =~ s/%%groupid%%/$gid/;
    }

    if ( $item->{name} =~ /%%groupname%%/ ) {
        my $name = $group->{name};
        $item->{name} =~ s/%%groupname%%/$name/;
        # Get icon for the group based on group type
        $item->{icons} = [
            $icons->{ $group->{type} }
        ];
    }
}

sub _item_allowed {
    my ( $self, $item, $gid ) = @_;

    my $target = ($gid) ? $gid : CTX->request->auth_user_id;

    return $self->check_secure( $item->{secure}, $target );
}

sub _get_processed_navi_items {
    my ( $self, $type, $tgid, $tuid, $active_item, $settings, $check_url ) = @_;
    
    my $navi_items = eval {
        CTX->lookup_object( 'navigation_item' )->fetch_group( {
            where => 'type = ?',
            value => [ $type ],
            order => 'ordering asc'
        } );
    } || [];
    
    my @navis = ();
    
    for my $navi ( @$navi_items ) {
        next unless $navi->{active} == 1;
        
        if ( $navi->{groups_ids} ) {
            my $id = $tgid || 0;
            my $ids = $navi->{groups_ids};
            
            if ( $ids =~ s/^\!// ) {
                next if scalar( grep { $_ == $id } split /\s*,\s*/, $ids );
            }
            else {
                next unless scalar( grep { $_ == $id } split /\s*,\s*/, $ids );
            }
        }
        
        if ( $navi->{users_ids} ) {
            my $id = $tuid || 0;
            my $ids = $navi->{users_ids};
            
            if ( $ids =~ s/^\!// ) {
                next if scalar( grep { $_ == $id } split /\s*,\s*/, $ids );
            }
            else {
                next unless scalar( grep { $_ == $id } split /\s*,\s*/, $ids );
            }
        }
        if ( $tgid ) {
            $navi->{link} =~ s/%%groupid%%/$tgid/ if $navi->{link};
        }
        elsif ( $tuid ) {
            $navi->{link} =~ s/%%userid%%/$tuid/ if $navi->{link};
        }
        
        if ( $settings ) {
            if ( my $name = $settings->setting( 'rename_' . $navi->{navid} ) ) {
                $navi->{name} = $name;
            }
        }
        
        $navi->{abs_link} = $navi->{link};
        
        # TODO: For now this works only if the url has been expressed as absolute
        # but you could parse out the current domain name here..
        # But be sure not to parse other domain names like this does.. ;)
        # $navi->{abs_link} =~ s/^https?:\/\/[^\/]*//;
      
        push @navis, $navi;
     }
     
     # Check for url matches first, if none, then check for $active_item match
     
     my $selected_found = 0;
     if ( $check_url ) {
        # sort so that longest is first
        my @reordered_items = sort { $b->{abs_link} cmp $a->{abs_link} } @navis;
        for my $navi ( @reordered_items ) {
            next unless $navi->{abs_link};
            if ( index( $check_url, $navi->{abs_link} ) == 0 ) {
                $navi->{selected} = 1;
                $selected_found = 1;
                last;
            }
        }
    }
     
     unless ( $selected_found ) {
        for my $navi ( @$navi_items ) {
            if ( $navi->{navid} eq $active_item ) {
                $navi->{selected} = 1;
            }
        }
     }
     return \@navis;
}

sub simple_navigation {
    my ( $self ) = @_;

    my $ia = CTX->controller->initial_action;
    my $tgid = $ia->param('target_type') eq 'group' ?
        $ia->param('target_group_id') : 0;
    my $tuid = $ia->param('target_type') eq 'user' ?
        $ia->param('target_user_id') : 0;
    my $uid = CTX->request->auth_user_id;
    my $user = $uid ? CTX->request->auth_user : undef;
    
    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };
    my $domain_id = $current_domain ? $current_domain->{domain_id} : 0;
    
    my $tool_string = 'navigation';
    $tool_string .= '_' . $domain_id if $domain_id;
    
    my $settings = Dicole::Settings->new_fetched_from_params(
        tool => $tool_string,
    );
    
    my ( @head_widgets, @footer_widgets, @end_widgets );
    my $globals = {};

    my $params = {};

    my $current_area = $ia->current_area;
    $current_area->{name} = Dicole::Utils::Text->shorten(
        $current_area->{name}, 50
    );
    $params->{current_area} = $current_area;
    
    my @disabled_tools = ();
    
    if ( $tgid ) {
        my $group = $ia->param('target_group');
        my @group_tools = @{ $group->tool || [] };
        my %group_tools = map { $_->{toolid} => 1 } @group_tools;

        foreach my $tool ( @{ CTX->lookup_object('tool')
            ->fetch_group( { where => 'type = "group"' } )
        } ) {
            push @disabled_tools, $tool->{toolid} unless
                $group_tools{ $tool->{toolid} };
        }
    }
    elsif ( $tuid ) {
        foreach my $tool ( @{ CTX->lookup_object('tool')
            ->fetch_group( { where => 'type = "personal"' } )
        } ) {
            if ( $tool->{users_ids} ) {
                unless ( $tuid == CTX->request->auth_user_id && scalar(
                    grep { $_ == $tuid } split /\s*,\s*/, $tool->{users_ids}
                ) ) {
                    push @disabled_tools, $tool->{toolid}
                };
            }
        }
    }

    my $url_after_action = CTX->controller->initial_action->derive_full_url;

    my @action_widgets = ();

    if ( $user ) {
        my $enable_actions = 1;
        if ( $tgid && $ia->param('target_group') ) {
            my $group = $ia->param('target_group');
            unless ( Dicole::Utility->user_belongs_to_group( $user->id, $group->id ) ) {
                $enable_actions = 0;
                if ( $group->joinable == 1 ) {
                    $params->{area_name} = $group->name;
                    $params->{join_group_url} = Dicole::URL->from_parts(
                        action => 'groups',
                        task => 'join_group',
                        target => $group->id,
                        params => { url_after_join => $url_after_action },
                    );

                    push @action_widgets, Dicole::Widget::Hyperlink->new(
                        content => $self->_msg('Join area'),
                        link => Dicole::URL->from_parts(
                            action => 'groups',
                            task => 'join_group',
                            target => $group->id,
                            params => { url_after_join => $url_after_action },
                        ),
                        class => 'navi_join_group_action',
                    );
                }
            }
        }
        if ( $enable_actions ) {
            my $navi_items = $tgid ? $self->_get_processed_navi_items(
                'group_action', $tgid, $tuid, undef, $settings
            ) : [];

            for my $navi ( @$navi_items ) {
                next if grep { index( $navi->{navid}, $_ ) == 0 } @disabled_tools;
                next unless $self->_item_allowed( $navi, $tgid || $tuid );
                push @action_widgets, Dicole::Widget::Hyperlink->new(
                    content => $self->_msg( $navi->{name} ),
                    link => $navi->{link},
                    class => $navi->{navi_class},
                );
            }
        }
    }

    for my $widget ( @action_widgets ) {
        push @{ $params->{action_widgets} },
            Dicole::Widget->content_params( $widget );
    }

    unless ( $self->param('disable_login_widgets') ) {
        my @login_widgets = (
            $self->_simple_change_area_widget( $current_area, $uid, $current_domain ),
            $self->_logged_in_widget( $user, $tgid ),
            $self->_top_extras_widget( $tgid, $tuid, $settings, $domain_id ),
            $self->_simple_login_widget( $ia, $tgid, $url_after_action ),
        );
    
        for my $widget ( @login_widgets ) {
            push @{ $params->{login_widgets} },
                Dicole::Widget->content_params( $widget );
        }
    }

    my $active_item = $ia->param('active_navigation');
    my $navi_items = $self->_get_processed_navi_items(
        $ia->param('navigation_type'), $tgid, $tuid,
        $active_item, $settings, CTX->request->url_absolute
    );
    
    my @navis = ();

    for my $navi ( @$navi_items ) {
        next if grep { index( $navi->{navid}, $_ ) == 0 } @disabled_tools;
        next unless $self->_item_allowed( $navi, $tgid || $tuid );
        push @navis, $navi;
    }

    my @other;
    if ( scalar( @navis ) > 6 ) {
        @other = splice @navis, 5;
    }

    $params->{navi_widgets} = [];

    for my $nav ( @navis ) {
        my $class = $nav->{navi_class} || 'other';
	$class .= $nav->{selected} ? ' ' . $class . '_selected' : '';
        $class .= $nav->{selected} ? ' selected' : '';

        my $widget = Dicole::Widget::Hyperlink->new(
            class => $class,
            'link' => $nav->{'link'},
            content => Dicole::Widget::Inline->new( contents => [ $self->_reformat_tool_name(
                $self->_msg( $nav->{name} )
            ) ] ),
        );

        push @{ $params->{navi_widgets} },
            Dicole::Widget->content_params( $widget );
    }

    if ( scalar( @other ) ) {
        my $other_text = $self->_msg( 'Other' );
        if ( $settings ) {
            if ( my $renamed = $settings->setting( 'rename_group_other_menu' ) ) {
                $other_text = $renamed;
            }
        }
        my $dd = Dicole::Widget::Dropdown->new(
            text => $self->_reformat_tool_name(
                $other_text
            ),
            text => $other_text,
            class => 'other',
            arrow => 1,
            template => CTX->server_config->{dicole}{base} . '::' . 'widget_dropdown',
        );

        for my $v ( @other ) {
            if ( $v->{selected} ) {
                my $class = $v->{navi_class} || 'other';
                $class .= ' ' . $class . '_selected';
		$class .= ' selected';
                
                $dd->class( $class );
                $dd->text( $self->_reformat_tool_name(
                    $self->_msg( $v->{name} )
                ) );
                $dd->text( $self->_msg( $v->{name} ) );
            }
            $dd->add_element(
                text => $self->_msg( $v->{name} ),
                link => $v->{link},
                class => $v->{navi_class} || 'other',
            );
        }

        push @{ $params->{navi_widgets} },
            Dicole::Widget->content_params( $dd );
    }

    push @head_widgets, Dicole::Widget::Javascript->new(
        code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');',
    );
    
    my $footer_items = $tgid ? $self->_get_processed_navi_items(
        'group_footer', $tgid, $tuid, undef, $settings
    ) : [];
    
    for my $nav ( @$footer_items ) {
        push @footer_widgets, Dicole::Widget::Hyperlink->new(
            class => $nav->{navi_class},
            'link' => $nav->{'link'},
            content => $nav->{name},
        );
    }

    # custom css
    my $at_tool = 'automatic_theme' . ( $domain_id ? '_' . $domain_id : '');
    my @custom_css = ();

    my $domain_at_hash = Dicole::Settings->new_fetched_from_params(
        tool => $at_tool,
        group_id => 0,
    )->settings_as_hash;

    push @custom_css, $self->generate_content(
        $domain_at_hash, { name => 'dicole_settings::special_automatic_theme' }
    );
 
    push @custom_css, $settings->setting('custom_css');

    if ( $tuid || $tgid ) {
        if ( $tgid ) {
            my $group_at_hash = Dicole::Settings->new_fetched_from_params(
                tool => $at_tool,
                group_id => $tgid,
            )->settings_as_hash;

            push @custom_css, $self->generate_content(
                $group_at_hash, { name => 'dicole_settings::special_automatic_theme' }
            );
        }
        my $local_settings = Dicole::Settings->new_fetched_from_params(
            tool => $tool_string,
            user_id => $tuid,
            group_id => $tgid,
        );
        push @custom_css, $local_settings->setting('custom_css');
    }
    
    for my $css ( @custom_css ) {
        push @head_widgets, Dicole::Widget::Raw->new(
            raw => '<style type="text/css" media="all">'.$css.'</style>'
        ) unless $css =~ /^\s*$/s;
    }

    $self->param( 'head_widgets', \@head_widgets );
    $self->param( 'footer_widgets', \@footer_widgets );
    $self->param( 'end_widgets', \@end_widgets );

    return $self->generate_content(
        $params, { name => 'dicole_navigation::simple_navigation' }
    );

}

# Completely new old navigation code

sub render_navigation {
    my ( $self ) = @_;

    my $ia = CTX->controller->initial_action;
    my $tgid = $ia->param('target_type') eq 'group' ?
        $ia->param('target_group_id') : 0;
    my $tuid = $ia->param('target_type') eq 'user' ?
        $ia->param('target_user_id') : 0;
    my $uid = CTX->request->auth_user_id;
    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $params = {};

#    $params->{url_after_login} = $ia->derive_url(
#        params => \%query_params
#    );

    my $current_area = $ia->current_area;
    $current_area->{name} = Dicole::Utils::Text->shorten(
        $current_area->{name}, 22
    );
    $params->{current_area} = $current_area;
    
    my @left_widgets = (
        $self->_community_area_widget( $current_domain ),
        $self->_personal_area_widget( $uid ),
        $self->_change_area_widget( $current_area, $uid ),
        $self->_bookmark_area_widget,
    );

    for my $widget ( @left_widgets ) {
        push @{ $params->{left_widgets} },
            Dicole::Widget->content_params( $widget );
    }

    my @right_widgets = (
        $self->_settings_widget,
        $self->_admin_area_widget,
        $self->_feedback_widget,
        $self->_login_widget,
    );

    for my $widget ( @right_widgets ) {
        push @{ $params->{right_widgets} },
            Dicole::Widget->content_params( $widget );
    }

    my $navi_items = eval {
        CTX->lookup_object( 'navigation_item' )->fetch_group( {
            where => 'type = ?',
            value => [ $ia->param('navigation_type') ],
            order => 'ordering asc'
        } );
    } || [];

    my $disabled_tools = {};

    if ( $tgid ) {
        my $group = $ia->param('target_group');
        my @group_tools = @{ $group->tool || [] };
        my %group_tools = map { $_->{toolid} => 1 } @group_tools;

        foreach my $tool ( @{ CTX->lookup_object('tool')
            ->fetch_group( { where => 'type = "group"' } )
        } ) {
            $disabled_tools->{ $tool->{toolid} } = 1 unless
                $group_tools{ $tool->{toolid} };
            my $gids = $tool->{groups_ids};
            if ( $gids ) {
                if ( $gids =~ s/^\!// ) {
                    $disabled_tools->{ $tool->{toolid} } = 1 if
                        scalar( grep { $_ == $tuid } split /\s*,\s*/, $gids )
                }
                else {
                    $disabled_tools->{ $tool->{toolid} } = 1 unless
                        scalar( grep { $_ == $tuid } split /\s*,\s*/, $gids )
                    
                }
            }
        }
    }
    elsif ( $tuid ) {
        foreach my $tool ( @{ CTX->lookup_object('tool')
            ->fetch_group( { where => 'type = "personal"' } )
        } ) {
            my $uids = $tool->{users_ids};
            if ( $uids ) {
                if ( $uids =~ s/^\!// ) {
                    $disabled_tools->{ $tool->{toolid} } = 1 if
                        scalar( grep { $_ == $tuid } split /\s*,\s*/, $uids );
                }
                else {
                    unless ( $tuid == CTX->request->auth_user_id && scalar(
                        grep { $_ == $tuid } split /\s*,\s*/, $uids
                    ) ) {
                        $disabled_tools->{ $tool->{toolid} } = 1;
                    };
                }
            }
        }
    }

    my $active_item = $ia->param('active_navigation');
    my @navis = ();

    for my $navi ( @$navi_items ) {
        next unless $navi->{active} == 1;
        next if $disabled_tools->{ $navi->{navid} };
        next unless $self->_item_allowed( $navi, $tgid || $tuid );
        if ( $navi->{navid} eq $active_item ) {
            $navi->{selected} = 1;
        }
        if ( $tgid ) {
            $navi->{link} =~ s/%%groupid%%/$tgid/ if $navi->{link};
            my $ids = $navi->{groups_ids};
            if ( $ids ) {
                if ( $ids =~ s/^\!// ) {
                    next if scalar( grep { $_ == $tgid } split /\s*,\s*/, $ids );
                }
                else {
                    next unless scalar( grep { $_ == $tgid } split /\s*,\s*/, $ids );
                }
            }
        }
        elsif ( $tuid ) {
            $navi->{link} =~ s/%%userid%%/$tuid/ if $navi->{link};
            my $ids = $navi->{users_ids};
            if ( $ids ) {
                if ( $ids =~ s/^\!// ) {
                    next if scalar( grep { $_ == $tuid } split /\s*,\s*/, $ids );
                }
                else {
                    next unless scalar( grep { $_ == $tuid } split /\s*,\s*/, $ids );
                }
            }
        }
        push @navis, $navi;
    }

    my @other;
    if ( scalar( @navis ) > 5 ) {
        @other = splice @navis, 4;
    }

    $params->{navi_widgets} = [];

    for my $nav ( @navis ) {
        my $class = $nav->{navi_class} || 'other';
	$class .= $nav->{selected} ? ' ' . $class . '_selected' : '';
        $class .= $nav->{selected} ? ' selected' : '';

        my $widget = Dicole::Widget::Hyperlink->new(
            class => $class,
            'link' => $nav->{'link'},
            content => $self->_reformat_tool_name(
                $self->_msg( $nav->{name} )
            ),
        );

        push @{ $params->{navi_widgets} },
            Dicole::Widget->content_params( $widget );
    }

    if ( scalar( @other ) ) {
        my $dd = Dicole::Widget::Dropdown->new(
            text => $self->_reformat_tool_name(
                $self->_msg( 'Other' )
            ),
            class => 'other',
            arrow => 1,
            template => CTX->server_config->{dicole}{base} . '::' . 'widget_dropdown',
        );

        for my $v ( @other ) {
            if ( $v->{selected} ) {
                my $class = $v->{navi_class} || 'other';
                $class .= ' ' . $class . '_selected';
		$class .= ' selected';
                
                $dd->class( $class );
                $dd->text( $self->_reformat_tool_name(
                    $self->_msg( $v->{name} )
                ) );
            }
            $dd->add_element(
                text => $self->_msg( $v->{name} ),
                link => $v->{link},
                class => $v->{navi_class} || 'other',
            );
        }

        push @{ $params->{navi_widgets} },
            Dicole::Widget->content_params( $dd );
    }

    # custom css
    my $tool_string = 'navigation';
    $tool_string .= '_' . $current_domain->{domain_id} if $current_domain;
    
    my $settings = Dicole::Settings->new;
    $settings->tool( $tool_string );
    $settings->global( 1 );
    $settings->fetch_settings;
    my @custom_css = ( $settings->setting('custom_css') );
    
    if ( $tuid || $tgid ) {
        my $settings = Dicole::Settings->new;
        $settings->tool( $tool_string );
        $settings->user( $tuid );
        $settings->group( $tgid );
        $settings->global( 0 );
        $settings->fetch_settings;
        push @custom_css, $settings->setting('custom_css');
    }
    
    $params->{custom_css} = \@custom_css;

    return $self->generate_content(
        $params, { name => 'dicole_navigation::nice_navigation' }
    );
}

sub _community_area_widget {
    my ( $self, $current_domain ) = @_;
    
    my $show = 1;
    if ( $current_domain ) {
        my $str = 'domain_user_manager_' . $current_domain->{domain_id};
        my $settings = Dicole::Settings->new;
        $settings->tool( $str );
        $settings->global( 1 );
        $settings->fetch_settings;
        $show = $settings->setting('hide_community') ? 0 : 1;
    }
    
    return Dicole::Widget::Hyperlink->new(
        content => $self->_msg('Community'),
        link => '/groups/list/',
    ) if $show;
    
    return ();
}

sub _logged_in_widget {
    my ( $self, $user, $gid ) = @_;
    
    return $user ? Dicole::Widget::Horizontal->new(
        id => 'navi_logged_in_as',
        contents => [
            $gid ? (
                Dicole::Widget::Hyperlink->new(
                    class => 'navi_logged_in_as_profile',
                    content =>  Dicole::Widget::Text->new( class=> 'navi_logged_in_as_profile_text', text => $self->_msg( 'My profile' ) ),
                    link => Dicole::URL->from_parts( action => 'networking', task => 'profile', target => $gid, additional => [ $user->id ] ),
                ),
                Dicole::Widget::Hyperlink->new(
                    class => 'navi_logged_in_as_settings',
                    content => Dicole::Widget::Text->new( class=> 'navi_logged_in_as_settings_text', text => $self->_msg( 'Settings' ) ),
                    link => Dicole::URL->from_parts( action => 'global_settings', task => 'detect', target => $gid ),
                ),
            ) : ()
        ],
     ) : ();
}

sub _top_extras_widget {
    my ( $self, $tgid, $tuid, $settings, $domain_id ) = @_;

    my $navi_items = $self->_get_processed_navi_items(
        'top_extras', $tgid, $tuid, undef, $settings
    );

    my $help_link = Dicole::Utils::Domain->setting( $domain_id, 'help_link' );

    return () unless @$navi_items || $help_link;

    my $container = Dicole::Widget::Horizontal->new(
        id => 'navi_top_extras'
    );

    for my $nav ( @$navi_items ) {
        my $class = $nav->{navi_class} || '';

        my $widget = Dicole::Widget::Hyperlink->new(
            class => $class,
            'link' => $nav->{'link'},
            content => Dicole::Widget::Inline->new( contents => [
                $nav->{name}
            ] ),
        );

        $container->add_content( $widget );
    }

    if ( $help_link ) {
        $container->add_content(
            Dicole::Widget::Hyperlink->new(
                class => 'navigation_help_link',
                'link' => $help_link,
                content => Dicole::Widget::Inline->new( contents => [
                    $self->_msg( 'Help' )
                ] ),
            )
        );
    }

    return ( $container );
}

sub _change_area_widget {
    my ( $self, $current_area, $uid, $current_domain ) = @_;

    my $where = 'user_id = ?';
    my @value = ( $uid );

    my $domain_uids = undef;
    my $domain_gids = undef;

    eval {
        my $dd = CTX->lookup_action('dicole_domains');
        my $domain = $dd->execute('get_current_domain');

        if ( $dd && $domain ) {
            push @value, $domain->id;
            $where .= ' AND domain_id = ?';
            
            my $domain_users = $dd->users_by_domain;
            $domain_uids = { map { $_ => 1 } @$domain_users };
            
            my $domain_groups = $dd->groups_by_domain;
            $domain_gids = { map { $_ => 1 } @$domain_groups };
        }
    };
    
    $where .= ' AND sticky = ?';

    my $vobject = CTX->lookup_object( 'area_visit' );

    my $sticky_visits = $vobject->fetch_group( {
        where => $where,
        value => [ @value, 1 ],
        order => 'hit_count DESC',
    } ) || [];

    my $last_visits = $vobject->fetch_group( {
        where => $where,
        value => [ @value, 0 ],
        order => 'last_visit DESC',
        limit => '10',
    } ) || [];

    my $dd = Dicole::Widget::Dropdown->new(
        text => $self->_msg('Other areas'),
        selected => -1,
        template => CTX->server_config->{dicole}{base} . '::' . 'widget_dropdown',
    );

    # do not skip the first title after all ;)
    # return this to 0 as default if you want to skip the first title
    my $first_title_skipped = 1;
    my $dd_filled = 0;
#    my $ia = CTX->controller->initial_action;

    for my $v ( @$sticky_visits ) {
#        next if $current_area->{url} eq $v->{url};
        next if $v->{target_user_id} == CTX->request->auth_user_id;
        next if $domain_uids && $v->{target_user_id} &&
            ! $domain_uids->{ $v->{target_user_id} };
        next if $domain_gids && $v->{target_group_id} &&
            ! $domain_gids->{ $v->{target_group_id} };

#        next if $_->{target_group_id} && ! $_->{target_user_id} &&
#            $_->{target_group_id} == $ia->param('target_group_id');
#        next if $_->{target_user_id} && ! $_->{target_group_id} &&
#            $_->{target_user_id} == $ia->param('target_user_id');

#        unless ( $current_area->{url} eq $v->{url} ) {
            $dd->add_title( $self->_msg('Groups'), 'groups' ) unless $dd_filled;
            $dd->add_element( text => $v->{name}, link => $v->{url} );
            $first_title_skipped = 1;
            $dd_filled = 1;
#        }
    }

    my %visits = ();
    for my $v ( @$last_visits ) {
#        next if $current_area->{url} eq $v->{url};
        next if $v->{target_user_id} == CTX->request->auth_user_id;
        next if $domain_uids && $v->{target_user_id} &&
            ! $domain_uids->{ $v->{target_user_id} };
        next if $domain_gids && $v->{target_group_id} &&
            ! $domain_gids->{ $v->{target_group_id} };

#        next if $_->{target_group_id} && ! $_->{target_user_id} &&
#            $_->{target_group_id} == $ia->param('target_group_id');
#        next if $_->{target_user_id} && ! $_->{target_group_id} &&
#            $_->{target_user_id} == $ia->param('target_user_id');

        if ( $v->{target_group_id} ) {
            $visits{g} ||= [];
            push @{$visits{g}}, $v;
        }
        elsif ( $v->{target_user_id} ) {
            $visits{u} ||= [];
            push @{$visits{u}}, $v;
        }
        else {
            $visits{o} ||= [];
            push @{$visits{o}}, $v;
        }
    }

#     if ( $visits{g} ) {
#         $dd_filled = 1;
#         if ( $first_title_skipped ) {
#             $dd->add_title( $self->_msg('Visited groups') );
#         }
#         else {
#             $first_title_skipped = 1;
#         }
#         $dd->add_element( text => $_->{name}, link => $_->{url} )
#             for @{$visits{g}};
#     }
    if ( $visits{u} ) {
        $dd_filled = 1;
        if ( $first_title_skipped ) {
            $dd->add_title( $self->_msg('Visited blogs'), 'blogs' );
        }
        else {
            $first_title_skipped = 1;
        }
        $dd->add_element( text => $_->{name}, link => $_->{url} )
            for @{$visits{u}};
    }
#     if ( $visits{o} ) {
#         $dd_filled = 1;
#         if ( $first_title_skipped ) {
#             $dd->add_title( $self->_msg('Visited general areas'), 'other' );
#         }
#         else {
#             $first_title_skipped = 1;
#         }
#        $dd->add_element( text => $_->{name}, link => $_->{url} )
#             for @{$visits{o}};
#     }
    
    return $dd_filled ? $dd : ();
}

sub _simple_change_area_widget {
    my ( $self, $current_area, $uid, $current_domain ) = @_;

    my $where = 'user_id = ? and visiting_disabled = ?';
    my @value = ( $uid, 0 );

    my $domain_uids = undef;
    my $domain_gids = undef;

    eval {
        my $dd = CTX->lookup_action('dicole_domains');
        my $domain = $dd->execute('get_current_domain');

        if ( $dd && $domain ) {
            push @value, $domain->id;
            $where .= ' AND domain_id = ?';
            
#            my $domain_users = $dd->users_by_domain;
#            $domain_uids = { map { $_ => 1 } @$domain_users };
            
            my $domain_groups = $dd->groups_by_domain;
            $domain_gids = { map { $_ => 1 } @$domain_groups };
        }
    };
    
    $where .= ' AND sticky = ?';

    my $vobject = CTX->lookup_object( 'area_visit' );

    my $sticky_visits = $vobject->fetch_group( {
        where => $where,
        value => [ @value, 1 ],
        order => 'hit_count DESC',
    } ) || [];

    my $dd = Dicole::Widget::Dropdown->new(
        text => $self->_msg('Change area'),
        selected => -1,
        template => CTX->server_config->{dicole}{base} . '::' . 'widget_dropdown',
        class => 'navi_other_areas',
    );

    # do not skip the first title after all ;)
    # return this to 0 as default if you want to skip the first title
    my $first_title_skipped = 1;
    my $sticky_count = 0;
    my $sticky_first = undef;
    my $dd_filled = 0;
#    my $ia = CTX->controller->initial_action;

    for my $v ( @$sticky_visits ) {
#        next if $current_area->{url} eq $v->{url};
        next if $v->{target_user_id} == CTX->request->auth_user_id;
#        next if $domain_uids && $v->{target_user_id} &&
#            ! $domain_uids->{ $v->{target_user_id} };
        next if $v->{target_user_id};
        next if $domain_gids && $v->{target_group_id} &&
            ! $domain_gids->{ $v->{target_group_id} };

#        next if $_->{target_group_id} && ! $_->{target_user_id} &&
#            $_->{target_group_id} == $ia->param('target_group_id');
#        next if $_->{target_user_id} && ! $_->{target_group_id} &&
#            $_->{target_user_id} == $ia->param('target_user_id');

#        unless ( $current_area->{url} eq $v->{url} ) {
            $dd->add_title( $self->_msg('Groups'), 'groups' ) unless $dd_filled;
            $dd->add_element( text => $v->{name}, link => $v->{url} );
            $first_title_skipped = 1;
            $dd_filled = 1;
            $sticky_count++;
            $sticky_first ||= $v;
#        }
    }

    my $other_added = 0;
    my $show_community = 1;
    my $show_personal = 1;
    my $community_string = $self->_msg('Community');
    my $community_link = '/groups/list/';
    if ( $current_domain ) {
        my $str = 'domain_user_manager_' . $current_domain->{domain_id};
        my $settings = Dicole::Settings->new;
        $settings->tool( $str );
        $settings->global( 1 );
        $settings->fetch_settings;
        $show_community = $settings->setting('hide_community') ? 0 : 1;
        $show_personal = 0;
        $community_string = $settings->setting('community_string') if $settings->setting('community_string');
        $community_link = $settings->setting('community_link') if $settings->setting('community_link');
    }
    if ( $show_community && CTX->request && CTX->request->auth_user_id ) {
        $dd_filled = 1;
        $dd->add_title( $self->_msg('Other'), 'other' ) unless $other_added;;
        $other_added = 1;
        $dd->add_element( text => $community_string, link => $community_link );
    }
    my $summary_allowed = $self->mchk_y(
        'OpenInteract2::Action::DicolePersonalSummary',
        'read',
        CTX->request->auth_user_id
    );

    if ( 0 && $summary_allowed && $show_personal ) {
        $dd_filled = 1;
        $dd->add_title( $self->_msg('Other'), 'other' ) unless $other_added;
        $other_added = 1;
        $dd->add_element( text => $self->_msg('My area'), link => '/personalsummary/summary/' . $uid );
    }

    if ( $self->mchk_y( 'OpenInteract2::Action::UserManager', 'manage' ) ) {
        $dd_filled = 1;
        $dd->add_title( $self->_msg('Other'), 'other' ) unless $other_added;
        $other_added = 1;
        $dd->add_element( text => $self->_msg('Admin (action)'), link => '/admin_online_users/' );
    }
    
    eval {
        my $d = CTX->lookup_action('dicole_domains');
        my $uid = CTX->request->auth_user_id;
        my $isadmin = $d->execute( is_domain_admin => {
            user_id => $uid
        } );
        
        if ( $isadmin ) {
            $dd_filled = 1;
            $dd->add_title( $self->_msg('Other'), 'other' ) unless $other_added;
            $other_added = 1;
            $dd->add_element( text => $self->_msg('Domain managing'), link => '/dusermanager/' );
        }
    };

    # Do not show an empty box. Do not show a box with one group if it's selected.
    return ( $dd_filled && ( $other_added || $sticky_count > 1 || ( $sticky_first && $current_area->{url} ne $sticky_first->{url} ) ) ) ? $dd : ();
}

sub _bookmark_area_widget {
    my ( $self ) = @_;

    return ();
}

sub _personal_area_widget {
    my ( $self, $uid ) = @_;
    
    my $summary_allowed = $self->mchk_y(
        'OpenInteract2::Action::DicolePersonalSummary',
        'read',
        CTX->request->auth_user_id
    );
    
    my $blog_allowed = $self->mchk_y(
        'OpenInteract2::Action::Weblog',
        'user_add',
        CTX->request->auth_user_id
    );

    if ( $summary_allowed ) {
        if ( 0 && $blog_allowed ) {
            my $area = Dicole::Widget::Hyperlink->new(
                content => $self->_msg('My area'),
                link => '/personalsummary/summary/' . $uid,
            );
            my $blog = Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Write to weblog'),
                link => '/personal_weblog/add/' . $uid,
            );
            return Dicole::Widget::Inline->new( contents => [
                $area, ' > ', $blog
            ] );
        }
        else {
            return Dicole::Widget::Hyperlink->new(
                content => $self->_msg('My area'),
                link => '/personalsummary/summary/' . $uid,
            );
        }
    }
    elsif ( 0 && $blog_allowed ) {
        return Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Write to my weblog'),
            link => '/personal_weblog/add/' . $uid,
        );
    }
    
    return ();
}

sub _admin_area_widget {
    my ( $self ) = @_;

    my @widgets = ();
    push @widgets, Dicole::Widget::Hyperlink->new(
        content => $self->_msg('Admin (action)'),
        link => '/admin_online_users/',
    ) if $self->mchk_y(
        'OpenInteract2::Action::UserManager', 'manage'
    );
    
    eval {
        my $d = CTX->lookup_action('dicole_domains');
        my $uid = CTX->request->auth_user_id;
        my $isadmin = $d->execute( is_domain_admin => {
            user_id => $uid
        } );
        
        if ( $isadmin ) {
            push @widgets, Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Domain managing'),
                link => '/dusermanager/',
            );
        }
    };

    return @widgets;
}

sub _settings_widget {
    my ( $self ) = @_;

    return Dicole::Widget::Hyperlink->new(
        content => $self->_msg('Settings'),
        link => '/settings/settings/' . CTX->request->auth_user_id,
    );
}

sub _feedback_widget {
    my ( $self ) = @_;

    return Dicole::Widget::Hyperlink->new(
        content => $self->_msg('Feedback'),
        link => 'http://www.dicole.com/?page_id=21',
    );
}

sub _login_widget {
    my ( $self ) = @_;

    if ( CTX->request->auth_is_logged_in ) {
        return Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Logout'),
            id => 'navi_logout_link',
            'link' => '/xlogout/',
        );
    }
    else {
        return ();
    }
}

sub _simple_login_widget {
    my ( $self, $ia, $tgid, $url_after_action ) = @_;

    if ( CTX->request->auth_user_id ) {
        return Dicole::Widget::Hyperlink->new(
            content => Dicole::Widget::Text->new(
                class => 'navi_logout_link_text', 
                text => $self->_msg( 'Logout' ),
            ),
            id => 'navi_logout_link',
            'link' => '/xlogout/',
        );
    }
    else {
        my $register_target = CTX->lookup_action( 'user_manager_api' )->e( allowed_domain_registration_target => {
            group_id => $tgid, group_object => $ia->param('target_group')
        } );

        my @register_widgets = ();
        push @register_widgets, Dicole::Widget::Hyperlink->new(
            content => Dicole::Widget::Text->new(
                class => 'navi_register_link_text js_open_register_dialog',
                text => $self->_msg( 'Register (action)' ),
            ),
            'link' => $register_target ?
                Dicole::URL->from_parts(
                    action => 'registering',
                    task => 'register',
                    target => $register_target,
                    params => { url_after_register => $url_after_action },
                )
                :
                Dicole::URL->from_parts(
                    action => 'register',
                    task => 'register',
                    params => { url_after_register => $url_after_action },
                ),
            class => 'js_open_register_dialog',
            id => 'navi_register_link',
        ) if $register_target;

        push @register_widgets, Dicole::Widget::Hyperlink->new(
            content => Dicole::Widget::Text->new(
                class => 'navi_login_link_text', 
                text => $self->_msg( 'Login (action)' ),
            ),
            class => 'js_open_login_dialog',
            id => 'navi_login_link',
            'link' => '#',
        );
        return @register_widgets;
    }
}

sub _reformat_tool_name {
    my ( $self, $name ) = @_;

    # We try really hard to get all kinds of tool names behave and
    # stay on 2 rows
    # This expects that approximately 13 characters fit on one row.
    # As a special case, if the first non-whitespace string is
    # longer than 13 chars it will be truncated to {11 chars}..

    my @parts = split /\s+/, $name;

    my $part1 = shift @parts;
    while ( @parts ) {
        my $possible = $part1 . ' ' . $parts[0];
        if ( $possible =~ /^(.{0,13})$/ ) {
            $part1 = $part1 . ' ' . shift @parts;
        }
        else {
            last;
        }
    }

    $part1 =~ s/(.{11})...+/$1../;

    my $part2 = join ' ', @parts;
    $part2 =~ s/(.{11})...+/$1../;

    return join ' ', ( $part2 ? ( $part1, $part2 ) : ( $part1 ) );
}

# Area recording action

sub register_area_visit {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id') || CTX->request->auth_user_id; 

    return unless $user_id;

    my $ia = $self->param('action');
    my $current_area = $ia->current_area;

    return unless ref( $current_area ) eq 'HASH';
    return if $current_area->{disable_visit};

    my $domain_id = $self->param( 'domain_id' );

    if ( !defined( $domain_id ) ) {
        $domain_id = 0;
        eval {
            my $domain_object = CTX->lookup_action('dicole_domains')->execute(
                'get_current_domain'
            );
            $domain_id = $domain_object->id if $domain_object;
        };
    }

    my $visits = CTX->lookup_object( 'area_visit' )->fetch_group( {
        where => 'user_id = ? AND domain_id = ? AND url = ?',
        value => [
            $user_id,
            $domain_id,
            $current_area->{url},
        ],
    } ) || [];

    my $visit = shift @$visits;

    unless ( $visit ) {
        $visit = CTX->lookup_object( 'area_visit' )->new;
        $visit->user_id( $user_id );
        $visit->domain_id( $domain_id );
        $visit->url( $current_area->{url} );

        $visit->sticky( 0 );
        $visit->hit_count( 0 );
        $visit->visiting_disabled( 0 );
    }

    $visit->name( $current_area->{name} );
    $visit->hit_count( $visit->hit_count + 1 );
    $visit->last_visit( time );
    $visit->target_user_id( $ia->param('target_user_id') || 0 );
    $visit->target_group_id( $ia->param('target_group_id') || 0 );
    if ( my $g = $ia->param('target_group') ) {
        $visit->visiting_disabled( 1 ) if $g->has_area == 2;
    }

    my $sticky = $self->param('set_sticky');
    if ( defined( $sticky ) ) {
        $visit->sticky( $sticky );
    }

    $visit->save;
}

sub set_area_visiting_for_group {
    my ( $self ) = @_;
    my $group = $self->param('group');
    $group ||= CTX->lookup_object('groups')->fetch( $self->param('group_id') );

    my $disabled = ( $group->has_area == 2 ) ? 1 : 0;
    my $visits = CTX->lookup_object( 'area_visit' )->fetch_group(
        { where => 'target_group_id = ?', value => [ $group->id ] }
    ) || [];
    for my $visit ( @$visits ) {
        $visit->visiting_disabled( $disabled );
        $visit->save;
    }
}

sub remove_group_sticky {
    my ( $self ) = @_;
    
    my $user_id = $self->param('user_id');
    my $group_id = $self->param('group_id');
    my $domain_id = $self->param( 'domain_id' );

    if ( !defined( $domain_id ) ) {
        $domain_id = 0;
        eval {
            my $domain_object = CTX->lookup_action('dicole_domains')->execute(
                'get_current_domain'
            );
            $domain_id = $domain_object->id if $domain_object;
        };
    }

    next unless $user_id && $group_id;
    
    my $visits = CTX->lookup_object( 'area_visit' )->fetch_group( {
        where => 'user_id = ? AND domain_id = ? AND target_group_id = ?',
        value => [
            $user_id,
            $domain_id,
            $group_id,
        ],
    } ) || [];

    $_->sticky( 0 ) for @$visits;
    $_->save for @$visits;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Navigation - A class that provides navigation tree.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
