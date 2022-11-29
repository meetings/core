package OpenInteract2::Action::DicoleDocumentation;

use strict;

use OpenInteract2::Context   qw( CTX );
use Dicole::Tool;

use base qw( Dicole::Action );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub show {
    my ( $self ) = @_;

    CTX->controller->add_content_param( 'page_title',
        CTX->server_config->{dicole}{title} . ' :: ' . $self->_msg( 'Help' )
    );

    CTX->controller->set_main_template( 'dicole_documentation::base_main' );
    CTX->controller->add_content_param( 'lang', {
        code => CTX->request->session->{lang}{code},
        charset => CTX->request->session->{lang}{charset}
    } );

    my ( $theme_css, $theme_images ) = Dicole::Tool->_get_theme_css_params();

    # Set theme stuff in controller params
    CTX->controller->add_content_param( 'theme_css', $theme_css );
    CTX->controller->add_content_param( 'theme_images', $theme_images );

    my $package = CTX->lookup_action( $self->param( 'action' ) )->package_name;

    my $template = $package . '::' . 'doc_'
        . $self->param( 'action' ) . '_'
        . $self->param( 'task' ) . '_'
        . $self->param( 'id' );

    return $self->generate_content( {}, { name => $template } );
}

1;

