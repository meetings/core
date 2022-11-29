package OpenInteract2::Action::DicoleWiki;

use strict;
use base qw(
    OpenInteract2::Action::DicoleWikiCommon
    Dicole::Action::Common::Settings
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Data::Dumper;

use Algorithm::Diff;
use JSON;
use YAML::Syck;
use HTML::Entities;

use Dicole::MessageHandler   qw( :message );
use Dicole::Utility;
use Dicole::Utils::SPOPS;
use Dicole::Utils::SQL;
use Dicole::Utils::HTML;

use Dicole::Widget::LinkButton;
use Dicole::Widget::Text;
use Dicole::Widget::Javascript;
use Dicole::Widget::CSSLink;
use Dicole::Widget::ContentBox;
use Dicole::Widget::Vertical;
use Dicole::Widget::Columns;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Horizontal;
use Dicole::Widget::HiddenBlock;
use Dicole::Widget::FormControl::Select;
use Dicole::Widget::FormControl::SubmitButton;
use Dicole::Widget::DatedList;
use Dicole::Widget::TagSuggestionListing;
use Dicole::Widget::TagSuggestions;
use Dicole::Widget::TagCloud;
use Dicole::Widget::LinkCloud;

use HTML::Entities;

sub CHANGE_NORMAL { 0 }
sub CHANGE_MINOR  { 1 }
sub CHANGE_CREATE { 2 }
sub CHANGE_REVERT { 3 }

#######
# Feed
#######

sub init_tool {
    my $self = shift;

    $self->SUPER::init_tool( {
            tool_args => {
                feeds => $self->init_feeds(
                    task => 'feed',
                ),
                no_tool_tabs => 1,
            },
            cols => 2,
            @_,
    } );

    my $navi = $self->tool->get_tablink_box( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->name( $navi->{name} );
    $self->tool->Container->box_at( 0, 0 )->content( $navi->{content} );
    $self->tool->Container->column_width( '280px', 1 );

    if ( $self->task =~ /^(show)$/ ) {
        $self->tool->action_buttons( [ {
            name => $self->_msg('Create page'),
            class => 'wiki_create_action',
            url => $self->derive_url( action => 'wiki', task => 'create', additional => [] ),
        } ] ) if $self->schk_y( 'OpenInteract2::Action::DicoleWiki::create' );
    }
}

sub _digest {
    my ( $self ) = @_;

   # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};
    $self->language( $self->param('lang') );

    my $group_id = $self->param('group_id');
    my $user_id = $self->param('user_id');
    my $domain_host = $self->param('domain_host');
    my $start_time = $self->param('start_time');
    my $end_time = $self->param('end_time');

    my $items = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'groups_id = ? AND change_type = ? AND creation_time >= ? AND creation_time < ?',
        value => [ $group_id, CHANGE_NORMAL, $start_time, $end_time ],
        order => 'creation_time DESC'
    } ) || [];

    if (! scalar( @$items ) ) {
        return undef;
    }

    my $pages = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $items,
        link_field => 'page_id',
        object_name => 'wiki_page',
    );

    my $return = {
        tool_name => $self->_msg( 'Wiki' ),
        items_html => [],
        items_plain => []
    };

    for my $item ( @$items ) {

        my $vn = $item->version_number;
        my @diffs = $vn ? ( $vn - 1, $vn ) : ( 0, 0 );

        my $link = $domain_host . Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'show',
            target => $group_id,
            additional => [
                $pages->{ $item->page_id }->{title}
            ],
        );
        my $link_history = $domain_host . Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'changes',
            target => $group_id,
            additional => [
                $pages->{ $item->page_id }->{title},
                @diffs
            ],
        );

        my $title = $pages->{ $item->page_id }->{readable_title};

        my $date_string = Dicole::DateTime->medium_datetime_format(
            $item->{creation_time}, $self->param('timezone'), $self->param('lang')
        );

        my $user = CTX->lookup_object('user')->fetch( $item->{creator_id}, { skip_security => 1 } );
        my $user_name = $user->first_name . ' ' . $user->last_name;

        push @{ $return->{items_html} },
            '<span class="date">' . $date_string
            . '</span> - <a href="' . $link . '">' . $title
            . '</a> - <a href="' . $link_history . '">v. ' . $item->{version_number} . '</a> - <span class="author">'
            . $user_name . ' - ' . $item->{change_description} . '</span>';

        push @{ $return->{items_plain} },
            $date_string . ' - ' . $title  .' - v. ' . $item->{version_number} . ' - '
            . $user_name . "\n" . $item->{change_description} . "\n  - " . $link;
    }

    return $return;
}

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
            elsif ( ! $settings_hash->{ 'public_feed' } ) {
                return 'Access denied.';
            }
        }
        else {
            return 'Access denied.' unless $self->chk_y(
                'read', $self->param('target_group_id')
            );
        }
    }

    my $group = CTX->lookup_object( 'groups' )->fetch(
        $self->param('target_group_id'),
    );

    # default to five posts per feed
    my $limit = $settings_hash->{ 'number_of_items_in_feed' };
    $limit = 5 if ! $limit || ! ( $limit =~ /^\d+$/ );

    my $objects = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'groups_id = ? AND change_type = ?',
        value => [
            $self->param('target_group_id'),
            CHANGE_NORMAL
        ],
        order => 'creation_time DESC',
        limit => $limit,
    } ) || [];

    my $pages = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $objects,
        link_field => 'page_id',
        object_name => 'wiki_page',
    );

    foreach my $item ( @{ $objects } ) {

        my $vn = $item->version_number;
        my @diffs = $vn ? ( $vn - 1, $vn ) : ( 0, 0 );

        my $link = Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'changes',
            target => $group->id,
            additional => [
                $pages->{ $item->page_id }->{title},
                @diffs
            ],
        );
        $item->{custom_link} = $link;
        $item->{custom_title} = $pages->{ $item->page_id }->{readable_title};
    }

    my $feed = Dicole::Feed->new( action => $self );

    $feed->list_task('history'),
    $feed->creator('Dicole Wiki');
    $feed->title( $group->{name} . ' - ' . $self->_msg( 'Wiki' ) );
    $feed->desc( $group->{description} );

    $feed->title_field('custom_title');
    $feed->link_field('custom_link');
    $feed->content_field('change_description');
    $feed->date_field('creation_time');

    return $feed->feed(
        objects => $objects,
    );
}

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'wiki' );
    $settings->user( 0 );
    $settings->group( 1 );
}

sub _post_init_common_settings {
    my ( $self ) = @_;

    my $pages = CTX->lookup_object( 'wiki_page' )->fetch_group( {
        where => 'groups_id = ?',
        value => [ $self->param('target_group_id') ],
        order => 'readable_title',
    } ) || [];

    my $field = $self->gtool->get_field( 'starting_page' );
    for ( @$pages ) {
        $field->add_dropdown_item( $_->title, $_->readable_title );
    }

    $field = $self->gtool->get_field( 'sidebar_page' );
    $field->add_dropdown_item( undef, $self->_msg('None') );
    for ( @$pages ) {
        $field->add_dropdown_item( $_->title, $_->readable_title );
    }
    $field = $self->gtool->get_field( 'sidebar_page_2' );
    $field->add_dropdown_item( undef, $self->_msg('None') );
    for ( @$pages ) {
        $field->add_dropdown_item( $_->title, $_->readable_title );
    }
}

sub _settings_container_box {
    my ( $self ) = @_;
    return $self->tool->Container->box_at( 1, 0 );
}

######################
# public functions

sub detect {
    my ( $self ) = @_;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $starting_page = $settings->setting('starting_page');

    if ( ! $starting_page ) {
        Dicole::MessageHandler->add_message( MESSAGE_WARNING,
            $self->_msg( 'Group does not have a starting page!' )
        );

        if ( $self->chk_y( 'create' ) ) {
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'create',
                )
            );
        }
        else {
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'browse',
                )
            );
        }
    }

    return $self->_go_to( 'show', $starting_page );
}

sub show_by_id {
    my ( $self ) = @_;

    my $page = CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );
    die "security error" unless $page->groups_id == $self->param('target_group_id');

    return $self->_go_to( 'show', $page->title );
}

