package OpenInteract2::Action::GroupPages;

use strict;

use base qw(
    Dicole::Action
    Dicole::Action::Common::Summary
    Dicole::Action::Common::Settings
);

use OpenInteract2::Context   qw( CTX );

use Dicole::URL;
use Dicole::MessageHandler qw( :message );
use Dicole::Content::Controlbuttons;
use Dicole::Content::Button;
use Dicole::Content::Text;
use Dicole::Generictool;
use Dicole::DateTime;
use Dicole::WikiFormat;
use Dicole::Pathutils;
use Dicole::Generictool::Data;
use Dicole::Feed;
use Dicole::Diff3::Merge;

# use HTML::FormatText;
use Algorithm::Diff;
use YAML::Syck;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.107 $ =~ /(\d+)\.(\d+)/);

########################################
# Summary box
########################################

sub _summary_customize {
    my ( $self ) = @_;
    
    my $title = Dicole::Widget::Horizontal->new;
    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Wiki'),
            link => Dicole::URL->create_from_parts(
                action => 'grouppages',
                task => 'detect',
                target => CTX->request->target_group_id,
            ),
        )  
    );
    $title->add_content(
        Dicole::Widget::Text->new( text => ' > ' . $self->_msg('Recent changes') )
    );
    
    return {
        box_title => $title->generate_content,
        object => 'group_pages',
        query_options => {
            where => 'groups_id = ?',
            value => [ $self->param('box_group') ],
            limit => 10,
            order => 'last_modified DESC',
        },
        empty_box => $self->_msg( 'No pages found.' ),
        date_field => 'last_modified',
    };
}

sub _summary_item_author {
    my ( $self, $item ) = @_;
    my $author = $item->last_author_user( { skip_security => 1 } );
    return join ' ', ( $author->{first_name}, $author->{last_name} );
}

sub _summary_item_href {
    my ( $self, $item ) = @_;
    return Dicole::URL->create_from_current(
        action => 'grouppages',
        task => 'show',
        other => [ $self->_create_link_title( $item->{title} ) ],
    );
}

########################################
# RSS feed
########################################

# Provide RSS feed for the tool
sub feed {
    my ( $self ) = @_;

    # use the first additional to set a new language
    $self->_shift_additional_language;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    if ( ! $self->skip_secure ) {
        unless ( CTX->request->auth_is_logged_in ) {
            if ( $settings_hash->{ 'ip_addresses_feed'} =~ /^\d+/ ) {
                if ( $self->_check_ip_addresses(
                $settings_hash->{ 'ip_addresses_feed'} )
                ) {
                    return 'Access denied.';
                }
            }
            elsif ( !$settings_hash->{ 'public_feed' } ) {
                return 'Access denied.';
            }
        }
        else {
            return 'Access denied.' unless $self->chk_y( 'read', $self->target_id );
        }
    }

    my $feed = Dicole::Feed->new( action => $self );

    $feed->list_task( 'detect' );

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('group_pages') );

    $feed->creator( 'Dicole wiki' );

    my $group = CTX->lookup_object( 'groups' )->fetch( $self->target_group_id );

    $feed->title( $group->{name} . ' - ' . $self->_msg( 'Wiki' ) );
    $feed->desc( $group->{description} );
    # Fetch latest 10 group pages
    $data->query_params( {
        where => 'groups_id = ?',
        value => [ $self->target_group_id ],
        limit => $settings_hash->{ 'number_of_items_in_feed' } || 5,
        order => 'last_modified DESC'
    } );
    $data->data_group;

    foreach my $object ( @{ $data->data } ) {
        $object->{title_link} = $self->derive_url(
            action => 'grouppages',
            task => 'show',
            additional => [ $self->_create_link_title( $object->{title} ) ],
        );
    }

    $feed->content_link( 'group_pages_content' );
    $feed->date_field( 'last_modified' );
    $feed->subject_field( 'title' );
    $feed->link_field( 'title_link' );

    return $feed->feed(
        objects => $data->data,
    );
}

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'group_pages' );
    $settings->user( 0 );
    $settings->group( 1 );
}

sub _post_init_common_settings {
    my ( $self ) = @_;
    # TODO: check if the forum is in the selected tools before generating this menu
    my $field = $self->gtool->get_field( 'discussion_forum' );
    my $iter = CTX->lookup_object( 'forums' )->fetch_iterator( {
        where => 'groups_id = ?',
        value => [ $self->target_group_id ],
        order => 'title',
    } );
    $field->add_dropdown_item( undef, '-- ' . $self->_msg( 'Select discussion forum' ) . ' --' );
    while ( $iter->has_next ) {
        my $object = $iter->get_next;
        $field->add_dropdown_item( $object->id, $object->{title} );
    }
    $iter->discard;
}

#############################################################

# Overrides Dicole::Action
# Override some parameters passed to init_tool
# to include our RSS feed and other stuff
sub init_tool {
    my ( $self, %hash ) = @_;

    $self->SUPER::init_tool( {
        tool_args => {
            feeds => $self->init_feeds,
        },
        %hash
    } );

}

sub detect {
    my ( $self ) = @_;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    if ( !$settings_hash->{start_title} ) {
        Dicole::MessageHandler->add_message( MESSAGE_WARNING,
            $self->_msg( 'Group does not have a front page!' )
        );
        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'settings',
            )
        ) if $self->chk_y( 'config' );

        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'list',
            )
        );
    }
    return $self->_go_to( 'show', $settings_hash->{start_title} );
}

