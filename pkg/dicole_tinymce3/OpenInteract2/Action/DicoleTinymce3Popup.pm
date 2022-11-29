package OpenInteract2::Action::DicoleTinymce3Popup;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _default_generate {
    my ( $self, $task, $params ) = @_;

    $params = {
        disable_navigation => 1,
        disable_footer => 1,
        %{ $params || {} },
    };

    my $head_widgets = [
        Dicole::Widget::Javascript->new(
            src => '/js/tiny_mce/tiny_mce_popup.js',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/tiny_mce/utils/form_utils.js',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_tinymce3_popup.js',
        ),
        Dicole::Widget::CSSLink->new(
            href => '/css/dicole_tinymce3.css',
        ),
    ];

    $params->{head_widgets} = [
        @{ $params->{head_widgets} || [] },
        @$head_widgets,
    ];

    return $self->generate_solo_content(
        template_params => $params,
        template_name => 'dicole_tinymce3::' . $task,
        title => '',
    );
}

sub html {
    my ( $self ) = @_;

    return $self->_default_generate( html => {
        msg => {
            embedded_html => $self->_msg('Embedded HTML'),
            type_html => $self->_msg('Type the HTML:'),
            save => $self->_msg('Save'),
            cancel => $self->_msg('Cancel'),
        }
    } );

}

sub attachment {
    my ( $self ) = @_;

    return $self->_default_generate( attachment => {
        msg => {
        }
    } );
}

sub image {
    my ( $self ) = @_;

    return $self->_default_generate( image => {
        msg => {
            image_selector =>  $self->_msg('Image selector'),
            image_url =>  $self->_msg('Image URL:'),
            image_description => $self->_msg('Image description:'),
            image_location => $self->_msg('Image location:'),
            on_row => $self->_msg('In line'),
            on_right => $self->_msg('Right'),
            on_left => $self->_msg('Left'),
            'select' => $self->_msg('Select'),
            cancel => $self->_msg('Cancel'),
        }
    } );
}

sub link {
    my ( $self ) = @_;

    return $self->_default_generate( 'link' => {
        msg => {
            link_selector =>  $self->_msg('Link selector'),
            link_url =>  $self->_msg('Link URL:'),
            'select' => $self->_msg('Select'),
            cancel => $self->_msg('Cancel'),
        }
    } );
}

1;