sub show {
    my ( $self ) = @_;

    if ( CTX->request->param('find') ) {
        my $ns = CTX->request->param('new_search');
        my @p = $ns ? ( search => $ns ) : ();
        $self->redirect( $self->derive_url(
            task => 'search',
            additional => [],
            params => { @p }
        ) );
    }

    if ( my $a = CTX->request->param('anchor') ) {
        $self->redirect( $self->derive_url( ( $a eq '_clear' ) ? () : ( anchor => $a ) ) );
    }

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );
    my $readable_title = $page->readable_title;
    my $version = $self->param('version');

    if ( $version && ! $self->chk_y( 'browse_versions' ) ) {
        $self->_redirect_to_current_version( $page );
    }
    
    my $wiki_settings = $self->_fetch_wiki_settings_for_page( $page );

    my $sections = eval{ $self->_sections_for_page( $page, $version ) };
    if ( $@ ) {
        $self->redirect( $self->derive_url( additional => [ $page->title ] ) );
    }
    
    if ( $version && $version == $page->last_version_number ) {
        $self->redirect( $self->derive_url( additional => [ $page->title ] ) );
    }

    if ( ! $version ) {
        if ( defined( $version ) && $version =~ /0+/ ) {
            $self->_redirect_to_current_version( $page );
        }
        $self->_process_locking( $page );
        $self->_process_comment_toggling( $page );
        $self->_process_summary_page( $page );
    }

    my $editable = ! $version && $self->chk_y( 'edit' ) && ! $page->moderator_lock;

    if ( $version ) {
        if ( CTX->request->param('revert') && $self->chk_y( 'edit' ) ) {
            if ( $page->moderator_lock ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg('Could not revert since the page is locked.')
                );
                $self->redirect( $self->derive_url );
            }
            
            my $locks = $self->_fetch_locks_for_page( $page ) || [];
            if ( scalar( @$locks ) ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg('Revert failed because the page is currenty being edited.')
                );
                $self->redirect( $self->derive_url );
            }
            
            $self->_process_revert( $page, $sections );
            
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Revert succesful')
            );
            
            $self->redirect( $self->derive_url( additional => [ $page->title ] ) );
        }
    }
    elsif ( CTX->request->param('cancel') ) {
        $self->_remove_lock;
        $self->redirect( $self->derive_url );
    }
    elsif ( CTX->request->param('save') ) {
        if ( $editable ) {
            $sections = $self->_process_save( $page, $sections );
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg('Could not save changes because page is locked.')
            ) if $page->moderator_lock;
            # we leave the lock in database just in case since it contains
            # the change which could not be saved.
        }
        $self->redirect( $self->derive_url );
    }

    my $lock_info = [];
    my $block_info = [];

    if ( $editable ) {

        my $shifted_locks = $self->_get_shifted_locks_for_version(
            $page, $page->last_version_number
        ) || [];

        $lock_info = $self->_get_lock_info( $shifted_locks );

        $block_info = $self->_get_block_info( $sections );
    }

    $self->init_tool( rows => 20, tab_override => 'detect', upload => 1 );
    $self->tool->custom_css_class( 'wiki_page_id_' . $page->id );

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object => $page,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $page->groups_id,
        act => 'show',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    my $js_params = {
        'wiki_start_annotation_url' => $self->derive_url(
            action => 'wiki_json', task => 'start_annotation', additional => [],
        ),
        'wiki_save_annotation_url' => $self->derive_url(
            action => 'wiki_json', task => 'save_annotation', additional => [],
        ),
        'wiki_cancel_annotation_url' => $self->derive_url(
            action => 'wiki', task => 'cancel_annotation',
        ),
        'wiki_page_id' => $page->id,
        'wiki_base_version_number' => $page->last_version_number,
        'wiki_renew_lock_url' => $self->derive_url(
            action => 'wiki_json', task => 'renew_lock',
        ),
        'wiki_right_to_annotate' => ( $page->moderator_lock || ! $self->_page_annotations_visible( $page, $wiki_settings ) || ! $self->chk_y('annotate') ) ? 0 : 1,
    };

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables( ' . Dicole::Utils::JSON->uri_encode( $js_params ) . ' );'
        ),
        Dicole::Widget::Javascript->new(
            code =>
                'page_params = ' . Dicole::Utils::JSON->encode( {
                    page_id => $page->id,
                    base_version_number => $page->last_version_number,
                } ) .
                ';content_data = ' . Dicole::Utils::JSON->encode( {
                    locks => $lock_info,
                    blocks => $block_info,
                    mce_lang => CTX->request->session->{lang}{code},
                    target_group_id => $self->param('target_group_id'),
                    user_id => CTX->request->auth_user_id,
                    start_editing_url => $self->derive_url(
                        action => 'wiki_json', task => 'start_editing',
                    ),
                    renew_lock_url => $self->derive_url(
                        action => 'wiki_json', task => 'renew_lock',
                    ),
                    strings => {
                        'Edit block' => $self->_msg( 'Edit chapter' ),
                        'Edit content' => $self->_msg( 'Edit text' ),
                        'Edit whole' => $self->_msg( 'Edit whole page' ),
                        'Edit begin' => $self->_msg( 'Edit beginning' ),
                        'Reserving lock..' =>
                            $self->_msg( 'Reserving lock..' ),
                        'Resume edit' =>
                            $self->_msg( 'Resume interrupted editing' ),
                        'show' => $self->_msg( 'show' ),
                        'hide' => $self->_msg( 'hide' ),
                        'warning' => $self->_msg('You have not saved or cancelled the edit and the part you were editing is still locked. If you continue others can not edit the part until your lock expires.'),
                    }
                } ),
        ),
    );

    if ( $editable ) {
        my $alist = $self->_attachment_list_html( $page );
        $self->tool->add_tinymce_widgets( 'wiki', 0, {
            wiki => 1,
            attachment_list_initial => $alist,
            attachment_list_url => $self->derive_url(
                action => 'wiki_json', task => 'attachment_list_data', additional => [ $page->id ]
            ),
            attachment_post_url => $self->derive_url(
                action => 'wiki_raw', task => 'attachment_post', additional => [ $page->id ],
                params => { dic => Dicole::Utils::User->temporary_authorization_key( CTX->request->auth_user ) },
            ),
        } );

        $self->tool->add_head_widgets(
            Dicole::Widget::Javascript->new(
                src => '/js/dicole_comments_tinymce_init.js',
            ),
        );
    }
    else {
        $self->tool->add_tinymce_widgets( 'comments', 0, {} );
    }

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new(
            code => 'dojo.require("dicole.comments");',
        ),
        Dicole::Widget::Javascript->new(
            code => 'dojo.require("dicole.wiki");',
        ),
        Dicole::Widget::CSSLink->new(
            href => '/css/dicole_wiki.css',
        ),
    );

    $self->tool->add_end_widgets(
        Dicole::Widget::Raw->new( raw => 
            '<table class="defaultSkin" id="wiki_toolbar_container_table" style="position: absolute;"><tr id="wiki_toolbar_container_tr"><td></td></tr></table>'
        ),
        Dicole::Widget::Javascript->new(
            code => 'wiki_init()',
        ),
    );

    my $toc_elements = $self->_gather_toc_elements( $sections );

    $self->_filter_outgoing_links( $page, $sections );
    $self->_filter_outgoing_images( $page, $sections );
    $self->_filter_outgoing_annos( $page, $sections, $wiki_settings );
    $self->_add_anchors_to_headers( $page, $sections );
    $self->_add_sh_switches_to_link_headers( $page, $sections );


    my $wiki_page = $self->_temporary_wiki_widget(
        $page, $sections, $toc_elements
    );

    $self->_create_side_boxes( $page, $version, $wiki_settings );

    my $box_name = $readable_title;
    $box_name .= ' ' . $self->_msg('( version [_1] )', $version ) if $version;

    $self->tool->Container->box_at( 1, 0 )->name(
        $box_name
    );
    $self->tool->Container->box_at( 1, 0 )->add_content( [
        $wiki_page,
    ] );

#     my $box_attachments = $self->_msg('Attachments');
#     $self->tool->Container->box_at( 1, 1 )->name(
#         $box_attachments,
#     );
#     $self->tool->Container->box_at( 1, 1 )->add_content( [
#         $self->_create_attachments_box()
#     ] );
# 
    eval {
        my $t = CTX->lookup_action('commenting')->execute( 'get_comment_tree_widget', {
            object => $page,
            comments_action => 'wiki_comments',
            disable_commenting => ( ! $page->moderator_lock && $self->chk_y( 'comment' ) ) ? 0 : 1,
            right_to_remove_comments =>
                $self->chk_y( 'remove_comments' ),
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
        
       # $self->tool->add_comments_widgets if $self->chk_y( 'comment' );
        
        $self->tool->Container->box_at( 1, 2 )->class( 'wiki_comments_container_box' );
        
        my $comment_count = CTX->lookup_action('commenting')->execute( 'get_comment_count', {
        	object => $page
    	} ) || 0;
        
        if($comment_count == 0) {
        	$self->tool->Container->box_at( 1, 2 )->name( $self->_msg('No comments') );
        } elsif($comment_count == 1) {
        	$self->tool->Container->box_at( 1, 2 )->name( $self->_msg('One comment') );
        } elsif($comment_count > 1) {
        	$self->tool->Container->box_at( 1, 2 )->name( $self->_msg('[_1] comments', $comment_count) );
        }
        
        $self->tool->Container->box_at( 1, 2 )->add_content(
            [ $t ]
        );
    } unless $page->hide_comments;

    $self->tool->tool_title_suffix( $readable_title );

    eval { CTX->lookup_action('awareness_api')->e( add_open_graph_properties => {
        title => $self->tool->tool_title_suffix,
        description => Dicole::Utils::HTML->html_to_text( $self->_sections_to_html( $sections ) ),
        images_from_html => $self->_sections_to_html( $sections ),
    } ) };

    return $self->generate_tool_content;
}

sub add_bookmark {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );

    die "security error" unless $page;
    die "security error" unless CTX->request->auth_user_id;

    CTX->lookup_action('bookmarks_api')->e( add_user_bookmark_for_object => {
        object => $page,
        creator_id => CTX->request->auth_user_id,    
    } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,    
        $self->_msg('Bookmark added succesfully.')
    );

    return $self->redirect( $self->derive_url( task => 'show' ) ); 
}

sub remove_bookmark {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );

    die "security error" unless $page;
    die "security error" unless CTX->request->auth_user_id;

    CTX->lookup_action('bookmarks_api')->e( remove_user_bookmark_for_object => {
        object => $page,
        creator_id => CTX->request->auth_user_id,    
    } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,    
        $self->_msg('Bookmark removed succesfully.')
    );

    return $self->redirect( $self->derive_url( task => 'show' ) ); 
}
sub create {
    my ( $self ) = @_;

    my $readable_title = CTX->request->param( 'new_title' );
    $readable_title = $self->_raw_title_to_readable_form( $readable_title );

    if ( $readable_title && CTX->request->param('suffix_tag') ) {
        $readable_title .= ' (#' . CTX->request->param('suffix_tag') . ')';
    }

    my $title = $self->_title_to_internal_form( $readable_title );

    if ( $title ) {
        if ( $self->_fetch_page( $title ) ) {
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page already exists!')
            );
            $self->_go_to('show', $title);
        }
    }

    if ( CTX->request->param('create') ) {

        if ( $title ) {
            my $new_page = $self->_create_page(
                group_id => $self->param('target_group_id'),
                readable_title => $readable_title,
                title => $title,
                base_page_id => CTX->request->param('base_page'),
                prefilled_tags => CTX->request->param('prefilled_tags'),
            );

            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page created!')
            );

            $self->_go_to('show', $title);
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg('No page name specified!')
            );
        }
    }

    $self->init_tool;

    if ( $title ) {
        $self->tool->Container->box_at( 1, 0 )->name(
            $self->_msg( "Creating page '[_1]'", $readable_title )
        );

        $self->tool->Container->box_at( 1, 0 )->add_content(
            [
                @{ $self->_get_common_create_widgets },
            ]
        );
    }
    else {
        $self->tool->Container->box_at( 1, 0 )->name(
            $self->_msg( 'New page creation' ) );

        $self->tool->Container->box_at( 1, 0 )->add_content(
            [
                Dicole::Widget::Text->new(
                    text => $self->_msg( "Type the name of the page:" ),
                ),
                Dicole::Widget::FormControl::TextField->new(
                    name => "new_title",
                ),
                @{ $self->_get_common_create_widgets },
            ]
        );
    }

    return $self->generate_tool_content;
}

sub rename {
    my ($self) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );
    my $new_title = CTX->request->param('new_title');
    if ( $new_title ) {
        if ( $self->_fetch_page( $self->_raw_title_to_internal_form( $new_title ) ) ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg('Page already exists!')
            );
        }
        else {
            my $redir = CTX->lookup_object('wiki_redirection')->new;
            $redir->date( time() );
            $redir->title( $page->title );
            $redir->readable_title( $page->readable_title );
            $redir->page_id( $page->id );
            $redir->group_id( $page->groups_id );
            $redir->save;

            $page->readable_title( $self->_raw_title_to_readable_form( $new_title ) );
            $page->title( $self->_raw_title_to_internal_form( $new_title ) );
            $page->save;

            my $settings = $self->_get_settings;
            $settings->fetch_settings;
            my $starting_page = $settings->setting('starting_page');
            if ( lc ( $starting_page ) eq lc( $redir->title ) ) {
                $settings->setting( starting_page => $page->title );
            }

            $self->_update_page_indexes( $page );

            return $self->redirect( $self->derive_url(
                task => 'show', additional => [ $self->_raw_title_to_internal_form( $new_title ) ]
            ) );
        }
    }

    $self->init_tool;

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( "Renaming page '[_1]'", $page->readable_title )
    );

    $self->tool->Container->box_at( 1, 0 )->add_content( [
        Dicole::Widget::Text->new( text => $self->_msg( 'New page name:' ) ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'new_title',
            value => $new_title ? $new_title : '',

        ),
        Dicole::Widget::FormControl::SubmitButton->new(
            name => 'submit',
            value => $self->_msg('Rename'),
        ),
    ] );

    return $self->generate_tool_content;
}

sub remove {
    my ($self) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );

    if ( CTX->request->param('delete') ) {
        $self->_remove_page( $page, $self->param('domain_id'), CTX->request->auth_user_id );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( "Page '[_1]' succesfully deleted",
                $page->readable_title
            )
        );

        $self->_return_to_main;
    }

    # fetch linking;
    my $links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linked_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my @output = ();

    if ( scalar(@$links) ) {
        @output = ( $self->_msg('Please note that the following pages are currently linking to this page:') );
        # Fix this with a list widget when the tuits come this way
        push @output, Dicole::Widget::Vertical->new(
            contents => [ map( {
                Dicole::Widget::Hyperlink->new(
                    link => $self->derive_url(
                        task => 'show',
                        additional => [ $_->linking_page_title ],
                    ),
                    content => $_->readable_linking_title,
                )
            } @$links) ]
        );
    }

    my $query = Dicole::Widget::Vertical->new(
        contents => [
            $self->_msg("Are you sure that you want to delete the page '[_1]' and it's version history?", $page->readable_title ),
            @output,
            Dicole::Widget::Horizontal->new( contents => [
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => 'delete',
                    text => $self->_msg('Yes, I am sure'),
                    value => 1,
                ),
                Dicole::Widget::LinkButton->new(
                    text => $self->_msg('Back'),
                    link => $self->derive_url( task => 'show' ),
                )
            ] )
        ]
    );

    $self->init_tool;

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( "Confirm removing page '[_1]'",
            $page->readable_title ) );

    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $query ]
    );

    return $self->generate_tool_content;
}

