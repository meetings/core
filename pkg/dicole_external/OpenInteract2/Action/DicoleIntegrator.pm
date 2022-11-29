package OpenInteract2::Action::DicoleIntegrator;

# $Id: DicoleIntegrator.pm,v 1.12 2007-07-06 15:26:31 amv Exp $

use strict;

use base ( qw(
    Dicole::Action::Common::List
    Dicole::Action::Common::Edit
    Dicole::Action::Common::Show
) );

use Dicole::Security qw( :receiver :target :check );
use Dicole::MessageHandler qw( :message );
use Dicole::Generictool;
use Dicole::URL;
use Dicole::Utility;
use Dicole::Generictool::FakeObject;
use Text::CSV_XS;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

########################################
# Settings tab
########################################

sub add {
    my ($self) = @_;
    
    return OpenInteract2::Action::DicoleIntegrator::Add->new( $self, {
        box_title => 'New external integration details',
        class => 'externalsource',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

sub remove {
    my ($self) = @_;
    
    return OpenInteract2::Action::DicoleIntegrator::Remove->new( $self, {
        box_title => 'List of integrations',
        path_name => 'Remove integrations',
        class => 'externalsource',
        confirm_text => 'Are you sure you want to remove the selected integrations?',
        view => 'remove',
    } )->execute;
}

# Generates parent navigation element selection dropdown
sub _generate_navparents {
    my ( $self ) = @_;
    my $nav_dropdown = $self->gtool->get_field( 'navigation_parent' );
    $nav_dropdown->add_dropdown_item( 0, $self->_msg( '-' ) );
    my $navs = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navparent like "tab_%"',
        order => 'ordering',
    } );
    foreach my $nav ( @{ $navs } ) {
        $nav_dropdown->add_dropdown_item( $nav->{navid}, $self->_msg( $nav->{name} ) );
    }
    $navs = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navparent = ?',
        value => [ 'space_groups' ],
        order => 'ordering',
    } );
    foreach my $nav ( @{ $navs } ) {
        $nav_dropdown->add_dropdown_item( $nav->{navid},
            $self->_msg( 'Group' ) . ' > ' . $self->_msg( $nav->{name} )
        );
    } 
}

sub _post_init_common_list {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_list;
}

# Replace inherited methods in Common::Show

sub _pre_init_common_show {
    my ( $self ) = @_;
    $self->_config_tool_show( 'tab_override', 'list' );
    $self->_config_tool_show( 'rows', 1 );
    return $self->SUPER::_pre_init_common_show;
}

sub _post_init_common_show {
    my ( $self, $id ) = @_;
    $self->SUPER::_post_init_common_show;
    $self->_generate_navparents;
    $self->_merge_fields( $id );
    # Tell gtool to skip construction of fields that are empty.
    # We limit the ammount of fields displayed this way
    $self->gtool->Construct->undef_if_empty( 1 );
}

sub _pre_init_common_edit {
    my ( $self ) = @_;
    $self->_config_tool_edit( 'tab_override', 'list' );
    return $self->SUPER::_pre_init_common_edit;
}

sub _post_init_common_edit {
    my ( $self, $id ) = @_;
    $self->SUPER::_post_init_common_edit( $id );
    $self->_generate_navparents;
    $self->_merge_fields( $id ) unless CTX->request->param( 'save' );
}