sub show {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    return $self->_return_main if !$title;

    $self->init_tool;

    $self->tool->custom_css_class( 'wikiPage' );

    my $page = $self->_fetch_page( $title );

    if ( !$page ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( "Page you requested does not exist!" )
        );
        return $self->_go_to( 'create', $title ) if $self->chk_y( 'create' );
        return $self->_return_main;
    }

    if ( defined CTX->request->param( 'locked' ) ) {
        my $lock = CTX->request->param( 'locked' );
        $lock = 0 if !grep $lock, ( 0, 1 );

        if ( $lock ) {
            $self->tool->add_message( MESSAGE_SUCCESS,
                $self->_msg( "Page [_1] has been locked.", $title )
            );
        }
        else {
            $self->tool->add_message( MESSAGE_SUCCESS,
                $self->_msg( "Page [_1] has been unlocked.", $title )
            );
        }

        $page->{locked} = $lock;
        $page->save;
    }

    my $content = $page->group_pages_content || {};
    
    $content = Dicole::Content::Text->new(
        content => $content->{content}, no_filter => 1,
    );

    my $bb = new Dicole::Content::Controlbuttons;

    if ( $self->chk_y( 'edit' ) &&
         ( !$page->{locked} || $self->chk_y( 'lock' ) ) ) {

        $bb->add_buttons( {
            type => 'link',
            value => $self->_msg( 'Edit page' ),
            link => Dicole::URL->create_from_current(
                task => 'edit',
                other => [ $self->_create_link_title( $title ) ],
            ),
        } );
    }

    if ( $self->chk_y( 'lock' ) ) {

        my $name = $page->{locked}
            ? $self->_msg( "Unlock page" )
            : $self->_msg( "Lock page" );
        my $lock = $page->{locked} ? 0 : 1;

        $bb->add_buttons( {
            type => 'link',
            value => $name,
            link => Dicole::URL->create_full_from_current(
                params => { locked => $lock },
            ),
         } );
    }

    $bb->add_buttons( {
        type => 'link',
        value => $self->_msg( 'Version history' ),
        link => $self->derive_url(
            task => 'diff',
            $self->_create_link_title( $title )
        ),
    } );
    
    if ( $self->chk_y( 'remove' ) ) {
        $bb->add_buttons( {
            type  => 'confirm_submit',
            value => $self->_msg( 'Remove page' ),
            confirm_box => {
                title => $self->_msg( 'Remove page' ),
                name => $page->id,
                msg   => $self->_msg( 'This page and its version history will be completely removed. Are you sure you want to remove this page?' ),
                href  => Dicole::URL->create_from_current(
                    task => 'remove',
                    other => [ $self->_create_link_title( $title ) ]
                )
            }
        } );
    }

    my $user = $page->last_author_user( { skip_security => 1 } );
    my $modified = Dicole::Content::Text->new(
        text => $self->_msg( 'This page was last modified [_1] by [_2]',
            Dicole::DateTime->long_datetime_format( $page->{last_modified} ),
            $user->{first_name} . ' ' . $user->{last_name} ),
        attributes => { class => 'lastModifiedWiki' }
    );

    # Discussion
    my @discussions;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    # If discussion forum is active...
    if ( $settings_hash->{discussion_forum} ) {
        # Fetch the message that is supposed to be
        my $message = CTX->lookup_object( 'forums_messages' )->fetch_group( {
            where => 'groups_id = ? AND forum_id = ? AND parent_id = 0 AND title = ?',
            value => [
                $self->target_group_id, # groups_id
                $settings_hash->{discussion_forum}, # forum_id
                $title # title
            ]
        } )->[0];
        if ( ref $message ) {

            # Use an iterator to find out the number of messages in the forum in addition to
            # the latest poster and date of the post
            my $i = 0;
            my $last_user = undef;
            my $last_date = undef;
            my $discussion_iterator = CTX->lookup_object( 'forums_messages' )
                ->fetch_iterator( {
                    where => '(parent_id = ? OR msg_id = ?) AND active = 1',
                    value => [ $message->id, $message->id ],
                    order => 'date DESC'
                } );
            while ( $discussion_iterator->has_next ) {
                my $object = $discussion_iterator->get_next;
                $i++;
                if ( $i == 1 ) {
                    my $user = $object->user;
                    $last_user = $user->{first_name} . ' ' . $user->{last_name};
                    $last_date = Dicole::DateTime->long_date_format( $object->{date} );
                }
            }
            $discussion_iterator->discard;

            push @discussions, Dicole::Content::Text->new(
                text => $self->_msg( 'Number of messages in discussion: [_1]', $i ),
                attributes => { class => 'lastModifiedWiki' }
            );
            push @discussions, Dicole::Content::Text->new(
                text => $self->_msg( 'Last post by: [_1] - [_2]', $last_user, $last_date ),
                attributes => { class => 'lastModifiedWiki' }
            );

            # Add button that leads directly to the discussion
            $bb->add_buttons( {
                type => 'link',
                value => $self->_msg( 'Discussion' ),
                link => Dicole::URL->create_from_current(
                    action => 'forums',
                    task => 'messages',
                    other => [
                        $message->{forum_id},
                        $message->{thread_id},
                        $message->id
                    ]
                ),
            } );
        }
        else {
            # Add button that leads directly to the discussion
            $bb->add_buttons( {
                type => 'link',
                value => $self->_msg( 'Start discussion' ),
                link => Dicole::URL->create_from_current(
                    action => 'forums',
                    task => 'add_thread',
                    params => {
                        id => $settings_hash->{discussion_forum},
                        force_title => $title,
                        content => '<a href="'
                            . Dicole::URL->create_full_from_current
                            . '">' . $title . '</a></br></br>'
                    }
                ),
            } );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name( $title );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $content, $modified, @discussions, $bb ]
    );

    return $self->generate_tool_content;
}

