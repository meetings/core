package OpenInteract2::Action::DicolePersonalSummary;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Content::Text;
use Dicole::DateTime;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

sub summary {
    my ( $self ) = @_;

    if ( ! CTX->request->target_user_id && CTX->request->auth_user_id ) {
        return CTX->response->redirect(
            $self->derive_url( target => CTX->request->auth_user_id )
        );
    }
    
    unless ( $self->chk_y( 'read' ) ) {
        die "security error";
    }

    $self->init_tool( {
        tool_args => { structure => 'desktop', no_tool_tabs => 1, wrap_form => 0 },
    } );
    
    my $uid = CTX->request->target_user_id;
    my $action_name = CTX->request->action_name;

    my $columns = Dicole::Summary->get_column_layout( $action_name, $uid, 0 );

    if ( CTX->request->param( 'open_box' ) ) {

        Dicole::Summary->open_box( $columns, CTX->request->param( 'open_box' ) );
        Dicole::Summary->store_layout( $columns, $action_name, $uid, 0 );
    }

    my $tools = CTX->lookup_object( 'tool' )->fetch_group( {
        where => 'type = "personal"'
    } );
    push @$tools, { summary_list => 'freeform_summary_list' };

    my $summaries = Dicole::Summary->generate_summary_content(
        $columns, $tools, $uid, 0, 'open_box'
    );

    $self->tool->summaries( $summaries );

    return $self->generate_tool_content;
}

sub store_layout {
    my ( $self, $layout ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $action_name = $self->name;
    my $columns = $layout->{columns};

    Dicole::Summary->store_layout( $columns, $action_name, $uid, 0 );
}

sub freeform_remove {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicolePersonalSummary::Remove->new( $self, {
        box_title => 'List of freeform summaries',
        path_name => 'Remove summaries',
        class => 'freeform_summary',
        skip_security => 1,
        confirm_text => 'Are you sure you want to remove the selected summaries?',
        view => 'user_remove',
    } )->execute;
}

sub freeform_add {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicolePersonalSummary::Add->new( $self, {
        box_title => $self->_msg('New freeform summary details'),
        class => 'freeform_summary',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

sub freeform_edit {
    my ( $self ) = @_;
    return OpenInteract2::Action::DicolePersonalSummary::Edit->new( $self, {
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

    die if $ffs->user_id && $ffs->user_id != $self->param('box_user');

    my $box = Dicole::Box->new;
    $box->name( $ffs->title );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $ffs->summary ) );
    }

    return $box->output;
}

1;

package OpenInteract2::Action::DicolePersonalSummary::Remove;

use base 'Dicole::Task::GTRemove';
use OpenInteract2::Context   qw( CTX );

sub _post_init {
    my ( $self ) = @_;
    $self->action->gtool->Data->query_params( {
        where => 'user_id = ? and group_id = ?',
        value => [ $self->action->target_user_id, 0 ]
    } );
    
    return 1;
}

1;

package OpenInteract2::Action::DicolePersonalSummary::Add;

use base 'Dicole::Task::GTAdd';
use OpenInteract2::Context   qw( CTX );

sub _pre_save {
    my ( $self, $data ) = @_;

    $data->data->{user_id} = $self->action->target_user_id;
    $data->data->{group_id} = 0;
    
    return 1;
}

package OpenInteract2::Action::DicolePersonalSummary::Edit;

use base 'Dicole::Task::GTEdit';
use OpenInteract2::Context   qw( CTX );

sub _pre_save {
    my ( $self, $data ) = @_;

    $data->data->{user_id} = $self->action->target_user_id;
    $data->data->{group_id} = 0;

    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicolePersonalSummary - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
