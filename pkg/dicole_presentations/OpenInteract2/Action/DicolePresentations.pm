package OpenInteract2::Action::DicolePresentations;

use strict;
use base qw( OpenInteract2::Action::DicolePresentationsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use Dicole::Utils::HTTP;
use XML::Simple;
use Digest::SHA;
use URI;
use URI::QueryParam;

sub _presentations_digest {
    my ( $self ) = @_;

   # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};
    $self->language( $self->param('lang') );

    my $group_id = $self->param('group_id');
    my $user_id = $self->param('user_id');
    my $domain_id = $self->param('domain_id');
    my $domain_host = $self->param('domain_host');
    my $start_time = $self->param('start_time');
    my $end_time = $self->param('end_time');

    my $comments = CTX->lookup_object( 'comments_post' )->fetch_group( {
        from => [ 'dicole_comments_thread', 'dicole_comments_post' ],
        where => 'dicole_comments_thread.thread_id = dicole_comments_post.thread_id AND '.
            'dicole_comments_thread.group_id = ? AND dicole_comments_thread.object_type = ? AND ' .
            'published >= ? AND published < ? AND removed = ?',
        value => [ $group_id, CTX->lookup_object('presentations_prese'), $start_time, $end_time, 0 ],
    } ) || [];

    my $comments_by_thread = {};
    for my $comment ( @$comments ) {
        $comments_by_thread->{ $comment->thread_id } ||= [];
        push @{ $comments_by_thread->{ $comment->thread_id } }, $comment;
    }

    my $threads_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $comments,
        link_field => 'thread_id',
        object_name => 'comments_thread',
    );

    my $threads_by_entry = { map { $_->object_id => $_ } values %$threads_by_id };
    my @extra_entries_ids = keys %$threads_by_entry;

    my $entries = CTX->lookup_object('presentations_prese')->fetch_group( {
        where => 'group_id = ? AND ( (' .
            ' creation_date >= ? AND creation_date < ? ) OR ( ' .
            Dicole::Utils::SQL->column_in( prese_id => \@extra_entries_ids ) .
            ' ) )',
        value => [ $group_id, $start_time, $end_time ],
        order => 'creation_date DESC'
    } ) || [];

    if ( ! scalar( @$entries ) ) {
        return undef;
    }

    my $entry_users_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $entries,
        link_field => 'creator_id',
        object_name => 'user',
    );

    my $comment_users_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $comments,
        link_field => 'user_id',
        object_name => 'user',
    );

    my $users_by_id = {
        %$entry_users_by_id,
        %$comment_users_by_id,
    };

    my $return = {
        tool_name => $self->_msg( 'Media' ),
        items_html => [],
        items_plain => [],
    };

    for my $entry ( @$entries ) {
        my $user = $users_by_id->{ $entry->creator_id };
        my $name = $user ? $user->first_name . ' ' . $user->last_name : $self->_msg('Unknown user');
        my $link = $domain_host . $self->_show_url( $entry, $domain_id );

        my $date_string = Dicole::DateTime->medium_datetime_format(
            $entry->created_date, $self->param('timezone'), $self->param('lang')
        );

        my $html = '<span class="date">' . Dicole::Utils::HTML->encode_entities($date_string) . '</span> - ' .
            '<a href="' . Dicole::Utils::HTML->encode_entities($link) . '">' . Dicole::Utils::HTML->encode_entities($entry->name) . '</a> - ' .
            '<span class="author">' . Dicole::Utils::HTML->encode_entities($name) . '</span>';

        my $text = $date_string . ' - ' . $entry->name . ' - '  . $name . "\n  - " . $link;

        my $entry_comments = ref( $threads_by_entry->{ $entry->id } ) ?
            $comments_by_thread->{ $threads_by_entry->{ $entry->id }->id } || [] : [];
        if ( scalar( @$entry_comments ) ) {
            $html .= "\n" . '<ul>';
            for my $comment ( sort { $b->date <=> $a->date } @$entry_comments ) {
                my $cuser = $users_by_id->{ $comment->user_id };
                my $cname = $comment->anon_name;
                $cname ||= $cuser ? $cuser->first_name . ' ' . $cuser->last_name : $self->_msg('Unknown user');
                my $cdate_string = Dicole::DateTime->medium_datetime_format(
                    $comment->date, $self->param('timezone'), $self->param('lang')
                );
                my $clink = $domain_host . $self->_show_url( $entry, $domain_id, {
                       anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id,
                } );

                $html .= "\n" . '<li>';
                $html .= '<span class="date">' . Dicole::Utils::HTML->encode_entities($cdate_string) . '</span> - ' .
                    '<a href="' . Dicole::Utils::HTML->encode_entities($clink) . '">' . $self->_msg( 'Comment by [_1]', Dicole::Utils::HTML->encode_entities($cname) ) . '</a>';
                $html .= '</li>';

                $text .= '    * ' . $cdate_string . ' - ' . $self->_msg( 'Comment by [_1]', $cname ) . "\n" . $clink;
            }
            $html .= '</ul>';
        }

        push @{ $return->{items_html} }, $html;
        push @{ $return->{items_plain} }, $text;
    }

    return $return;
}

sub _tagsearch_summary {
    my ( $self ) = @_;

    my $params = {
        complete_url => $self->derive_url( action => 'presentations_json', task => 'tag_completion', target => $self->param('target_group_id') ),
        go_url_base => $self->derive_url( action => 'presentations', task => 'init_tag_search', target => $self->param('target_group_id') ),
    };

    my $content = $self->generate_content( $params, { name => 'dicole_presentations::tagsearch_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Search materials (summary title)') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _featured_summary {
    my ( $self ) = @_;

    my $preses = $self->_generic_preses(
        where => 'dicole_presentations_prese.featured_date > 0',
        group_id => $self->param('target_group_id'),
        order => 'dicole_presentations_prese.featured_date desc',
        limit => 1,
    );
    my $prese = pop @$preses;

    return unless $prese;

    my $params = {
        embed => $self->_embed_for_object( $prese ),
        description => Dicole::Utils::HTML->shorten( $prese->description, 200 ),
        more_url => $self->derive_url( action => 'presentations', task => 'detect_show', target => $self->param('target_group_id'), additional => [ $prese->id ] ),
    };
    my $content = $self->generate_content( $params, { name => 'dicole_presentations::featured_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Featured media (summary title)') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _new_summary {
    my ( $self ) = @_;

    my $preses = $self->_generic_preses(
        group_id => $self->param('target_group_id'),
        order => 'dicole_presentations_prese.creation_date desc',
        limit => 5,
    );
    my $params = { medias => [] };

    for my $prese ( @$preses ) {
        my $info = {
            title => $prese->name,
            summary => Dicole::Utils::HTML->shorten( $prese->description, 50 ),
            'link' => $self->_show_url( $prese ),
            image => CTX->lookup_action('thumbnails_api')->execute(create => {url => $self->_get_presentation_image( $prese ), width => 50, height => 50}),
            date => Dicole::Utils::Date->localized_ago( epoch => $prese->creation_date ),
        };
        push @{ $params->{medias} }, $info;
    }

    $params->{show_media_url} = Dicole::URL->from_parts( action => 'presentations', task => 'detect', target => $self->param('target_group_id') );

    my $content = $self->generate_content( $params, { name => 'dicole_presentations::new_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Latest media') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 10, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });

    $self->tool->tool_title( $self->_msg('Media') );

    $self->tool->Container->column_width( '280px', 1 );

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.presentations");' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");' ),
    );
    $self->tool->add_head_widgets( Dicole::Widget::Javascript->new(
        code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $params{globals} ) . ');'
    ) ) if $params{globals};

    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/dicole_presentations.css' ),
    ) if $self->task =~ /^(recent)$/;

    if ( $self->task =~ /^(show|new|top|featured|recent)$/ ) {
        $self->tool->action_buttons( [ {
            name => $self->_msg('Add content'),
            class => 'presentations_add_action',
            url => $self->derive_url( action => 'presentations', task => 'add', additional => [] ),
        } ] ) if $self->schk_y( 'OpenInteract2::Action::DicolePresentations::add' );
    }
}

sub detect {
    my ( $self ) = @_;

    if ( $self->param('domain_name') =~ /sanako|languagepoint|work\-dev/ ) {
        $self->redirect( $self->derive_url( task => 'recent' ) );
    }

    if ( $self->param('domain_id') == 70 ) {
        $self->redirect( $self->derive_url(
            task => 'browse', additional => []
        ) );
    }

    my $parts = Dicole::URL->get_parts_from_action( $self );
    $parts->{task} = 'new';
    $parts->{additional} ||= [];
    unshift @{ $parts->{additional} }, 'any';

    return $self->redirect( Dicole::URL->from_parts( %$parts ) );
}

sub init_tag_search {
    my ( $self ) = @_;

    my $tags = CTX->request->param('tags');

    return $self->redirect( $self->derive_url( task => 'detect', additional => [ $tags ] ) );
}

sub detect_show {
    my ( $self ) = @_;

    if ( $self->param('domain_id') == 70 ) {
        $self->redirect( $self->derive_url(
            task => 'browse', additional => []
        ) );
    }

    return $self->redirect( $self->_show_url( $self->param('prese_id') ) );
}