sub browse {
    my ( $self ) = @_;

    my $links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'groups_id = ? AND linked_page_id != ?',
        value => [ $self->param('target_group_id'), 0 ],
    } ) || [];

    my $pages = CTX->lookup_object('wiki_page')->fetch_group( {
        where => 'groups_id = ?',
        value => [ $self->param('target_group_id')],
        order => 'readable_title',
    } ) || [];

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $starting_page_title = $settings->setting('starting_page');

    my $starting_page = $self->_fetch_page(
        $starting_page_title, $pages
    );

    my $linked_pages = {};

    my $found_tree;
    if ( $starting_page ) {
        $found_tree = $self->_get_tree_of_found_pages(
            $links, $linked_pages, $starting_page
        );
    }

    my $orphaned_tree = $self->_get_tree_of_orphaned_pages(
        $links, $pages, $linked_pages
    );

    my @trees = ();
    unshift @trees, $found_tree if $found_tree;
    unshift @trees, $orphaned_tree if $orphaned_tree;

    $self->init_tool;
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Structure of wiki' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        \@trees
    );

    return $self->generate_tool_content;
}

sub page_history {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );
    my $readable_title = $page->readable_title;

    if ( ! $self->chk_y( 'browse_versions' ) ) {
        $self->_redirect_to_current_version( $page );
    }

    $self->init_tool;
    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('wiki_version'),
            current_view => 'page_history',
            initial_construct_params => {
                custom_link_values => {
                    page_name => $page->title,
                    versions => sub {
                        my $vn = shift->object->version_number;
                        return ( $vn > 0 ) ? $vn - 1 . "/$vn" : "$vn/$vn";
                    },
                    version_number => sub {
                        return shift->object->version_number;
                    },
                }
            }
        )
    );

    $self->init_fields;

    my $dd = $self->gtool->get_field('creator_id');
    my $users = CTX->lookup_object('user')->fetch_group({
    }) || [];
    for ( @$users ) {
        $dd->add_dropdown_item(
            $_->id, $_->first_name.' '.$_->last_name
        );
    }

    $self->gtool->Data->add_where(
        'page_id = ' . $page->id
    );

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'History for page [_1]', $readable_title )
    );

    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_list(
            browse_location => 'bottom',
        )
    );

    $self->tool->tool_title_suffix($self->_msg( 'History for page [_1]', $readable_title ));
    return $self->generate_tool_content;
}

sub history {
    my ( $self ) = @_;

    if ( ! $self->chk_y( 'browse_versions' ) ) {
        $self->redirect( $self->derive_url( task => 'detect', additional => [] ) );
    }

    $self->init_tool;

    my $pages = CTX->lookup_object('wiki_page')->fetch_group({
        where => 'groups_id = ' . $self->param('target_group_id'),
    }) || [];

    my $page_title_lookup = { map { $_->id => $_->title } @$pages };

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('wiki_version'),
            current_view => 'history',
            initial_construct_params => {
                custom_link_values => {
                    page_name => sub  {
                        $page_title_lookup->{ shift->object->page_id };
                    },
                    versions => sub {
                        my $vn = shift->object->version_number;
                        return ( $vn > 0 ) ? $vn - 1 . "/$vn" : "$vn/$vn";
                    }
                }
            }
        )
    );

    $self->init_fields;

    my $dd = $self->gtool->get_field('page_id');
    for ( @$pages ) {
        $dd->add_dropdown_item(
            $_->id, $_->readable_title
        );
    }

    $dd = $self->gtool->get_field('creator_id');
    my $users = CTX->lookup_object('user')->fetch_group({
    }) || [];
    for ( @$users ) {
        $dd->add_dropdown_item(
            $_->id, $_->first_name.' '.$_->last_name
        );
    }

    $self->gtool->Data->add_where(
        'groups_id = ' . $self->param('target_group_id')
    );
    $self->gtool->Data->add_where(
        'change_type = ' . CHANGE_NORMAL
    );

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Change history' )
    );

    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_list(
            browse_location => 'bottom',
        )
    );

    return $self->generate_tool_content;

}

sub changes {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page_or_redirect( $title );
    my $readable_title = $page->readable_title;

    if ( ! $self->chk_y( 'browse_versions' ) ) {
        $self->_redirect_to_current_version( $page );
    }

    my $vn1 = $self->param( 'first_version' );
    my $vn2 = $self->param( 'second_version' );

    if ( ! ( defined($vn1) && $vn1 =~ /^\d+$/ ) ) {
        $vn1 = $page->last_version_number;
        $self->redirect( $self->derive_url(
            additional => [ $title, $vn1 - 1, $vn1 ]
        ) );
    }
    # if vn2 is not valid, redirect to diff from vn1 - 1 to vn1
    elsif ( ! ( defined $vn2 && $vn2 =~ /^\d+$/ ) ) {
        if ( $vn1 < 1 ) {
            $self->_go_to( 'show', $title );
        }
        $self->redirect( $self->derive_url(
            additional => [ $title, $vn1 - 1, $vn1 ]
        ) );
    }

#    $self->init_tool( { tab_override => 'history' } );
    $self->init_tool;

    my $v1 = $self->_fetch_version_for_page( $page, $vn1 );
    my $v2 = $self->_fetch_version_for_page( $page, $vn2 );

    if ( ! $v1 || ! $v2 ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( "Requested version does not exists!" )
        );

        $self->_go_to( 'page_history', $title );
    }

    my $dropdowns = $self->_generate_diff_dropdowns( $page, $v1, $v2 );
    my $table = $self->_generate_diff_table( $page, $v1, $v2 );

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Changes for page [_1]',
            $readable_title
        )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content( [
        $dropdowns, $table,
    ] );

    $self->tool->tool_title_suffix($self->_msg( 'Changes for page [_1]',
        $readable_title
    ));
    return $self->generate_tool_content;
}

sub import_pages {
    my ( $self ) = @_;

    if ( CTX->request->param( 'upload' ) ) {
        my $file = CTX->request->upload( 'pages_file' );
        my $data = '';
        if ( ref $file ) {
            my $fh = $file->filehandle;
            local $/;
            $data = <$fh>;
        }

        my $pagedata = eval { YAML::Syck::Load( $data ) };
        if ( $@ ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Could not parse file:' ) . $@
            );
        }
        elsif ( ref $pagedata && ref $pagedata->{pages} eq 'ARRAY' ) {

            my $settings = $self->_get_settings;
            $settings->fetch_settings;

            my @created_pages = ();
            my @existing_pages = ();

            for my $page ( @{ $pagedata->{pages} } ) {

                my $readable_title = $self->_raw_title_to_readable_form(
                    $page->{readable_title}
                );
                my $title = $self->_title_to_internal_form(
                    $readable_title
                );

                if ( $self->_fetch_page( $title ) ) {
                    push @existing_pages, $readable_title;
                }
                else {
                    my $new_page = $self->_create_page(
                        group_id => $self->param('target_group_id'),
                        readable_title => $readable_title,
                        title => $title,
                        content => $page->{content},
                        skip_starting_page_proposal => 1,
                    );

                    $self->_propose_starting_page( $new_page, $settings );
                    push @created_pages, $readable_title;
                }
            }

            my $msg = '';
            if ( @existing_pages ) {
                $msg .= $self->_msg('Some pages already existed:') . ' ' .
                    join ', ', @existing_pages;
            }

            if ( @created_pages ) {
                $msg .= "\n" . $self->_msg('Created pages:') . ' ' .
                    join ', ', @created_pages;
            }

            my $code = (scalar @existing_pages) ?
                MESSAGE_WARNING : MESSAGE_SUCCESS;

            Dicole::MessageHandler->add_message( $code, $msg );
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'No pages found.' )
            );
        }
    }

    $self->init_tool(
        upload => 1
    );

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Import pages' )
    );

    $self->tool->Container->box_at( 1, 0 )->add_content( [
        Dicole::Widget::Raw->new(
            raw => '<input name="pages_file" type="file" value="" />'
        ),
        Dicole::Widget::FormControl::SubmitButton->new(
            text => $self->_msg('Upload'),
            name => 'upload',
        ),
    ] );

    return $self->generate_tool_content;
}

sub search {
    my ( $self ) = @_;

    if ( CTX->request->param('find') ) {
        my $ns = CTX->request->param('new_search');
        my @p = $ns ? ( search => $ns ) : ();
        $self->redirect( $self->derive_url(
            params => { @p }
        ) );
    }

    my $search = CTX->request->param('search');
    my @results = ();

    if ( $search ) {
        # could not find anything to do this for me :/
        my @tokens = $search =~ /(\-?"[^"]+"|[^" ]+)/g;
        my @yes = ();
        my @no = ();
        for ( @tokens ) {
            my $token = $_;
            $token =~ s/\\/\\\\/g;
            $token =~ s/([%_'])/\\$1/g;

            if ( $token =~ /^\-"(.*)"$/ ) {
                push @no, $1 if $1;
            }
            elsif ( $token =~ /^\-(.*)/ ) {
                push @no, $1 if $1;
            }
            elsif ( $token =~ /^"(.*)"$/ ) {
                push @yes, $1 if $1;
            }
            else {
                push @yes, $token if $token;
            }
        }

        my @columns = ('dicole_wiki_search.text');
        my @where = ();
        for my $hit ( @no ) {
            my @options = ();
            push @options, "$_ NOT LIKE '%$hit%'" for @columns;
            push @where, "( " . join(' AND ', @options ) . " )";
        }
        for my $hit ( @yes ) {
            my @options = ();
            push @options, "$_ LIKE '%$hit%'" for @columns;
            push @where, "( " . join(' OR ', @options ) . " )";
        }
        my $likes = join ' AND ', @where;
        my $where = 'groups_id = ? AND ' .
            'dicole_wiki_page.page_id = dicole_wiki_search.page_id';
        $where .= $likes ? ' AND ' . $likes : '';

        my $total_count = CTX->lookup_object('wiki_page')->fetch_count( {
            from => [ 'dicole_wiki_page', 'dicole_wiki_search' ],
            where => $where,
            value => [ $self->param('target_group_id') ],
        } ) || [];


        my $browse = Dicole::Generictool::Browse->new( {
            action => [ # Make browse page unique.
                CTX->request->action_name . '_' .
                $self->param('target_user_id') . '_' .
                $self->param('target_group_id')
            ]
        } );
        $browse->default_limit_size( 20 );
        $browse->set_limits;
        $browse->total_count( $total_count );

        if ( $total_count && $total_count <= $browse->limit_start ) {
            my $raw_pages = $total_count / $browse->limit_size;
            my $actual_pages = int( $raw_pages );
            $actual_pages -= 1 if $raw_pages == $actual_pages;
            $browse->set_limits( $actual_pages * $browse->limit_size );
        }

        my $pages = CTX->lookup_object('wiki_page')->fetch_group( {
            from => [ 'dicole_wiki_page', 'dicole_wiki_search' ],
            where => $where,
            value => [ $self->param('target_group_id') ],
            limit => $browse->get_limit_query,
            order => 'last_modified_time DESC',
        } ) || [];

        if ( scalar( @$pages ) ) {
            my $browse_content = $browse->get_browse;
            push @results, $browse_content if $browse_content;

            for my $page ( @$pages ) {
                my $content = $page->last_content_id_wiki_content->content;
                $content = Dicole::Utils::HTML->html_to_text( $content );
                $content =~ s/\s+/ /gs;

                my @unfound = ();
                push @unfound, quotemeta($_) for @yes;

                my $regex = join '|', @unfound;

                my $cs = 10;
                my $hl = '';
                while ( $content && $regex ) {
                    local( $1, $2, $3, $4 );
                    last unless
                        $content =~ /^(.*?)((?:\S+\s+){0,$cs}\S*)($regex)(.*)/i;
                    my $begin = $1;
                    my $prefix = $2;
                    my $match = $3;
                    $content = $4;

                    if ( $hl ) {
                        local( $1, $2 );
                        if ( $begin =~ /^(\S*(?:\s+\S+){0,$cs})\s*(.*)/ ) {
                            $hl .= HTML::Entities::encode($1);
                            $hl .= ' <i>[...]</i> ' if $2;
                        }
                    }
                    else {
                        $hl .= ' <i>[...]</i> ' if $begin;
                    }

                    $hl .= HTML::Entities::encode($prefix) .
                        '<b>' . HTML::Entities::encode($match) . '</b>';

                    my @now_unfound = ();
                    for my $r ( @unfound ) {
                        push @now_unfound, $r unless $match =~ /$r/i;
                    }

                    @unfound = @now_unfound;
                    $regex = join '|', @unfound;
                }
 
                if ( $hl ) {
                    local( $1, $2 );
                    if ( $content =~ /^(\S*(?:\s+\S+){0,$cs})\s*(.*)/ ) {
                        $hl .= HTML::Entities::encode($1);
                        $hl .= ' <i>[...]</i> ' if $2;
                    }
                }
                else {
                    $hl .= ' <i>[...]</i> ' if $content;
                }

                push @results, $self->_wiki_page_result_widget( $page, $hl );
            }

            $browse_content = $browse->get_browse;
            push @results, $browse_content if $browse_content;
        }
        else {
            push @results, Dicole::Widget::Text->new(
                class => 'wiki_search_not_found listing_not_found',
                text => $self->_msg('No pages matched your search'),
            );
        }
    }

    $self->init_tool;

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Search results' ) );

    $self->tool->Container->box_at( 1, 0 )->add_content(
        [
            Dicole::Widget::Horizontal->new( contents => [
                Dicole::Widget::FormControl::TextField->new(
                    id => "new_search_input",
                    name => "new_search",
                    value => $search,
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    text => $self->_msg( 'Search' ),
                    name => 'find',
                    class => 'wiki_search_results_search_button',
                ),
            ] ),
            @results,
        ]
    );

    return $self->generate_tool_content;
}

