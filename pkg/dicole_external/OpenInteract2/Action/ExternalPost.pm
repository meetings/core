package OpenInteract2::Action::ExternalPost;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Tool;
use Dicole::Content;
use Text::CSV_XS;
use Dicole::Security::Encryption;
use OpenInteract2::Action::External;

our $VERSION = sprintf(
    "%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/
);

# Here's an example of the simplest response...

sub handler {
    my ( $self ) = @_;

    my $source = OpenInteract2::Action::External->_fetch_source;
    return $source unless ref $source;

    $self->param( 'active_navigation', $source->{navid} );
    $self->param( 'navigation_type', $source->{navigation_type} );

    my $csv = Text::CSV_XS->new( { binary => 1 } );
    $csv->parse( $source->{parameters} );
    my $params = { $csv->fields };

    # Use currently authorized login password if configuration specifies
    if ( $source->{use_login_pass} ) {
        my $sec = Dicole::Security::Encryption->new;
        $sec->use_dynamic( 1 );
        $params->{ $source->{pass_field} } = $sec->decrypt(
            CTX->request->session->{login_password}
        );
    }

    # Use currently authorized login name if configuration specifies
    $params->{ $source->{user_field} } = CTX->request
        ->auth_user->{login_name} if $source->{use_login_user};

    if ( $source->{custom_object} ) {
        my $obj = OpenInteract2::Action::External->_get_custom_object(
            $source
        );
        foreach my $param ( keys %{ $params } ) {
            $params->{$param} = OpenInteract2::Action::External
                ->_use_custom_object( $source, $params->{$param}, $obj );
        }
    }

    if ( $source->{parameters_from_request} ) {
        for my $key ( split /\s*\n\s*/, $source->{parameters_from_request} ) {
            $params->{$key} = CTX->request->param( $key )
                if $key && CTX->request->param( $key );
        }
    }

    my $content = new Dicole::Content(
        template => 'dicole_external::autopost',
        content => { url => $source->{url}, params => $params }
    );

    CTX->controller->no_template( 'yes' );

    $self->tool( Dicole::Tool->new(
        action => $self,
        no_tool_tabs => 1,
        wrap_form => 0,
        structure => 'custom',
        custom_content => $content,
    ) );

    return $self->generate_tool_content;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::External - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