sub add {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $object = CTX->lookup_object('presentations_prese')->new;
    my $gid = $self->param('target_group_id');

    my $tags_value = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    if ( CTX->request->param('save') ||  CTX->request->param('preview') ) {

        $self->_move_params_to_object( $object );
        $self->_process_attachment_upload( $object, CTX->request->auth_user );
        $self->_process_image_upload( $object, CTX->request->auth_user );

        if ( CTX->request->param('save') ) {
            if ( ! CTX->request->param('name') ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg('You must fill the name.')
                );
            }
            else {
                $object->group_id( $gid );
                $object->creator_id( CTX->request->auth_user_id );
                $object->creation_date( time );
                $object->featured_date( 0 );
                $object->rating_count( 0 );
                $object->rating( 0 );
                $object->scribd_id(CTX->request->param('scribd_id'));
                $object->scribd_key(CTX->request->param('scribd_key'));

                $object->save;

                if ( $object->attachment_id ) {
                    my $a = CTX->lookup_object('attachment')->fetch( $object->attachment_id );
                    CTX->lookup_action( 'attachment')->execute( reattach => {
                        attachment => $a,
                        user_id => 0,
                        group_id => $gid,
                        object => $object,
                    } );
                }
                if ( $object->image =~ /^\d+$/ ) {
                    my $a = CTX->lookup_object('attachment')->fetch( $object->image );
                    CTX->lookup_action( 'attachment')->execute( reattach => {
                        attachment => $a,
                        user_id => 0,
                        group_id => $gid,
                        object => $object,
                    } );
                }

                my $tags_data = [];

                eval {
                    my $tags_action = CTX->lookup_action('tags_api');
                    eval {
                        my $tags = $tags_action->e( merge_input_to_json_tags => {
                            input => CTX->request->param('prefilled_tags') || '',
                            json => $tags_value,
                        } );
                        $tags_action->e( attach_tags_from_json => {
                            object => $object,
                            json => $tags,
                        } );
                    };
                    $self->log('error', $@ ) if $@;
                    $tags_data = $tags_action->e( decode_json => { json => $tags_value } ) || [];
                };

                $self->_store_creation_event( $object, $tags_data );

                Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg('Content created.') );
                return $self->redirect( CTX->request->param('url_after_creation') ?
                    CTX->request->param('url_after_creation') :
                    $self->derive_url( task => 'detect_show', additional => [ $object->id ] )
                );
            }
        }

        return $self->_add_based_on_object( $object, $tags_value );
    }

    if ( CTX->request->param('refetch') ) {
        eval { $self->_fill_object_from_url( $object, CTX->request->param('url') ) };
        if ( $@ ) {
        	get_logger(LOG_APP)->error($@);
            Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg('Unsupported URL') );
        }
        return $self->_add_based_on_object( $object, $tags_value );
    }

    if ( CTX->request->param('fetch_submit') ) {
        eval { $self->_fill_object_from_url( $object, CTX->request->param('fetch_seed') ) };
        if ( $@ ) {
        	get_logger(LOG_APP)->error($@);
            Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg('Unsupported URL') );
        }
        else {
            return $self->_add_based_on_object( $object, $tags_value );
        }
    }

    if ( CTX->request->param('embed_submit') && CTX->request->param('embed_seed') ) {
        $object->embed( CTX->request->param('embed_seed') );
        $object->creation_date( time );
        $object->prese_type( 'custom' );
        $object->presenter( Dicole::Utils::User->full_name( CTX->request->auth_user ) );
        return $self->_add_based_on_object( $object, $tags_value );
    }
    if ( CTX->request->param('upload_submit') && CTX->request->param('upload_attachment') ) {
        $self->_process_attachment_upload( $object, CTX->request->auth_user );
        $object->creation_date( time );
        $object->presenter( Dicole::Utils::User->full_name( CTX->request->auth_user ) );
        return $self->_add_based_on_object( $object, $tags_value );
    }

    return $self->_add_guide;
}

sub _add_based_on_object {
    my ( $self, $object, $tags_value ) = @_;

    $self->_default_tool_init( upload => 1 );

    $self->tool->add_tinymce_widgets;
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.presentations");' ),
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");' ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );

    my $save_pressed = CTX->request->param('save') || CTX->request->param('preview')  ? 1 : 0;

    unless ( $self->param('domain_id') == 70 ) {
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );
    }
    $self->tool->Container->box_at( 1, 1 )->name( $self->_msg('Add content info') );
    $self->tool->Container->box_at( 1, 1 )->add_content(
        [ $self->_fields( $object, $save_pressed, $tags_value, 1 ) ]
    );

    $self->_add_preview_box( 1, 0, $object );
    $self->_add_type_select_box( 0, 2, $object->prese_type );

    return $self->generate_tool_content;
}

sub _add_guide {
    my ( $self ) = @_;

    if ( $self->param('domain_id') == 70 ) {
        return $self->_new_add_guide;
    }

    $self->_default_tool_init( upload => 1 );

    my $fields = Dicole::Widget::Vertical->new(
        contents => [
            Dicole::Widget::Text->new(
                text => $self->_msg( 'How would you like to add content?' ),
                class => 'definitionHeader presentations_add',
            ),
            Dicole::Widget::Text->new(
                text => $self->_msg( 'Upload from your computer' ),
                id => 'presentations_add_select_upload',
                class => 'definitionHeader presentations_add_upload'
            ),
            Dicole::Widget::Raw->new(
                raw => '<input name="upload_attachment" type="file" value="" />',
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                class => 'presentations_add_upload_submit',
                name => 'upload_submit',
                text => $self->_msg('Upload'),
            ),
            Dicole::Widget::Text->new(
                text => $self->_msg( 'Fetch it from the internet' ),
                id => 'presentations_add_select_fetch',
                class => 'definitionHeader presentations_add_select'
            ),
            Dicole::Widget::Inline->new( contents => [
                Dicole::Widget::FormControl::TextField->new(
                    class => 'presentations_add_fetch_url',
                    name => 'fetch_seed',
                    value => '',
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    class => 'presentations_add_fetch_submit',
                    name => 'fetch_submit',
                    text => $self->_msg('Fetch'),
                ),
            ] ),
            Dicole::Widget::Inline->new( class => 'presentations_add_supported', contents => [
                Dicole::Widget::Text->new(
                    text => $self->_msg( 'Supported services' ),
                ),
                ' ',
#                Dicole::Widget::Hyperlink->new(
#                    class => 'presentations_add_custom_youtube_link',
#                    link => 'http://youtube.com/',
#                    content => Dicole::Widget::Text->new(
#                        class => 'presentations_add_custom_youtube_text',
#                        text => $self->_msg( 'YouTube' ),
#                    ),
#                ),
#                ' ',
                Dicole::Widget::Hyperlink->new(
                    class => 'presentations_add_custom_slideshare_link',
                    link => 'http://slideshare.net/',
                    content => Dicole::Widget::Text->new(
                        class => 'presentations_add_custom_slideshare_text',
                        text => $self->_msg( 'Slideshare' ),
                    ),
                ),
#                 Dicole::Widget::Hyperlink->new(
#                     class => 'presentations_add_custom_ovi_link',
#                     link => 'http://ovi.com/',
#                     content => Dicole::Widget::Text->new(
#                         class => 'presentations_add_custom_ovi_text',
#                         text => $self->_msg( 'Ovi' ),
#                     ),
#                 ),
            ] ),
            Dicole::Widget::Text->new(
                text => $self->_msg( 'Embed custom HTML' ),
                id => 'presentations_add_select_custom',
                class => 'definitionHeader presentations_add_custom'
            ),
            Dicole::Widget::FormControl::TextArea->new(
                name => 'embed_seed',
                rows => 15,
                cols => 50,
                value => '',
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                class => 'presentations_add_custom_submit',
                name => 'embed_submit',
                text => $self->_msg('Embed'),
            ),
        ]
    );

    unless ( $self->param('domain_id') == 70 ) {
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );
    }
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Add content') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $fields ]
    );

    return $self->generate_tool_content;
}

sub _add_preview_box {
    my ( $self, $x, $y, $prese ) = @_;

    my $preview = Dicole::Widget::FancyContainer->new(
        class => 'presentations_prese_preview presentations_prese_show_container',
        contents => [
            Dicole::Widget::Container->new(
                class => 'presentations_prese_show_embed',
                contents => [ Dicole::Widget::Raw->new( raw => $self->_embed_for_object( $prese ) ) ],
            ),
        ],
    );

    $self->tool->Container->box_at( $x, $y )->name( $self->_msg('Preview: [_1]', $prese->name) );
    $self->tool->Container->box_at( $x, $y )->add_content(
        [ $preview ]
    );
}