sub export_pages {
    my ( $self ) = @_;

    my $file_name = $self->param('file_name');
    if ( $file_name ne 'pages.yaml' ) {
        return $self->redirect( $self->derive_url(
            additional => [ 'pages.yaml' ],
        ) );
    }

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    my $pages = CTX->lookup_object('group_pages')->fetch_group({
        where => 'groups_id = ?',
        value => [ $self->param('target_group_id') ],
    });

    my $output = {
        pages => [],
    };

    # stupid sorting...
    my @pages = ();
    my $first = ();
    for my $page ( @$pages ) {
        if ( ! $first && $page->title eq $settings_hash->{start_title} ) {
            $first = $page;
        }
        else {
            push @pages, $page;
        }
    }

    @pages = sort { $a->title cmp $b->title } @pages;
    unshift @pages, $first if $first;

    for my $page ( @pages ) {
        my $vn = $page->current_version_group_pages_version;
        my $vn_content = $vn->group_pages_version_content;
        my $raw = $vn_content->content;

        my $formatter = Dicole::WikiFormat->new( exporting => 1 );

        my ($html, $links) = $formatter->execute($raw);

        my $title = $page->title;
        $title =~ s/_/ /g;

        push @{ $output->{pages} }, {
            readable_title => $title,
            content => $html,
        };
    }

    my $yaml = YAML::Syck::Dump( $output );
    my $size = 0;
    {
        use bytes;
        $size = length( $yaml );
    }
    
    CTX->response->header( 'Content-Length', $size ); 
    CTX->response->content_type( 'application/octet-stream' );
    CTX->controller->no_template( 'yes' );

    return $yaml;
}

sub diff {
    my ( $self ) = @_;
    
    my $title = $self->_parse_title;

    return $self->_return_main if !$title;

    my $page = $self->_fetch_page( $title );

    if ( !$page ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( "Page you requested does not exist!" )
        );
        return $self->_return_main;
    }
    
    my $from_id = $self->param('diff_from');
    my $to_id = $self->param('diff_to');
    
    if ( ! defined $from_id || ! defined $to_id ) {
        return CTX->response->redirect(
            $self->_latest_diff_url( $page )
        )
    }
    $self->init_tool;

    my $versions = $page->group_pages_version || [];
    my $content;

    if ( $from_id =~ /^\d+$/ && $to_id =~ /^\d+$/ ) {

        $content = eval {
            $self->_create_diff_content( $page, $from_id, $to_id, $versions );
        };

        if ( $@ ) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( "Requested version does not exists!" )
            );
            return $self->_go_to( 'show', $title );        
       }
    }

    my $name = $title . ' - ' . sprintf( 
        $self->_msg( 'Changes from version %d to version %d' ), $from_id, $to_id
    );
    
    $self->tool->Container->box_at( 0, 0 )->name( $name );

    my $diff = Dicole::Content::Text->new(
        content => $content, no_filter => 1,
    );

    my $current_version = $page->current_version_group_pages_version->{version_number};
    my $link_title = $self->_create_link_title( $title );

    my $from_drop = Dicole::Content::Formelement::Dropdown->new(
        autourl => 1,
        attributes => { name => 'post_diff_from' },
        options => [],
    );
    my $to_drop = Dicole::Content::Formelement::Dropdown->new(
        autourl => 1,
        attributes => { name => 'post_diff_to' },
        options => [],
    );

    my $buttons = [];
    
    push @$buttons, Dicole::Content::Button->new(
        type => 'link', value => '<+<',
        link => $self->derive_url(
            additional => [ $link_title, $from_id - 1, $to_id - 1 ]
        )
    ) if $from_id > 1 && $to_id > 1;
    
    push @$buttons, Dicole::Content::Button->new(
        type => 'link', value => '<',
        link => $self->derive_url(
            additional => [ $link_title, $from_id - 1, $to_id ]
        )
    ) if $from_id > 1;

    push @$buttons, $from_drop;
    push @$buttons, $to_drop;

    push @$buttons, Dicole::Content::Button->new(
        type => 'link', value => '>',
        link => $self->derive_url(
            additional => [ $link_title, $from_id, $to_id + 1 ]
        )
    ) if $to_id < $current_version;
    
    push @$buttons, Dicole::Content::Button->new(
        type => 'link', value => '>+>',
        link => $self->derive_url(
            additional => [ $link_title, $from_id + 1, $to_id + 1 ]
        )
    ) if $to_id < $current_version && $from_id < $current_version;
    
    push @$buttons, Dicole::Content::Button->new(
        type => 'link',
        value => $self->_msg( 'Show current page' ),
        link => $self->derive_url(
            task => 'show',
            additional => [ $link_title ]
        )
    );
    
    foreach my $version ( @$versions ) {

        my $uname = $version->creator_id_user( { skip_security => 1 } );

        $uname = $uname->{first_name} . ' ' . $uname->{last_name};

        my $vtime = $version->{creation_time};
        $vtime = Dicole::DateTime->medium_date_format( $vtime );

        # From dropdown

        my $from_options = {
            attributes => {
                value => $self->derive_url(
                    additional => [
                        $self->_create_link_title( $title ),
                        $version->{version_number}, $to_id
                    ]
                ),
            },
            content => $version->{version_number} . ": $vtime - $uname"
        };

        if ( $version->{version_number} == $from_id ) {
            $from_options->{attributes}->{selected} = 1;
        }
        
        $from_drop->add_options( [ $from_options ] );

        # To dropdown

        my $to_options = {
            attributes => {
                value => $self->derive_url(
                    additional => [
                        $self->_create_link_title( $title ),
                        $from_id, $version->{version_number}
                    ]
                ),
            },
            content => $version->{version_number} . ": $vtime - $uname"
        };

        if ( $version->{version_number} == $to_id ) {
            $to_options->{attributes}->{selected} = 1;
        }
        
        $to_drop->add_options( [ $to_options ] );
    };

    $buttons = Dicole::Content::Controlbuttons->new( buttons => $buttons );
    
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $buttons, $diff ]
    );

    return $self->generate_tool_content;
}

