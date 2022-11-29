package OpenInteract2::Action::DicoleSecurityCollections;

# $Id: DicoleSecurityCollections.pm,v 1.8 2009-01-07 14:42:33 amv Exp $

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;
use Dicole::Content::List;
use Dicole::Tool;
use Dicole::MessageHandler qw( :message );
use Dicole::Generictool;
use Dicole::Utility;
use Data::Dumper;
use Dicole::Generictool::Wizard;
use Dicole::Security qw( :target :check );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);
our $author  = 'hannes@ionstream.fi';


#### PUBLIC METHODS ####


##################
# ACTION METHODS #
###########################################################
#
# These methods produce the content displayed to the user.
#
###########################################################


# Prints the list of security collections. Uses Generictool.
sub list {
    my ( $self ) = @_;

    $self->init_tool;
    $self->_init_generictool;

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'List of collections' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}




# Prints the list of security collections with checkboxes.
# Also handles the deletion of selected objects. Uses Generictool.
sub del {
    my ( $self ) = @_;

    $self->init_tool;
    $self->_init_generictool;

    $self->gtool->Data->add_where( "archetype = ''" );

    if ( CTX->request->param( 'del' ) ) {

        $self->tool->add_message( $self->gtool->Data->remove_group( 'sel' ) );
    }

    $self->gtool->bottom_buttons( [ {
        type  => 'confirm_submit',
        value => $self->_msg( 'Remove selected collections' ),
        confirm_box => {
            title => $self->_msg( 'Confirmation' ),
            name => 'del',
            msg => $self->_msg( 'Are you sure you want to remove the selected collections?' )
        }
    } ] );


    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'List of collections' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_sel
    );

    return $self->generate_tool_content;
}


# Prints details of the collection with the id specified in an apache parameter.
# Uses Generictool.
sub details {
    my ( $self ) = @_;

    my $collection_id = CTX->request->param( 'id' );
    my $collection = CTX->lookup_object('dicole_security_collection')->fetch(
        $collection_id
    );

    # go somewhere instead ?
    return if !$collection;

    $self->init_tool( { tab_override => 'list' } );
    $self->_init_generictool;

    $self->gtool->bottom_buttons( [ {
            type  => 'link',
            value => $self->_msg( 'Edit' ),
            link  => Dicole::URL->create_from_current(
                task => 'edit',
                params => { id => $collection_id },
            ),
        }, {
            type  => 'link',
            value => $self->_msg( 'Show list' ),
            link  => Dicole::URL->create_from_current(
                task => 'list',
            ),
    } ] );


    my ( $list, $buttons ) = @{ $self->gtool->get_show( object => $collection ) };

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Collection details' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( [
        $list,
        $self->_collection_level_table( $collection ),
        $buttons
    ] );

    return $self->generate_tool_content;
}




# Prints the add collection page(s). Uses Wizard.
sub add {
    my ( $self ) = @_;

    $self->init_tool;
    my $wizard = $self->_init_wizard(
        cancel_redirect => Dicole::URL->create_from_current
    );

    if( $wizard->has_more_pages ) {

        $wizard->apply_to_tool( $self->tool );
    }
    elsif( $wizard->finished ) {

        $self->tool->add_message(
            $self->_save_collection_wizard_results( $wizard->results )
        );

        return CTX->response->redirect(
            Dicole::URL->create_from_current
        );
    }

    return $self->generate_tool_content;
}




# Prints the edit collection page(s). Uses Wizard.
sub edit {
    my ( $self ) = @_;

    $self->init_tool( { tab_override => 'list' } );

    my $collectionID = CTX->request->param( 'id' );
    my $collection_obj = CTX->lookup_object('dicole_security_collection')->fetch( $collectionID );

    # go somewhere
    return if !$collection_obj;

    # TRIM
    my $collection_levels = $collection_obj->dicole_security_level;
    my @collection_level_ids = map { $_->id } @$collection_levels;

    my $default_values = {
        name => $collection_obj->{name},
        target_type => $collection_obj->{target_type},
        type => $collection_obj->{type},
    };

    $default_values->{world_sec_levels} = \@collection_level_ids if( $collection_obj->{target_type} == TARGET_SYSTEM );
    $default_values->{group_sec_levels} = \@collection_level_ids if( $collection_obj->{target_type} == TARGET_GROUP );
    $default_values->{user_sec_levels} = \@collection_level_ids if( $collection_obj->{target_type} == TARGET_USER );

    my $wizard = $self->_init_wizard(
        defaults => $default_values,
        cancel_redirect => Dicole::URL->create_from_current(
            task => 'details',
            params =>  { id => $collectionID },
        ),
        hidden_fields => { id => $collectionID },
    );

    if( $wizard->has_more_pages ) {

        $wizard->apply_to_tool( $self->tool );
    }
    elsif( $wizard->finished ) {

        $self->tool->add_message(
            $self->_save_collection_wizard_results( $wizard->results, $collection_obj )
        );

        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'details',
                params =>  { id => $collectionID },
            )
        );
    }

    return $self->generate_tool_content;
}




#### PRIVATE METHODS: ####