sub edit {
    my ( $self ) = @_;

    my $pid = $self->param('prese_id');
    my $gid = $self->param('target_group_id');

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    die "security error" unless $prese && $prese->group_id == $self->param('target_group_id');
    die "security error" unless $self->_current_user_can_edit_object( $prese );

    $self->_default_tool_init( upload => 1 );

    $self->tool->add_tinymce_widgets;
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.presentations");' ),
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");' ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );

    my $pressed = CTX->request->param('save') || CTX->request->param('preview');
    my $description = CTX->request->param('description');
    my $name = CTX->request->param('name');

    my $prese_tags_old = CTX->request->param('tags_old');
    my $prese_tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    if ( $pressed ) {
       $self->_move_params_to_object( $prese );
       $self->_process_attachment_upload( $prese );
       $self->_process_image_upload( $prese );

       if ( ! $name ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill the name.')
            );
        }
        # allow storing no tags if prese had no tags for backwards compatibility
#         elsif ( $prese_tags eq '[]' && $prese_tags_old ne '[]'  ) {
#             $self->tool->add_message(
#                 MESSAGE_ERROR, $self->_msg('You must have at least one tag.')
#             );
#         }
        else {
            if ( CTX->request->param('save') ) {
            	$prese->scribd_thumbnail_timestamp_start(0);
            	$prese->scribd_thumbnail_timestamp(0);
                $prese->save;

                eval {
                    my $tags = CTX->lookup_action('tagging');
                    eval {
                        $tags->execute( 'update_tags_from_json', {
                            object => $prese,
                            group_id => $gid,
                            user_id => 0,
                            json => $prese_tags,
                            json_old => $prese_tags_old,
                        } );
                    };
                    $self->log('error', $@ ) if $@;
                };

                $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Content updated') );

                return $self->redirect( CTX->request->param('url_after_save') ?
                    CTX->request->param('url_after_save') :
                    $self->derive_url( task => 'detect_show', additional => [ $prese->id ] )
                );
            }
        }
    }
    if ( CTX->request->param('refetch') ) {
        $self->_fill_object_from_url( $prese, CTX->request->param('url') );
    }
    if ( CTX->request->param('delete') ) {
        return $self->redirect( $self->derive_url( task => 'delete', CTX->request->param('url_after_save') ? ( params => { url_after_save => CTX->request->param('url_after_save') } ) : () ) );
    }
    if ( CTX->request->param('feature') ) {
        $prese->featured_date( time );
        $prese->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Content featured.') );
    }
    if ( CTX->request->param('unfeature') ) {
        $prese->featured_date( 0 );
        $prese->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Content not featured anymore.') );
    }

    unless ( $self->param('domain_id') == 70 ) {
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );
    }
    $self->tool->Container->box_at( 1, 1 )->name( $self->_msg('Edit content') );
    $self->tool->Container->box_at( 1, 1 )->add_content(
        $self->_fields( $prese, $pressed, $prese_tags )
    );

    $self->_add_preview_box( 1, 0, $prese );

    $self->_add_type_select_box( 0, 2, $prese->prese_type );

    return $self->generate_tool_content;
}

sub feature {
    my ( $self ) = @_;

    return $self->_feature( time, $self->_msg('Content featured.') );
}

sub unfeature {
    my ( $self ) = @_;

    return $self->_feature( 0, $self->_msg('Content not featured anymore.') );
}

sub _feature {
    my ( $self, $value, $message ) = @_;

    die "security error" unless $self->param('prese_id');

    my $object = eval { CTX->lookup_object('presentations_prese')->fetch(
        $self->param('prese_id')
    ) };

    my $gid = $self->param('target_group_id');

    die "security error" unless $object && $object->group_id == $gid;
    die "security error" unless $self->chk_y('admin') || $object->creator_id == CTX->request->auth_user_id;

    $object->featured_date( $value );
    $object->save;

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $message );

    $self->redirect( $self->derive_url( task => 'detect_show', additional => [ $object->id ] ) );
}

sub delete {
    my ( $self ) = @_;

    die "security error" unless $self->param('prese_id');

    my $object = eval { CTX->lookup_object('presentations_prese')->fetch(
        $self->param('prese_id')
    ) };

    my $gid = $self->param('target_group_id');

    die "security error" unless $object && $object->group_id == $gid;
    die "security error" unless $self->chk_y('admin') || $object->creator_id == CTX->request->auth_user_id;

    $self->_default_tool_init;

    if ( CTX->request->param('delete') ) {

        $self->_remove_object( $object, undef, CTX->request->auth_user_id );

        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Content removed.') );

        return $self->redirect( CTX->request->param('url_after_save') ?
            CTX->request->param('url_after_save') :
            $self->derive_url( task => 'detect', additional => [ ] )
        );
    }

    if ( CTX->request->param('cancel') ) {
        $self->redirect( CTX->request->param('url_after_save') ?
            $self->derive_url(
                task => 'edit',
                params => { url_after_save => CTX->request->param('url_after_save') }
            )
            :
            $self->derive_url( task => 'detect_show' )
        );
    }

    my $confirm = Dicole::Widget::Vertical->new(
        contents => [
            Dicole::Widget::Text->new( text =>
                $self->_msg('Are you sure you want to delete the media object "[_1]"?', $object->name),
            ),
            Dicole::Widget::Horizontal->new( contents => [

                Dicole::Widget::FormControl::SubmitButton->new(
                    text => $self->_msg('Delete'),
                    name => 'delete',
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    text => $self->_msg('Cancel'),
                    name => 'cancel',
                ),
            ] ),
        ]
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Confirmation') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $confirm ]
    );

    return $self->generate_tool_content;
}

sub _fields {
    my ( $self, $object, $pressed, $post_tags, $add ) = @_;

    my @tag_widgets = ();

    eval {
        my $tagging = CTX->lookup_action('tagging');

        my $old_tags = ( ! $add ) ? CTX->lookup_action('tagging')->execute( 'get_tags_for_object_as_json', {
            object => $object,
            group_id => $self->param('target_group_id'),
            user_id => 0,
        } ) : Dicole::Utils::JSON->encode([]);

        my $current_tags_json = ( $pressed || $add ) ? $post_tags || Dicole::Utils::JSON->encode([]) : $old_tags;
        if ( my $additional = CTX->request->param('prefilled_tags') ) {
            $current_tags_json = CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                input => $additional,
                json => $current_tags_json,
            } );
        }

        push @tag_widgets, Dicole::Widget::FormControl::Tags->new(
            id => 'tags',
            name => 'tags',
            value => $current_tags_json,
            old_value => $pressed ? CTX->request->param( 'tags_old' ) || Dicole::Utils::JSON->encode([]) :
                $old_tags,
        );

        my $weighted_tags = $tagging->execute( 'get_weighted_tags', {
            group_id => $self->param('target_group_id'),
            user_id => 0,
        } );

        my @popular_weighted = @$weighted_tags;

        if ( scalar( @popular_weighted ) ) {
            my $cloud = Dicole::Widget::TagCloudSuggestions->new(
                target_id => 'tags',
            );
            $cloud->add_weighted_tags_array( \@popular_weighted );
            push @tag_widgets, (
                Dicole::Widget::Text->new(
                    class => 'definitionHeader',
                    text => $self->_msg( 'Click to add popular tags' ),
                ),
                $cloud,
            );
        }
    };

    return Dicole::Widget::Vertical->new( class => '', contents => [
    	( $object->scribd_id ) ? (
    		Dicole::Widget::Raw->new(raw => '<input name="scribd_id" type="hidden" value="' . $object->scribd_id .'" />')
    	) : (),
    	( $object->scribd_key ) ? (
    		Dicole::Widget::Raw->new(raw => '<input name="scribd_key" type="hidden" value="' . $object->scribd_key .'" />')
    	) : (),
        ( $object->url ) ? (
            Dicole::Widget::Text->new( text => $self->_msg( 'Source URL' ), class => 'definitionHeader' ),
            Dicole::Widget::Inline->new( class => '', contents => [
                Dicole::Widget::FormControl::TextField->new(
                    class => 'presentations_add_refetch_url',
                    name => 'url',
                    value => $pressed ? CTX->request->param('url') || '' : $object->url || '',
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    class => 'presentations_add_refetch_submit',
                    name => 'refetch',
                    text => $self->_msg('Refetch'),
                ),
            ] ),
        ) : (),
        Dicole::Widget::Text->new( text => $self->_msg( 'Name' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'name',
            value => $pressed ? CTX->request->param('name') || '' : $object->name || '',
        ),
        Dicole::Widget::Inline->new( class => '', contents => [
            Dicole::Widget::Text->new(
                class => '',
                text => $self->_msg( 'presented by' ),
            ),
            ' ',
            Dicole::Widget::FormControl::TextField->new(
                name => 'presenter',
                value => $pressed ? CTX->request->param('presenter') || '' : $object->presenter || '',
            ),
            ' ',
            Dicole::Widget::Text->new(
                class => '',
                text => $self->_msg( 'length' ),
            ),
            ' ',
            Dicole::Widget::FormControl::TextField->new(
                name => 'duration',
                value => $pressed ? CTX->request->param('duration') || '' : $object->duration || '',
            ),
        ] ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Preview image' ), class => 'definitionHeader' ),
        ( $object->image ) ? Dicole::Widget::Image->new(
            class => 'presentations_image_preview',
            src => $self->_get_presentation_image( $object, CTX->request->param('preview') ),
        ) : (),
        Dicole::Widget::Raw->new(
            raw => '<input name="image" type="hidden" value="' .
                Dicole::Utils::HTML->encode_entities( $object->image ) .
                '" />',
        ),
        Dicole::Widget::Raw->new(
            raw => '<input name="scribd_id" type="hidden" value="' .
                Dicole::Utils::HTML->encode_entities( $object->scribd_id || '' ) .
                '" />',
        ),
        Dicole::Widget::Raw->new(
            raw => '<input name="scribd_key" type="hidden" value="' .
                Dicole::Utils::HTML->encode_entities( $object->scribd_key || '' ) .
                '" />',
        ),
        Dicole::Widget::Raw->new(
            raw => '<input class="req" name="upload_image" type="file" value="" />',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Description' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextArea->new(
            name => 'description',
            rows => 15,
            value => $pressed ? CTX->request->param('description') || '<p></p>' : $object->description || '<p></p>',
            html_editor => 1,
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Tags' ), class => 'definitionHeader' ),
        @tag_widgets,
        ( $object->embed && ! $object->url && ! $object->attachment_id ) ? (
            Dicole::Widget::Text->new( text => $self->_msg( 'Embed code' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::TextArea->new(
                name => 'embed',
                rows => 15,
                cols => 50,
                value => $pressed ? CTX->request->param('embed') || '' : $object->embed || '',
            ),
        ) : (),
        ( $object->embed && $object->url && ! $object->attachment_id ) ? (
            Dicole::Widget::HiddenBlock->new(
                content => Dicole::Widget::FormControl::TextArea->new(
                    name => 'embed',
                    rows => 15,
                    cols => 50,
                    value => $pressed ? CTX->request->param('embed') || '' : $object->embed || '',
                ),
            ),
        ) : (),
        ( $object->attachment_id ) ? (
            Dicole::Widget::HiddenBlock->new(
                content => Dicole::Widget::FormControl::TextField->new(
                    name => 'attachment_id',
                    value => $object->attachment_id,
                ),
            ),
            Dicole::Widget::Text->new(
                text => $self->_msg( 'Upload a new file' ),
                id => 'presentations_upload',
                class => 'definitionHeader presentations_upload'
            ),
            Dicole::Widget::Raw->new(
                raw => '<input name="upload_attachment" type="file" value="" />',
            ),

        ) : (),
        Dicole::Widget::Inline->new( class => '', contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                name => 'save',
                text => $add ? $self->_msg( 'Create' ) :
                    $self->_msg( 'Save' ),
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                name => 'preview',
                text => $self->_msg( 'Preview' ),
            ),
            $add && 1 ? () :
            (
                $self->chk_y('admin') ? (
                    $object->featured_date ?
                        Dicole::Widget::FormControl::SubmitButton->new(
                            name => 'unfeature',
                            text => $self->_msg( 'Unfeature' ),
                        )
                        :
                        Dicole::Widget::FormControl::SubmitButton->new(
                            name => 'feature',
                            text => $self->_msg( 'Feature' ),
                        ),
                ) : (),
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => 'delete',
                    text => $self->_msg( 'Delete' ),
                ),
            ),
        ] ),
    ] );
}

sub _move_params_to_object {
    my ( $self, $object ) = @_;

    $object->image( CTX->request->param('image') );
    $object->description( CTX->request->param('description') );
    $object->duration( CTX->request->param('duration') );
    $object->presenter( CTX->request->param('presenter') );
    $object->name( CTX->request->param('name') );
    $object->embed( CTX->request->param('embed') );
    $object->url( CTX->request->param('url') );
    $object->prese_type( CTX->request->param('prese_type') );
    $object->scribd_id( CTX->request->param('scribd_id') );
    $object->scribd_key( CTX->request->param('scribd_key') );
    $object->group_id( $self->param('target_group_id') );
}

sub new { return shift->_generic_listing(
    'Latest media',
    'dicole_presentations_prese.creation_date desc',
) };

sub top { return shift->_generic_listing(
    'Best rated media',
    'dicole_presentations_prese.rating desc, dicole_presentations_prese.creation_date desc',
) };

sub _generic_listing {
    my ( $self, $title, $order ) = @_;

    my $type = $self->param('type') || 'new';
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');

    $self->_default_tool_init(
        tool_args => {
            feeds => $self->init_feeds(
                action => 'presentations_feed',
                task => $self->task,
                target => $gid,
                additional_file => '',
                additional => $tag ? [ $type, $tag ] : [ $type ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        }
    );

    my $preses = $self->_generic_preses(
        tag => $tag,
        group_id => $gid,
        order => $order,
        limit => 10,
        type => $type,
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );

    $self->_fill_first_boxes( $preses, $tag, $title);

    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('presentations_prese'),
            where => 'dicole_presentations_prese.group_id = ?',
            value => [ $gid ],
        } );
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [ $type ] ),
                $tags
            ) ]
        );
    };

    $self->_add_type_filter_box( 0, 5, $type );

    return $self->generate_tool_content;
}

