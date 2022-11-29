package OpenInteract2::Manage::Website::RegisterTool;

use strict;
use base qw( OpenInteract2::Manage::Website Dicole::Registerer );
use OpenInteract2::Context   qw( CTX );
use Dicole::Security qw( :receiver :target );
use File::Spec;
use Data::Dumper;

sub get_name {
    return 'register_tool';
}

sub get_brief_description {
    return "Registers packages tool data into websites database";
}

sub get_parameters {

    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package     => $self->_get_package_param,
    };
}
sub setup_task {

    my ( $self ) = @_;
    $self->_setup_context();
}

sub run_task {

    my ( $self ) = @_;

    my $repository = CTX->repository;

    foreach my $package_name ( @{ $self->param( 'package' ) } ) {

        my $package = $repository->fetch_package( $package_name );

        die "Couldn't find package $package: $!" if !$package;

        my $toolini = File::Spec->catfile(
    		$repository->full_config_dir, $package_name, 'tool.ini'
	    );

        next if !-f $toolini;

        my $config = OpenInteract2::Config::Ini->new({ filename => $toolini });

        $self->register(
            object_name => 'tool',
            items => $config->{tool},
            defaults => {
                active => 1,
                ordering => 0,
                secure => '',
                groups_ids => '',
                users_ids => '',
                summary => '',
                summary_list => '',
                modified => 0,
            },
            id_fields => [ 'toolid' ],
            order_fields => { ordering => 1 },
            csv_fields => {
                secure => 'normal',
                summary => 'normal',
                groups_ids => 'normal',
                users_ids => 'normal',
            },
            package => $package_name,
        );

        $self->register(
            object_name => 'digest_source',
            items => $config->{digest},
            defaults => {
                active => 1,
                ordering => 0,
                type => '',
                action => '',
                secure => '',
                modified => 0,
            },
            id_fields => [ 'idstring' ],
            order_fields => { ordering => 1 },
            csv_fields => {
                secure => 'normal',
            },
            package => $package_name,
        );

        $self->register(
            object_name => 'navigation_item',
            items => $config->{navigation},
            defaults => {
                active => 1,
                ordering => 0,
                persistent => 0,
                groups_ids => '',
                users_ids => '',
                secure => '',
                icons => '',
                type => '',
                navi_class => '',
                localize => 1,
                modified => 0,
            },
            id_fields => [ 'navid' ],
            order_fields => { 'ordering' => 1 },
            csv_fields => {
                secure => 'normal',
                groups_ids => 'normal',
                users_ids => 'normal',
            },
            package => $package_name,
        );

        $self->register(
            object_name => 'dicole_security_meta',
            items => $config->{secmeta},
            defaults => {
                ordering => 0,
                idstring => '',
                name => '',
            },
            id_fields => [ 'idstring' ],
            order_fields => { 'order' => 1 },
            package => $package_name,
        );

        my ( $created_level_ids, $updated_level_ids ) = $self->register(
            object_name => 'dicole_security_level',
            items => $config->{seclevel},
            defaults => {
                target_type => 0,
                name => 'none',
                oi_module => 'Dicole::Security',
                id_string => 'none',
                description => 'no description',
                secure => '',
                archetype => '',
            },
            id_fields => [ 'oi_module', 'id_string', 'target_type' ],
            csv_fields => { secure => 'normal', archetype => 'normal' },
            package => $package_name,
        );

        $self->_merge_created_levels( $created_level_ids );
        $self->_merge_updated_levels( $updated_level_ids );

        my ( $created_collection_ids, $updated_collection_ids ) = $self->register(
            object_name => 'dicole_security_collection',
            items => $config->{seccollection},
            defaults => {
                target_type => 0,
                name => 'none',
                allowed => 0,
                idstring => '',
                meta => '',
                secure => '',
                archetype => '',
                modified => 0,
            },
            id_fields => [ 'package', 'name', 'target_type' ],
            csv_fields => { secure => 'normal', archetype => 'normal' },
            package => $package_name,
        );

        $self->_merge_created_collections( $created_collection_ids );
        $self->_merge_updated_collections( $updated_collection_ids );
    }

}

sub _merge_created_levels {
    my ( $self, $ids ) = @_;

    my $collections = $self->_add_levels_to_collections( $ids );

    $self->_update_collection_securities( $collections );
}

sub _merge_updated_levels {
    my ( $self, $ids ) = @_;

    my $collections = $self->_add_levels_to_collections( $ids, 'update' );

    $self->_update_collection_securities( $collections );
}

sub _merge_created_collections {
    my ( $self, $ids ) = @_;

    my $collections = $self->_fill_collections_with_levels( $ids );

    $self->_update_collection_securities( $collections );

    $self->_assign_superuser_rights( $ids );
    $self->_assign_default_global_rights( $ids );
}

sub _merge_updated_collections {
    my ( $self, $ids ) = @_;

    my $collections = $self->_fill_collections_with_levels( $ids, 'update' );

    $self->_update_collection_securities( $collections );
}


