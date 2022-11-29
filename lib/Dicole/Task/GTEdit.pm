package Dicole::Task::GTEdit;

use base 'Dicole::Task::GT';

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;

Dicole::Task::GTEdit->mk_accessors( qw(
  box_x 
  box_y 
  box_title 
  path_name 
  preview
  cancel_link
  save_redirect
  id_param
) );


sub execute {
    my ( $self ) = @_;

    # Run custom pre-init operations
    my $id = $self->_pre_init;

    # Init tool
    $self->_init( $id );

    # Run custom post-init operations
    $self->_post_init( $id );

    # Adds some buttons to the view
    $self->_buttons( $id );

    # Saves the object if save button pressed
    $self->_save( $id );
    
    return undef if CTX->response->is_redirect;

    my $x = $self->box_x || 0;
    my $y = $self->box_y || 0;

    if ( CTX->request->param( 'preview_edit' ) ) {

        # Move add form one level down
        $y++;
        $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { fill_only => 1 }
        );

        # User should implement the preview box contents
        $self->_gen_preview_box;
    }

    # Create add form
    $self->action->tool->Container->box_at( $x, $y )->name(
        $self->action->_msg( $self->box_title || 'Box title' )
    );
    $self->action->tool->Container->box_at( $x, $y )->add_content(
        $self->action->gtool->get_edit( id => $id )
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool;

    return $self->action->generate_tool_content;
}

sub _pre_init {
    my ( $self )  = @_;
    if ( CTX->request->param( 'preview_edit' ) ) {
        $self->_config_tool_add( 'rows', 2 );
    }
    return CTX->request->param( $self->id_param );
}

sub _init {
    my ( $self, $id )  = @_;
    $self->_gt_init( {
        tool_config => $self->_tool_config,
        class => $self->class,
        skip_security => $self->skip_security,
        view => $self->view,
    } );
}

sub _post_init {
    my ( $self, $id )  = @_;

    $self->action->tool->Path->add( name => $self->action->_msg(
        $self->path_name
    ) ) if $self->path_name;

}

sub _gen_preview_box {
    my ( $self )  = @_;
    $self->action->tool->Container->box_at( 0, 0 )->name(
        $self->action->_msg( 'Preview' )
    );
    $self->action->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Content::Text->new( text => 'Preview box not implemented.' ) ]
    );
}

sub _buttons {
    my ( $self, $id ) = @_;

    $self->action->gtool->add_bottom_button(
        name  => 'save',
        value => $self->action->_msg( 'Save' ),
    );

    if ( $self->preview ) {
        $self->action->gtool->add_bottom_button(
            name  => 'preview_edit',
            value => $self->action->_msg( 'Preview' ),
        );
    }

    if ( $self->cancel_link ) {
        $self->action->gtool->add_bottom_button(
            type  => 'link',
            value => $self->action->_msg( 'Cancel' ),
            link  => $self->cancel_link
        );
    }
}

sub _save {
    my ( $self, $id ) = @_;

    if ( CTX->request->param( 'save' ) ) {

        # Validate input parameters
        my ( $code, $message ) = $self->_validate_input( $id );

        if ( $code ) {

            my $data = $self->action->gtool->Data;

            # Run pre tasks for saving the object
            if ( $self->_pre_save( $data ) ) {

                $data->data_save;

                # Run post tasks for saving the object
                my $new_message = $self->_post_save( $data );
                $self->action->tool->add_message( $code, $new_message || $message );

                return CTX->response->redirect(
                    $self->save_redirect
                ) if $self->save_redirect;
            }
        } else {
            $message = $self->action->_msg( "Save failed: [_1]", $message );
            $self->action->tool->add_message( $code, $message );
        }
    }
}

sub _validate_input {
    my ( $self, $id ) = @_;
    my ( $code, $message ) = $self->action->gtool->validate_and_save(
        $self->action->gtool->visible_fields,
        { no_save => 1, object_id => $id }
    );
    return ( $code, $message );
}

sub _pre_save {
    my ( $self, $data ) = @_;
    return 1;
}

sub _post_save {
    my ( $self, $data ) = @_;
    return undef;
}


sub _pre_gen_tool {
    my ( $self )  = @_;
}

1;