sub remove {
    my ( $self ) = @_;
    my $title = $self->_parse_title;

    return $self->_return_main unless $title;

    my $page = $self->_fetch_page( $title );
    unless ( $page ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( "Page you requested does not exist!" )
        );
        return $self->_go_to( 'show', $title );
    }

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    if ( $settings_hash->{start_title} eq $title ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( "Front page cannot be removed." )
        );
        return $self->_go_to( 'show', $title );
    }

    my $data = Dicole::Generictool::Data->new;
    # Remove page itself
    unless ( $data->remove_object( $page ) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error removing page [_1].', $title )
        );
        return $self->_return_main;
    }
    # Remove page content
    unless ( $data->remove_object( $page->group_pages_content ) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error removing page [_1].', $title )
        );
        return $self->_return_main;
    }
    # Remove page versions and version contents
    foreach my $version ( @{ $page->group_pages_version } ) {
        $data->remove_object( $version->group_pages_version_content );
        $data->remove_object( $version );
    }

    # Remove links from other pages to removed page
    $data->object( CTX->lookup_object('group_pages_link') );
    $data->query_params( {
        where => 'linked_title = ? AND groups_id = ?',
        value => [ $title, $self->target_group_id ]
    } );
    $data->remove_group( undef, $data->data_group( 1 ) );

    # Tell previously linking pages to rebuild their content
    $self->_rebuild_linkers( $title, $data->data );

    # Remove links from removed page to other pages
    $self->_renew_links( $title );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Page [_1] successfully removed.', $title )
    );

    return $self->_return_main;
}

sub list {
    my ( $self ) = @_;

    my $title = $self->_parse_title;

    $self->init_tool;

        $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('group_pages'),
            skip_security => 1,
            current_view => 'list',
        )
    );
    $self->gtool->Data->add_where('groups_id = '.$self->active_group);

    $self->init_fields( package => 'dicole_group_pages' );

    my $tfield = $self->gtool->get_field('title');

    $tfield->link(
        Dicole::URL->create_from_current(
                task => 'show',
                other => [ 'IDVALUE' ],
        )
    );

    $tfield->link_field('title');

    $self->gtool->add_bottom_button(
        type => 'link',
        value => $self->_msg('Export all pages to a file'),
        link => $self->derive_url( task => 'export_pages' ),
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Page listing' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

sub create {
    my ( $self ) = @_;

    my $new_title = CTX->request->param( 'title' );
    my $content = CTX->request->param( 'content' );
    my $preview = CTX->request->param( 'preview' );
    my $create = CTX->request->param( 'create' );

    $new_title ||= $self->_parse_title;

    $new_title = ucfirst( $new_title );

    if ( $self->_fetch_page( $new_title ) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( "Page with this name exists already!" )
        );
        return $self->_go_to( 'show', $new_title );
    }

    $self->init_tool(
        rows => ( $preview ) ? 2 : 1
    );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('group_pages'),
            skip_security => 1,
            current_view => 'create',
        )
    );

    $self->init_fields( package => 'dicole_group_pages' );

    $self->gtool->get_field('title')->{value} = $new_title;
    $self->gtool->get_field('title')->{use_field_value} = 1;

    if ( $create || $preview ) {
        my ( $code, $message ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );

        if ( $code ) {

            my $new_title = CTX->request->param( 'title' );

            if ( $self->_fetch_page( $new_title ) ) {
                $code = MESSAGE_ERROR;
                $message = $self->_msg( "Page with this name exists already!" );
                $self->gtool->get_field('title')->{error} = 1;
            }
            elsif ( ! $preview ) {
                my $version = $self->_create_version( $new_title );
                $self->_build_page( $version, $new_title );

                $message = $self->_msg( "Page has been created." );
                $self->tool->add_message( $code, $message );
                return $self->_go_to( 'show', $new_title );
            }
            else {
                $code = MESSAGE_WARNING;
                $message = $self->_msg( "This is a preview page! It is not yet saved!" );
            }
        }
        else {

            $message = $self->_msg( "Failed to create page: [_1]", $message );

        }

        $self->gtool->get_field('content')->{value} = $content;
        $self->gtool->get_field('content')->{use_field_value} = 1;

        $self->tool->add_message( $code, $message );
    }

    $self->gtool->get_field('title')->{value} = $new_title;
    $self->gtool->get_field('title')->{use_field_value} = 1;

    $self->gtool->bottom_buttons( [
        {
            name  => 'create',
            value => $self->_msg( 'Save' ),
        },
        {
            name  => 'preview',
            value => $self->_msg( 'Preview' ),
        }
    ] );

    if ( ! $preview ) {
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Page information' ) );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            $self->gtool->get_add
        );
    }
    else {

        $self->tool->custom_css_class( 'wikiPage' );

        my $parsed_content = $self->_create_parsed_content(
                { content => $content },
        );

        my $preview_content = Dicole::Content::Text->new(
            content => $parsed_content,
            no_filter => 1,
        );

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Page preview' ) );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ $preview_content ]
        );

        $self->tool->Container->box_at( 0, 1 )->name( $self->_msg( 'Page information' ) );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            $self->gtool->get_add
        );
    }

    return $self->generate_tool_content;

}

