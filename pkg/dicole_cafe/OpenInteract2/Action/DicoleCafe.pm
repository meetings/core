package OpenInteract2::Action::DicoleCafe;
use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Settings;

sub display {
    my ( $self ) = @_;

    unless ( CTX->request->auth_user_id ) {
        my $params = CTX->request->param;

        return CTX->response->redirect(
            Dicole::URL->create(
                [
                    'login',
                    'login',
                ],
                {
                    url_after_login => CTX->controller->initial_action->derive_url(
                        params => $params,
                    ),
                    logout => 2
                },
            )
        );
 
    };
    if ( CTX->request->param('dic') ) {
        $self->redirect( $self->derive_full_url( params => {} ) );
    }

    my $tool = 'navigation' . ( $self->param('domain_id') ? '_' . $self->param('domain_id') : '' );

    my $domain_css = Dicole::Settings->fetch_single_setting(
        tool => $tool, attribute => 'custom_css'
    );
    my $group_css = Dicole::Settings->fetch_single_setting(
        tool => $tool, group_id => $self->param('target_group_id'), attribute => 'custom_css'
    );

    my $gid = $self->param('target_group_id');
    my $ginfo = CTX->lookup_action('groups_api')->e( info_for_groups => { group_ids => [ $gid ] } );

    my $variables = {
        event_server_url => 'http://event-server-'. int( rand( 1000 ) ) . ( CTX->server_config->{dicole}{development_mode} ?
            '-dev.dicole.net/' : '.dicole.net/' ),
        domain_host => Dicole::Utils::Domain->guess_current->domain_name,
        localization_api_url => $self->derive_url(
            action => 'localization_json', task => 'lexicon', additional => []
        ),
        instant_authorization_key_url => $self->derive_url(
            action => 'login_json', task => 'instant_authorization_key', target => 0, additional => []
        ),
    };
    

    my %params = (
        global_vars => Dicole::Utils::JSON->uri_encode( $variables ),
        domain_name => $self->param('domain_name'),
        group_id => $gid,
        group_name => $ginfo->{ $gid }->{name},
#        lexicon => Dicole::Utils::JSON->encode( CTX->lookup_action('localization_api')->e( lexicon => {} ) ),
        auth_token => Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ),
        domain_css => $domain_css,
        group_css => $group_css,
        group_starting_page => Dicole::URL->create_from_parts(
            action => 'groups',
            task => 'starting_page',
            target => $gid,
        ),
    );

    my @show_params = ( qw/ show_twitter show_posts show_pages show_media / );
    $params{$_} = CTX->request->param($_) for ( @show_params, 'custom_title', 'tag' );

    # show all columns if none is selected
    my $column_count = 0;
    $column_count += $params{ $_ } || 0 for ( @show_params );

    unless ( $column_count ) {
        $params{$_} = 1 for ( @show_params );
        $params{show_twitter} = '' unless $params{tag};
    }

    CTX->response->content_type( 'text/html; charset=utf-8' );

    return $self->generate_content(
        \%params, { name => 'dicole_cafe::main_display' }
    );
}

1;

