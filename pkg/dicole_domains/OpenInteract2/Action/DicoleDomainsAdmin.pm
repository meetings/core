package OpenInteract2::Action::DicoleDomainsAdmin;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });
    $self->tool->Container->column_width( '280px', 1 );
#    $self->tool->add_head_widgets(
#       Dicole::Widget::CSSLink->new( href => '/css/dicole_groups.css' ),
#    );
#    $self->tool->add_head_widgets(
#        Dicole::Widget::Raw->new( raw => '<!--[if lt IE 7]><link rel="stylesheet" href="/css/dicole_groups_ie6.css" media="all" type="text/css" /><![endif]-->' . "\n" ),
#    );
    $self->tool->add_head_widgets( Dicole::Widget::Javascript->new(
        code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $params{globals} ) . ');'
    ) ) if $params{globals};

#    $self->tool->add_head_widgets(
#        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.groups");' ),
#    );
}

sub look {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};

    my $tool = 'navigation';
    $tool .= '_' . $domain_id if $domain_id;

    if ( CTX->request->param('save') ) {
        $params->{custom_css} = Dicole::Settings->store_single_setting(
            tool => $tool,
            attribute => 'custom_css',
            value => CTX->request->param('custom_css') 
        );
    }

    $params->{custom_css} = Dicole::Settings->fetch_single_setting(
        tool => $tool,
        attribute => 'custom_css',
    );

    return $self->_generate_default_admin_boxes( 'look', $globals, $params );

}

sub _generate_default_admin_boxes {
    my ( $self, $task, $globals, $params, $override_selected_task ) = @_;

    $self->_default_tool_init( ( $globals ? ( globals => $globals ) : () ) );

#    $self->tool->add_tinymce_widgets if $task eq 'users';

    my $tools = $self->_get_available_tools;

    my %tool_by_task = map { $_->{task} => $_->{name} } @$tools;

    $_->{class} = 'domains_admin_navi_' . $_->{action} . '_' . $_->{task} for @$tools;

    my $navi_params = {
        tasks => $tools,
        selected_task => $override_selected_task || $task . '2',
    };

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Navigation' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'domains_left_admin_navi domains_left_admin_navi_' . $task );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $navi_params, { name => 'dicole_domains::component_domains_left_admin_navi' } )
        ) ]
    );

    $params->{dump} = Data::Dumper::Dumper( $params );

    $self->tool->Container->box_at( 1, 0 )->name( $tool_by_task{ $task } );
    $self->tool->Container->box_at( 1, 0 )->class( 'domains_right_admin_' . $task );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_domains::component_domains_right_admin_' . $task } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _get_available_tools {
    my ( $self ) = @_;

    my $tools = [
        $self->mchk_y('OpenInteract2::Action::DomainUserManager', 'manage') ? 
            ( { action => 'domains_admin', task => 'look', name => $self->_msg('Custom CSS') } ) : (),
    ];

    $_->{url} = $self->derive_url( action => $_->{action}, task => $_->{task}, additional => [] ) for @$tools;

    return $tools;
}

1;
