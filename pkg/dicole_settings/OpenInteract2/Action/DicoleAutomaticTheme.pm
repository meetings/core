package OpenInteract2::Action::DicoleAutomaticTheme;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use base qw( Dicole::Action );

sub edit {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = ( $self->param('target_type') eq 'group' ) ? $self->param('target_group_id') : 0;

    my $tool = 'automatic_theme' . ( $domain_id ? '_' . $domain_id : '');

    my $settings = Dicole::Settings->new_fetched_from_params(
        tool => $tool,
        group_id => $group_id || 0,
    );

    my $hash = $settings->settings_as_hash;

    if ( CTX->request->param('save') ) {
        my $params = CTX->request->param;
        my $new_hash = {};
        for my $key ( keys %$params ) {
            my ( $k ) = $key =~ /at_(.+)/;
            next unless $k;
            $new_hash->{$k} = $params->{'at_' . $k};
            next if $new_hash->{$k} eq $hash->{$k};
            $settings->setting( $k, $new_hash->{$k} );
        }
        for my $key ( keys %$hash ) {
            next if $new_hash->{$key};
            $settings->remove_setting( $key );
        }
        $hash = $new_hash;
    }

    my $params = { map { 'at_' . $_ => $hash->{$_} } keys %$hash };

    $params->{dump} = Data::Dumper::Dumper( $params );

    $self->init_tool({ rows => 1, cols => 1, tool_args => { no_tool_tabs => 1 } });
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Automatic theme settings') );
    $self->tool->Container->box_at( 0, 0 )->class( '' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_settings::automatic_theme_settings' } )
        ) ]
    );

    return $self->generate_tool_content;
}

1;