############################
# INITIALIZATION FUNCTIONS #
################################################################
#
# These functions are used by the action methods to initialize
# the objects they need (Tool, Generictool and/or Wizard).
#
################################################################


# Initializes the generictool object
sub _init_generictool {
    my $self = shift;

    # Create new Generictool object
    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('dicole_security_collection'),
            current_view => ( split '::', ( caller(1) )[3] )[-1],
        )
    );

    $self->init_fields( package => 'dicole_security' );

}




# Initializes the wizard used while adding and editing collections.
sub _init_wizard {
    my ($self, %args) = @_;

    my $wizard = Dicole::Generictool::Wizard->new( %args );

    #########
    # SELECT COLLECECTION INFORMATION
    #########

    my $general_info_page = $wizard->add_page( name => $self->_msg( 'General collection information' ) );

    $self->init_fields(
        package => 'dicole_security',
        defaults => $args{defaults},
        gtool => $general_info_page->Generictool,
        view => ( split '::', ( caller(1) )[3] )[-1],
    );

    #########
    # SELECT LEVELS
    #########

    my $sec_selection_page = $wizard->add_page_switch;

    my $world_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'World levels' ),
        selected_name => $self->_msg( 'Selected levels' ),
        display_if => { target_type => TARGET_SYSTEM },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_level'),
        },
        field_options => {
            id => 'world_sec_levels',
            value => $args{defaults}->{world_sec_levels} || undef
        }
    );

    my $user_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'User levels' ),
        selected_name => $self->_msg( 'Selected levels' ),
        display_if => { target_type => TARGET_USER },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_level'),
        },
        field_options => {
            id => 'user_sec_levels',
            value => $args{defaults}->{user_sec_levels} || undef
        }
    );

    my $group_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Group levels' ),
        selected_name => $self->_msg( 'Selected levels' ),
        display_if => { target_type => TARGET_GROUP },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_level'),
        },
        field_options => {
            id => 'group_sec_levels',
            value => $args{defaults}->{group_sec_levels} || undef
        }
    );

    # set the where-clauses to the advanced selection lists
    # (for example we want to show only group rights in the group right selection page)

    $world_selection_page->Generictool->Data->where("target_type = " . TARGET_SYSTEM);
    $user_selection_page->Generictool->Data->where("target_type = " . TARGET_USER);
    $group_selection_page->Generictool->Data->where("target_type = " . TARGET_GROUP);

    # Each conditional page has the same fields:
    foreach my $advpage ( $world_selection_page, $user_selection_page, $group_selection_page ) {
        $self->init_fields(
            package => 'dicole_security',
            gtool => $advpage->Generictool,
            view => 'levels',
        );
    }

    $wizard->activate();

    return $wizard;
}




######################
# DATABASE FUNCTIONS #
#################################################################
#
# These functions are used to edit/remove/add new spops objects.
#
#################################################################


# Processes and saves the results of the wizard (both add & edit).
# If $spop_object is given, a new one isn't created (used in edit wizard).
sub _save_collection_wizard_results {
    my ( $self, $results, $spops_object ) = @_;

    $spops_object = CTX->lookup_object('dicole_security_collection')->new() unless( defined $spops_object );

    $spops_object->{target_type} = $results->{target_type};
    $spops_object->{name} = $results->{name};
    $spops_object->{allowed} = $results->{allowed};
    $spops_object->{modified} = $results->{modified}; # every object which goes through his function is "modified"
    $spops_object->{secure} = ''; # compute this to be all levels securities
    $spops_object->save();

    my $selected_sec_levels;
    if( $results->{target_type} == TARGET_SYSTEM ) { $selected_sec_levels = $results->{world_sec_levels}; }
    elsif( $results->{target_type} == TARGET_GROUP ) { $selected_sec_levels = $results->{group_sec_levels}; }
    elsif( $results->{target_type} == TARGET_USER ) { $selected_sec_levels = $results->{user_sec_levels}; }

    Dicole::Utility->renew_links_to(
        object => $spops_object,
        relation => 'dicole_security_level',
        new => $selected_sec_levels,
    );

    return (MESSAGE_SUCCESS, $self->_msg( 'Collection saved' ));
}




#####################
# CONTENT FUNCTIONS #
#####################################################
#
# These functions are used to generate page content.
#
#####################################################


# Returns a Dicole::Content::List object that contains the
# attributes of the security levels of the collection given.
sub _collection_level_table {
    my ( $self, $collection ) = @_;

    return if !$collection;

    my $list = Dicole::Content::List->new( type => 'vertical' );
    $list->add_keys( [
        { name => $self->_msg( 'Security level name' ) },
        { name => $self->_msg( 'Security level description' ) },
        { name => $self->_msg( 'Module' ) },
    ] );

    my $levels = $collection->dicole_security_level;

    foreach my $col ( @{ $levels } ) {
        $list->add_content( [ [
            { content => $self->_msg( $col->{name} ) },
            { content => $self->_msg( $col->{description} ) },
            { content => $col->{oi_module} },
        ] ] );
    }

    return $list;
}



1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleSecurityCollections - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
