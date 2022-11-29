package OpenInteract2::Action::DicoleSecuritySpecial;

# $Id: DicoleSecuritySpecial.pm,v 1.7 2009-01-07 14:42:33 amv Exp $

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Tool;
use Dicole::MessageHandler qw( :message );

use Dicole::Generictool;
use Dicole::Generictool::Wizard;

use Dicole::Security qw( :target :receiver :check );
use Dicole::URL;

use Data::Dumper;

use base qw( Dicole::Action Dicole::Action::Common::Remove );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);
our $author            = 'antti@ionstream.fi';


# Prints the add collection page(s). Uses Wizard.

sub add {
    my ( $self ) = @_;


    my $tool = $self->init_tool;
    $tool->Path->add( name => $self->_msg( 'Add new security settings' ) );

    my $wizard = $self->_init_wizard(
        cancel_redirect => Dicole::URL->create_from_current
    );

    if( $wizard->has_more_pages() ) {
        $wizard->apply_to_tool( $tool );
    }
    elsif( $wizard->finished() ) {
        $tool->add_message( $self->_save_wizard_results( $wizard->results ) );

        return CTX->response->redirect(
            Dicole::URL->create_from_current
        );
    }

    return $self->generate_tool_content;
}



sub _init_wizard {
    my ($self, %args) = @_;

    my $wizard = Dicole::Generictool::Wizard->new( %args );



    #########
    # SELECT RECEIVER AND TARGET TYPES
    #########

    my $general_info_page = $wizard->add_page( name => $self->_msg( 'Receiver and target types' ) );
    my $general_gtool = $general_info_page->Generictool;

    $self->init_fields(
        package => 'dicole_security',
        view => 'generic_info',
        gtool => $general_gtool,
    );



    #########
    # SELECT COLLECTIONS
    #########

    # Note: These are different pages so that we do not accidentally
    # assign more than the correct selected rights.
    # ( for example if somebody changes to target group after
    # already selecting some target user rights )

    my $sec_selection_page = $wizard->add_page_switch();

    my $user_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the collections' ),
        selected_name => $self->_msg( 'Selected collections' ),
        display_if => { target_type => TARGET_USER },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_collection'),
            skip_security => 1,
            default_sort => { column => 'name', order => 'ASC' },
        },
        field_options => {
            id => 'user_sec_collections',
            value => $args{defaults}->{user_sec_collections}
        },
    );

    my $group_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the collections' ),
        selected_name => $self->_msg( 'Selected collections' ),
        display_if => { target_type => TARGET_GROUP },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_collection'),
            skip_security => 1,
            default_sort => { column => 'name', order => 'ASC' },
        },
        field_options => {
            id => 'group_sec_collections',
            value => $args{defaults}->{group_sec_collections}
        },
    );

    my $world_selection_page = $sec_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the collections' ),
        selected_name => $self->_msg( 'Selected collections' ),
        display_if => { target_type => TARGET_SYSTEM },
        gtool_options => {
            object => CTX->lookup_object('dicole_security_collection'),
            skip_security => 1,
            default_sort => { column => 'name', order => 'ASC' },
        },
        field_options => {
            id => 'world_sec_collections',
            value => $args{defaults}->{world_sec_collections}
        },
    );

    $world_selection_page->Generictool->Data->where("target_type = " . TARGET_SYSTEM);
    $user_selection_page->Generictool->Data->where("target_type = " . TARGET_USER);
    $group_selection_page->Generictool->Data->where("target_type = " . TARGET_GROUP);

    # Each conditional page has the same fields:
    foreach my $advpage ( $world_selection_page, $user_selection_page, $group_selection_page ) {

        $self->init_fields(
            package => 'dicole_security',
            view => 'collections',
            gtool => $advpage->Generictool,
        );
    }



    #########
    # SELECT TARGETS
    #########


    my $target_selection_page = $wizard->add_page_switch();

    my $user_target_selection_page = $target_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the users which the rights will target' ),
        selected_name => $self->_msg( 'Selected targets' ),
        display_if => { target_type => TARGET_USER },
        gtool_options => {
            object => CTX->lookup_object('user'),
            skip_security => 1,
            default_sort => { column => 'login_name', order => 'ASC' },
        },
        field_options => {
            id => 'user_targets',
            value => $args{defaults}->{user_targets}
        },
    );

    $self->init_fields(
        package => 'dicole_security',
        view => 'select_users',
        gtool => $user_target_selection_page->Generictool,
    );

    my $group_target_selection_page = $target_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the groups which the rights will target' ),
        selected_name => $self->_msg( 'Selected targets' ),
        display_if => { target_type => TARGET_GROUP },
        gtool_options => {
            object => CTX->lookup_object('groups'),
            default_sort => { column => 'name', order => 'ASC' },
        },
        field_options => {
            id => 'group_targets',
            value => $args{defaults}->{group_targets}
        },
    );

    $self->init_fields(
        package => 'dicole_security',
        view => 'select_groups',
        gtool => $group_target_selection_page->Generictool,
    );

    my $world_target_selection_page = $target_selection_page->add_info_page(
        name => $self->_msg( 'Select targets' ),
        display_if => { target_type => TARGET_SYSTEM },
        info => $self->_msg( 'Rights will target the whole system. Proceed to the next step.' ),
    );



    #########
    # SELECT RECEIVERS
    #########


    my $receiver_selection_page = $wizard->add_page_switch();

    my $user_receiver_selection_page = $receiver_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select the users who receive these rights' ),
        selected_name => $self->_msg( 'Selected receivers' ),
        display_if => { receiver_type => RECEIVER_USER },
        gtool_options => {
            object => CTX->lookup_object('user'),
            skip_security => 1,
            default_sort => { column => 'login_name', order => 'ASC' },
        },
        field_options => {
            id => 'user_receivers',
            value => $args{defaults}->{user_receivers}
        },
    );

    $self->init_fields(
        package => 'dicole_security',
        view => 'select_users',
        gtool => $user_receiver_selection_page->Generictool,
    );

    my $group_receiver_selection_page = $receiver_selection_page->add_advanced_select_page(
        select_name => $self->_msg( 'Select groups which receive these rights' ),
        selected_name => $self->_msg( 'Selected receivers' ),
        display_if => { receiver_type => RECEIVER_GROUP },
        gtool_options => {
            object => CTX->lookup_object('groups'),
            default_sort => { column => 'name', order => 'ASC' },
        },
        field_options => {
            id => 'group_receivers',
            value => $args{defaults}->{group_receivers}
        },
    );

    $self->init_fields(
        package => 'dicole_security',
        view => 'select_groups',
        gtool => $group_receiver_selection_page->Generictool,
    );

    my $local_receiver_selection_page = $receiver_selection_page->add_info_page(
        name => $self->_msg( 'Select receivers' ),
        display_if => { receiver_type => RECEIVER_LOCAL },
        info => $self->_msg( 'Rights will be applied to all local users. Proceed to the next step.' ),
    );

    my $global_receiver_selection_page = $receiver_selection_page->add_info_page(
        name => $self->_msg( 'Select receivers' ),
        display_if => { receiver_type => RECEIVER_GLOBAL },
        info => $self->_msg( 'Rights will be applied globally. Proceed to the next step.' ),
    );

    $wizard->activate();

    return $wizard;
}