sub _merge_fields {
    my ( $self, $id ) = @_;
    my $fake_object = Dicole::Generictool::FakeObject->new;
    my $external = CTX->lookup_object( 'externalsource' )->fetch( $id );
    $self->gtool->fake_objects( [ $fake_object ] );
    $self->gtool->merge_fake_to_spops( 1 );
    my ( $csv );
    foreach my $field ( qw(groups_ids users_ids custom_fields) ) {
        $csv = Text::CSV_XS->new( { binary => 1 } );
        $csv->parse( $external->{$field} );
        foreach my $key ( $csv->fields ) {
            $fake_object->{$field} .= $key . "\n";
        }
    }
    $csv = Text::CSV_XS->new( { binary => 1 } );
    $csv->parse( $external->{parameters} );
    my %params = ( $csv->fields );
    foreach my $key ( keys %params ) {
        $fake_object->{parameters} .= $key . ' = ' . $params{$key} . "\n";
    }
    return unless $external->{navid};
    my $nav_item = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navid = ?',
        value => [ $external->{navid} ]
    } );
    $nav_item = $nav_item->[0];
    $fake_object->{navigation_active} = $nav_item->{active};
    $fake_object->{navigation_parent} = $nav_item->{navparent};
    $fake_object->{navigation_ordering} = $nav_item->{ordering};
    $fake_object->{navigation_persistent} = $nav_item->{persistent};
    $fake_object->{navigation_icon} = $nav_item->{icons};
    $fake_object->{navigation_name} = $nav_item->{name};
    $fake_object->{navigation_type} = $nav_item->{type};
    $fake_object->{navigation_class} = $nav_item->{navi_class};
    $fake_object->{navigation_id} = $nav_item->{navid};
    my $tool_item = CTX->lookup_object( 'tool' )->fetch_group( {
        where => 'toolid = ?',
        value => [ $external->{navid} ]
    } );
    $tool_item = $tool_item->[0];
    if ( ref $tool_item ) {
        $fake_object->{tool_name} = $tool_item->{name};
        $fake_object->{tool_description} = $tool_item->{description};
    }
}

sub _validate_input_edit {
    my ( $self, $id ) = @_;
    my ( $code, $message ) = $self->SUPER::_validate_input_edit( $id );
    return ( $code, $message ) unless $code;
    my $orig_external = CTX->lookup_object( 'externalsource' )->fetch( $id );
    my $nav_id = OpenInteract2::Action::DicoleIntegrator::Add
        ->_clean_nav_id( CTX->request->param( 'navigation_id' ) );
    my $nav_items = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navid = ?',
        value => [ $nav_id ]
    } );
    if ( $orig_external->{navid} ne $nav_id && ref $nav_items->[0] ) {
        $code = 0;
        $message = $self->_msg( 'Navigation item with name [_1] already exists.', $nav_id );
    }
    my $name = CTX->request->param( 'name' );
    $name =~ tr/0-9A-Za-z_-//cd;
    my $externals = CTX->lookup_object( 'externalsource' )->fetch_group( {
        where => 'name = ?',
        value => [ $name ]
    } );
    if ( $orig_external->{name} ne $name && ref $externals->[0] ) {
        $code = 0;
        $message = $self->_msg( 'Integration with name [_1] already exists.', $name );
    }
    unless ( $name ) {
        $code = 0;
        $message = $self->_msg( "Identification name not defined." )
    }
    return ( $code, $message );
}

sub _pre_save_edit {
    my ( $self, $data ) = @_;
    
    # Set package name as it is not tied to any package anymore
    $data->data->{package} = '-external integrator-';
    
    # Get rid of unwanted characters
    $data->data->{name} =~ tr/0-9A-Za-z_-//cd;
    
    # Convert to CSV
    $self->_convert_to_csv( $data->data );
    
    # If navigation is active but nav element does not exist, create it
    if ( CTX->request->param( 'navigation_active' ) && !$data->data->{navid} ) {
        my $nav_item = CTX->lookup_object( 'navigation_item' )->new;
        unless ( OpenInteract2::Action::DicoleIntegrator::Add
            ->_fill_nav_item( $nav_item, $data ) ) {
            $self->tool->add_message( 0,
                $self->_msg( "Navigation identification name not defined." )
            );
            return 0;
        }
        my $tool_item = CTX->lookup_object( 'tool' )->fetch_group( {
            where => 'toolid = ?',
            value => [ $nav_item->{navid} ]
        } );
        $tool_item = $tool_item->[0];
        $tool_item = CTX->lookup_object( 'tool' )->new unless ref $tool_item;
        OpenInteract2::Action::DicoleIntegrator::Add
            ->_fill_tool_item( $tool_item, $data );
        return 1;
    }
    # If navigation is not present, simply just skip editing it
    elsif ( !$data->data->{navid} ) {
        return 1;
    }
    my $nav_item = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navid = ?',
        value => [ $data->data->{navid} ]
    } );
    return 1 unless ref( $nav_item->[0] );
    OpenInteract2::Action::DicoleIntegrator::Add
            ->_fill_nav_item( $nav_item->[0], $data );
    # Do the same for tool item
    my $tool_item = CTX->lookup_object( 'tool' )->fetch_group( {
        where => 'toolid = ?',
        value => [ $data->data->{navid} ]
    } );
    return 1 unless ref( $tool_item->[0] );
    OpenInteract2::Action::DicoleIntegrator::Add
            ->_fill_tool_item( $tool_item->[0], $data );
    return 1;
}

