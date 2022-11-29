package OpenInteract2::Action::DicoleWikiPopup;

use strict;
use base qw( OpenInteract2::Action::DicoleWikiCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Widget::LinkButton;
use Dicole::Widget::Text;
use Dicole::Widget::Javascript;
use Dicole::Widget::CSSLink;
use Dicole::Widget::Vertical;
use Dicole::Widget::Horizontal;
use Dicole::Widget::Columns;
use Dicole::Widget::LinkBar;
use Dicole::Widget::FormControl::TextField;

sub tinymce3_select_page {
    my ( $self, $task, $params ) = @_;

    $params = {
        disable_navigation => 1,
        disable_footer => 1,
    };

    my $data = {
        action_data => $self->_get_latest_action_data,
        page_anchors_url => $self->derive_url( action => 'wiki_json', task => 'page_anchors' ),
    };

    $params->{head_widgets} = [
        Dicole::Widget::Javascript->new(
            src => '/js/tiny_mce/tiny_mce_popup.js',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_wiki_popup.js',
        ),
        Dicole::Widget::CSSLink->new(
            href => '/css/dicole_wiki_popup.css',
        ),
        $self->_get_latest_action_data_widget,
        Dicole::Widget::Javascript->new(
            code => 'select_page_data = ' . Dicole::Utils::JSON->encode( $data )
        ),
    ];

    return $self->generate_solo_content(
        template_params => $params,
        template_name => 'dicole_wiki::tinymce3_select_page',
        title => '',
    );
}

sub tinymce_select_page {
    my ($self) = @_;
    $self->init_tool();
    $self->tool->structure('popup');

    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new(
            href => '/css/dicole_wiki_popup.css',
        ),
#        Dicole::Widget::Javascript->new(
#            src => '/tinymce/jscripts/tiny_mce/tiny_mce_popup.js',
#        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_wiki_popup.js',
        ),
    );

    $self->tool->add_end_widgets(
        Dicole::Widget::Javascript->new(
            code => 'wiki_popup_init();',
        ),
    );

    my $controls = Dicole::Widget::Vertical->new();
    $controls->add_content(
        Dicole::Widget::LinkBar->new(
            id => 'latest_bar',
            content => $self->_msg( 'Latest pages' ),
            class => 'latest_pages',
            href => '#',
        )
    );
    $controls->add_content(
        Dicole::Widget::LinkBar->new(
            id => 'alphabetic_bar',
            content => $self->_msg( 'Pages alphabetically' ),
            class => 'pages_alphabetically',
            href => '#',
        ),
    );

    $self->_create_latest_action_data;

    my $content = Dicole::Widget::Raw->new(
        raw => '<div id="title_select_container"></div>'
    );

    my $selector = Dicole::Widget::Columns->new(
        right => $controls,
        center => $content,
        height => '300px',
        right_width => '200px',
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg('Page selector')
    );

    $self->tool->Container->box_at( 0, 0 )->add_content( [
        Dicole::Widget::Text->new( text => $self->_msg( 'Type page name:' ) ),
        Dicole::Widget::FormControl::TextField->new(
            id => 'page_input',
            name => 'page',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Select page header:' ) ),
        Dicole::Widget::Raw->new( raw =>
            '<select id="header_input" name="header"><option value="">' .
            $self->_msg('No header (top of the page)') .
            '</option></select>'
        ),
        Dicole::Widget::Text->new(
            text => $self->_msg( 'Or select page from list:' )
        ),
        $selector,
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::LinkButton->new(
                onclick => 'execute_popup(); return false;',
                text => $self->_msg( 'Select' ),
            ),
            Dicole::Widget::LinkButton->new(
                onclick => 'cancel_popup(); return false;',
                text => $self->_msg( 'Cancel' ),
            )
        ] ),
    ] );

    return $self->generate_tool_content;
}

sub _create_latest_action_data {
    my ( $self ) = @_;

    $self->tool->add_head_widgets(
        $self->_get_latest_action_data_widget
    );
}

sub _get_latest_action_data_widget {
    my ( $self ) = @_;

    return Dicole::Widget::Javascript->new(
        code => 'action_data = ' . Dicole::Utils::JSON->encode(
            $self->_get_latest_action_data
        )
    );
}

sub _get_latest_action_data {
    my ( $self ) = @_;

    my $pages = CTX->lookup_object('wiki_page')->fetch_group( {
        where => 'groups_id = ?',
        value => [ $self->param('target_group_id') ],
        order => 'last_modified_time DESC',
    } ) || [];

    my @data = ();

    for my $page (@$pages) {
        my $title = $page->readable_title;

        push @data, {
            id => $page->id,
            title => $title,
            modified => $page->last_modified_time,
        };
    }

    return \@data;
}