sub _save_wizard_results {
    my ( $self, $results ) = @_;

    my $object;
    my $receivers = [];

    if ( $results->{receiver_type} == RECEIVER_USER ) {
        $receivers = $results->{user_receivers} || [];
    }
    elsif ( $results->{receiver_type} == RECEIVER_GROUP ) {
        $receivers = $results->{group_receivers} || [];
    }
    else {
        $receivers = [ 0 ];
    }

    $object = CTX->lookup_object('dicole_security');

    return ( 0, $self->_msg( 'Error' ) ) if !$object;

    my $targets = [];
    my $collections = [];

    if ( $results->{target_type} == TARGET_USER ) {
        $targets = $results->{user_targets} || [];
        $collections = $results->{user_sec_collections} || [];
    }
    elsif ( $results->{target_type} == TARGET_GROUP ) {
        $targets = $results->{group_targets} || [];
        $collections = $results->{group_sec_collections} || [];
    }
    elsif ( $results->{target_type} == TARGET_SYSTEM ) {
        $targets = [ 0 ]; # just add once..
        $collections = $results->{world_sec_collections} || [];
    }

    foreach my $collection ( @$collections ) {
        foreach my $target ( @$targets ) {
            foreach my $receiver ( @$receivers ) {

                my $o = $object->new;

                if ( $results->{receiver_type} == RECEIVER_USER ) {
                    $o->{receiver_user_id} = $receiver;
                }
                if ( $results->{receiver_type} == RECEIVER_GROUP ) {
                    $o->{receiver_group_id} = $receiver;
                }

                if ( $results->{target_type} == TARGET_USER ) {
                    $o->{target_user_id} = $target;
                }
                if ( $results->{target_type} == TARGET_GROUP ) {
                    $o->{target_group_id} = $target;
                }
                
                $o->{collection_id} = $collection;

                $o->{target_type} = $results->{target_type};
                $o->{receiver_type} = $results->{receiver_type};

                $o->save;
            }
        }
    }

    return ( MESSAGE_SUCCESS, $self->_msg( 'Security settings added' ) );
}





1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleSecuritySpecial - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