sub featured {
    my ( $self ) = @_;

    my $type = $self->param('type');
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');

    $self->_default_tool_init(
        tool_args => {
            feeds => $self->init_feeds(
                action => 'presentations_feed',
                task => $self->task,
                target => $gid,
                additional_file => '',
                additional => $tag ? [ $type, $tag ] : [ $type ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        }
    );

    my $preses = $self->_generic_preses(
        where => 'dicole_presentations_prese.featured_date > 0',
        tag => $tag,
        group_id => $gid,
        order => 'dicole_presentations_prese.featured_date desc',
        limit => 10,
        type => $type,
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );

    $self->_fill_first_boxes( $preses, $tag, 'Featured media');

    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('presentations_prese'),
            where => 'dicole_presentations_prese.group_id = ? AND ' .
                'dicole_presentations_prese.featured_date > ?',
            value => [ $gid, 0 ],
        } );
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [ $type ] ),
                $tags
            ) ]
        );
    };

    $self->_add_type_filter_box( 0, 5, $type );

    return $self->generate_tool_content;
}

sub _fill_first_boxes {
    my ( $self, $preses, $tag, $title ) = @_;

    $title .= ' tagged with: [_1]' if $tag;

    my $hide_add ||= 1 if $tag;
    $hide_add ||= 1 if ! CTX->request->auth_user_id;
    $hide_add ||= 1 if $self->task ne 'new';
    $hide_add ||= 1 if $self->param('type') ne 'any';
    $hide_add ||= 1 if ! $self->chk_y( 'add' );

    my $list = scalar( @$preses ) ?
        $self->_visualize_prese_list( $preses ) :
        Dicole::Widget::Inline->new( contents => [
            Dicole::Widget::Text->new(
                class => 'presentations_no_preses_found listing_not_found_string',
                text => $self->_msg('No content found.'),
            ),
            $hide_add ? () : (
                ' ',
                Dicole::Widget::Hyperlink->new(
                    class => 'presentations_no_preses_add',
                    content => $self->_msg('Be the first to add one!'),
                    'link' => $self->derive_url(
                        task => 'add',
                        additional => [ ],
                    ),
                ),
            ),
        ] );

    # $self->_msg('Latest media resources');
    # $self->_msg('Latest media resources tagged with: [_1]');
    # $self->_msg('Featured media resources');
    # $self->_msg('Featured media resources tagged with: [_1]');
    # $self->_msg('Best rated media resources');
    # $self->_msg('Best rated media resources tagged with: [_1]');

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( $title, $tag ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );
}

sub _type_hash {
    my ( $self ) = @_;
    return {
        video => $self->_msg('Video'),
        slideshow => $self->_msg('Slideshow'),
        image => $self->_msg('Image'),
        audio => $self->_msg('Audio'),
#         map => $self->_msg('Map'),
#         gizmo => $self->_msg('Gizmo'),
        bookmark => $self->_msg('Document'),
        custom => $self->_msg('Other'),
    };
}

sub _ordered_types {
    my ( $self ) = @_;
    return [
        'video',
        'slideshow',
        'image',
        'audio',
#         'map',
#         'gizmo',
        'bookmark',
        'custom',
    ];
}

sub _add_type_select_box {
    my ( $self, $x, $y, $selected_type ) = @_;
    $self->tool->Container->box_at( $x, $y )->name( $self->_msg( 'Choose type' ) );
    $self->tool->Container->box_at( $x, $y )->add_content(
        [ $self->_prese_type_select_widget( $selected_type ) ]
    );
}

sub _prese_type_select_widget {
    my ( $self, $selected_type ) = @_;

    $selected_type ||= 'custom';
    my @links = ();
    my $type_hash = $self->_type_hash;
    $selected_type = 'custom' unless $type_hash->{ $selected_type };

    for my $type ( @{ $self->_ordered_types } ) {
        next unless $type;
        push @links, Dicole::Widget::Hyperlink->new(
            class => 'presentations_type_select_link ' . $type,
            content => $type_hash->{$type},
            title => $type,
            link => '#',
        );
        push @links, ' ';
    }


    return Dicole::Widget::Container->new( class => 'presentations_type_select', contents => [
        @links,
        Dicole::Widget::Raw->new( raw =>
            '<input type="hidden" id="presentations_type_select_input" name="prese_type" value="' .
                Dicole::Utils::HTML->encode_entities( $selected_type ) .
            '" />',
        ),
    ] );

}

sub _add_type_filter_box {
    my ( $self, $x, $y, $selected_type, $tag ) = @_;

    my @links = ();

    my $type_hash = $self->_type_hash;
    for my $type ( @{ $self->_ordered_types } ) {
        next unless $type;
        push @links, Dicole::Widget::Hyperlink->new(
            class => 'presentations_type_filter_link ' . $type .
                ( ( $selected_type && $type eq lc( $selected_type ) ) ? ' selected' : '' ),
            content => $type_hash->{$type},
            link => $self->derive_url( additional => [ $type , $tag ? ( $tag ) : () ] ),
        );
        push @links, ' ';
    }

    my $box = Dicole::Widget::Container->new(
        class => 'presentations_type_filter_container',
        contents => [ @links ],
    );

    $self->tool->Container->box_at( $x, $y )->name( $self->_msg( 'Filter by type' ) );
    $self->tool->Container->box_at( $x, $y )->add_content(
        [ $box ]
    );
}

