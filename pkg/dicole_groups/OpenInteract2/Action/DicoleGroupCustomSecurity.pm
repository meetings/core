package OpenInteract2::Action::DicoleGroupCustomSecurity;

# $Id: DicoleGroupCustomSecurity.pm,v 1.12 2009-01-07 14:42:33 amv Exp $

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Security qw( :receiver :target :check );
use Dicole::MessageHandler qw( :message );

use Dicole::Generictool;
use Dicole::Generictool::Wizard;

use Dicole::Utility;
use Dicole::URL;

sub member_list {
    my ( $self ) = @_;

    $self->init_tool;

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security'),
            current_view => 'member_list'
        )
    );

    $self->gtool->Data->add_where(
        'target_group_id = ' . CTX->request->active_group
        . ' AND receiver_type = ' . RECEIVER_USER
        . ' AND target_type = ' . TARGET_GROUP
    );

    $self->init_fields( package => 'dicole_groups' );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Default members right settings') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}


sub member_add {

    my ( $self ) = @_;

    $self->init_tool;

    my $wizard = $self->_init_wizard(
        cancel_redirect => Dicole::URL->create_from_current(
                task => 'member_list'
        ),
    );

    if( $wizard->has_more_pages ) {
        $wizard->apply_to_tool( $self->tool );
    }
    elsif( $wizard->finished ) {
        $self->tool->add_message( $self->_save_wizard_results( $wizard->results ) );

        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'member_list'
            )
        );
    }

    return $self->generate_tool_content;


}

sub member_remove {
    my ( $self ) = @_;

    $self->init_tool;

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security'),
            current_view => 'member_remove'
        )
    );

    $self->init_fields( package => 'dicole_groups' );

    $self->gtool->Data->add_where(
        'target_group_id = ' . CTX->request->active_group
        . ' AND receiver_type = ' . RECEIVER_USER
        . ' AND target_type = ' . TARGET_GROUP
    );

    if ( CTX->request->param( 'remove' ) ) {
        $self->tool->add_message( $self->gtool->Data->remove_group( 'sel' ) );
    }

    $self->gtool->bottom_buttons( [
        {
            value => $self->_msg('Remove'),
            name => 'remove'
        }
    ] );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Remove members right settings') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_sel
    );

    return $self->generate_tool_content;
}

sub _init_wizard {
    my ($self, %p) = @_;

    my $p = \%p;
    my $wizard = Dicole::Generictool::Wizard->new( %{ $p->{wizard_params} } );

    # USERS SELECT

    my $user_selection_page = $wizard->add_advanced_select_page(
        select_name => $self->_msg('Select users'),
        selected_name => $self->_msg('Selected users'),
        gtool_options => {
            object => CTX->lookup_object('user'),
            skip_security => 1,
        },
        field_options => {
            id => 'users',
            value => $p->{defaults}->{users},
        }
    );

    my $group = CTX->lookup_object('groups')->fetch( $self->active_group );
    my $id_field = $user_selection_page->Generictool->Data->object->id_field;
    $user_selection_page->Generictool->Data->selected_where(
        list => { $id_field => [
            map { $_->id }
            @{ $group->user( { skip_security => 1 } ) }
        ] }
    );

    $self->init_fields(
        gtool => $user_selection_page->Generictool,
        view => 'user',
        package => 'dicole_groups',
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
        "target_type = " . TARGET_GROUP
    );

    $self->init_fields(
        gtool => $coll_selection_page->Generictool,
        view => 'collection',
        package => 'dicole_groups',
    );


    $wizard->activate();

    return $wizard;
}

sub _save_wizard_results {
    my ( $self, $results ) = @_;

    my $users = $results->{users} || [];
    my $collections = $results->{collections} || [];

    foreach my $uid ( @$users ) {
        foreach my $cid ( @$collections ) {

            my $o = CTX->lookup_object('dicole_security')->new;
            $o->{receiver_user_id} = $uid;
            $o->{target_group_id} = CTX->request->active_group;
            $o->{collection_id} = $cid;
            $o->{target_type} = TARGET_GROUP;
            $o->{receiver_type} = RECEIVER_USER;

            $o->save;
        }
    }

    return ( MESSAGE_SUCCESS, $self->_msg('Securities added') );
}
1;