sub _convert_to_csv {
    my ( $self, $data ) = @_;
    my ( $csv, @fields );
    foreach my $field ( qw(groups_ids users_ids custom_fields) ) {
        $csv = Text::CSV_XS->new( { binary => 1 } );
        @fields = ();
        foreach my $line ( split /\r?\n/, $data->{$field} ) {
            next if $line =~ /^\s*$/;
            push @fields, $line;
        }
        $csv->combine( @fields );
        $data->{$field} = $csv->string;
    }
    $csv = Text::CSV_XS->new( { binary => 1 } );
    @fields = ();
    foreach my $line ( split /\r?\n/, $data->{parameters} ) {
        next if $line =~ /^\s*$/;
        my ( $key, $value ) = split( /\s+=\s+/, $line );
        push @fields, ( $key, $value );
    }
    $csv->combine( @fields );
    $data->{parameters} = $csv->string;
}

package OpenInteract2::Action::DicoleIntegrator::Add;

use base 'Dicole::Task::GTAdd';
use OpenInteract2::Context   qw( CTX );

sub _post_init {
    my ( $self ) = @_;
    $self->action->_generate_navparents;
}

sub _pre_save {
    my ( $self, $data ) = @_;
    # Set package as zero, meaning it's not installed from any package
    $data->data->{package} = '-external integrator-';
    # Get rid of unwanted characters
    $data->data->{name} =~ tr/0-9A-Za-z_-//cd;
    $self->action->_convert_to_csv( $data->data );
    unless ( $data->data->{name} ) {
        $self->action->tool->add_message( 0,
            $self->action->_msg( "Identification name not defined." )
        );
        return 0;
    }
    # Create navigation item and fill it based on form
    if ( CTX->request->param( 'navigation_active' ) ) {
        my $nav_item = CTX->lookup_object( 'navigation_item' )->new;
        unless ( $self->_fill_nav_item( $nav_item, $data ) ) {
            $self->action->tool->add_message( 0,
                $self->action->_msg( "Navigation identification name not defined." )
            );
            return 0;
        }
        my $tool_item = CTX->lookup_object( 'tool' )->fetch_group( {
            where => 'toolid = ?',
            value => [ $nav_item->{navid} ]
        } );
        $tool_item = $tool_item->[0];
        $tool_item = CTX->lookup_object( 'tool' )->new unless ref $tool_item;
        $self->_fill_tool_item( $tool_item, $data );
    }
    else {
        $data->data->{navid} = 0;
    }
    return 1;
}

sub _fill_nav_item {
    my ( $self, $nav_item, $data ) = @_;
    $nav_item->{secure} = '';
    $nav_item->{groups_ids} = $data->data->{groups_ids};
    $nav_item->{users_ids} = $data->data->{users_ids};
    $nav_item->{'package'} = '-external integrator-';
    $nav_item->{localize} = 1;
    $nav_item->{active} = CTX->request->param( 'navigation_active' ) || 0;
    $nav_item->{type} = CTX->request->param( 'navigation_type' );
    $nav_item->{navi_class} = CTX->request->param( 'navigation_class' ) || '';
    $nav_item->{name} = CTX->request->param( 'navigation_name' ) || 'Null';
    $nav_item->{navid} = CTX->request->param( 'navigation_id' );
    $nav_item->{navid} = $nav_item->{name} unless $nav_item->{navid};
    $nav_item->{navid} = $self->_clean_nav_id( $nav_item->{navid} );
    unless ( $nav_item->{navid} ) {
        return undef;
    }
    $nav_item->{navparent} = CTX->request->param( 'navigation_parent' );
    $nav_item->{ordering} = CTX->request->param( 'navigation_ordering' ) || 0;
    $nav_item->{persistent} = CTX->request->param( 'navigation_persistent' ) || 0;
    $nav_item->{icons} = CTX->request->param( 'navigation_icon' );
    my $linked_id = 0;
    if ( $data->data->{external_type} == 1 ) {
        $linked_id = '%%userid%%';
    }
    elsif ( $data->data->{external_type} == 2 ) {
        $linked_id = '%%groupid%%';
    }
    $nav_item->{'link'} = '/external/' . $data->data->{name} . '/' . $linked_id;
    $nav_item->save;
    # Store navigation id in external tool
    $data->data->{navid} = $nav_item->{navid};
    return $nav_item;
}