sub show {
    my ( $self ) = @_;

    my $pid = $self->param('prese_id');

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    die "security error" unless $prese && $prese->group_id == $self->param('target_group_id');

    $self->_default_tool_init;
    $self->tool->add_comments_widgets;

    unless ( $prese ) {
        $self->tool->add_message(
            MESSAGE_ERROR, $self->_msg('No such content.')
        );

        $self->redirect( $self->derive_url( task => 'new', additional => []));
    }

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object => $prese,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $prese->group_id,
        act => 'show',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    my $right_to_edit = $self->_current_user_can_edit_object( $prese );
    my $a = CTX->lookup_object('attachment')->fetch( $prese->attachment_id );

    my $simple_embed = $self->_embed_for_object( $prese, $a, 'simple', 'include_host' );
    my $embed_html = Dicole::Utils::HTML->encode_entities( $self->_msg('Embed') ) .': <input class="js_focus_select_all" type="text" size="10" value="'. Dicole::Utils::HTML->encode_entities( $simple_embed ) .'" />';

    my $tags = eval { CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
        object => $prese,
        group_id => $self->param('target_group_id'),
        user_id => 0,
    } ) };

    my $bookmark_action = CTX->lookup_action('bookmarks_api')->e( get_user_bookmark_action_for_object => {
        object => $prese,
        creator_id => CTX->request->auth_user_id,
    } );

    my $content = Dicole::Widget::FancyContainer->new(
        class => 'presentations_prese_show_container',
        contents => [
            Dicole::Widget::Container->new( class => 'presentations_prese_show_inner_container', contents => [
                Dicole::Widget::Container->new(
                    class => 'presentations_prese_show_embed',
                    contents => [ Dicole::Widget::Raw->new( raw => $self->_embed_for_object( $prese ) ) ],
                ),
                $self->_rating_widget_for_object( $prese, {
                    rating_disabled => $self->chk_y('rate') ? 0 : 1,
                } ),
                Dicole::Widget::Container->new(
                    class => 'presentations_prese_show_description',
                    contents => [ Dicole::Widget::Raw->new( raw => $prese->description ) ],
                ),
                $self->_fake_tag_list_widget( $prese, $tags ),
                Dicole::Widget::Horizontal->new( contents => [
                    ( $bookmark_action && $bookmark_action eq 'add' ) ? (
                        Dicole::Widget::Hyperlink->new(
                            content => $self->_msg('Bookmark'),
                            link => $self->derive_url( task => 'add_bookmark' ),
                        ),
                        ( ' | ' ),

                    ) : (),
                    ( $bookmark_action && $bookmark_action eq 'remove' ) ? (
                        Dicole::Widget::Hyperlink->new(
                            content => $self->_msg('Unbookmark'),
                            link => $self->derive_url( task => 'remove_bookmark' ),
                        ),
                        ( ' | ' ),

                    ) : (),
                    ( CTX->request->auth_user_id && $a ) ? (
                        Dicole::Widget::Hyperlink->new(
                            content => $self->_msg('Open'),
                            link => Dicole::URL->from_parts(
                                action => 'presentations', task => 'attachment_original', target => $a->group_id,
                                domain_id => $prese->domain_id, additional => [ $a->id, $prese->id || 0, $a->filename ]
                            ),
                        ),
                        ( ' | ' ),
                        Dicole::Widget::Hyperlink->new(
                            content => $self->_msg('Download'),
                            link => Dicole::URL->from_parts(
                                action => 'presentations', task => 'attachment_download', target => $a->group_id,
                                domain_id => $prese->domain_id, additional => [ $a->id, $prese->id || 0, $a->filename ]
                            ),
                        ),
                        ( ' | ' ),
                    ) : (),
                    $right_to_edit ? Dicole::Widget::Hyperlink->new(
                        content => $self->_msg('Edit'),
                        link => $self->derive_url( task => 'edit' ),
                    ) : (),
                    $right_to_edit ? ( ' | ' ) : (),
                    $right_to_edit ? Dicole::Widget::Hyperlink->new(
                    	content => $self->_msg('Delete'),
                    	link => $self->derive_url( task => 'delete' ),
                    ) : (),
                    $self->chk_y('admin') ? (
                         $right_to_edit ? ( ' | ' ) : (),
                         $prese->featured_date ?
                            Dicole::Widget::Hyperlink->new(
                                link => $self->derive_url( task => 'unfeature' ),
                                content => $self->_msg( 'Unfeature' ),
                            )
                            :
                            Dicole::Widget::Hyperlink->new(
                                link => $self->derive_url( task => 'feature' ),
                                content => $self->_msg( 'Feature' ),
                            ),
                    ) : (),
                    CTX->request->auth_user_id ? (
                        $right_to_edit ? ( ' | ' ) : (),
                        Dicole::Widget::Raw->new( raw => $embed_html ),
                    ) : (),
                ] ),
            ] ),
        ],
    );

    my $type_hash = $self->_type_hash;

    my $cuser = CTX->lookup_object('user')->fetch( $prese->creator_id );
    my $creator = $cuser ? $cuser->first_name . ' ' . $cuser->last_name : $self->_msg('Unknown');

    my $date = $self->_date_string_for_object( $prese );

    my $duration = $prese->duration;
    if ( $prese->prese_type eq 'slideshow' && $duration && $duration =~ /^\s*\d+\s*$/ ) {
        $duration = $self->_msg( '[_1] slides', $duration );
    }

    my $info = Dicole::Widget::Columns->new(
        class => 'presentations_prese_info',
        left => Dicole::Widget::Text->new(
            class => 'presentations_prese_info_type ' . $prese->prese_type,
            text => $type_hash->{ $prese->prese_type } || $type_hash->{custom} || $prese->prese_type,
        ),
        right => Dicole::Widget::Vertical->new(
            class => 'presentations_prese_info_right',
            contents => [
                $duration ? (
                    Dicole::Widget::Text->new(
                        class => 'presentations_prese_info_duration ' . $prese->prese_type,
                        text => $self->_msg( 'Length [_1]', $duration ),
                    )
                ) : (),
                $prese->presenter ? (
                    Dicole::Widget::Text->new(
                        class => 'presentations_prese_info_presenter',
                        text => $self->_msg( 'Presented by [_1]', $prese->presenter ),
                    )
                ) : (),
                Dicole::Widget::Inline->new(
                    class => 'presentations_prese_info_uploader',
                    contents => [
                        Dicole::Widget::Text->new(
                            class => 'presentations_prese_info_uploader_text',
                            text => $self->_msg( 'Uploaded by' ),
                        ),
                        ' ',
                        $cuser ? Dicole::Widget::Hyperlink->new(
                            class => 'presentations_prese_info_uploader_link',
                            content => $creator,
                            link => $self->derive_url(
                                action => 'networking',
                                task => 'profile',
                                additional => [ $cuser->id ],
                            ),
                        )
                        :
                        Dicole::Widget::Text->new(
                            class => 'presentations_prese_info_uploader_anon',
                            text => $creator,
                        ),
                   ]
                ),
                Dicole::Widget::Text->new(
                    class => 'presentations_prese_info_date',
                    text => $self->_msg( 'on [_1]', $date ),
                ),
            ],
        ),
        left_class => 'presentations_prese_info_columns_left',
        left_td_class => 'presentations_prese_info_columns_td_left',
        right_class => 'presentations_prese_info_columns_right',
        right_td_class => 'presentations_prese_info_columns_td_right',
    );

    my $comments = Dicole::Widget::Container->new(
        id => 'comments',
        class => 'presentations_prese_comments',
        contents => [
            CTX->lookup_action('commenting')->execute( get_comment_tree_widget => {
                object => $prese,
                comments_action => 'presentations_json',
                input_anchor => 'prese_comments_' . $prese->id,
                input_hidden => 0,
                start_writing_string => $self->_msg('Add a comment'),
                submit_comment_string => $self->_msg('Submit comment'),
                write_comment_string => $self->_msg('Write your comment:'),
                comment_content_string => $self->_msg('Comment content'),
                right_to_remove_comments => $self->chk_y('admin'),

                disable_commenting => $self->chk_y('comment') ? 0 : 1,
                requesting_user_id => CTX->request->auth_user_id,
                requires_approval => $self->_commenting_requires_approval,
                right_to_publish_comments =>
                    $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
                } ),
        ]
    );

    unless ( $self->param('domain_id') == 70 ) {
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
        if ( $self->param('domain_name') =~ /sanako|languagepoint|work\-dev/ ) {
            my $filtered = CTX->request->param('filtered');

            $self->tool->Container->box_at( 0, 0 )->add_content(
                [
                    $filtered ? (
                        Dicole::Widget::Hyperlink->new(
                            content => $self->_msg('Back to search results'),
                            'link' => $self->derive_url( task => 'detect', additional => [ $filtered ], params => { amount => 60 } ),
                        )
                    )
                    : (),
                    Dicole::Widget::Hyperlink->new(
                        content => $self->_msg('Browse materials'),
                        'link' => $self->derive_url( task => 'detect', additional => [] ),
                    )
                ]
            );
        }
        else {
            $self->tool->Container->box_at( 0, 0 )->add_content(
                [ $self->tool->get_tablink_widgets ]
            );
        }
    }

    my $share_this_box = CTX->lookup_action('awareness_api')->e( create_share_this_box => {} );
    if ( $share_this_box ) {
        $self->tool->Container->box_at( 0, 1 )->name( $share_this_box->{name} );
        $self->tool->Container->box_at( 0, 1 )->content( $share_this_box->{content} );
        $self->tool->Container->box_at( 0, 1 )->class( $share_this_box->{class} );
    }

    if ( my $box = $self->_create_pages_box( $tags ) ) {
        $self->tool->Container->box_at( 0, 2 )->name( $box->{name} );
        $self->tool->Container->box_at( 0, 2 )->content( $box->{content} );
        $self->tool->Container->box_at( 0, 2 )->class( $box->{class} );
    }


    if ( my $box = $self->_create_bookmarkers_box( $prese ) ) {
        $self->tool->Container->box_at( 0, 3 )->name( $box->{name} );
        $self->tool->Container->box_at( 0, 3 )->content( $box->{content} );
        $self->tool->Container->box_at( 0, 3 )->class( $box->{class} );
    }

    $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Content info') );
    $self->tool->Container->box_at( 0, 4 )->add_content(
        [ $info ]
    );

    $self->tool->Container->box_at( 1, 0 )->name( $prese->name );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $content ]
    );

    my $comment_count = CTX->lookup_action('commenting')->execute( 'get_comment_count', {
		object => $prese
	} ) || 0;

	if($comment_count == 0) {
		$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('No comments') );
	} elsif($comment_count == 1) {
		$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('One comment') );
	} elsif($comment_count > 1) {
		$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('[_1] comments', $comment_count) );
	}

    $self->tool->Container->box_at( 1, 1 )->add_content(
        [ $comments ]
    );

    $self->tool->tool_title_suffix( $prese->name );

    # NOTE: this has to be at least 200x200 or it wont be recognized - funny eh? ;)
    my $big_image = $self->_get_presentation_image( $prese );

    eval { CTX->lookup_action('awareness_api')->e( add_open_graph_properties => {
        title => $self->tool->tool_title_suffix,
        description => Dicole::Utils::HTML->html_to_text( $prese->description ),
        image => $big_image,
    } ) };

    return $self->generate_tool_content;
}

