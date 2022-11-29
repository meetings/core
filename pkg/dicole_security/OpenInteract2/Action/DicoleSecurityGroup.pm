package OpenInteract2::Action::DicoleSecurityGroup;

# $Id: DicoleSecurityGroup.pm,v 1.3 2009-01-07 14:42:33 amv Exp $

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Security qw( :receiver :target :check );
use Dicole::MessageHandler qw( :message );

use Dicole::Utility;
use Dicole::URL;

use Dicole::Generictool;
use Dicole::Generictool::Wizard;

sub list {
    my ( $self ) = @_;

    $self->init_tool;

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security'),
            current_view => 'group_list'
        )
    );

    $self->gtool->Data->add_where( 'receiver_type = ' . RECEIVER_GROUP  );
    $self->gtool->Data->add_where( 'target_type = ' . TARGET_SYSTEM  );
    
    $self->init_fields;

	$self->tool->Container->box_at( 0, 0 )->name( $self->_msg("Groups' rights") );
	$self->tool->Container->box_at( 0, 0 )->add_content(
		$self->gtool->get_list
	);

    return $self->generate_tool_content;
}


sub add {

	my ( $self ) = @_;

	$self->init_tool;

	my $wizard = $self->_init_wizard( 
		cancel_redirect => Dicole::URL->create_from_current(
                task => 'list'
        ),
	);

  	if( $wizard->has_more_pages ) {
        $wizard->apply_to_tool( $self->tool );
  	}
  	elsif( $wizard->finished ) {
		$self->tool->add_message( $self->_save_wizard_results( $wizard->results ) );

        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'list'
            )
        );
  	}

    return $self->generate_tool_content;


}

sub del {
    my ( $self ) = @_;

    $self->init_tool;

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security'),
            current_view => 'group_del'
        )
    );
    
    $self->init_fields;

    $self->gtool->Data->add_where( 'receiver_type = ' . RECEIVER_GROUP  );
    $self->gtool->Data->add_where( 'target_type = ' . TARGET_SYSTEM );

    if ( CTX->request->param( 'remove' ) ) {
        $self->tool->add_message( $self->gtool->Data->remove_group( 'sel' ) );
    }
    
    $self->gtool->bottom_buttons( [
        {
            value => $self->_msg('Remove'),
            name => 'remove'
        }
    ] );

	$self->tool->Container->box_at( 0, 0 )->name( $self->_msg("Remove groups' rights") );
	$self->tool->Container->box_at( 0, 0 )->add_content(
		$self->gtool->get_sel
	);

    return $self->generate_tool_content;
}

sub _init_wizard {
	my ($self, %p) = @_;

    my $p = \%p;	
  	my $wizard = Dicole::Generictool::Wizard->new( %{ $p->{wizard_params} } );

    # GROUPS SELECT

	my $group_selection_page = $wizard->add_advanced_select_page( 
		select_name => $self->_msg('Select groups'),
        selected_name => $self->_msg('Selected groups'),
		gtool_options => {
			object => CTX->lookup_object('groups'),
            skip_security => 1,
		},
		field_options => {
			id => 'groups',
			value => $p->{defaults}->{groups},
		}
	);

    $self->init_fields(
        gtool => $group_selection_page->Generictool,
        view => 'select_groups',
    );

    # COLLECTION SELECT

	my $coll_selection_page = $wizard->add_advanced_select_page( 
		select_name => $self->_msg('Select collections'),
        selected_name => $self->_msg('Selected collections'),
		gtool_options => {
			object => CTX->lookup_object('dicole_security_collection'),
            skip_security => 1,
		},
		field_options => {
			id => 'collections',
			value => $p->{defaults}->{collections},
		}
	);

    $coll_selection_page->Generictool->Data->add_where(
        "target_type = " . TARGET_SYSTEM
    );

    $self->init_fields(
        gtool => $coll_selection_page->Generictool,
        view => 'collections',
    );


	$wizard->activate();

	return $wizard;
}

sub _save_wizard_results {
    my ( $self, $results ) = @_;

    my $groups = $results->{groups} || [];
    my $collections = $results->{collections} || [];

    foreach my $gid ( @$groups ) {
        foreach my $cid ( @$collections ) {

            my $o = CTX->lookup_object('dicole_security')->new;
            $o->{receiver_group_id} = $gid;
            $o->{collection_id} = $cid;
            $o->{target_type} = TARGET_SYSTEM;
            $o->{receiver_type} = RECEIVER_GROUP;

            $o->save;
        }
    }

    return ( MESSAGE_SUCCESS, $self->_msg('Securities added') );
}
1;
