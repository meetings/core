package Dicole::Task::GTRemove;

use base 'Dicole::Task::GT';

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utility;

Dicole::Task::GTRemove->mk_accessors( qw(
  box_x 
  box_y 
  box_title 
  path_name 
  check_prefix 
  remove_text 
  confirm_title 
  confirm_text 
  active 
  active_field
  archive
  archive_field
) );


sub execute {
    my ( $self ) = @_;

    $self->check_prefix('remove') unless $self->check_prefix('remove');

    # Run custom pre-init operations
    $self->_pre_init;

    # Init tool
    $self->_init;

    # Run custom post-init operations
    $self->_post_init;

    # Adds some buttons to the view
    $self->_buttons;

    # Remove objects
    $self->_remove;

    my $x = $self->box_x || 0;
    my $y = $self->box_y || 0;

    $self->action->tool->Container->box_at( $x, $y )->name(
        $self->action->_msg( $self->box_title || 'Box title' )
    );
    $self->action->tool->Container->box_at( $x, $y )->add_content(
        $self->action->gtool->get_sel( checkbox_id => $self->check_prefix )
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool;

    return $self->action->generate_tool_content;
}

sub _pre_init {
    my ( $self )  = @_;
}

sub _init {
    my $self = shift;
    $self->_gt_init( {
        tool_config => $self->_tool_config,
        class => $self->class,
        skip_security => $self->skip_security,
        view => $self->view
    } );
    
    if ( $self->active ) {
        $self->action->gtool->Data->flag_active( 1 );
        $self->action->gtool->Data->active_field(
            $self->active_field || 'active'
        );
    }

    if ( ref( $self->archive ) eq 'HASH' ) {
        my $archive_field = $self->archive_field || 'archive';
        if ( exists $self->action->gtool->Data->object->CONFIG->{field_map}{$archive_field} ) {
            $archive_field = $self->action->gtool->Data->object->CONFIG->{field_map}{$archive_field};
        }
        $self->action->gtool->Data->add_where( "$archive_field != 1" );
    }
}

sub _post_init {
    my ( $self )  = @_;
    $self->action->tool->Path->add( name => $self->action->_msg(
        $self->path_name
    ) ) if $self->path_name;
}

sub _buttons {
    my ( $self ) = @_;

    $self->action->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->action->_msg( $self->remove_text || 'Remove checked' ),
        confirm_box => {
            title => $self->action->_msg(
                $self->confirm_title || 'Confirmation'
            ),
            name => $self->check_prefix,
            msg => $self->action->_msg(
                $self->confirm_text
                    || 'Are you sure you want to remove the selected items?'
            )
        }
    );

}

sub _remove {
    my ( $self ) = @_;

    if ( CTX->request->param( $self->check_prefix ) ) {
        my $data = $self->action->gtool->Data;
        my $ids = Dicole::Utility->checked_from_apache( $self->check_prefix );
        if ( $self->_pre_remove( $ids, $data ) ) {
            my ( $code, $message ) = $data->remove_group( $self->check_prefix );
            if ( $code ) {
                my $new_message = $self->_post_remove( $ids, $data );
                $self->action->tool->add_message( $code, $new_message || $message );
            } else {
                $message = $self->action->_msg( "Error during remove: [_1]", $message );
                $self->action->tool->add_message( $code, $message );
            }
        }
    }

}

sub _pre_remove {
    my ( $self, $ids, $data ) = @_;
    return 1;
}

sub _post_remove {
    my ( $self, $ids, $data ) = @_;
    return undef;
}

sub _pre_gen_tool {
    my ( $self )  = @_;
}


1;