sub add_bookmark {
    my ( $self ) = @_;

    my $pid = $self->param('prese_id');

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    die "security error" unless $prese && $prese->group_id == $self->param('target_group_id');
    die "security error" unless CTX->request->auth_user_id;

    CTX->lookup_action('bookmarks_api')->e( add_user_bookmark_for_object => {
        object => $prese,
        creator_id => CTX->request->auth_user_id,
    } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg('Bookmark added succesfully.')
    );

    return $self->redirect( $self->_show_url( $prese ) );
}

sub remove_bookmark {
    my ( $self ) = @_;

    my $pid = $self->param('prese_id');

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    die "security error" unless $prese && $prese->group_id == $self->param('target_group_id');
    die "security error" unless CTX->request->auth_user_id;

    CTX->lookup_action('bookmarks_api')->e( remove_user_bookmark_for_object => {
        object => $prese,
        creator_id => CTX->request->auth_user_id,
    } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg('Bookmark removed succesfully.')
    );

    return $self->redirect( $self->_show_url( $prese ) );
}

sub _create_bookmarkers_box {
    my ( $self, $prese ) = @_;

    my $return = eval {
        my $html = CTX->lookup_action('bookmarks_api')->e( get_sidebar_html_for_object_bookmarkers => {
            object => $prese,
        } );
        if ( $html ) {
            return {
                name => $self->_msg('Who has bookmarked this'),
                content => Dicole::Widget::Raw->new( raw => $html ),
                class => 'prese_bookmarkers_box'
            };
        }
    };
    if ( $@ ) {
        get_logger(LOG_APP)->error($@);
    }

    return $return;
}

sub _create_pages_box {
    my ( $self, $tags ) = @_;
    my $return = eval {
        my $box_html = CTX->lookup_action('wiki_api')->e(
            get_sidebar_list_html_for_pages_with_any_of_tags => {
                group_id => $self->param('target_group_id'),
                tags => $tags,
            }
        );
        if ( $box_html ) {
            return {
                name => $self->_msg('Related pages'),
                content => Dicole::Widget::Raw->new( raw => $box_html ),
                class => 'prese_wiki_box'
            };
        }
    };
    if ( $@ ) {
        get_logger(LOG_APP)->error($@);
    }

    return $return;
}

# TODO: Create a widget, used also in other packages
sub _fake_tag_cloud_widget {
    my ($self, $prefix, $tags, $limit ) = @_;

    return Dicole::Widget::Text->new( text => $self->_msg('No tags.') ) unless @$tags;

    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => $prefix,
        limit => $limit,
    );
    $cloud->add_weighted_tags_array( $tags );
    return $cloud;
}

sub _process_attachment_upload {
    my ( $self, $object, $target ) = @_;

    my $upload_obj = CTX->request->param('upload_attachment') ? CTX->request->upload( 'upload_attachment' ) : undef;
    if ( ref( $upload_obj ) ) {
        my $a = CTX->lookup_action('attachment')->execute( store_from_request_upload => {
            object => $target || $object,
            upload_name => 'upload_attachment',
            group_id => $self->param('target_group_id'),
            user_id => 0,
            owner_id => CTX->request->auth_user_id,
        } );
        $object->attachment_id( $a->id );

        my $image_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_image', target => $a->group_id,
            additional => [ $a->id, $a->filename . '.jpg' ]
        );

        my $scribd_api_key = CTX->server_config->{dicole}->{scribd_api_key};
        if ( 0 && $scribd_api_key && $a->filename =~ /\.(pdf|txt|ps|rtf|epub|odt|odp|ods|odg|odf|sxw|sxc|sxi|sxd|doc|ppt|pps|xls|docx|pptx|ppsx|xlsx|tif|tiff)$/i ) {
        	my $file_extension = $1;
        	my $scribd_id = $object->{scribd_id};
			if($scribd_id) {
				my $scribd_xml = Dicole::Utils::HTTP->post(
					'http://api.scribd.com/api',
					{
						method => 'docs.delete',
						api_key => $scribd_api_key,
						doc_id => $scribd_id
					}
				);
			}

        	my $file_url = Dicole::URL->from_parts(
        		action => 'presentations', task => 'attachment_original', target => $a->group_id,
            	additional => [ $a->id, $object->id || 0, $a->filename ],
            	params => { dic => Dicole::Utils::User->permanent_authorization_key(CTX->request->auth_user_id) }
            );

            $file_url = Dicole::URL->get_server_url(443) . $file_url;

            my $scribd_xml = Dicole::Utils::HTTP->post(
            	'http://api.scribd.com/api',
            	{
            		method => 'docs.uploadFromUrl',
            		api_key => $scribd_api_key,
            		url => $file_url,
            		doc_type => $file_extension,
            		access => 'private'
            	}
            );

            my $xml_parser = new XML::Simple;
            my $scribd = $xml_parser->XMLin($scribd_xml);

            if($scribd->{stat} eq 'ok') {
            	my $scribd_settings_xml = Dicole::Utils::HTTP->post(
            		'http://api.scribd.com/api',
					{
						method => 'docs.getSettings',
						doc_id => $scribd->{doc_id},
						api_key => $scribd_api_key
					}
				);

				my $scribd_settings = $xml_parser->XMLin($scribd_settings_xml);

            	$object->scribd_id(Dicole::Utils::Text->ensure_utf8($scribd->{doc_id}));
            	$object->scribd_key(Dicole::Utils::Text->ensure_utf8($scribd->{access_key}));
            	$object->scribd_fail(0);

                my $thumbnail_url = $scribd_settings->{thumbnail_url};

                # NOTE: we need a bigger thumbnail for social media sites..
                eval {
                    my $scribd_thumbnail_response_xml = Dicole::Utils::HTTP->post( 'http://api.scribd.com/api' => {
                            method => 'thumbnail.get',
                            width => 408,
                            height => 228,
                            doc_id => $scribd->{doc_id},
                            api_key => $scribd_api_key
                        } );

                    my $scribd_thumbnail_response = $xml_parser->XMLin($scribd_thumbnail_response_xml);

                    if ( my $t = $scribd_thumbnail_response->{thumbnail_url} ) {
                        $thumbnail_url = $t;
                    }
                };
                get_logger(LOG_APP)->error( $@ ) if $@;

                $thumbnail_url =~ s/^\s+|\s+$//g;
                $object->image(Dicole::Utils::Text->ensure_utf8($thumbnail_url));
            }
            else {
            	$object->set('scribd_id', undef);
            	$object->set('scribd_key', undef);
            	$object->scribd_fail($object->scribd_fail + 1);
            }

            $object->prese_type( $self->_guess_prese_type_from_filename( $a->filename ) );
        }
        elsif ( $a->mime =~ /image/ ) {
            $object->prese_type('image');
            $object->image( $image_url );
        }
        elsif ( $a->mime =~ /video/ ) {
            $object->prese_type('video');
            $object->image( $image_url );
        }
        elsif ( $a->mime =~ /audio/ ) {
            $object->prese_type('audio');
        }
        else {
            $object->prese_type('custom');
        }
    }
    else {
        $object->attachment_id( CTX->request->param('attachment_id') ) if CTX->request->param('attachment_id');
    }
}

# TODO: use a framework - for now use profile pictures directory with "seed_image_" -prefix
sub _process_image_upload {
    my ( $self, $presentation, $target ) = @_;

    return unless CTX->request->param('upload_image');

    my $upload_obj = CTX->request->upload( 'upload_image' );

    return unless ref $upload_obj;

    my $attachment = CTX->lookup_action('attachment')->execute(store_from_request_upload => {
        object => $target || $presentation,
        upload_name => 'upload_image',
        group_id => $presentation->group_id,
        user_id => 0,
        owner_id => CTX->request->auth_user_id,
        domain_id => $presentation->domain_id
    } );

    $presentation->image($attachment->id);

    return 1;
}

sub _create_object_image_path {
    my ( $self, @parts ) = @_;
    return CTX->lookup_directory( 'dicole_profilepics' ) . '/' .
        $self->_create_object_image_filename( @parts );
}

sub _create_object_image_filename {
    my ( $self, $object, $random, $suffix ) = @_;
    return 'prese_image_' . ( $object->id || 0 ) . "_$random.$suffix";
}

sub _check_magick_error {
    my ( $self, $error ) = @_;
    return undef unless $error;
    $error =~ /(\d+)/;
    # Status code less than 400 is a warning
    $self->log( 'error',
        "Image::Magick returned status $error while resizing image in presentations package"
    );
    if ( $1 >= 400 ) {
        return 1;
    }
    return undef;
}