sub edit {
    my ( $self ) = @_;

    my $content = CTX->request->param( 'content' );
    my $preview = CTX->request->param( 'preview' );
    my $save = CTX->request->param( 'save' );
    my $ancestor_version_id = CTX->request->param( 'ancestor_version' );
    my $ancestor_version;
    my $current_version;
    my $merge;
    my $conflict;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );

    if ( !$page ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( "Page you requested does not exist!" )
        );
        return $self->_return_main;
    }

    if ( $page->{locked} && !$self->chk_y( 'lock' ) ) {

        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( "Page is locked!" )
        );
        return $self->_go_to( 'show', $title );
    }

    if (! $ancestor_version_id ) {
        $current_version = $page->current_version_group_pages_version;
        $ancestor_version_id = $current_version->{version_number};
    }
    
    if ( $save ) {
        $current_version ||= $page->current_version_group_pages_version;
        
        if ($ancestor_version_id != $current_version->{version_number} ) {
            $merge = 1;
        }
    }

    $self->init_tool(
        rows => ( $preview ) ? 2 : 1
    );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('group_pages'),
            skip_security => 1,
            current_view => 'edit',
        )
    );
    
    $self->init_fields( package => 'dicole_group_pages' );
    
    # Tags
    # Get the tag action class
    my $tag_action = eval { CTX->lookup_action( 'tag_exports' ); };
    # Disabled for now
    if ( $tag_action && 0 ) {
        # Set the object_id so that it is passed to the 
        # construct_tags correctly 
        my $tags_field = $self->gtool->get_field( 'tags' );
        $tags_field->object_id( $page->{'group_page_id'} );

        # Edit the tags if we are saving the page
        if ( $save ) {
            # We are editing the tags
            $tag_action->task( 'edit' );
    
            # Set the object_id and object_type as params
            $tag_action->param( object_id => $tags_field->object_id() );
            $tag_action->param(
                object_type => $tags_field->object_type()
            );
    
            # Call the tag action
            $tag_action->execute();
        }
    }

    if ( $merge ) {
        $ancestor_version = CTX->lookup_object('group_pages_version')
            ->fetch( $ancestor_version_id );
        
        my $vc_object = CTX->lookup_object('group_pages_version_content');
        
        my $ancestor_content = $vc_object->
            fetch( $ancestor_version->{content_id} )->content;
        my $current_content = $vc_object->
            fetch( $current_version->{content_id} )->content;
    
        my $uname = $current_version->creator_id_user(
            { skip_security => 1 }
        );
    
        $uname = $uname->{first_name} . ' ' . $uname->{last_name};
        
        my @conflict_begin = (
            $self->_msg('>>>>>>>>>> BEGINNING OF A CONFLICT'),
            $self->_msg('>>>>>>>>>> You wrote:'),
        );
        my @conflict_middle = (
            sprintf( $self->_msg('>>>>>>>>>> %s wrote:'), $uname),
        );
        my @conflict_end = (
            $self->_msg('>>>>>>>>>> END OF A CONFLICT'),
        );

        my ($merge, $conflicts) = Dicole::Diff3::Merge::merge(
            [ split $/, $ancestor_content ],
            [ split $/, $content ],
            [ split $/, $current_content ],
            sub { (
                @conflict_begin,
                (@{$_[0]}),
                @conflict_middle,
                (@{$_[1]}),
                @conflict_end,
            )}
        );

        $conflict = $conflicts;
        $content = join $/, @$merge;
        
        if ( $conflict ) {
            $self->gtool->get_field('content')->{value} = $content;
        
            $ancestor_version_id = $current_version->{version_number};
        
            $self->tool->add_message( MESSAGE_WARNING,
                $self->_msg( "Conflicts during merging of concurrent edits. Edit not saved yet!" )
            );
        }
        
    }
    
    if ( ! $conflict && ( $save || $preview ) ) {
        my ( $code, $message ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );

        if ( $code ) {
            if ( $preview ) {
                $code = MESSAGE_WARNING;
                $message = $self->_msg( "This is a preview page! It is not yet saved!" );
            }
            else {

                my $version = $self->_create_version( $title, $content );
                $page = $self->_build_page( $version, $title );

                $message = $self->_msg( "Page has been saved." );
                $self->tool->add_message( $code, $message );

                return $self->_go_to( 'show', $title );
            }
        } else {
            $message = $self->_msg( "Failed to save page: [_1]", $message );
        }

        $self->gtool->get_field('content')->{value} = $content;

        $self->tool->add_message( $code, $message );
    }

    my $buttons = [
        Dicole::Content::Formelement->new(
            attributes => {
                type => 'hidden',
                name => 'ancestor_version',
                value => $ancestor_version_id
            },
        ),
    ];

    # Create the base version dropdown
    # (Sets edits initial content as side effect)
    if ( !$preview && !$merge ) {
  
        unshift @$buttons, (
            Dicole::Content::Text->new(
                content => $self->_msg( 'Select base version:' )
            ),
            Dicole::Content::Formelement::Dropdown->new(
                autourl => 1,
                attributes => { name => 'selected_url' },
                options => [],
            ),
        );
    
    
        my $vnum = CTX->request->param('v');
    
        $current_version ||= $page->current_version_group_pages_version;
        my $cnum = $current_version->{version_number};

        $vnum = $cnum if $vnum < 1 || ( $cnum && $vnum > $cnum );


        my $versions = $page->group_pages_version || [];

        foreach my $version ( @$versions ) {
    
            my $uname = $version->creator_id_user(
                { skip_security => 1 }
            );
    
            $uname = $uname->{first_name} . ' ' . $uname->{last_name};
    
            my $vtime = $version->{creation_time};
            $vtime = Dicole::DateTime->medium_date_format( $vtime );
    
            my $options = {
                attributes => {
                    value => Dicole::URL->create_full_from_current(
                        params => { v => $version->{version_number} }
                    ),
                },
                content => $version->{version_number} . ": $vtime - $uname"
            };
    
            if ( $vnum == $version->{version_number} ) {
    
                $options->{attributes}->{selected} = 1;
                $content = $version->group_pages_version_content->{content} unless $preview;
            }
    
            $buttons->[1]->add_options( [ $options ] );
        };
    }

    my $versionsel = Dicole::Content::Controlbuttons->new(
        buttons => $buttons
    );

    my $cfield = $self->gtool->get_field('content');

    $cfield->{value} = $content;
    $cfield->{use_field_value} = 1;

    $self->gtool->bottom_buttons( [ {
        name  => 'save',
        value => $self->_msg( 'Save' ),
    }, {
        name  => 'preview',
        value => $self->_msg( 'Preview' ),
    },{
        type => 'link',
        value => $self->_msg( 'Show page' ),
        link => Dicole::URL->create_from_current(
            task => 'show',
            other => [ $self->_create_link_title( $title ) ],
        )
    } ] );

    my $output = $self->gtool->get_add;
    unshift @$output, $versionsel;

    if ( $merge ) {

        $self->tool->Container->box_at( 0, 0 )->name(
            $self->_msg( "Page [_1] information", $title )
        );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ @$output ]
        );
    }
    elsif ( $preview ) {

        $self->tool->custom_css_class( 'wikiPage' );

        my $parsed_content = $self->_create_parsed_content(
                { content => $content },
        );

        my $preview_content = Dicole::Content::Text->new(
            content => $parsed_content,
            no_filter => 1,
        );

        $self->tool->Container->box_at( 0, 0 )->name(
            $self->_msg( 'Page preview' )
        );

        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ $preview_content ]
        );


        $self->tool->Container->box_at( 0, 1 )->name(
            $self->_msg( "Page [_1] information", $title )
        );

        $self->tool->Container->box_at( 0, 1 )->add_content(
            [ @$output ]
        );
    }
    else {
        $self->tool->Container->box_at( 0, 0 )->name(
            $self->_msg( "Page [_1] information", $title )
        );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ @$output ]
        );
    }

    return $self->generate_tool_content;
}

