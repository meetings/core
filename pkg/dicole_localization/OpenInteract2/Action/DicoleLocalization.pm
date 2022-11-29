package OpenInteract2::Action::DicoleLocalization;
use strict;

use base qw( OpenInteract2::Action::DicoleLocalizationCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub customize {
    my ( $self ) = @_;

    my $lang = $self->param('lang');
    return $self->redirect( $self->derive_url( additional => ['en'] ) ) unless $lang;

    my $group_id = $self->param('target_group_id') || 0;
    
    my $ns = eval{ $self->param('domain')->localization_namespace } || '';
    my @args = ();
    push @args, '[_' . $_ . ']' for (1..20);

    my $handle = OpenInteract2::I18N->get_handle( $lang );
    my $dict = {};
    for my $ref ( @{ $handle->_lex_refs } ) {
        for my $key ( keys %$ref) {
            next if exists $dict->{ $key };
            next if ! $key || $key =~ /^ /;
            my $value = $ref->{ $key };
            $dict->{ $key } = ref( $value ) ? ref( $value ) eq 'SCALAR' ? $$value : &$value($handle, @args) : $value;
        }
    }

    my @list = ();
    for my $key ( sort keys %$dict ) {
        my $default = $dict->{ $key };
        if ( $group_id && $ns ) {
            my $domain_default = Dicole::Localization->get_custom_localization_template(
                $handle, $ns, 0, $key
            );
            $default = $domain_default if $domain_default;
        }

        my $custom = $ns ? Dicole::Localization->get_custom_localization_template(
            $handle, $ns, $group_id, $key,
        ) || '' : '';

        push @list, {
            key => $key,
            default => $default,
            custom => $custom,
        };
    }

    my $params = {
        list => \@list,
        update_url => $self->derive_url( action => 'localization_json', task => 'update' ),
        language => $lang,
        languages => [
            { id => 'en', name => $self->_msg('English'), url => $self->derive_url( additional => ['en'] ), },
            { id => 'fi', name => $self->_msg('Finnish'), url => $self->derive_url( additional => ['fi'] ), },
        ],
    };

    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1 } });
    $self->tool->Container->column_width( '280px', 1 );
    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/dicole_localization.css' ),
    );
#     $self->tool->add_head_widgets(
#         Dicole::Widget::Raw->new( raw => '<!--[if lt IE 7]><link rel="stylesheet" href="/css/dicole_localization_ie6.css" media="all" type="text/css" /><![endif]-->' . "\n" ),
#     );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.localization");' ),
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Language selection' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'localization_language_selection' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_localization::language_selection' } )
        ) ]
    );
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Customizable strings' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'localization_customizable_strings' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_localization::customizable_strings' } )
        ) ]
    );

    return $self->generate_tool_content;
    
}

1;