sub _fill_object_from_url {
    my ( $self, $object, $url ) = @_;

    if ( $url =~ /^https?:\/\/(www\.)?youtube.com\/.+/ ) {
        return $self->_fill_object_from_youtube( $object, $url );
    }
    if ( $url =~ /^https?:\/\/(www\.)?slideshare.net\/.+/ ) {
        return $self->_fill_object_from_slideshare( $object, $url );
    }
    if ( $url =~ /^https?:\/\/(www\.)?share.ovi.com\/.+/ ) {
        return $self->_fill_object_from_ovi( $object, $url );
    }
    die $self->_msg('Could not process URL. Sorry.');
}

sub _fill_object_from_ovi {
    my ( $self, $object, $url ) = @_;

    my ($albumname, $medianame) =  $url =~  /^https?:\/\/share\.ovi\.com\/media\/(.+?)\/(.+?\.\d+)/;

    $object->url( $url );
    $object->creation_date( time );

    my $embed_url = 'http://share.ovi.com/js/html/embed.aspx?media=' . $medianame . '&albumname=' . $albumname;
    my $thumbnail_url = 'http://share.ovi.com/search/' . $medianame;
    my $display_content = '';
    my $embed_content = '';
    my $thumbnail_content = '';
    for(1..3) {
        $display_content ||= eval { $self->_fetch_url_content($url) };
        $embed_content ||= eval { $self->_fetch_url_content($embed_url) };
        $thumbnail_content ||= eval { $self->_fetch_url_content($thumbnail_url) };
    }

    eval {
        my $display_tree = Dicole::Utils::HTML->safe_tree($display_content);
        my $name = $self->_first_down($display_tree, {_tag => 'div', class => 'breadcrumblinks bigtxt'});
        $object->name($self->_content_html($name) || ());
        my $description = $self->_first_down($display_tree, {_tag => 'span', id => 'M_c_uidescription_uilabel'});
        $object->description($self->_content_html($description) || ());
        my $presenter = $self->_first_down($display_tree, {_tag => 'span', id => 'M_uimainnav_uiprofile_uimemberitem_uidisplayname'});
        $object->presenter($self->_content_html($presenter) || ());

        my $thumbnail_tree = Dicole::Utils::HTML->safe_tree($thumbnail_content);
        my $thumbnail = $self->_first_down($thumbnail_tree, {_tag => 'img', id => 'M_c_uimedia_uir_ctl00_uimedia_uimediaimage'});
        $object->image($self->_attr_value($thumbnail, 'src') || ());

        my $embed_tree = Dicole::Utils::HTML->safe_tree($embed_content);
        my $embed = $self->_first_down($embed_tree, {_tag => 'textarea', id => 'uicopytext'});
        my $embed_html = $self->_content_html($embed) || ();
        $object->embed($embed_html);

        $object->prese_type('image');
        $object->prese_type('video') if $embed_html =~ /http:\/\/share\.ovi\.com\/flash\/player\.aspx/;
        $object->prese_type('audio') if $embed_html =~ /http:\/\/share\.ovi\.com\/flash\/audioplayer\.aspx/;
    };

    $self->_force_utf8_object( $object );
}

sub _fill_object_from_youtube {
    my ( $self, $object, $url ) = @_;

    $object->url( $url );
    $object->prese_type( 'video' );
    $object->creation_date( time );
#     $object->image('http://img.youtube.com/vi/'. $key .'/0.jpg');
#
#     my $search_url = 'http://youtube.com/results?search_query=' . $key;
#     my $watch_url = 'http://www.youtube.com/watch?v=' . $key;
#     my $search_page = '';
#     my $watch_page = '';
#     for (1..3) {
#         $search_page ||= eval { $self->_fetch_url_content( $search_url ) };
#         $watch_page ||= eval { $self->_fetch_url_content( $watch_url ) };
#     }
#
#     eval {
#         my ( $duration ) = $search_page =~ qr{<div class="runtime">(.{4,8})</div>};
#         $object->duration( $duration || () );
#     };
#
#     eval {
#         my $watch_tree = Dicole::Utils::HTML->safe_tree( $watch_page );
#
#         my $embed = $self->_first_down( $watch_tree, { _tag => 'input', id => 'embed_code' } );
#         $object->embed( $self->_attr_value( $embed, 'value' ) || () );
#
#         my $video_details = $self->_first_down( $watch_tree, { _tag => 'div', id => "watch-video-details-inner" } );
#         my $desc_div = $self->_first_down( $video_details, {_tag => 'div', class => 'expand-content' } );
#         my $desc = $self->_first_down( $desc_div, {_tag => 'div', class => 'watch-video-desc' } );
#         $object->description( $self->_content_html( $desc ) || () );
#
#         my $meta_title = $self->_first_down( $watch_tree, { _tag => 'meta', name => "title" } );
#         $object->name( $self->_attr_value( $meta_title, 'content' ) || () );
#
#         my $watch_stats = $self->_first_down( $watch_tree, { _tag => 'div', id => "watch-channel-stats" } );
#         my $presenter = $self->_first_down( $watch_stats, { _tag => 'a' } );
#         $object->presenter( $self->_content_html( $presenter ) || () );
#     };
	my ($key) = $url =~ /watch(?:\#\!|\?)v=([\w\-\d]{11})/;
	my $raw_videodata = Dicole::Utils::HTTP->get("http://gdata.youtube.com/feeds/api/videos/$key?alt=json");
	my $videodata = Dicole::Utils::JSON->decode($raw_videodata);

	my $entry = $videodata->{entry};

	my $image = $entry->{'media$group'}->{'media$thumbnail'}[0]->{url};

	my $total_seconds = $entry->{'media$group'}->{'yt$duration'}->{seconds};

	my $minutes = int($total_seconds / 60);
	my $seconds = $total_seconds % 60;

	my $media_url = '';
	my $media_type = '';
	for my $media ( @{$entry->{'media$group'}->{'media$content'}} ) {
		if ( $media->{'yt$format'} eq '5' ) {
			$media_url = $media->{url};
			$media_type = $media->{type};
		}
	}

#	my $embed = '<object width="425" height="350"><param name="movie" value="'. $media_url .'"></param><embed src="'. $media_url .'" type="'. $media_type .'" width="425" height="350"></embed></object>';
	my $embed = '<iframe width="425" height="350" src="https://www.youtube.com/embed/'.$key.'" frameborder="0" allowfullscreen></iframe>';
	my $description = $entry->{'media$group'}->{'media$description'}->{'$t'};
	my $name = $entry->{'media$group'}->{'media$title'}->{'$t'};
	my $presenter = $entry->{author}[0]->{name}->{'$t'};

	$object->image($image);
	$object->duration($minutes .':'. $seconds);
	$object->embed($embed);
	$object->description($description);
	$object->name($name);
	$object->presenter($presenter);

    $self->_force_utf8_object( $object );
}

sub _fill_object_from_slideshare {
    my ( $self, $object, $url ) = @_;

    $object->url( $url );
    $object->prese_type( 'slideshow' );
    $object->creation_date( time );

    my $xml = undef;
    for (1..3) {
        next if $xml;
        my $time = time;
        my $ssuri = "http://www.slideshare.net/api/2/get_slideshow";
        $ssuri .= '?slideshow_url=' . URI::Escape::uri_escape( $url );
        $ssuri .= '&detailed=1';
        $ssuri .= '&api_key=' . CTX->server_config->{dicole}{slideshare_api_key};
        $ssuri .= '&ts=' . $time;
        $ssuri .= '&hash=' . Digest::SHA::sha1_hex( CTX->server_config->{dicole}{slideshare_api_secret} . $time );
        my $result = eval { Dicole::Utils::HTTP->get( $ssuri ) };
        $xml = eval{ XML::Simple->new->XMLin( $result ) };
    }
    eval {
        $object->name( $xml->{Title} );
        $object->image( $xml->{ThumbnailURL} || () );
        $object->description( '<p>' .  $xml->{Description} . '</p>' );
        $object->presenter( $xml->{Username} || () );
        $object->duration( $xml->{NumSlides} || () );
        $object->embed( $xml->{Embed} || () );
    };

    $self->_force_utf8_object( $object );
}

sub _force_utf8_object {
    my ( $self, $object ) = @_;

    for my $field ( qw/
        name
        image
        description
        presenter
        duration
        embed
    / ) {
        my $value = $object->get( $field );
        if ( $value ) {
            $object->set( $field, Dicole::Utils::Text->ensure_utf8( $value ) );
        }
    }
}

sub _attr_value {
    my ( $self, $object, $attr ) = @_;

    return () unless $object && ref( $object );
    return $object->attr( $attr ) || '';
}

sub _content_html {
    my ( $self, $object ) = @_;

    return undef unless $object && ref( $object );
    my $contents =  $object->content_array_ref;

    my @htmls = map { ref( $_ ) ? $_->as_XML() : $_ } @$contents;
    return join '', @htmls;
}

sub _content_text {
    my ( $self, $object ) = @_;

    return undef unless $object && ref( $object );

    my $html = $self->_content_html( $object );

    return Dicole::Utils::HTML->html_to_text( $html );
}

sub _first_down {
    my ( $self, $root, $attr ) = @_;
    return undef unless ref( $root );
    $attr ||= {};
    my @elems = $root->look_down( %$attr );
    return shift @elems;
}

sub _fetch_url_content {
    my ( $self, $url ) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->agent( 'Dicole' );
    $ua->timeout( 10 );

    my $response = $ua->get( $url );

    unless ( $response->is_success ) {
        die $response->status_line;
    }

    return $response->content;
}


# HERE COMES THE NEW CODE! :D

sub _get_valid_attachment {
    my ( $self ) = @_;

    my $a = eval { CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') ) };
    unless ( $a && $a->group_id == $self->param('target_group_id') ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        return $self->redirect( $self->derive_url(
            task => 'browse',
            additional => [],
        ) );
    }

    return $a;
}

sub attachment_original {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object_id => $self->param('prese_id'),
        object_type => scalar( CTX->lookup_object('presentations_prese') ),
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $self->param('target_group_id'),
        act => 'download',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
    } );
}

sub attachment_view {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
    } );
}

sub attachment_scribd {
    my ( $self ) = @_;

    die "security error" unless CTX->request->param('sec') eq $self->_generate_scribd_sec( $self->param('attachment_id') );

    my $a = eval { CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') ) };

    die "security error" unless $a;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
    } );
}

sub attachment_box {
    my ( $self ) = @_;

    die "security error" unless CTX->request->param('sec') eq $self->_generate_scribd_sec( $self->param('attachment_id') );

    my $a = eval { CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') ) };

    die "security error" unless $a;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
    } );
}

sub attachment_download {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object_id => $self->param('prese_id'),
        object_type => scalar( CTX->lookup_object('presentations_prese') ),
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $self->param('target_group_id'),
        act => 'download',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    CTX->lookup_action('attachment')->execute( serve => {
        download => 1,
        attachment => $a,
    } );
}


sub attachment_image {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment
        or get_logger(LOG_APP)->error("No valid attachment");

    my $size = $self->param('image_width');
    $size = '320' unless $size && $size =~ /^\d+$/;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => 1,
        max_width => $size,
    } );
}

sub attachment_embed {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        embeddable_video => 1,
    } );
}

sub attachment_embed_mp4 {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        embeddable_video => 1,
        video_type => 'mp4',
    } );
}

sub attachment_embed_ogv {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        embeddable_video => 1,
        video_type => 'ogv',
    } );
}

sub attachment_embed_mp3 {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        embeddable_audio => 1,
    } );
}

sub attachment_embed_ogg {
    my ( $self ) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        embeddable_audio => 1,
        audio_type => 'ogg',
    } );
}

# NEW browse interface

sub recent {
    my ( $self ) = @_;

    return $self->_new_generic_listing(
        'dicole_presentations_prese.creation_date desc',
    );
}

sub _new_generic_listing {
    my ( $self, $order ) = @_;

    my $tag = $self->param('tag') || '';
    my $tags = $tag ? [ split( /\s*,\s*/, $tag ) ] : [];

    $self->_new_fill_first_boxes( $tags, $order,
        { tool_args => {
            feeds => $self->init_feeds(
                action => 'presentations_feed',
                task => $self->task,
                target => $self->param('target_group_id'),
                additional_file => '',
                additional => $tag ? [ $tag ] : [],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        } },
    );

    return $self->generate_tool_content;
}

sub _new_fill_first_boxes {
    my ( $self, $tags, $order, $tool_params ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $gid = $self->param('target_group_id');

    my $amount = int( CTX->request->param('amount') ) || 30;
    $amount = 30 if $amount > 100 || $amount < 1;

    my $state = { order => $order, tags => $tags ? $tags : [] };
    my $info = $self->_fetch_state_prese_list_info( $gid, $domain_id, $state, $amount );

    $state = $info->{state};
    my $links = $self->_fetch_state_prese_filter_suggestions( $gid, $domain_id, $state );

    my $params = {
        keywords => [ map { { name => $_ } } @{ $state->{tags} || [] } ],
        suggestions => $links,
        objects => $info->{object_info_list},
        result_count => $info->{count},
        end_of_pages => $info->{end_of_pages},
        tag_complete_url => $self->derive_url( action => 'presentations_json', task => 'tag_completion', target => $self->param('target_group_id') ),
        go_url_base => $self->derive_url( action => 'presentations', task => 'init_tag_search', target => $self->param('target_group_id') ),
    };

    my $globals = {
        presentations_materials_state => Dicole::Utils::JSON->encode( $state ),
        presentations_keyword_change_url => $self->derive_url(
            action => 'presentations_json', task => 'keyword_change', additional => []
        ),
        presentations_more_materials2_url => $self->derive_url(
            action => 'presentations_json', task => 'more_materials2', additional => []
        ),
        presentations_end_of_pages => $info->{end_of_pages},
        presentations_tag_complete_url => $self->derive_url( action => 'presentations_json', task => 'tag_completion', target => $self->param('target_group_id') ),
    };

    $self->_default_tool_init(
        %$tool_params,
        rows => 1, cols => 1,
        globals => $globals,
    );

    $self->tool->Container->box_at( 0, 0 )->name( '' );
    $self->tool->Container->box_at( 0, 0 )->class( 'presentations_list' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_presentations::main_list' } )
        ) ]
    );
}

# NON-USED NEW CODE which is older than the previous

sub browse {
    my ( $self ) = @_;

    my %params = ();

    push @{ $params{head_widgets} }, (
        @{ CTX->lookup_action('tinymce_api')->execute( get_head_widgets => { type => 'comments' } ) },
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.presentations");' ),
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.comments");' ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_presentations.css' ),
    );

    my $listing = $self->param('listing') || 'new';
    my $type = $self->param('type_filter') || 'any';
    my $tag = $self->param('tag');
    my $search = CTX->request->param('search');

    if ( defined( CTX->request->param('media-search') ) ) {
        my $kw = CTX->request->param('media-search');
        return $self->redirect( $self->derive_url(
            additional => [], params => { $kw ? ( search => $kw ) : ()  },
        ) );
    }

    my $preses = $self->_generic_preses(
        group_id => $self->param('target_group_id'),
        listing => $listing,
        type => $type,
        tag => $tag,
        search => $search,
    );

    my @presedata = map { {
        id => $_->id,
        json_url => $self->derive_url(
            action => 'presentations_json', task => 'presentation_info', additional => [ $_->id ]
        ),
        title => $_->name,
        by_author => $self->_msg( "by [_1]", $_->presenter || Dicole::Utils::User->short_name( $_->creator_id ) ),
        type => $self->_simple_type_for_object( $_ ),
        duration => $self->_duration_string_for_object( $_ ) || '?',
        rating => $_->rating,
        rating_simple => $self->_simple_rating_for_object( $_ ),
        image => CTX->lookup_action('thumbnails_api')->execute(create => {url => $self->_get_presentation_image( $_ ), width => 209, height => 115}),
        comments => $self->_msg( "[_1] comments", $self->_comment_count_for_object( $_ ) ),
        description => $self->_short_description_for_object( $_ ),
        date => $self->_date_string_for_object( $_ ),
    } } @$preses;

    my @pages = ();
    my $count = 0;
    my $pageitems = 8;
    for my $pd ( @presedata ) {
        my $page = int( $count / $pageitems );
        if ( ! $pages[ $page ] ) {
            $pages[ $page ] = { number => ( $page + 1 ), presentations => [ $pd ] };
        }
        else {
            push @{ $pages[ $page ]{presentations} }, $pd;
        }
        $count++;
    }

    my $pagecount = scalar( @pages );
    for my $page ( @pages ) {
        # these are "reversed" as they tell for which this is prev or next
        my $prev = $page->{number} + 1;
        $prev = 1 if $prev > $pagecount;
        $page->{prev_number} = $prev;

        my $next = $page->{number} - 1;
        $next = $pagecount if $next < 1;
        $page->{next_number} = $next;
    }

    $params{pages} = \@pages;

    my @tag = $tag ? ( $tag ) : ();

    $params{selected_listing} = $listing;
    $params{selected_type} = $type;
    $params{selected_tag} = $tag;

    $params{new_link} = $self->derive_url( additional => ['new', 'any', @tag ] );
    $params{best_link} = $self->derive_url( additional => ['best', 'any', @tag ] );
    $params{featured_link} = $self->derive_url( additional => ['featured', 'any', @tag ] );

    $params{video_link} = $self->derive_url( additional => [ 'new', 'video', @tag ] );
    $params{slideshow_link} = $self->derive_url( additional => [ 'new', 'slideshow', @tag ] );
    $params{image_link} = $self->derive_url( additional => [ 'new', 'image', @tag ] );
    $params{other_link} = $self->derive_url( additional => [ 'new', 'other', @tag ] );

    $params{add_media_link} = $self->derive_url( task => 'add', additional => [] ) if $self->chk_y( 'add' );
    $params{current_search} = $search;

    $params{initial_open_template} = $self->derive_url(
        action => 'presentations_json', task => 'presentation_info', additional => ['---id---']
    );

    $params{messages} = $self->_get_messages_array;

    return $self->generate_solo_content(
        template_params => \%params,
        template_name => 'dicole_presentations::browse',
        title => $self->_msg('Media'),
    );
}

sub _new_add_guide {
    my ( $self ) = @_;

    my %params = ();
    push @{ $params{head_widgets} }, (
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.presentations");' ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_presentations.css' ),
    );


    $params{back_link} = $self->derive_url( task => 'browse' );

    $params{messages} = $self->_get_messages_array;

    return $self->generate_solo_content(
        template_params => \%params,
        template_name => 'dicole_presentations::add',
        title => $self->_msg('Media'),
    );
}

sub _get_messages_array {
    my ( $self ) = @_;

    my $messages = Dicole::MessageHandler->get_messages;
    Dicole::MessageHandler->clear_messages;

    return $messages;
}

sub image {
    my ($self) = @_;

    my $pid = $self->param('prese_id');
    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    unless ($prese) {
        get_logger(LOG_APP)->error("Failed to fetch valid image for presentation '$pid'");
        return;
    }

    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $prese->image,
        thumbnail => 1,
    } );
}

sub preview_image {
    my ($self) = @_;

    my $a = $self->_get_valid_attachment;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => 1,
    } );
}

1;
