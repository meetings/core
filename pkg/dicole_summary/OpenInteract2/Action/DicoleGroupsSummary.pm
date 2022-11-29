package OpenInteract2::Action::DicoleGroupsSummary;

use strict;

use base qw( OpenInteract2::Action::DicoleSummaryCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Data::Dumper;

use Dicole::Box;
use Dicole::Summary;

sub summary {
    my ( $self ) = @_;

    my $layout = Dicole::Settings->fetch_single_setting(
        tool => 'summary',
        attribute => 'layout',
        group_id => $self->param('target_group_id'),
    );

    if ( $layout ) {
        return $self->redirect( $self->derive_full_url( action => 'summary' ) );
    }

    my $uid = CTX->request->auth_user_id;
    my $gid = CTX->request->target_group_id;
    my $action_name = CTX->request->action_name;
    my $valid_invite = $self->_valid_invite_exists;

    die "security error" unless $valid_invite || $self->mchk_y( 'OpenInteract2::Action::DicoleGroupsSummary', 'read' );

    if ( $valid_invite && ! CTX->request->auth_user_id ) {
        $self->change_current_rights( $gid, 'group' );
    }

    $self->init_tool( {
        tool_args => { structure => 'desktop', no_tool_tabs => 1, wrap_form => 0 },
    } );

    my $move_right = $self->chk_y( 'move' );
    my $manage_right = $self->chk_y( 'manage' );

    my $columns = Dicole::Summary->get_column_layout(
         $action_name, $move_right ? $uid : 0, $gid
    );

    my $personal_column_layout_count = 0;

    if ( $move_right ) {
        $personal_column_layout_count += scalar( @{ $_->{boxes} } ) for @$columns;
        $columns = Dicole::Summary->get_column_layout(
            $action_name, 0, $gid
        ) if $personal_column_layout_count == 0;
    }

    if ( $move_right && CTX->request->param( 'open_box' ) ) {
        Dicole::Summary->open_box( $columns, CTX->request->param( 'open_box' ) );
        Dicole::Summary->store_layout( $columns, $action_name, $uid, $gid );
        return $self->redirect( $self->derive_url );
    }
    if ( $manage_right && CTX->request->param( 'set_default_layout' ) ) {
        Dicole::Summary->store_layout( $columns, $action_name, 0, $gid );
        # it's somewhat logical to revert here since after that
        # the user sees if the default changes if no additional
        # changes are done.
        Dicole::Summary->revert_layout( $action_name, $uid, $gid );
        return $self->redirect( $self->derive_url );
    }
    if ( CTX->request->param( 'revert_default_layout' ) ) {
        Dicole::Summary->revert_layout( $action_name, $uid, $gid );
        return $self->redirect( $self->derive_url );
    }

    my $tools = CTX->lookup_object( 'groups' )->fetch( $gid )->tool || [];
    push @$tools, { summary_list => 'freeform_summary_list' };

    my $summaries = Dicole::Summary->generate_summary_content(
        $columns, $tools, $uid, $gid, 'open_box', $move_right ? 0 : 1
    );

    $self->tool->summaries( $summaries );
    $self->tool->tool_title_suffix( $self->_msg('Summary'));
    
    my $move_show = $personal_column_layout_count;
    
    my @controls = ();
    push @controls, Dicole::Widget::Hyperlink->new(
        link => $self->derive_url(
            task => 'summary',
            params => { revert_default_layout => 1 },
        ),
        content => $self->_msg( "Revert to default summary layout" ),
    ) if $move_show;
    
    push @controls, Dicole::Widget::Text->new(
        text => ' | ',
    ) if $move_show && $manage_right;
    
    
    push @controls, Dicole::Widget::Hyperlink->new(
        link => $self->derive_url(
            task => 'summary',
            params => { set_default_layout => 1 },
        ),
        content => $self->_msg( "Store this as default summary layout" ),
    ) if $manage_right;
    
    
    $self->tool->add_footer_widgets(
        Dicole::Widget::Container->new(
            class => 'summary_control_container',
            contents => [ @controls ],
        )
    ) if scalar( @controls );

    my $globals = $self->_gather_common_globals( $valid_invite );
    $self->tool->add_js_variables( $globals );

    return $self->generate_tool_content;
}

sub store_layout {
    my ( $self, $layout ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $gid = $layout->{target};
    my $action_name = $self->name;
    my $columns = $layout->{columns};

    Dicole::Summary->store_layout( $columns, $action_name, $uid, $gid );
}

sub actions {
    my ( $self ) = @_;

    $self->init_tool;
    
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( "Actions" )
    );
    
    my $buttons = Dicole::Widget::Horizontal->new;
    
    $buttons->add_content(
        Dicole::Widget::LinkButton->new(
            link => $self->derive_url(
                task => 'summary',
                params => { revert_default_layout => 1 },
            ),
            text => $self->_msg( "Revert to default summary layout" ),
        ),
    ) if $self->chk_y( 'move' );
    
    $buttons->add_content(
        Dicole::Widget::LinkButton->new(
            link => $self->derive_url(
                task => 'summary',
                params => { set_default_layout => 1 },
            ),
            text => $self->_msg( "Set your summary layout as default layout" ),
        ),
    ) if $self->chk_y( 'manage' );
    
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $buttons ]
    );
    
    return $self->generate_tool_content;
}

sub freeform_remove {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicoleGroupsSummary::Remove->new( $self, {
        box_title => 'List of freeform summaries',
        path_name => 'Remove summaries',
        class => 'freeform_summary',
        skip_security => 1,
        confirm_text => 'Are you sure you want to remove the selected summaries?',
        view => 'group_remove',
    } )->execute;
}

sub freeform_add {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicoleGroupsSummary::Add->new( $self, {
        box_title => $self->_msg('New freeform summary details'),
        class => 'freeform_summary',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

sub freeform_edit {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicoleGroupsSummary::Edit->new( $self, {
        box_title => $self->_msg('Freeform summary details'),
        class => 'freeform_summary',
        skip_security => 1,
        view => 'edit',
        id_param => 'id',
    } )->execute;
}

sub _freeform_summary {
    my ( $self ) = @_;
    
    my $ffs = CTX->lookup_object('freeform_summary')->fetch(
        $self->param('box_param')
    );

    die if $ffs->group_id && $ffs->group_id != $self->param('box_group');

    my $box = Dicole::Box->new;
    $box->name( $ffs->title );
    $box->class( 'group_freeform_summary_' . $ffs->id );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $ffs->summary ) );
    }

    return $box->output;
}

1;

package OpenInteract2::Action::DicoleGroupsSummary::Remove;

use base 'Dicole::Task::GTRemove';
use OpenInteract2::Context   qw( CTX );

sub _post_init {
    my ( $self ) = @_;
    $self->action->gtool->Data->query_params( {
        where => 'user_id = ? and group_id = ?',
        value => [ 0, $self->action->target_group_id ]
    } );
    
    return 1;
}

1;

package OpenInteract2::Action::DicoleGroupsSummary::Add;

use base 'Dicole::Task::GTAdd';
use OpenInteract2::Context   qw( CTX );

sub _pre_save {
    my ( $self, $data ) = @_;

    $data->data->{user_id} = 0;
    $data->data->{group_id} = $self->action->target_group_id;

    return 1;
}

package OpenInteract2::Action::DicoleGroupsSummary::Edit;

use base 'Dicole::Task::GTEdit';
use OpenInteract2::Context   qw( CTX );

sub _pre_save {
    my ( $self, $data ) = @_;

    $data->data->{user_id} = 0;
    $data->data->{group_id} = $self->action->target_group_id;

    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleGroupsSummary - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