sub _add_levels_to_collections {
    my ( $self, $ids, $update ) = @_;

    return if ref $ids ne 'ARRAY';

    my $levelobject = CTX->lookup_object( 'dicole_security_level' );
    my $collectionobject = CTX->lookup_object( 'dicole_security_collection' );

    my $modified_collections = [];

    foreach my $id ( @$ids ) {

        # fetch level
        my $target = $levelobject->fetch( $id );

        # build archetype list
        my @atypes = split /\s*,\s*/, $target->{archetype};

        # We want to proceed even if there are no archetypes
        # since this way update cleares hanging

        # fetch all collections
        my $group = $collectionobject->fetch_group || [];


        # build archetype hash with collection arrays as values
        my $hash = {};

        foreach my $item ( @$group ) {

            my @itematypes = split  /\s*,\s*/, $item->{archetype};

            push @{ $hash->{ $_ } }, $item foreach @itematypes;

        }

        # add level to collections which have the same archetypes
        my $checked_collection_ids = {};

        foreach my $atype ( @atypes ) {

            next if ref $hash->{ $atype } ne 'ARRAY';

            foreach my $item ( @{ $hash->{ $atype } } ) {

                $checked_collection_ids->{ $item->id }++;
                
                # Do nothing if category modified/non-factory or things are correct
                next if ! $item->{package};
                next if $item->{modified};
                next if $update &&
                    $self->_collection_contains_level( $item, $target );

                $item->dicole_security_level_add( $target );
                push @$modified_collections, $item;
            }
        }
        
        # if this is an update, remove the level from all collections
        # which are not modified, from package and were not processed in last loop
        if ( $update ) {        
            foreach my $item ( @$group ) {
                next if ! $item->{package};
                next if $item->{modified};
                next if $checked_collection_ids->{ $item->id };
                next if ! $self->_collection_contains_level( $item, $target );

                eval { $item->dicole_security_level_remove( $target ); };
                push @$modified_collections, $item;
            }
        }        
    }

    return $modified_collections;
}


sub _fill_collections_with_levels {
    my ( $self, $ids, $update ) = @_;

    return if ref $ids ne 'ARRAY';

    my $levelobject = CTX->lookup_object( 'dicole_security_level' );
    my $collectionobject = CTX->lookup_object( 'dicole_security_collection' );

    my $modified_collections = [];

    foreach my $id ( @$ids ) {
    
        # fetch collection
        my $target = $collectionobject->fetch( $id );

        # don't touch modified or non-factory collections
        next if $target->{modified};
        next if ! $target->{package};
        
        # build archetype list
        my @atypes = split /\s*,\s*/, $target->{archetype};

        # We want to proceed even if there are no archetypes
        # since this way update cleares hanging

        # fetch all levels
        my $group = $levelobject->fetch_group || [];

        # build archetype hash with level arrays as values
        my $hash = {};

        foreach my $item ( @$group ) {
            my @itematypes = split  /\s*,\s*/, $item->{archetype};
            push @{ $hash->{ $_ } }, $item foreach @itematypes;
        }


        # add all levels that have matching archetypes to collection
        my $modified = 0;
        my $checked_level_ids = {};

        foreach my $atype ( @atypes ) {

            next if ref $hash->{ $atype } ne 'ARRAY';

            foreach my $item ( @{ $hash->{ $atype } } ) {

                $checked_level_ids->{ $item->id }++;
                
                # do nothing if things are correct
                next if $update &&
                    $self->_collection_contains_level( $target, $item );
                
                $target->dicole_security_level_add( $item );
                $modified = 1;
            }
        }
        
        # if this is an update, try to remove all other levels which
        # weren't just added, since they don't belong here anymore
        if ( $update ) {
            for my $item ( @$group ) {
                next if $checked_level_ids->{ $item->id };
                next if ! $self->_collection_contains_level( $target, $item );
            
                eval { $target->dicole_security_level_remove( $item ); };
                $modified = 1;
            }
        }
        push @$modified_collections, $target if $modified;
    }

    return $modified_collections;
}

sub _collection_contains_level {
    my ( $self, $coll, $lev ) = @_;
    
    my $levels = $coll->dicole_security_level( {
        where => 'level_id = ?',
        value => [ $lev->id ],
    } ) || [];

    return ( scalar @$levels ) ? 1 : 0;
}

sub _update_collection_securities {
    my ( $self, $collections ) = @_;

    # TODO: Update modified collections' secure!

}

sub _assign_superuser_rights {
    my ( $self, $ids ) = @_;

    my $collectionobject = CTX->lookup_object( 'dicole_security_collection' );
    my $securityobject = CTX->lookup_object( 'dicole_security' );

    foreach my $id ( @$ids ) {

        my $target = $collectionobject->fetch( $id );

        if ( $target->{idstring} eq 'system_administrator' ) {

            my $o = $securityobject->new;

            $o->{target_type} = TARGET_SYSTEM;
            $o->{receiver_type} = RECEIVER_USER;
            $o->{receiver_user_id} = 1; # superuser.. hopefully ;)
            $o->{collection_id} = $id;

            $o->save;
        }
        
        if ( $target->{idstring} eq 'default_personal_rights' ) {

            my $o = $securityobject->new;

            $o->{target_type} = TARGET_USER;
            $o->{receiver_type} = RECEIVER_USER;
            $o->{receiver_user_id} = 1; # superuser.. hopefully ;)
            $o->{target_user_id} = 1;
            $o->{collection_id} = $id;

            $o->save;
        }
    }
}

sub _assign_default_global_rights {
    my ( $self, $ids ) = @_;

    my $collectionobject = CTX->lookup_object( 'dicole_security_collection' );
    my $securityobject = CTX->lookup_object( 'dicole_security' );

    foreach my $id ( @$ids ) {

        my $target = $collectionobject->fetch( $id );

        if ( $target->{idstring} eq 'system_user_defaults' ) {

            my $o = $securityobject->new;

            $o->{target_type} = TARGET_SYSTEM;
            $o->{receiver_type} = RECEIVER_LOCAL;
            $o->{collection_id} = $id;

            $o->save;
        }
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