sub cancel_annotation {
    my ( $self ) = @_;

    $self->_remove_lock;

    return $self->redirect( $self->derive_url( task => 'show' ) );
}

######################
# private functions
sub _redirect_to_current_version {
    my ( $self, $page ) = @_;

    return $self->redirect( $self->derive_url( task => 'show', additional => [ $page->title ] ) );
}

sub _process_locking {
    my ( $self, $page ) = @_;

    if ( $self->chk_y('lock') ) {
        if ( CTX->request->param('admin_lock') ) {

            my $locks = $self->_fetch_locks_for_page( $page );

            if ( ! scalar( @$locks ) ) {
                $page->moderator_lock(1);
                $page->save;
                Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                    $self->_msg('Page locked.')
                );
            }
            else {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg('Page is being edited so it could not be locked.')
                );
            }
            $self->redirect( $self->derive_url( params => {} ) );
        }
        elsif ( CTX->request->param('admin_unlock') ) {
            $page->moderator_lock(0);
            $page->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page unlocked.')
            );
            $self->redirect( $self->derive_url( params => {} ) );
        }
    }
}

sub _process_comment_toggling {
    my ( $self, $page ) = @_;

    if ( $self->chk_y('disable_page_comments') ) {
        if ( CTX->request->param('disable_comments') ) {
            $page->hide_comments(1);
            $page->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page comments disabled.')
            );
            $self->redirect( $self->derive_url( params => {} ) );
        }
        elsif ( CTX->request->param('enable_comments') ) {
            $page->hide_comments(0);
            $page->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page comments enabled.')
            );
            $self->redirect( $self->derive_url( params => {} ) );
        }
        if ( CTX->request->param('disable_annotations') ) {
            $page->hide_annotations(1);
            $page->show_annotations(0);
            $page->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page annotations disabled.')
            );
            $self->redirect( $self->derive_url( params => {} ) );
        }
        elsif ( CTX->request->param('enable_annotations') ) {
            $page->hide_annotations(0);
            $page->show_annotations(1);
            $page->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page annotations enabled.')
            );
            $self->redirect( $self->derive_url( params => {} ) );
        }
    }
}

sub _process_summary_page {
    my ( $self, $page ) = @_;

    if ( $self->chk_y('summary') ) {
        if ( CTX->request->param('summary_add') ) {
            $self->_add_page_as_summary_page(
                $page, $self->param('target_group_id')
            );

            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page added to summary.')
            );

            $self->redirect( $self->derive_url( params => {} ) );
        }
        elsif ( CTX->request->param('summary_remove') ) {

            my $a = CTX->lookup_object('wiki_summary_page')->fetch_group( {
                where => 'group_id = ? AND page_id = ?',
                value => [ $self->param('target_group_id'), $page->id ],
            } ) || [];

            $_->remove for @$a;

            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg('Page removed from summary.')
            );

            $self->redirect( $self->derive_url( params => {} ) );
        }
    }
}

sub _get_common_create_widgets {
    my ( $self ) = @_;

    my @widgets = ();

    push @widgets, Dicole::Widget::Text->new(
        text => $self->_msg( 'Select page to use as base:' ),
    );

    my $pages = CTX->lookup_object('wiki_page')->fetch_group( {
        where => 'groups_id = ?',
        value => [ $self->param('target_group_id') ],
    } ) || [];

    my $select = Dicole::Widget::FormControl::Select->new(
        name => 'base_page'
    );

    $select->add_option(
        value => 0,
        text => $self->_msg( 'None' )
    );

    $select->add_objects_as_options( {
        objects => $pages,
        text_field => 'readable_title',
    } );

    push @widgets, $select;

    push @widgets, Dicole::Widget::Horizontal->new(
        contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                text => $self->_msg( 'Create page' ),
                name => 'create',
            ),
#            Dicole::Widget::LinkButton->new(
#                text => $self->_msg( 'Import pages' ),
#                link => $self->derive_url(
#                    task => 'import_pages',
#                    additional => [],
#                    params => {},
#                ),
#            )
        ],
    );
    return \@widgets;
}

sub _get_tree_of_found_pages {
    my ( $self, $links, $linked_pages, $starting_page ) = @_;

    my $starting_page_info = {
        page_id => $starting_page->id,
        parent_id => 0,
        title => $starting_page->title,
        readable_title => $starting_page->readable_title,
    };

    my $elements = $self->_create_tree_from_page(
        $starting_page_info,
        $links,
        $linked_pages
    );

    return $self->_get_page_tree_from_elements(
        $elements, $self->_msg( 'Pages linked to starting page' ),'found_tree'
    );
}

sub _get_tree_of_orphaned_pages {
    my ( $self, $links, $pages, $linked_pages ) = @_;

    my $elements = [];

    for my $page (@$pages) {
        next if $linked_pages->{ $page->page_id };

        my $info = {
            page_id => $page->page_id,
            parent_id => 0,
            title => $page->title,
            readable_title => $page->readable_title,
        };

        my $new_elements = $self->_create_tree_from_page(
            $info,
            $links,
            $linked_pages
        );

        push @$elements, @$new_elements;
    }

    return undef if ! scalar ( @$elements );

    return $self->_get_page_tree_from_elements(
        $elements, $self->_msg( 'Orphaned pages' ),
        'orphaned_tree', 'child_count'
    );
}

sub _get_page_tree_from_elements {
    my ( $self, $elements, $root, $tree_id, $order_key ) = @_;

    my $creator = new Dicole::Tree::Creator::Hash (
        id_key => 'page_id',
        parent_id_key => 'parent_id',
        order_key => $order_key,
        parent_key => '',
        sub_elements_key => 'sub_elements',
    );

    $creator->add_element_array( $elements );

    my $tree = Dicole::Navigation::Tree->new(
        root_name  => $root,
        selectable => 0,
        tree_id    => $tree_id,
        folders_initially_open => 1,
        no_collapsing => 1,
        no_root_select => 1,
#        icon_files => $group_icons->{group_icons},
    );
    $tree->root_href('');

    $self->_rec_create_tree($tree, undef, $creator->create );

    return $tree->get_tree;
}

sub _create_tree_from_page {
    my ( $self, $page_info, $links, $linked_pages ) = @_;

    my @children = ( $page_info );
    my @children_left = ( $page_info );

    while ( scalar( @children_left ) ) {
        my $new_children = $self->_link_unlinked_children_to_page(
            shift( @children_left ), $links, $linked_pages
        );
        push @children_left, @$new_children;
        push @children, @$new_children;
    }

    return \@children;
}

sub _link_unlinked_children_to_page {
    my ( $self, $page_info, $links, $linked_pages ) = @_;

    my $page_id = $page_info->{page_id};

    next if $linked_pages->{ $page_id };
    $linked_pages->{ $page_id } = $page_info;

    my @children = ();

    for my $link ( @$links ) {
        next if $link->linking_page_id != $page_id;
        next if $linked_pages->{ $link->linked_page_id };

        push @children, {
            page_id => $link->linked_page_id,
            parent_id => $page_id,
            title => $link->linked_page_title,
            readable_title => $link->readable_linked_title,
        };
    }

    $page_info->{child_count} = - scalar( @children );

    return \@children;
}

sub _rec_create_tree {
    my ($self, $tree, $parent, $array) = @_;

    return if ref $array ne 'ARRAY';

    foreach my $page (@$array) {

        my $element = Dicole::Navigation::Tree::Element->new(
            parent_element => $parent,
            element_id => $page->{page_id},
            name => $page->{readable_title},
#            type => $group->{type},
            override_link => $self->derive_url(
                task => 'show',
                additional => [ $page->{title} ]
            ),
        );

        $tree->add_element( $element );

        $self->_rec_create_tree( $tree, $element, $page->{sub_elements} );
    }
}

sub _push_box {
    my ( $self, $i, $hash ) = @_;

    return unless $hash;

    $self->tool->Container->box_at( 0, $i )->name( $hash->{name} );
    $self->tool->Container->box_at( 0, $i )->content( $hash->{content} );
    $self->tool->Container->box_at( 0, $i )->class( $hash->{class} );
}

sub _create_side_boxes {
    my ( $self, $page, $version, $wiki_settings ) = @_;

    my $i = 0;

    $self->_push_box( $i++, $self->_create_search_box() );

    my $tags = eval {
        CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
            object => $page
        } );
    } || [];

    $self->_push_box( $i++, $self->_create_events_box( $page, $tags ) );

    my $hot_pages = $self->_fetch_hot_pages();

    for my $page ( @$hot_pages ) {
        $self->_push_box( $i++, $page );
    }

    $self->_push_box( $i++, CTX->lookup_action('awareness_api')->e( create_share_this_box => {} ) );

    $self->_push_box( $i++, {
        %{ $self->tool->get_tablink_box( $self->_msg('Navigation') ) },
        class => 'wiki_navigation_box',
    } );

    $self->_push_box( $i++, $self->_create_bookmarkers_box( $page ) );

    unless ( $version ) {
        my $backlink_box = $self->_create_backlink_box( $page );
        $self->_push_box( $i++, $backlink_box ) if $backlink_box;

        if ( $self->chk_y('edit') ) {
            my $link_box = $self->_create_link_box( $page );
            $self->_push_box( $i++, $link_box ) if $link_box;
        }
    }

    $self->_push_box( $i++, $self->_page_actions_box( $page, $version, $wiki_settings ) );
    $self->_push_box( $i++, $self->_create_show_tags_box( $page, $tags) );
    $self->_push_box( $i++, $self->_create_show_info_box() );
    $self->_push_box( $i++, $self->_create_attachments_box() );
    $self->_push_box( $i++, $self->_create_tag_cloud_box($page) );

    unless ( $version ) {
        my $change_box = $self->_create_change_box( $page );
        $self->_push_box( $i++, $change_box ) if $change_box;
    }
}