sub _fill_tool_item {
    my ( $self, $tool_item, $data ) = @_;
    $tool_item->{secure} = '';
    $tool_item->{toolid} = $data->data->{navid};
    $tool_item->{name} = CTX->request->param( 'tool_name' );
    $tool_item->{description} = CTX->request->param( 'tool_description' );
    $tool_item->{icon} = undef;
    $tool_item->{summary} = '';
    $tool_item->{'package'} = '-external integrator-';
    my $type = undef;
    if ( $data->data->{external_type} == 1 ) {
        $type = 'personal';
    }
    elsif ( $data->data->{external_type} == 2 ) {
        $type = 'group';
    }
    else {
        $type = 'admin';
    }
    $tool_item->{type} = $type;
    $tool_item->{groups_ids} = $data->data->{groups_ids};
    $tool_item->{users_ids} = $data->data->{users_ids};
    $tool_item->save;
    return $tool_item;
}

sub _clean_nav_id {
    my ( $self, $nav_id ) = @_;
    $nav_id = lc $nav_id;
    $nav_id =~ tr/0-9a-z_-//cd;
    return $nav_id;
}

sub _validate_input {
    my ( $self ) = @_;
    my ( $code, $message ) = $self->SUPER::_validate_input;
    return ( $code, $message ) unless $code;
    my $nav_id = $self->_clean_nav_id( CTX->request->param( 'navigation_id' ) );
    my $nav_items = CTX->lookup_object( 'navigation_item' )->fetch_group( {
        where => 'navid = ?',
        value => [ $nav_id ]
    } );
    if ( ref $nav_items->[0] ) {
        $code = 0;
        $message = $self->action->_msg( 'Navigation item with name [_1] already exists.', $nav_id );
    }
    my $name = CTX->request->param( 'name' );
    $name =~ tr/0-9a-zA-Z_-//cd;
    my $externals = CTX->lookup_object( 'externalsource' )->fetch_group( {
        where => 'name = ?',
        value => [ $name ]
    } );
    if ( ref $externals->[0] ) {
        $code = 0;
        $message = $self->action->_msg( 'Integration with name [_1] already exists.', $name );
    }
    return ( $code, $message );
}

sub _post_save {
    my ( $self, $data ) = @_;
    foreach my $object_field ( keys %{ $data->data } ) {
        $data->data->{$object_field} = '';
    }
    return $self->action->_msg( "Integration has been saved." );
}

package OpenInteract2::Action::DicoleIntegrator::Remove;

use base 'Dicole::Task::GTRemove';
use OpenInteract2::Context   qw( CTX );

sub _pre_remove {
    my ( $self, $ids, $data ) = @_;
    foreach my $external_id ( keys %{ $ids } ) {
        my $external = CTX->lookup_object( 'externalsource' )->fetch( $external_id );
        if ( $external->{navid} ) {
            my $nav_items = CTX->lookup_object( 'navigation_item' )->fetch_group( {
                where => 'navid = ?',
                value => [ $external->{navid} ]
            } );
            if ( ref $nav_items->[0] ) { $nav_items->[0]->remove }
            my $tool_items = CTX->lookup_object( 'tool' )->fetch_group( {
                where => 'toolid = ?',
                value => [ $external->{navid} ]
            } );
            if ( ref $tool_items->[0] ) { $tool_items->[0]->remove }
        }
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleIntegrator - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS


