package OpenInteract2::Action::DicoleTinymce3;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub get_head_widgets {
    my ( $self ) = @_;

    my $type = $self->param('type') || 'default';
    my $recent_page_data = CTX->lookup_action('wiki_api')->execute( recent_page_data => { limit => 10 } ) || [];

    return [
        Dicole::Widget::Javascript->new(
            code => 'content_data = ' . Dicole::Utils::JSON->encode( {
                mce_lang => eval { CTX->request->session->{lang}{code} } || 'en',
                target_group_id => eval { CTX->controller->initial_action->param('target_group_id') } || 0,
                target_user_id => eval { CTX->controller->initial_action->param('target_user_id') ||
                    CTX->request->auth_user_id } || 0,
            } ),
        ),
        $self->param('old_version') ? () : (
            Dicole::Widget::Javascript->new(
                code => 'tinymce3_data = ' . Dicole::Utils::JSON->encode( {
                    language => eval { CTX->request->session->{lang}{code} } || 'en',
#                    html_url => $self->_get_url( task => 'html' ),
#                    link_url => $self->_get_url( task => 'link' ),
#                    image_url => $self->_get_url( task => 'image' ),
#                    attachment_url => $self->_get_url(
#                        task => 'attachment',
#                        additional => scalar( $self->param('attachment_additional') ) || []
#                    ),
                    wiki_url => $self->_get_url(
                        action => 'wiki_popup',
                        task => 'tinymce3_select_page',
                        additional => scalar( $self->param('wiki_additional') ) || []
                    ),
                    attachment_list_url => $self->param('attachment_list_url') || '',
                    attachment_post_url => $self->param('attachment_post_url') || '',
                    document_base_url => Dicole::URL->get_server_url . '/',

                    dicole_save_container_template => $self->param('wiki') ? $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                    }, { name => 'dicole_tinymce3::save_container'} ) : '',

                    dicole_cancel_container_template => $self->param('wiki') ? $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                    }, { name => 'dicole_tinymce3::cancel_container'} ) : '',

                    dicole_attachment_container_template => $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                        attachment_list_initial => $self->param('attachment_list_initial') || '',
                        attachment_list_url => $self->param('attachment_list_url') || '',
                        attachment_post_url => $self->param('attachment_post_url') || '',
                    }, { name => 'dicole_tinymce3::attachment_container'} ),

                    dicole_link_container_template => $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                        wiki_recent_pages => $recent_page_data,
                        wiki_autofill_url => $self->_get_url(
                            action => 'wiki_json', task => 'page_autocomplete_data', additional => [],
                        ),
                        wiki_show_more_url => $self->_get_url(
                            action => 'wiki_popup', task => 'tinymce3_select_page', additional => [],
                        ),
                    }, { name => 'dicole_tinymce3::link_container'} ),
                    dicole_image_container_template => $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                    }, { name => 'dicole_tinymce3::image_container'} ),

                    dicole_html_container_template => $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                    }, { name => 'dicole_tinymce3::html_container'} ),

                    dicole_showroom_container_template => $self->generate_content( {
                        editor_id => 'REPLACE:EDITOR:ID:HERE',
                    }, { name => 'dicole_tinymce3::showroom_container'} ),

                } ),
            ),
        ),
        Dicole::Widget::Javascript->new(
            code => 'dojo.require("dicole.tinymce3.shortcut");',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/tiny_mce/tiny_mce.js',
        ),
        Dicole::Widget::Javascript->new(
             code => 'dojo.require("dicole.tinymce3");',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_'.$type.'_tinymce_init.js',
        ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tinymce3.css' ),
    ];
}

sub _recent_list_initial {
    my ( $self, %params ) = @_;

    my $action = $self->param('action') || CTX->controller->initial_action;

    return eval { CTX->lookup_action('wiki_api')->execute( tinymce_recent_list => {
        group_id => $action->param('target_group_id'),
    } ) } || '';
}

sub get_end_widgets {
    my ( $self ) = @_;

    my $type = $self->param('type') || 'default';

    return [] if $type eq 'comment' || $type eq 'wiki';
    return [
        Dicole::Widget::Raw->new( raw => 
            '<div id="tinymce_toolbar_container_div" style="position: absolute;"><table class="defaultSkin" style="width: 100%;"><tr id="tinymce_toolbar_container_tr"><td></td></tr></table></div>'
        ),
    ];

}