######################
# private functions

sub _parse_title {
    my ( $self ) = @_;

#    my $parts = Dicole::URL->get_current_parts;
#    my $title = $parts->{other}->[0];

    my $title = $self->param('title');

    $title =~ s/_/ /g;
    
    # Cleanup
    $title =~ s{/}{|}g;

    return $title;
}

sub _create_link_title {
    my ( $self, $title ) = @_;
    $title =~ s/ /_/g;
    $title =~ s{/}{|}g;
    return $title;
}

sub _go_to {
    my ( $self, $to, $title ) = @_;
    return CTX->response->redirect(
        Dicole::URL->create_from_current(
            task => $to,
            other => [ $self->_create_link_title( $title ) ],
        )
    );
}

sub _return_main {
    my ( $self ) = @_;
    return CTX->response->redirect(
        Dicole::URL->create_from_current(
            task => 'detect',
        )
    );
}

sub _fetch_page {
    my ( $self, $title ) = @_;

    my $page = CTX->lookup_object('group_pages')->fetch_group( {
        where => "groups_id = ? AND title = ?",
        value => [ CTX->controller->initial_action->target_group_id, $title ]
    } ) || [];

    return shift @$page;
}

sub _create_version {
    my ( $self, $title, $content ) = @_;

    my $version = CTX->lookup_object('group_pages_version')->new;
    my $vn_content = CTX->lookup_object('group_pages_version_content')->new;

    $vn_content->{content} = $content || CTX->request->param('content');

    # Turn fixed urls into relative
    my $server_name = CTX->request->server_name;
    $vn_content->{content} =~ s{http(s)?://$server_name/}{/}sgi;

    $vn_content->save;

    $version->{content_id} = $vn_content->id;
    $version->{creator_id} = CTX->request->auth_user_id;
    $version->{creation_time} = time;
    $version->{version_number} = $self->_next_version( $title );
    $version->save;

    return $version;
}

sub _build_page {
    my ( $self, $version, $title ) = @_;

    return if !$version || !$title;

    # Convert _ as spaces
    $title =~ s/_/ /gms;

    # Remove unnecessary spaces from the title
    $title =~ s/ +/ /gms;

    my $page = $self->_fetch_page( $title );

    my $content;

    if ( $page ) {
        $content = $page->group_pages_content;
    }
    else {
        $page = CTX->lookup_object('group_pages')->new;
        $content = CTX->lookup_object('group_pages_content')->new;

        $content->{content} = '';
        $content->save;
    }

    $page->{title} = $title;
    $page->{groups_id} = $self->target_group_id;
    $page->{current_version} = $version->id;
    $page->{content_id} = $content->id;
    $page->{last_author} = $version->{creator_id};
    $page->{last_modified} = $version->{creation_time};
    $page->{locked} = $page->{locked} || 0;
    $page->save;

    # Parse content after page saving to fix links to self upon creation.

    $content->{content} = $self->_create_parsed_content(
        $version->group_pages_version_content,
        $title
    );
    $content->save;

    $page->group_pages_version_add( $version );

    $self->_rebuild_linkers( $title ) if $version->{version_number} == 1;

    return $page;
}

sub _rebuild_linkers {
    my ( $self, $title, $linkers ) = @_;

    $linkers ||= CTX->lookup_object('group_pages_link')->fetch_group( {
        where => 'linked_title = ? AND groups_id = ?',
        value => [ $title, $self->target_group_id ],
    } ) || [];

    $self->_rebuild_content( $_->{linking_title} ) foreach @$linkers;
}

sub _rebuild_content {
    my ( $self, $title ) = @_;

    my $page = $self->_fetch_page( $title );
    return if !$page;

    my $version = $page->current_version_group_pages_version;
    return if !$version;

    my $content = $page->group_pages_content;
    return if !$content;

    $content->{content} = $self->_create_parsed_content(
        $version->group_pages_version_content,
        $title
    );

    $content->save;
}

sub _create_page_lookup_array {
    
    my ( $self ) = @_;
    my $lookup_array = [];
    my $iter = CTX->lookup_object('group_pages')->fetch_iterator( {
        where => 'groups_id = ?',
        value => [ $self->target_group_id ]
    } );    
    while ( $iter->has_next ) {
        my $object = $iter->get_next;
        push @{ $lookup_array }, $object->{title};
    }
    return $lookup_array;
}

sub _check_if_page_exists {
    my ( $self, $page ) = @_;
    $self->{_existing_pages} ||= $self->_create_page_lookup_array;
    if ( scalar( grep { $_ eq $page } @{ $self->{_existing_pages} } ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _create_parsed_content {
    my ( $self, $version_content, $title ) = @_;

    return if !ref $version_content;

    my $content = $version_content->{content};

    return if !$content;

    my $formatter = Dicole::WikiFormat->new(
    
        prefix => Dicole::URL->create_from_current(
            task => 'show',
        ) . '/',

        create_prefix => Dicole::URL->create_from_current(
            task => 'create',
        ) . '/',
    );

    my ($html, $links) = $formatter->execute($content);

    $links ||= {};
    my @links = keys %$links;

    $self->_renew_links($title, \@links) if $title;

    return $html;
}

sub _renew_links {
    my ( $self, $title, $new_links ) = @_;

    $new_links ||= [];

    my $old_links =  CTX->lookup_object('group_pages_link')->fetch_group( {
        where => 'linking_title = ? AND groups_id = ?',
        value => [ $title, $self->target_group_id ],
    } );

    foreach my $link (@$new_links) {
        next if grep { $link eq $_->{linked_title} } @$old_links;

        my $new = CTX->lookup_object('group_pages_link')->new;
        $new->{groups_id} = $self->target_group_id;
        $new->{linking_title} = $title;
        $new->{linked_title} = $link;
        $new->save;
    }
    foreach my $link (@$old_links) {
        next if grep { $link->{linked_title} eq $_ } @$new_links;

        $link->remove;
    }
    return $old_links;
}

sub _next_version{
    my ( $self, $title ) = @_;

    return 1 if !$title;

    my $page = $self->_fetch_page( $title );

    return 1 if !$page;

    return $page->current_version_group_pages_version->{version_number} + 1;
}

sub _latest_diff_url {
    my ( $self, $page ) = @_;

    my $current = $page->current_version_group_pages_version->{version_number};
    $current ||= 1;
    
    my $previous = $current - 1;
    $previous ||= 1;

    return $self->derive_url(
        task => 'diff',
        additional => [
            $self->_create_link_title( $page->{title} ),
            $previous, $current
        ],
    );
}

sub _create_diff_content {
    my ( $self, $page, $from_id, $to_id, $versions ) = @_;

    $versions ||= $page->group_pages_version || [];
    my %vhash = map { $_->{version_number} => $_ } @$versions;

    my $from_version = $vhash{ $from_id };
    my $to_version = $vhash{ $to_id };

    die if ! $from_version || ! $to_version;

#    my $from_parsed = ( $from_version ) ? $self->_create_parsed_content(
#        $from_version->group_pages_version_content
#    ) : '';

#    my $to_parsed = ( $to_version ) ? $self->_create_parsed_content(
#        $to_version->group_pages_version_content
#    )  : '';

#    my $from_text = ( $from_version ) ?
#        HTML::FormatText->format_string( $from_parsed ) : '';
#    my $to_text = ( $to_version ) ?
#        HTML::FormatText->format_string( $to_parsed ) : '';

    my $from_text = $from_version->group_pages_version_content->{content};
    my $to_text = $to_version->group_pages_version_content->{content};

    # escape texts here?

    my @from_lines= split( $/, $from_text );
    my @to_lines= split( $/, $to_text );

    my @changes = Algorithm::Diff::sdiff( \@from_lines, \@to_lines );

    # Unify same type of diffs & invert approproate changes
    
    my @uchanges = ();
    my $last_type = '';
    for my $diff ( @changes ) {
        if ( $last_type eq $diff->[0] ) {
            push @{ $uchanges[-1]->[1] }, $diff->[1];
            push @{ $uchanges[-1]->[2] }, $diff->[2];
        }
        else {
            push @uchanges, [ $diff->[0], [ $diff->[1] ], [ $diff->[2] ] ];
        }
        
        # check if this or last change should be inverted
        if ( $diff->[0] eq '-' && $last_type eq 'c' ) {
            $uchanges[-2]->[0] = 'c+';
        }
        elsif ( $diff->[0] eq 'c' && $last_type eq '+' ) {
            $uchanges[-1]->[0] = 'c+';
        }
        
        $last_type = $diff->[0];
    }

    my $output = '<div class="wikiDiff">';    

    $last_type = '';
    for my $diff ( @uchanges ) {

        for my $i (1,2) {
            for ( @{ $diff->[$i] } ) {
                $_ =~ s/(^ +| {2,})/<pre>$1<\/pre>/gs;
            }
        }

        if ( $diff->[0] eq 'u' ) {
            $output .= '</div>' if $last_type;
            $output .= '<div class="wikiDiffUnchanged">';
            $output .= join '<br/>', @{ $diff->[1] };
        }
        elsif ( $diff->[0] eq '-' ) {
            if ( $last_type ne 'c+' ) {
                $output .= '</div>' if $last_type;
                $output .= '<div class="wikiDiffRemove">';
            }
            else {
                $output .= '<br/>';
            }
            $output .= join '<br/>', @{ $diff->[1] };
        }
        elsif ( $diff->[0] eq '+' ) {
            if ( $last_type ne 'c' ) {
                $output .= '</div>' if $last_type;
                $output .= '<div class="wikiDiffAdd">';
            }
            else {
                $output .= '<br/>';
            }
            $output .= join '<br/>', @{ $diff->[2] };
        }
        elsif ( $diff->[0] eq 'c' ) {
            if ( $last_type ne '-' ) {
                $output .= '</div>' if $last_type;
                $output .= '<div class="wikiDiffRemove">';
            }
            else {
                $output .= '<br/>';
            }
            $output .= join '<br/>', @{ $diff->[1] };
            $output .= '</div><div class="wikiDiffAdd">';
            $output .= join '<br/>', @{ $diff->[2] };
        }
        elsif ( $diff->[0] eq 'c+' ) {
            if ( $last_type ne '+' ) {
                $output .= '</div>' if $last_type;
                $output .= '<div class="wikiDiffAdd">';
            }
            else {
                $output .= '<br/>';
            }
            $output .= join '<br/>', @{ $diff->[2] };
            $output .= '</div><div class="wikiDiffRemove">';
            $output .= join '<br/>', @{ $diff->[1] };
        }
        $last_type = $diff->[0];
    }
    $output .= '</div></div>';

    return $output;    
}

########################################
# Frontpage box
########################################



sub frontpage {
    my ( $self ) = @_;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    my $box = Dicole::Box->new();
    
    my $title = Dicole::Widget::Horizontal->new;
    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Wiki'),
            link => Dicole::URL->create_from_parts(
                action => 'grouppages',
                task => 'detect',
                target => CTX->request->target_group_id,
            ),
        )  
    );
    $title->add_content(
        Dicole::Widget::Text->new( text => ' > ' . $self->_msg('Front page') )
    );
    
    $box->name( $title->generate_content );

    my $page = $self->_fetch_page( $settings_hash->{start_title} );

    my $content = undef;
    if ( ref $page ) {
        $content = $page->group_pages_content || {};
        $content = $content->{content};
    }
    else {
        $content = $self->_msg( 'Front page not yet created.' );
    }

    $content = Dicole::Content::Text->new(
        text => $content,
        no_filter => 1,
    );

    $box->content( $content );

    return $box->output;
}


1;

__END__

=head1 NAME

OpenInteract2::Action::GroupPages - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
