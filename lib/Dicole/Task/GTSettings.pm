package Dicole::Task::GTSettings;

use base 'Dicole::Task::GT';

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;

Dicole::Task::GTSettings->mk_accessors( qw(
  tool
  user
  group
  global
  box_x
  box_y
  box_title
  path_name
  save_redirect
) );


sub execute {
    my ( $self ) = @_;

    my $settings = Dicole::Settings->new;
    $settings->tool( $self->tool || $self->action->name );
    $settings->user( $self->user );
    $settings->group( $self->group );
    $settings->global( $self->global );
    $settings->fetch_settings;
    
    # Run custom pre-init operations
    $self->_pre_init( $settings );

    # Init tool
    $self->_init( $settings );

    # Run custom post-init operations
    $self->_post_init( $settings );

    # Adds some buttons to the view
    $self->_buttons;

    # Saves the settings if save button pressed
    $self->_save( $settings );

    my $x = $self->box_x || 0;
    my $y = $self->box_y || 0;

    # Create add form
    $self->action->tool->Container->box_at( $x, $y )->name(
        $self->action->_msg( $self->box_title || 'Box title' )
    );
    $self->action->tool->Container->box_at( $x, $y )->add_content(
        $self->action->gtool->get_edit
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool;

    return $self->action->generate_tool_content;
}

sub _pre_init {
    my ( $self, $data ) = @_;
    return undef;
}

sub _init {
    my ( $self, $settings ) = @_;

    $self->_gt_init( {
        tool_config => $self->_tool_config,
        skip_security => $self->skip_security,
        view => $self->view,
    } );
    
    my $fake_object = Dicole::Generictool::FakeObject->new( { id => 'settings_id' } );
    $self->action->gtool->fake_objects( [ $fake_object ] );
    $self->action->init_fields;
    
    my $settings_hash = $settings->settings_as_hash;

    foreach my $param ( keys %{ $settings_hash } ) {
        $fake_object->{$param} = $settings_hash->{$param};
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
        name  => 'save',
        value => $self->action->_msg( 'Save' ),
    );
}

sub _save {
    my ( $self, $settings ) = @_;

    if ( CTX->request->param( 'save' ) ) {

        # Validate input parameters
        my ( $code, $message ) = $self->_validate_input;

        if ( $code ) {
            my $fake_object = $self->action->gtool->fake_objects->[0];
            if ( $self->_pre_save( $fake_object ) ) {

                foreach my $field ( @{ $self->action->gtool->visible_fields } ) {
                    $settings->setting( $field, $fake_object->{$field} || '' );
                }

                my $new_message = $self->_post_save( $settings );


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
    my ( $self ) = @_;
    my ( $code, $message ) = $self->action->gtool->validate_input(
        $self->action->gtool->visible_fields,
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