sub push_widgets {
    my ( $self ) = @_;

    my $target = $self->param('target');
    return unless $target;

    my $head = $self->get_head_widgets;
    eval { push @{ $target->{head_widgets} }, @$head };

    my $end = $self->get_end_widgets;
    eval { push @{ $target->{end_widgets} }, @$end };
}

sub _get_url {
    my ( $self, %params ) = @_;

    my $action = $self->param('action') || CTX->controller->initial_action;
    return Dicole::URL->get_server_url( undef, 'force_request_port_sniffing' ) . $action->derive_url(
        action => 'tinymce3_popup',
        %params
    );
}

sub filter_outgoing_html {
    my ( $self, $html ) = @_;

    $html ||= $self->param('html');

    $html = $self->filter_outgoing_wiki_links( $html );
    $html = $self->filter_outgoing_embedded_html( $html );
    $html = $self->filter_outgoing_showrooms( $html );

    return $html;
}

# NOTE: this does NOT mark unexisting wiki pages separately
# NOTE: the wiki package has own functions for it..
sub filter_outgoing_wiki_links {
    my ( $self, $html ) = @_;

    $html ||= $self->param('html');
    # Speed up a bit ;)
    return $html unless $html =~ /wikiLink/;

    my $wiki_link_generator = $self->param('wiki_link_generator');

    my $tree = Dicole::Utils::HTML->safe_tree( $html );

    my $rebuild = $self->_convert_wiki_links_tree_in_place( $tree, $wiki_link_generator, $self->param('group_id') );

    if ( $rebuild ) {
        $html = Dicole::Utils::HTML->tree_guts_as_xml( $tree );
    }

    $tree->delete;

    return $html;
}

sub _convert_wiki_links_tree_in_place {
    my ( $self, $tree, $link_generator, $gid ) = @_;

    $link_generator ||= sub {
        my ( $title, $group_id ) = @_;
        return CTX->lookup_action('wiki_api')->e( wiki_link_from_title => { title => $title, group_id => $group_id } );
    };

    my $rebuild = 0;
    if ( ref( $tree ) ) {
        my @alinks = $tree->look_down(
            '_tag' => 'a',
            'class' => qr/wikiLink/,
        );

        for my $alink ( @alinks ) {
            my $class = $alink->attr('class');

            my $link = $link_generator->( Dicole::Utils::Text->ensure_utf8( $alink->attr('title') ), $gid );

            $alink->attr( 'class', $class . ' existingWikiLink' );
            $alink->attr( 'href', Dicole::Utils::Text->ensure_internal( $link ) );

            $rebuild++;
        }
    }

    return $rebuild;
}

sub filter_outgoing_embedded_html {
    my ( $self, $html ) = @_;

    $html ||= $self->param('html');

    # Speed up a bit ;)
    return $html unless $html =~ /dicole_embedded_html/;

    my $tree = Dicole::Utils::HTML->safe_tree( $html );

    my $rebuild_html = 0;

    my @imgs = $tree->look_down(
        '_tag' => 'img',
        'class' => qr/dicole_embedded_html/,
    );

    for my $img ( @imgs ) {
        $rebuild_html = 1;
        my $ihtml = $img->attr('alt');
        $ihtml =~ s/mce_t(href|src)/$1/g;
        $ihtml = Dicole::Utils::HTML->strip_scripts( $ihtml );

        my $itree = Dicole::Utils::HTML->safe_tree( $ihtml );

        $img->replace_with( $itree->guts );
    }

    if ( $rebuild_html ) {
        $html = Dicole::Utils::HTML->tree_guts_as_xml( $tree );
    }

    return $html;
}

sub filter_outgoing_showrooms {
    my ( $self, $html ) = @_;

    $html ||= $self->param('html');

    # Speed up a bit ;)
    return $html unless $html =~ /dicole_showroom_link/;

    my $tree = Dicole::Utils::HTML->safe_tree( $html );

    my $rebuild_html = 0;

    my @links = $tree->look_down(
        '_tag' => 'a',
        'class' => qr/dicole_showroom_link/,
    );

    for my $link ( @links ) {
        $rebuild_html = 1;
        my $ihtml = $link->attr('title');
        $ihtml =~ s/mce_t(href|src)/$1/g;
        $link->attr('title', $ihtml);
    }

    if ( $rebuild_html ) {
        $html = Dicole::Utils::HTML->tree_guts_as_xml( $tree );
    }

    return $html;
}

1;