sub printable_page {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );
    return if ! $page;
    my $readable_title = $page->readable_title;

    my $version = $self->param('version');
    my $sections = eval { $self->_sections_for_page( $page, $version ) };
    if ( $@ ) {
        $self->redirect( $self->derive_url( additional => [ $page->title ] ) );
    }

    $self->_filter_outgoing_links( $page, $sections );

    $sections = $self->_get_sections_with_header_contents( $sections );

    $self->init_tool;
    $self->tool->structure('popup');

#    my $name = $self->_msg('Wiki page [_1]', $readable_title );
    my $name = $readable_title;
    $name .= ' ' . $self->_msg('( version [_1] )', $version ) if $version;

    $self->tool->title( $name );
    $self->tool->Container->box_at( 0, 0 )->name( $name );
    $self->tool->Container->box_at( 0, 0 )->add_content( [
        Dicole::Widget::Raw->new(
            raw => $self->_sections_to_html( $sections ),
        )
    ] );

    return $self->generate_tool_content;
}

sub printable_commented_page {
    my ( $self ) = @_;

    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );
    return if ! $page;
    my $readable_title = $page->readable_title;

    my $version = $self->param('version');
    my $sections = eval { $self->_sections_for_page( $page, $version ) };
    if ( $@ ) {
        $self->redirect( $self->derive_url( additional => [ $page->title ] ) );
    }

    $self->_filter_outgoing_links( $page, $sections );
    my $anno_info_list = $self->_filter_outgoing_annos_to_anchor_list( $page, $sections );


    $self->init_tool( { rows => 10 } );
    $self->tool->structure('popup');

#    my $name = $self->_msg('Wiki page [_1]', $readable_title );
    my $name = $readable_title;
    $name .= ' ' . $self->_msg('( version [_1] )', $version ) if $version;

    $self->tool->title( $name );
    $self->tool->Container->box_at( 0, 0 )->name( $name );
    $self->tool->Container->box_at( 0, 0 )->add_content( [
        Dicole::Widget::Raw->new(
            raw => $self->_sections_to_html( $sections ),
        )
    ] );

    eval {
        # TODO: do not show this if there are no comments
        my $comments_info = CTX->lookup_action('commenting')->execute( 'get_comments_info', {
            object => $page,
            comments_action => 'wiki_comments',
            disable_commenting => 1,
        } );
        
       # $self->tool->add_comments_widgets if $self->chk_y( 'comment' );

        if ( @$comments_info ) {
            my $params = { comments => $comments_info };
            
            $self->tool->Container->box_at( 0, 1 )->class( 'wiki_comments_container_box' );
            $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Comments to the whole page') );
            $self->tool->Container->box_at( 0, 1 )->add_content(
                [ Dicole::Widget::Raw->new(
                    raw => $self->generate_content( $params, { name => 'dicole_wiki::component_printable_comments' } )
                ) ]
            );
        }
    };

    if ( @$anno_info_list ) {
        my $anno_params = {};
        for my $anno_info ( @$anno_info_list ) {
            my $anno = $anno_info->{anno};
            my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
                object => $anno,
                group_id => $anno->group_id,
                user_id => 0,
                domain_id => Dicole::Utils::Domain->guess_current_id,
                size => 40,
            } );

            $anno_params->{annos} ||= [];
            push @{$anno_params->{annos}}, {
                id => $anno_info->{id},
                comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
            };
        }

        $self->tool->Container->box_at( 0, 2 )->class( 'wiki_annotations_container_box' );
        $self->tool->Container->box_at( 0, 2 )->name( $self->_msg('Comments to marked sections') );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $anno_params, { name => 'dicole_wiki::component_printable_annotations' } )
            ) ]
        );
    }

    return $self->generate_tool_content;

}

sub _get_sections_with_header_contents {
    my ( $self, $sections ) = @_;

    my @new_sections = ();

    for my $section (@$sections) {
        push @new_sections, $section;
        for ( my $i = 0; $i < scalar( @{ $section->{nodes} } ); $i++ ) {
            my $node = $section->{nodes}->[$i];
            next unless ref $node && $node->tag =~ /^h(\d+)$/;
            my $header_base = $1;

            my @wiki_links = $node->look_down(
                '_tag' => 'a',
                'class' => qr/existingWikiLink/,
            );

            next unless scalar( @wiki_links );

            my $link = shift @wiki_links;

            my $page_sections = $self->_get_shifted_sections_from_raw_title(
                $link->attr('title'), $header_base
            );

            push @new_sections, @$page_sections;
        }
    }

    return \@new_sections;
}

1;