sub _create_bookmarkers_box {
    my ( $self, $page ) = @_;

    my $return = eval {
        my $html = CTX->lookup_action('bookmarks_api')->e( get_sidebar_html_for_object_bookmarkers => {
            object => $page,
        } );
        if ( $html ) {
            return {
                name => $self->_msg('Who has bookmarked this'),
                content => Dicole::Widget::Raw->new( raw => $html ),
                class => 'wiki_bookmarkers_box'
            };
        }
    };
    if ( $@ ) {
        get_logger(LOG_APP)->error($@);
    } 

    return $return;
}

sub _page_actions_box {
    my ( $self, $page, $version, $wiki_settings ) = @_;

    my $boxed = Dicole::Widget::Vertical->new;

    my $bookmark_action = CTX->lookup_action('bookmarks_api')->e( get_user_bookmark_action_for_object => {
        object => $page,
        creator_id => CTX->request->auth_user_id,
    } );

    if ( $bookmark_action && $bookmark_action eq 'add' ) {
        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Bookmark' ),
                class => 'add_bookmark',
                link => $self->derive_url(
                    task => 'add_bookmark', additional => [ $page->title ],
                )
            )
        );
    }
    elsif ( $bookmark_action && $bookmark_action eq 'remove' ) {
        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Unbookmark' ),
                class => 'remove_bookmark',
                link => $self->derive_url(
                    task => 'remove_bookmark', additional => [ $page->title ],
                )
            )
        );
    }

    my $previous_version = $version ? $version - 1 : $page->last_version_number - 1;
    if ( $previous_version > 0 && $self->chk_y('browse_versions') ) {
        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Previous version' ),
                class => 'previous_version',
                link => $self->derive_url(
                    additional => [ $page->title, $previous_version ],
                )
            )
        );
    }
    
    if ( $version && $self->chk_y('browse_versions') ) {
        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Next version' ),
                class => 'next_version',
                link => $self->derive_url(
                    additional => [ $page->title, $version + 1 ],
                )
            )
        );
    }
    
    $boxed->add_content(
        Dicole::Widget::LinkBar->new(
            content => $self->_msg( 'Page change history' ),
            class => 'change_history',
            link => $self->derive_url(
                task => 'page_history',
                additional => [ $page->title ],
            )
        )
    ) if $self->chk_y('browse_versions');

    $boxed->add_content(
        Dicole::Widget::LinkBar->new(
            content => $self->_msg( 'Version changes' ),
            class => 'version_changes',
            link => $self->derive_url(
                task => 'changes',
                additional => [ $page->title, $version ? ( $version -1, $version ) : () ],
            )
        )
    ) if $page->last_version_number > 0 && $self->chk_y('browse_versions');

    $boxed->add_content(
        Dicole::Widget::LinkBar->new(
            content => $self->_msg( 'Printable page' ),
            class => 'printable_page',
            link => $self->derive_url(
                action => 'wiki_popup',
                task => 'printable_page',
                additional => [ $page->title, $version ],
            )
        )
    );

    $boxed->add_content(
        Dicole::Widget::LinkBar->new(
            content => $self->_msg( 'Printable page with comments' ),
            class => 'printable_page',
            link => $self->derive_url(
                action => 'wiki_popup',
                task => 'printable_commented_page',
                additional => [ $page->title, $version ],
            )
        )
    ) unless $page->hide_comments && ! $self->_page_annotations_visible( $page, $wiki_settings );

    if ( $version ) {
        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Revert to this version' ),
                class => 'revert_to_this_version',
                link => $self->derive_url(
                    params => { revert => 1 },
                )
            )
        ) if $self->chk_y( 'edit' ) && ! $page->moderator_lock;

        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Show current page' ),
                class => 'show_current_page',
                link => $self->derive_url(
                    additional => [ $page->title ],
                )
            )
        );
    }
    else {
        if ( $self->chk_y( 'lock' ) ) {
            if ( $page->moderator_lock ) {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Unlock page' ),
                        class => 'unlock_page',
                        link => $self->derive_url(
                            params => { admin_unlock => 1 }
                        )
                    )
                )
            }
            else {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Lock page' ),
                        class => 'lock_page',
                        link => $self->derive_url(
                            params => { admin_lock => 1 }
                        )
                    )
                )
            }
        }

        if ( $self->chk_y( 'disable_page_comments' ) ) {
            if ( $page->hide_comments ) {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Enable comments' ),
                        class => 'enable_comments',
                        link => $self->derive_url(
                            params => { enable_comments => 1 }
                        )
                    )
                )
            }
            else {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Disable comments' ),
                        class => 'disable_comments',
                        link => $self->derive_url(
                            params => { disable_comments => 1 }
                        )
                    )
                )
            }
            if ( ! $self->_page_annotations_visible( $page, $wiki_settings ) ) {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Enable annotations' ),
                        class => 'enable_annotations',
                        link => $self->derive_url(
                            params => { enable_annotations => 1 }
                        )
                    )
                )
            }
            else {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Disable annotations' ),
                        class => 'disable_annotations',
                        link => $self->derive_url(
                            params => { disable_annotations => 1 }
                        )
                    )
                )
            }
        }

        if ( $self->chk_y( 'summary' ) ) {
            my $a = CTX->lookup_object('wiki_summary_page')->fetch_group( {
                where => 'group_id = ? AND page_id = ?',
                value => [ $self->param('target_group_id'), $page->id ],
            } ) || [];

            if ( scalar( @$a ) ) {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Remove page from summary' ),
                        class => 'remove_page_from_summary',
                        link => $self->derive_url(
                            params => { summary_remove => 1 }
                        )
                    )
                )
            }
            else {
                $boxed->add_content(
                    Dicole::Widget::LinkBar->new(
                        content => $self->_msg( 'Add page to summary' ),
                        class => 'add_page_to_summary',
                        link => $self->derive_url(
                            params => { summary_add => 1 }
                        )
                    )
                )
            }
        }

        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Rename page' ),
                class => 'rename_page',
                link => $self->derive_url(
                    action => 'wiki',
                    task => 'rename',
                    additional => [ $page->title ],
                )
            )
        ) if $self->chk_y( 'remove' ) ;

        $boxed->add_content(
            Dicole::Widget::LinkBar->new(
                content => $self->_msg( 'Remove page' ),
                class => 'remove_page',
                link => $self->derive_url(
                    action => 'wiki',
                    task => 'remove',
                    additional => [ $page->title ],
                )
            )
        ) if $self->chk_y( 'remove' ) ;
    }

    return {
        name => $self->_msg('Page actions'),
        content => $boxed,
        class => 'wiki_actions_box',
    };
}

sub _create_search_box {
    my ( $self, $page ) = @_;
    my $search = Dicole::Widget::Horizontal->new( contents => [
        Dicole::Widget::FormControl::TextField->new(
            id => "new_search_input",
            name => "new_search",
        ),
        Dicole::Widget::FormControl::SubmitButton->new(
            text => $self->_msg( 'Search' ),
            name => 'find',
            size => 10,
            class => 'wiki_search_button',
        ),
    ] );

    return {
        name => $self->_msg('Search wiki'),
        content => $search,
        class => 'wiki_search_box',
    };
}

sub _create_events_box {
    my ( $self, $page, $tags ) = @_;
    my $return = eval {
        my $event_html = CTX->lookup_action('events_api')->e(
            get_sidebar_list_html_for_events_matching_tags => {
                group_id => $self->param('target_group_id'),
                tags => $tags,
            }
        );
        if ( $event_html ) {
            return {
                name => $self->_msg('Related events'),
                content => Dicole::Widget::Raw->new( raw => $event_html ),
                class => 'wiki_events_box'
            };
        }
    };
    if ( $@ ) {
        get_logger(LOG_APP)->error($@);
    } 

    return $return;
}

sub _create_show_tags_box {
    my ( $self, $page, $tags ) = @_;
    my $title = $self->_parse_title;
    my $gid = $self->param('target_group_id');

    my $tagstring = scalar( @$tags ) ?
        Dicole::Widget::Text->new(
            class => 'wiki_attached_tags_list',
            text => join( ', ', @$tags ),
        )
        :
        Dicole::Widget::Text->new(
            class => 'wiki_attached_tags_list_empty',
            text => $self->_msg( 'No tags yet.' ),
        );

    my @add_tags = ( $self->chk_y( 'edit' ) && ! $page->moderator_lock ) ?
        Dicole::Widget::LinkBar->new(
            content => 'Add tags',
            class => 'wiki_add_tags_linkbar',
            link =>  $self->derive_url(
                action => 'wiki',
                task => 'edit_info',
                additional => [ $page->page_id ],
            ),
        )
        :
        ();

    return {
        name => $self->_msg('Page tags'),
        content => Dicole::Widget::Vertical->new( contents => [
            $tagstring,
            @add_tags,
        ] ),
        class => 'wiki_show_tags_box',
    };
}

sub _create_show_info_box {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );
    my $gid = $self->param('target_group_id');
    my $last_m = $page->{last_modified_time};
    my $since_modified = $self->_msg('Never');
    my @contributors = ();
    my $user_name = ();
    my $users = ();
    my $user_hash = {} ;

    eval {
        $since_modified = CTX->lookup_action('awareness')->execute(
            epoch_to_when_string => { epoch => $last_m  }
        );
    };

        my $objects = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->{page_id} ],
        } );

        for my $o ( @$objects ) {
            $user_hash->{ $o->{creator_id} } += 1;
        }

        $users = Dicole::Utils::SPOPS->fetch_linked_objects(
        from_elements => $objects,
        link_field => 'creator_id',
        object_name => 'user',
        );

        for my $user ( @$users ) {
            my $name = $user->{first_name}.' '.$user->{last_name};
            my $weight = $user_hash->{$user->id};
            my $link = $self->derive_url(
                action => 'networking',
                task => 'profile',
                target => CTX->request->target_group_id,
                additional => [ $user->id ],
         );

        my $ss = CTX->lookup_object( 'user' )->fetch_group( {
            from => [ qw(sys_user dicole_group_user) ],
            where => 'dicole_group_user.groups_id = ? '
                . 'AND dicole_group_user.user_id = ?'
                . 'AND dicole_group_user.user_id = sys_user.user_id',
            value => [ $gid, $user->id ]
        } );

        #if user no longer in the group
        if ( @$ss==0 ) {
                my $e = {name => $name, weight => $weight};
                push @contributors, $e;
        }
        else {
            my $e = {name => $name, weight => $weight, link => $link};
            push @contributors, $e;
        }

        }
      
        my $cloud = Dicole::Widget::LinkCloud->new(
            links => \@contributors,
        );

    return {
        name => $self->_msg('Page info'),
        content => Dicole::Widget::Vertical->new( contents => [
            Dicole::Widget::Text->new( text => $self->_msg('Last modified'), class => 'definitionHeader wiki_since_modified_title' ),
            Dicole::Widget::Text->new( text => $since_modified, class => 'wiki_since_modified' ),
            Dicole::Widget::Text->new( text => $self->_msg('Contributors'), class => 'definitionHeader wiki_contributors_title' ),
            Dicole::Widget::Vertical->new( contents =>[$cloud] ),
        ] ),
        class => 'wiki_show_info_box',
    };
}

sub _create_attachments_box {
    my ( $self ) = @_;

    return {
        name => $self->_msg('Attachments'),
        content => $self->_create_attachments_box_content(),
        class => 'wiki_attachments_box',
    };
}

sub _create_attachments_box_content {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );
    my $gid = $self->param('target_group_id');
    my $save_pressed = CTX->request->param('saver');

     if ( $save_pressed && $self->chk_y('edit') ) {
        eval {
            CTX->lookup_action('attachment')->execute( store_from_request_upload => {
                upload_name => 'upload_attachment',
                object => $page,
                 group_id => $gid,
                 user_id => 0,
             } );
         };
         $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Attachments updated') );
       $self->redirect( $self->derive_url(
            task => 'show',
             additional => [$title],
         ) );
     }
    my $right_to_upload = $self->chk_y('edit');
    my $right_to_remove = $self->chk_y('remove_attachments');
    return Dicole::Widget::Vertical->new( class => 'wiki_attachments_container', contents => [
        $self->_get_attachments_widget( $page, ( $right_to_upload ? 0 : 1 ), ( $right_to_remove ? 0 : 1 ) ),
         ( $right_to_upload ? Dicole::Widget::FormControl::SubmitButton->new(
             name => 'saver',
             value => '1',
             text => $self->_msg( 'Add Attachment' ),
         ) : () ),
        ] );
}

sub _create_tag_cloud_box {
    my ( $self, $page ) = @_;

    my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
        object_class => CTX->lookup_object('wiki_page'),
    } );

   my $prefix = $self->derive_url(
            task => 'pages_by_tag',
            additional => [],
        );

    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => $prefix,
    );
    $cloud->add_weighted_tags_array($tags);

    my $return = Dicole::Widget::Vertical->new( contents => [$cloud]);

    return {
        name => $self->_msg('Search by tag'),
        content => $return,
        class => 'wiki_tag_cloud_box',
    };
}

sub edit_info {

    my ( $self ) = @_;

    $self->init_tool( 
         upload => 1
    );

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );

    my $uid=0;
    my $gid = $self->param('target_group_id');
    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');
    
    my $save_pressed = CTX->request->param('save') || CTX->request->param('save_continue');

    my $post_tags_old=();
    if ($save_pressed) {
        $post_tags_old = CTX->request->param('tags_old');
    }
    else {
        $post_tags_old = CTX->lookup_action('tagging')->execute( 'get_tags_for_object_as_json', {
        object => $page,
        group_id => $gid,
        user_id => 0,
    } );

    }
#     my $page_content = CTX->lookup_object( 'wiki_content' )->fetch_group( {
#         where => 'content_id = ?',
#         value => [ $page->last_content_id ],
#     } ) || [];

    my $post_tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    if ( $save_pressed ) {

            eval {
                my $tags = CTX->lookup_action('tagging');
                eval {
                    $tags->execute( 'update_tags_from_json', {
                        object => $page,
                        group_id => $gid,
                        user_id => 0,
                        json => $post_tags,
                        json_old => $post_tags_old,
                    } );
                };
                $self->log('error', $@ ) if $@;
            };

            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Entry updated') );

            return $self->redirect( Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $gid,
                other => [ $page->{title} ],
            ) );

    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Info for page [_1]', $page->{readable_title} ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_wiki_fields( $gid, $save_pressed, $post_tags, $page )
    );

    $self->tool->tool_title_suffix( $self->_msg('Edit info for page [_1]', $page->{readable_title} ) );
    return $self->generate_tool_content;
}

sub _wiki_fields {
    my ( $self, $gid, $pressed, $post_tags, $page ) = @_;

    return Dicole::Widget::Vertical->new( contents => [
        Dicole::Widget::Text->new( text => $self->_msg( 'Tags' ), class => 'definitionHeader' ),
        $self->_get_tagging_add_widget( $gid, 0, $pressed, $page, $post_tags ),
        $self->_get_tagging_suggestion_widgets( $self->param('target_group_id') ),
        Dicole::Widget::FormControl::SubmitButton->new(
            name => 'save',
            value => '1',
            text => $self->_msg( 'Save' ),
        ),
    ] );

}

sub _get_tagging_add_widget {
    my ( $self, $gid, $uid, $form_posted, $object, $post_tags ) = @_;
    
    my @widgets = ();
    
    eval {
        my $tagging = CTX->lookup_action('tagging');
        
        my $old_tags = $object ? $tagging->execute( 'get_tags_for_object_as_json', {
            object => $object,
            group_id => $gid,
            user_id => $uid,
        } ) : Dicole::Utils::JSON->encode([]);

        push @widgets, Dicole::Widget::FormControl::Tags->new(
            id => 'tags',
            name => 'tags',
            value => $form_posted ? $post_tags || Dicole::Utils::JSON->encode([]) :
                $old_tags,
            old_value => $form_posted ? CTX->request->param( 'tags_old' ) || Dicole::Utils::JSON->encode([]) :
                $old_tags,
            add_tag_text => $self->_msg('Add tag'),
        );
   };

   return @widgets;
}

sub _get_tagging_suggestion_widgets {
    my ( $self, $gid ) = @_;
    
    my @widgets = ();
    
    eval {
        my $tagging = CTX->lookup_action('tagging');
        
        my $suggested_tags = $tagging->execute( 'get_suggested_tags', {
            group_id => $gid,
            user_id => 0,
        } );
#     my $suggested_tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
#         object_class => CTX->lookup_object('wiki_page'),
#     } ); 
        
        if ( scalar( @$suggested_tags ) ) {
            push @widgets, (
                Dicole::Widget::Text->new(
                    class => 'definitionHeader',
                    text => $self->_msg( 'Click to add suggested tags' ),
                ),
                Dicole::Widget::TagSuggestionListing->new(
                    target_id => 'tags',
                    tags => $suggested_tags,
                ),
            );
        }
        
        my $weighted_tags = $tagging->execute( 'get_weighted_tags', {
            group_id => $gid,
            user_id => 0,
        } );
        
        my @popular_weighted = ();
        my %suggested_keys = map {$_ => 1} @$suggested_tags;
        for my $wtag ( @$weighted_tags ) {
            push @popular_weighted, $wtag unless $suggested_keys{ $wtag->[0] };
        }
        
        if ( scalar( @popular_weighted ) ) {
            my $cloud = Dicole::Widget::TagCloudSuggestions->new(
                target_id => 'tags',
            );
            $cloud->add_weighted_tags_array( \@popular_weighted );
            push @widgets, (
                Dicole::Widget::Text->new(
                    class => 'definitionHeader',
                    text => $self->_msg( 'Click to add popular tags' ),
                ),
                $cloud,
            );
        }
    };

    return @widgets;
}

sub attachment {
    my ( $self ) = @_;

    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');

    my $attachments = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $page,
    } );

    my %a_by_id = map { $_->id => $_ } @ {$attachments || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => CTX->request->param('thumbnail') ? 1 : 0,
        max_width => 400,
    } );
}

sub _get_attachments_widget {
    my ( $self, $page, $submitting ) = @_;

    my $action = CTX->lookup_action('attachment');
    my $attachments = $page ? $action->execute( get_attachments_for_object => {
        object => $page,
    } ) || [] : [];

    my @widgets = ();
    
    push @widgets, Dicole::Widget::Text->new(
        text => $self->_msg( 'Attachments' ),
        class => 'definitionHeader',
    );

    my @x_widgets = ();
    if ( scalar( @$attachments ) ) {
        push @x_widgets, Dicole::Widget::Container->new(
           class => 'wiki_attachment_container',
           contents => [ $self->_get_attachments_listing_widget( $page, $attachments ) ],
        );
    }
    else {
        push @x_widgets, $self->_msg('No attachments.');
    }

    push @widgets, Dicole::Widget::Container->new( class => 'wiki_attachments_list_container', contents => \@x_widgets );
    
     if ( ! $submitting ) {
         push @widgets, Dicole::Widget::Text->new( text => $self->_msg( 'Add attachment' ), class => 'definitionHeader' );
         push @widgets, Dicole::Widget::Raw->new(
             raw => '<input name="upload_attachment" type="file" size="8" value="" />',
         );
     }
    
    return @widgets;
}

sub pages_by_tag {
    my ( $self ) = @_;

    my $tag = $self->param('tag');
    my $pages=();

    $pages = eval { CTX->lookup_action('tagging')->execute('tag_limited_fetch_group', {
        from => ['dicole_wiki_page'],
        where => 'dicole_wiki_page.groups_id',
        limit => 5,
        order => 'dicole_wiki_page.last_modified_time DESC',
        tags => [ $tag ],
        object_class => CTX->lookup_object('wiki_page'),
    } ) } || [];
    
    my $content_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        object_name => 'wiki_content',
        from_elements => $pages,
        link_field => 'last_content_id',
    );

    my @results = ();

    for my $page ( @$pages ) {
        my $content = $content_by_id->{ $page->last_content_id };
        my $shortened_text = Dicole::Utils::HTML->html_to_text( $content->content );
        $shortened_text =~ s/\s+/ /gs;
        $shortened_text = Dicole::Utils::HTML->shorten( $shortened_text, 200 );
        
        push @results, $self->_wiki_page_result_widget( $page, $shortened_text );
    }

    @results = $self->_msg('No pages found.') unless scalar( @results );


    $self->init_tool;

    $self->tool->Container->box_at( 1, 0 )->name(
        HTML::Entities::encode( $self->_msg( 'Pages by tag [_1]', $tag ) )
    );

    $self->tool->Container->box_at( 1, 0 )->add_content( [
        Dicole::Widget::Vertical->new( contents => \@results ),
    ] );

    $self->tool->tool_title_suffix($self->_msg( 'Pages by tag [_1]', $tag ));
    return $self->generate_tool_content;
    
}

sub _wiki_page_result_widget {
    my ( $self, $page, $content ) = @_;
    
    return Dicole::Widget::Vertical->new( contents => [
        Dicole::Widget::Hyperlink->new(
            class => 'definitionHeader wiki_search_result_title',
            content => $page->readable_title,
            link => $self->derive_url(
                task => 'show',
                additional => [ $page->title ],
            ),
        ),
        Dicole::Widget::Container->new(
            class => 'wiki_search_result_content',
            contents => [
                Dicole::Widget::Raw->new( raw => $content ),
            ],
        ),
    ] );
}

sub _fetch_hot_pages {
    my ( $self ) = @_;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;

    my $sidebar_page = $settings->setting( 'sidebar_page' );
    my $sidebar_page_2 = $settings->setting( 'sidebar_page_2' );


    my @hot_pages = ();
    push @hot_pages, $sidebar_page || ();
    push @hot_pages, $sidebar_page_2 || ();
    my @widgets = ();

    for my $title ( @hot_pages ) {

        my $page = $self->_fetch_page( $title );
        next if ! $page;

        my $box = Dicole::Widget::ContentBox->new(
            name => $page->readable_title,
            class => 'mini_wiki_page',
        );

        my $sections = $self->_current_sections_for_page( $page );
        $self->_filter_outgoing_links( $page, $sections );
        $self->_filter_outgoing_images( $page, $sections );

        $box->content( Dicole::Widget::Raw->new(
            raw => $self->_sections_to_html( $sections ),
        ) );

        push @widgets, $box;
    }

    return \@widgets;
}

sub _create_change_box {
    my ( $self ) = @_;

    my $changes = CTX->lookup_object('wiki_version')->fetch_group( {
            where => 'groups_id = ? AND change_type = ?',
            value => [
                $self->param('target_group_id'),
                CHANGE_NORMAL
            ],
            limit => 25,
            order => 'creation_time DESC',
    } ) || [];

    return if ! scalar( @$changes );

    my %checkhash = ();
    my @top_changes = ();
    for my $change ( @$changes ) {
        my $key = join ",", (
            $change->page_id,
            $change->creator_id,
            $change->change_description,
        );
        next if $checkhash{ $key };
        $checkhash{ $key }++;
        push @top_changes, $change;
        last if scalar( @top_changes ) >= 5;
    }

    $changes = \@top_changes;

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $changes,
        link_field => 'creator_id',
        object_name => 'user',
    );

    my $elements = [];
    for my $item ( @$changes ) {

        my $page = $item->wiki_page;
        my $author = $users->{ $item->creator_id };

        my $aname = join ' ', ( $author->{first_name}, $author->{last_name} );
        my $text = $item->change_description ?
            $item->change_description . ' - ' . $aname : $aname;

        my $content = $page->{readable_title};

        my $vn = $item->version_number;
        my $href = ( $vn > 0 ) ?
            Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'changes',
                target => $self->param('target_group_id'),
                other => [ $page->{title}, $vn - 1, $vn ],
            ) :
            Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $self->param('target_group_id'),
                other => [ $page->{title} ],
            );

        push @$elements, {
            params => { date => $item->creation_time },
            content => Dicole::Widget::Vertical->new( contents => [
                Dicole::Widget::Hyperlink->new(
                    content => $content,
                    link => $href,
                ),
                Dicole::Widget::Text->new(
                    text => $text,
                    class => 'desktopHyperlinkText',
                ),
            ] ),
        };
    }

    my $list = Dicole::Widget::DatedList->new(
        elements => $elements,
    );

    my $box = {
        name => $self->_msg('Previous changes'),
        content => $list,
        class => 'wiki_change_box',
    };

    return $box;
}

sub _create_link_box {
    my ( $self, $page ) = @_;

    my $links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linking_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my @existing_titles = ();
    my @missing_titles = ();

    for my $link ( @$links ) {
        my $titles = {
            title => $link->linked_page_title,
            readable_title => $link->readable_linked_title
        };

        if ( $link->linked_page_id ) {
            push @existing_titles, $titles;
        }
        else {
            push @missing_titles, $titles;
        }
    }

#    return if ! scalar( @existing_titles ) && ! scalar( @missing_titles );
    return if ! scalar( @missing_titles );

    my $vertical = Dicole::Widget::Vertical->new();

#    $vertical->add_content( $self->_create_link_list(
#        [ @existing_titles ]
#    ) );

    $vertical->add_content( $self->_create_missing_link_list(
        [ @missing_titles ]
    ) );

    return {
        name => $self->_msg( 'Missing linked pages' ),
        content => $vertical,
        class => 'wiki_link_box',
    };
}

sub _create_backlink_box {
    my ( $self, $page ) = @_;
    my $box = Dicole::Widget::ContentBox->new(
        name => $self->_msg( 'Links to this page' ),
    );

    my $links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linked_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my @titles = map { {
        title => $_->linking_page_title,
        readable_title => $_->readable_linking_title
    } } @$links;

    return if ! scalar( @titles );

    $box->content( $self->_create_link_list(
        [ @titles ]
    ) );

    return {
        name => $self->_msg( 'Links to this page' ),
        content => $self->_create_link_list(
            [ @titles ]
        ),
        class => 'wiki_backlink_box',
    };
}

sub _create_link_list {
    my ( $self, $titles ) = @_;

    my $vertical = Dicole::Widget::Vertical->new();

    my @titles = sort {
        lc $a->{readable_title} cmp lc $b->{readable_title}
    } @$titles;

    my %done = ();
    for my $title (@titles) {
        my $readable_title = $title->{readable_title};
        next if $done{ $readable_title };

        my $hl = Dicole::Widget::Hyperlink->new(
            link => $self->derive_url(
                task => 'show',
                additional => [
                    $title->{title}
                ],
            ),
            content => $readable_title,
            class => 'existingWikiLink',
        );
        $vertical->add_content( $hl );

        $done{ $readable_title }++;
    }

    return $vertical;
}

sub _create_missing_link_list {
    my ( $self, $titles ) = @_;

    my $vertical = Dicole::Widget::Vertical->new();

    my @titles = sort {
        lc $a->{readable_title} cmp lc $b->{readable_title}
    } @$titles;

    my %done = ();
    for my $title (@titles) {
        my $readable_title = $title->{readable_title};
        next if $done{ $readable_title };

        my $hl = Dicole::Widget::Hyperlink->new(
            link => $self->derive_url(
                task => 'create',
                additional => [],
                params => {
                    new_title => $readable_title,
                }
            ),
            content => $title->{readable_title},
            class => 'missingWikiLink',
        );
        $vertical->add_content( $hl );

        $done{ $readable_title }++;
    }

    return $vertical;
}

sub _process_save {
    my ( $self, $page, $last_sections ) = @_;
    my $base_version = CTX->request->param('base_version_number');
    my $target_id = CTX->request->param('edit_target_id');
    my $target_type = CTX->request->param('edit_target_type');
    my $edit_content = CTX->request->param('edit_content');

    $self->_remove_lock;

    # this tries to prevent problems thaoccur if user just
    # pastes content from the edit page
    $edit_content = $self->_strip_dicole_generated_html( $edit_content );

    $edit_content = $self->_filter_incoming_links( $edit_content );

    my ( $new_sections, $change_info );

    if ($base_version == $page->last_version_number) {
        ( $new_sections, $change_info ) =
            $self->_create_new_sections_from_change(
                $last_sections, $target_id,
                $target_type, $edit_content
            );
    }
    else {
        ( $new_sections, $change_info ) =
            $self->_create_new_sections_from_merge(
                $last_sections, $target_id,
                $target_type, $edit_content,
                $page, $base_version
            );
    }

    my $html = $self->_sections_to_html( $new_sections );

#    $html = Dicole::Utils::HTML->strip_scripts( $html );

    $self->_create_new_version_for_page(
        $page, $html, $change_info
    );

    $self->_update_page_indexes( $page, $html );

    return $new_sections;
}

sub _process_revert {
    my ( $self, $page, $sections ) = @_;
    
    my $current_version = $page->last_version_id_wiki_version;

    my $current_sections = $self->_sections_for_page_version( $page, $current_version );
    my $old_size = $self->_get_length_for_sections( $current_sections );
    my $new_size = $self->_get_length_for_sections( $sections );
    
    my $change_info = {
        position => 0,
        old => $old_size,
        new => $new_size,
    };
    
    my $html = $self->_sections_to_html( $sections );

    $self->_create_new_version_for_page(
        $page, $html, $change_info, $current_version, CHANGE_REVERT
    );

    $self->_update_page_indexes( $page, $html );
}

sub _return_to_main {
    my ( $self, $error ) = @_;

    if ( $error ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $error );
    }

    $self->redirect(
        $self->derive_url(
            task => 'detect',
        )
    );
}

sub _go_to {
    my ( $self, $to, $title ) = @_;

    $self->redirect(
        $self->derive_url(
            task => $to,
            additional => [ $title ],
            params => {},
        )
    );
}

sub _fetch_page_or_redirect {
    my ( $self, $title ) = @_;

    if ( !$title ) {
        $self->_return_to_main;
    }

    my $page = $self->_fetch_page( $title );

    if ( !$page ) {
        if ( $page = $self->_fetch_redirected_page( $title ) ) {
            $self->redirect(
                $self->derive_url(
                    task => 'show',
                    additional => [ $page->title ],
                )
            );
        }

        Dicole::MessageHandler->add_message( MESSAGE_WARNING,
            $self->_msg('Page you requested does not exist')
        );

        if ( $self->chk_y( 'create' ) ) {
            $self->redirect(
                $self->derive_url(
                    task => 'create',
                    additional => [],
                    params => {
                        new_title => $self->param('title') || $title
                    },
                )
            );
        }
        else {
            $self->redirect(
                $self->derive_url(
                    task => 'browse',
                    additional => [],
                )
            );
        }
    }

    return $page;
}

sub _strip_dicole_generated_html {
    my ( $self, $edit_content ) = @_;

    my $tree = $self->_tree_from_content( $edit_content );

    my $rebuild_content = 0;

    my @containers = $tree->look_down(
        '_tag' => 'div',
        class => qr/wiki_container|contentItemContainer/,
    );

    for ( @containers ) {
        $_->replace_with_content;
        $rebuild_content = 1;
    }

    my @controls = $tree->look_down(
        '_tag' => 'div',
        class => qr/wiki_controls/,
    );

    my @switches = $tree->look_down(
        '_tag' => 'a',
        class => qr/sh_switch_(open|close)/,
    );

    my @anchors = $tree->look_down(
        '_tag' => 'a',
        class => qr/wiki_header_anchor/,
    );

    for ( @controls, @switches, @anchors ) {
        $_->delete;
        $rebuild_content = 1;
    }

    $edit_content = $self->_nodes_to_html( [ $tree->guts ] ) if $rebuild_content;

    return $edit_content;
}

sub _filter_incoming_links {
    my ( $self, $edit_content ) = @_;

    my $tree = $self->_tree_from_content( $edit_content );

    my @wiki_links = $tree->look_down(
        '_tag' => 'a',
        'class' => qr/wikiLink/,
    );

    my $rebuild_content = 0;

    for my $alink (@wiki_links) {
        my $class = $alink->attr('class');
        $class =~ s/ ?(existing|missing)WikiLink//g;
        $alink->attr( 'class', $class );

        my ( $title, $anchor ) = $self->_decode_title(
            $alink->attr('title')
        );
        my $readable_title = $self->_raw_title_to_readable_form( $title );

        $alink->attr( 'title', $self->_encode_title(
            $readable_title, $anchor
        ) );
        $alink->attr( 'href', '#' );

        $rebuild_content++;
    }

    $edit_content = $self->_nodes_to_html( [ $tree->guts ] ) if $rebuild_content;

    return $edit_content;
}

# List of contained sections for each section block (including self)
sub _get_block_info {
    my ( $self, $sections ) = @_;

    my %contents = ();
    my @level_stack = ();
    my $last_begin = 0;
    for my $section ( @$sections ) {
        my $id = $section->{id};
        while ( @level_stack &&
                $level_stack[-1]->{level} >= $section->{level} ) {
            pop @level_stack;
        }
        push @{ $contents{$id}{children} }, $id;
        push @{ $contents{ $_->{id} }{children} }, $id for @level_stack;

        my $size = $self->_get_length_for_section( $section );

        $contents{$id}{position} = $last_begin;
        $contents{$id}{size} = $size;

        $last_begin += $size;

        push @level_stack, {
            level => $section->{level},
            id => $id
        };
    }
    return \%contents;
}

sub _generate_diff_dropdowns {
    my ( $self, $page, $v1, $v2 ) = @_;

    my $from_id = $v1->version_number;
    my $to_id = $v2->version_number;
    my $title = $page->title;

    my $current_version = $page->last_version_number;
    my $from_drop = Dicole::Widget::FormControl::Select->new( autourl => 1 );
    my $to_drop = Dicole::Widget::FormControl::Select->new( autourl => 1 );

    my $buttons = [];

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '<+<',
        link => $self->derive_url(
            additional => [ $title, $from_id - 1, $to_id - 1 ]
        )
    ) if $from_id > 0 && $to_id > 0;

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '<',
        link => $self->derive_url(
            additional => [ $title, $from_id - 1, $to_id ]
        )
    ) if $from_id > 0;
    
    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '?',
        link => $self->derive_url(
            task => 'show',
            additional => [ $title, $from_id ]
        ),
    ) if $from_id > 0;

    push @$buttons, $from_drop;
    push @$buttons, $to_drop;

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '?',
        link => $self->derive_url(
            task => 'show',
            additional => [ $title, $to_id ]
        )
    ) if $to_id > 0;;

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '>',
        link => $self->derive_url(
            additional => [ $title, $from_id, $to_id + 1 ]
        )
    ) if $to_id < $current_version;

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => '>+>',
        link => $self->derive_url(
            additional => [ $title, $from_id + 1, $to_id + 1 ]
        )
    ) if $to_id < $current_version && $from_id < $current_version;

    push @$buttons, Dicole::Widget::LinkButton->new(
        text => $self->_msg( 'Show current page' ),
        link => $self->derive_url(
            task => 'show',
            additional => [ $title ]
        )
    );

    my $versions = $self->_fetch_versions_for_page_since( $page, 0 );

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $versions,
        link_field => 'creator_id',
        object_name => 'user',
    );


    my $generate_version_text = sub {
        my ( $version ) = @_;
        my $user = $users->{ $version->creator_id };
        $user = $user ? ' - '. $user->first_name .' '. $user->last_name : '';

        return $version->version_number . ': ' .
            Dicole::DateTime->date( $version->creation_time ) . $user;
    };

    $from_drop->add_objects_as_options( {
        objects => $versions,
        selected_id => $v1->id,
        text_sub => $generate_version_text,
        value_sub => sub {
           my ( $version ) = @_;
           return $self->derive_url(
                additional => [ $title, $version->version_number, $to_id ],
           );
        },
    } );

    $to_drop->add_objects_as_options( {
        objects => $versions,
        selected_id => $v2->id,
        text_sub => $generate_version_text,
        value_sub => sub {
           my ( $version ) = @_;
           return $self->derive_url(
                additional => [ $title, $from_id, $version->version_number ],
           );
        },
    } );

    return Dicole::Widget::Horizontal->new(
        contents => $buttons
    );
}

sub _generate_diff_table {
    my ( $self, $page, $v1, $v2 ) = @_;

    my $s1 = $self->_sections_for_page_version( $page, $v1 );
    my $s2 = $self->_sections_for_page_version( $page, $v2 );

    $self->_filter_outgoing_links( $page, [ @$s1, @$s2 ] );

#     my $n1 = [ map {$_->{html}} @$s1 ];
#     my $n2 = [ map {$_->{html}} @$s2 ];
    my $n1 = $self->_sections_to_html_nodes( $s1 );
    my $n2 = $self->_sections_to_html_nodes( $s2 );

    my @changes = Algorithm::Diff::sdiff( $n1, $n2 );

     # join consecutive conflicts
     my @cchanges = @changes;
#     my @cchanges = ();
#     my $last_was_c = 0;
#     for my $diff ( @changes ) {
#         if ( $diff->[0] eq 'c' && $last_was_c ) {
#             $cchanges[-1]->[1] .= $diff->[1];
#             $cchanges[-1]->[2] .= $diff->[2];
#         }
#         else {
#             push @cchanges, $diff;
#         }
#
#         if ( $diff->[0] eq 'c' ) {
#             $last_was_c = 1;
#         }
#         else {
#             $last_was_c = 0;
#         }
#     }

    # strip consecutive unchanged
    my @uchanges = ();
    my $before_max = 3;
    my $after_max = 3;
    my $u_count = $after_max;
    for my $diff (@cchanges) {
        if ( $diff->[0] eq 'u' ) {
            $u_count++;
        }
        else {
            if ( $u_count > $after_max + $before_max ) {
                splice(
                    @uchanges,
                    - $u_count + $after_max,
                    - $before_max,
                    ['x']
                );
            }

            $u_count = 0;
        }

        push @uchanges, $diff;
    }

    if ( $u_count > $after_max ) {
        splice(
            @uchanges,
            - $u_count + $after_max,
        );
        push @uchanges, ['x'];
    }


    my $c = '<table style="width:100%">';
    for my $diff ( @uchanges ) {
        $c .= '<tr>';

        if ( $diff->[0] eq 'x' ) {
            $c .= '<td colspan="4" align="center" style="background-color: #fff">...</td>';
        }
        elsif ( $diff->[0] eq 'u' ) {
            $c .= '<td width="25%"> </td><td width="50%" colspan="2" style="background-color: #eee">' . $diff->[1] . '</td><td width="25%"> </td>';
        }
        else {
            $c .= '<td width="50%" colspan="2" style="background-color: #fee">' . $diff->[1] . '</td>';
            $c .= '<td width="50%" colspan="2" style="background-color: #efe">' . $diff->[2] . '</td>';
        }
        $c .= '</tr>';
    }

    $c .= '</table>';


    return Dicole::Widget::Raw->new( raw => $c );
}

sub _add_sh_switches_to_link_headers {
    my ( $self, $page, $sections ) = @_;

    my $used_ids = {};

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for ( my $i = 0; $i < scalar( @{ $section->{nodes} } ); $i++ ) {
            my $node = $section->{nodes}->[$i];
            next unless ref $node && $node->tag =~ /^h(\d+)$/;
            my $hb = $1;

            my @wiki_links = $node->look_down(
                '_tag' => 'a',
                'class' => qr/existingWikiLink/,
            );

            next unless scalar( @wiki_links );

            $rebuild_html++;

            my $link = shift @wiki_links;

            my $id = int(rand()*1000000);

            my $link_class = 'wiki_header_link_' . $id;
            my $c = $link->attr('class');
            $link->attr('class', $c ? "$c $link_class" : $link_class );

            my $switch_href = $self->derive_url(
                action => 'wiki_json', task => 'page_content'
            );
            my $switch =
                '<span class="sh_switch_controls"> '.
                '<a class="hiddenBlock sh_switch_open sh_switch_open_'.$id.
                ' wiki_content_fetcher wiki_content_fetcher_'.$hb.'_'.$id.'"'.
                'href="'.HTML::Entities::encode_entities($switch_href).'">['.$self->_msg('preview').']</a>'.
                '<a class="hiddenBlock sh_switch_close sh_switch_close_'.$id.'" '.
                'href="#">['.$self->_msg('close').']</a>'.
                '</span>';

            $node->push_content(
                $self->_elements_from_content( $switch )
            );

            my $block = Dicole::Widget::HiddenBlock->new(
                class => ' wiki_content_container sh_switch_block sh_switch_block_' . $id,
                content => $self->_msg('Loading content..'),
            );

            my @b = $self->_elements_from_content( $block->generate_content );
            push @{ $section->{nodes} }, @b;

            $rebuild_html++;
        }

        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _create_description_dialog {
    my ( $self ) = @_;

    my $other = Dicole::Widget::Vertical->new(
        id => 'edit_confirm_controls',
        contents => [
            Dicole::Widget::Horizontal->new(
                contents => [
                    Dicole::Widget::Raw->new(
                        raw => '<input type="checkbox" id="edit_minor"> '
                    ),
                    $self->_msg( 'Minor edit' ),
                ]
            ),
            Dicole::Widget::LinkButton->new(
                id => 'confirm_save', text => $self->_msg( 'Save' ),
            ),
            Dicole::Widget::LinkButton->new(
                id => 'confirm_cancel',
                text => $self->_msg( 'Continue editing' ),
            ),
        ],
    );

    my $cols = Dicole::Widget::Columns->new(
        center => Dicole::Widget::Raw->new(
            raw => '<textarea rows="3" cols="50"'.
                'id="edit_description"></textarea>',
        ),
        right => $other, 
        right_width => '200px',
    );

    my $guide = Dicole::Widget::Vertical->new(
        id => 'edit_confirm_box',
        contents => [
            $self->_msg('You should type a short description of the changes you have made in the text area below. This way other people can get a quick overview of recent changes. If you have made only small changes of which others require no notification (like fixed a typing error) you can just check the "Minor edit" checkbox.'),
            $self->_msg('(empty description will automatically result in a minor edit)'),
            $cols
        ]
    );

    return Dicole::Widget::HiddenBlock->new(
        id => 'toolbar_comment_query',
        content => $guide,
    );
}

sub _create_cancel_dialog {
    my ( $self ) = @_;

    my $lines = Dicole::Widget::Vertical->new(
        id => 'edit_cancel_controls',
        contents =>  [
            $self->_msg('Are you sure you want to cancel editing and lose all the changes you have made?'),
            Dicole::Widget::Horizontal->new( contents => [
                Dicole::Widget::LinkButton->new(
                    id => 'cancel_accept',
                    text => $self->_msg( 'Cancel editing' ),
                ),
                Dicole::Widget::LinkButton->new(
                    id => 'cancel_back',
                    text => $self->_msg( 'Continue editing' ),
                ),
            ] ),
        ]
    );

    return Dicole::Widget::HiddenBlock->new(
        id => 'toolbar_cancel_query', content => $lines,
    );
}

sub _temporary_wiki_widget {
    my ( $self, $page, $sections, $toc_elements ) = @_;

    my $toc = $self->_create_toc_block( $page, $toc_elements );

    my $html = '';
    my @level_stack = ();

    for my $section ( @$sections ) {

        while ( @level_stack && $level_stack[-1] >= $section->{level} ) {
            $html .= '</div>';
            pop @level_stack;
        }

        push @level_stack, $section->{level};

        $html .= $/.'<div class="wiki_container wiki_block_container" ' .
            'id="wiki_block_'.$section->{id}.'">';
        $html .= '<div class="wiki_container wiki_content_container" ' .
            'id="wiki_content_'.$section->{id}.'">'.$/;
        $html .= '<div class="wiki_controls" id="wiki_controls_' .
            $section->{id} . '"></div>'.$/;

        # TODO: Find out why this can't just be ->{html}
        my $section_html = $self->_nodes_to_html( $section->{nodes} );
        $html .= $section_html;

        # Insert content table and scaffolding
        if ( $section->{level} == 0 ) {
            if ( $toc ) {
                $html .= '<h1 id="toc_header">';
                $html .= $self->_msg('Contents') . '</h1>';
                $html .= $toc;
            }
            elsif ( scalar( @$sections ) == 1 && ! $section_html ) {
                $html .= '<p>';
                $html .= $self->_msg('This page needs content! You can add text, pictures and other interesting stuff by clicking [_1] on the right.',
                    '<u>' . $self->_msg( 'Edit beginning' ) . '</u>'
                );
                $html .= '</p>';
            }
        }

        $html .= '</div>';
    }

    while ( @level_stack ) {
        $html .= '</div>';
        pop @level_stack;
    }

    my $hidden_fields = <<'FIELDS';
<input type="hidden" name="base_version_number" value="" />
<input type="hidden" name="edit_target_id" value="" />
<input type="hidden" name="edit_target_type" value="" />
<input type="hidden" name="edit_content" value="" />
<input type="hidden" name="edit_lock" value="" />
<input type="hidden" name="change_minor" value="" />
<input type="hidden" name="change_description" value="" />
<input type="hidden" name="save" value="" />
<input type="hidden" name="cancel" value="" />
FIELDS


    return new Dicole::Widget::Text(
        filter => 0,
        text => $hidden_fields . $html,
    );
}

sub _create_toc_block {
    my ( $self, $page, $elements ) = @_;

    return undef if scalar(@$elements) < 1;
    my @list = ();

    for my $elem ( @$elements ) {
        my $href = $self->derive_url(
            anchor => $elem->{anchor},
        );

        my $level = scalar(@{$elem->{numbers}});
        $level = 'x' if $level > 6;

        my $link = Dicole::Widget::Hyperlink->new(
            link => $href,
            content => Dicole::Widget::Inline->new(
                contents => [
                    Dicole::Widget::Text->new(
                        class => 'toc_entry_number',
                        text => join('.', @{$elem->{numbers}}),
                    ),
                    ' ' . $elem->{text},
                ]
            ),
        );

        my $item = '<div class="toc_entry toc_level_' . $level . '">';
        $item .= $link->generate_content;
        $item .= '</div>';

        push @list, $item;
    }

    my $block = Dicole::Widget::HiddenBlock->new(
        content => Dicole::Widget::Raw->new( raw => join("", @list) ),
        id => 'toc_block',
        visible => ( scalar(@$elements) > 4 ) ? 1 : 0,
    );

    return $block->generate_content;
}


1;

