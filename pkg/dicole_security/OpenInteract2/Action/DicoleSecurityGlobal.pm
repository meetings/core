package OpenInteract2::Action::DicoleSecurityGlobal;

# $Id: DicoleSecurityGlobal.pm,v 1.4 2009-01-07 14:42:33 amv Exp $

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );
use Dicole::Utility;

sub select {
    my ( $self ) = @_;

    $self->init_tool;

    my $class = CTX->lookup_object('dicole_security');
    
    my $selected = $class->fetch_group( {
        where => 'target_type = ? AND receiver_type = ?',
        value => [ TARGET_SYSTEM, RECEIVER_LOCAL ],
    } ) || [];
    
    # TODO: add a check list so that all rights are not removed every time..
    my @selected = map { $_->{collection_id} } @$selected;

    if ( CTX->request->param( 'save' ) ) {
         
        $_->remove for @$selected;

        $selected = Dicole::Utility->checked_from_apache( 'sel' ) || {};
        @selected = keys %$selected;
        
        foreach my $id ( @selected ) {
                my $o = $class->new;

                $o->{collection_id} = $id;
                $o->{target_type} = TARGET_SYSTEM;
                $o->{receiver_type} = RECEIVER_LOCAL;

                $o->save;
        }

        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Global rights updated') );
    }


    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security_collection'),
            current_view => 'global_collections'
        )
    );

    $self->init_fields;
 
    $self->gtool->Data->add_where( "target_type = " . TARGET_SYSTEM );

    $self->gtool->bottom_buttons( [
        {
            value => $self->_msg('Save'),
            name => 'save'
        }
    ] );

	$self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Select global rights') );
	$self->tool->Container->box_at( 0, 0 )->add_content(
	    $self->gtool->get_sel( checked => \@selected )
	);

    return $self->generate_tool_content;
}


1;
