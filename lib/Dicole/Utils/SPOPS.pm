package Dicole::Utils::SPOPS;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Utils::SQL;

=pod

=head2 fetch_objects()

Fetches all requested objects of the given type.

Works only for spops objects with numeral single column id.

Required params:
ids => arrayref of object ids

Required one of params:
object_name => name of objects to fetch
object => SPOPS object of the type of objects to fetch

=cut

sub fetch_objects {
    my ( $self, %p ) = @_;

    return [] unless ref( $p{ids} ) eq 'ARRAY';
    return [] unless scalar( @{ $p{ids} } );

    $p{object} ||= eval{ CTX->lookup_object( $p{object_name} ); };
    return [] unless $p{object};

    my @uniq = ();
    my %check = ();

    for my $id ( @{ $p{ids} } ) {
        next unless $id =~ /^\d+$/;
        next if exists $check{ $id };
        push @uniq, $id;
        $check{ $id } = ();
    }

    my $objects = $p{object}->fetch_group( {
        where => Dicole::Utils::SQL->column_in(
            $p{object}->id_field, \@uniq
        )
    } ) || [];

    return $objects if $p{do_not_sort};

    my %objects_by_id = map { $_->id => $_ } @$objects;
    my @ordered = ();
    for my $id ( @uniq ) {
        push @ordered, $objects_by_id{ $id } if $objects_by_id{ $id };
    }
    return \@ordered;
}

=pod

=head2 fetch_linked_objects_hash()

returns the results of fetch_objects() in a hashref
where object id is used as the object key.

=cut

sub fetch_objects_hash {
    my ( $self, %p ) = @_;

    $p{object} ||= eval{ CTX->lookup_object( $p{object_name} ); };
    return {} unless $p{object};

    my $objects = $self->fetch_objects( %p, do_not_sort => 1 );

    my $id_field = $p{object}->id_field;
    my %hash = map { $_->{ $id_field } => $_ } @$objects;

    return \%hash;
}

=pod

=head2 fetch_linked_objects()

Fetches all objects linked from provided elements.

Works only for spops objects with numeral single column id.

Required params:

from_elements => array of elements (either SPOPS objects or hashes)
link_field => name of the field containing linked object id

Required one of params:
object_name => name of objects to fetch
object => SPOPS object of the type of objects to fetch

=cut

sub fetch_linked_objects {
    my ( $self, %p ) = @_;

    return [] unless ref( $p{from_elements} ) eq 'ARRAY';
    return [] unless $p{link_field};

    return $self->fetch_objects(
        ids => [ map { $_->{ $p{link_field} } } @{ $p{from_elements} } ],
        %p
    );
}

=pod

=head2 fetch_linked_objects_hash()

returns the results of fetch_linked_objects() in a hashref
where object id is used as the object key.

=cut

sub fetch_linked_objects_hash {
    my ( $self, %p ) = @_;

    $p{object} ||= eval{ CTX->lookup_object( $p{object_name} ); };
    return {} unless $p{object};

    my $objects = $self->fetch_linked_objects( %p );

    my $id_field = $p{object}->id_field;
    my %hash = map { $_->{ $id_field } => $_ } @$objects;

    return \%hash;
}

=pod

=head2 renew_links_to()

Renews links_to relations according to new information.
New objects are added and old are removed if they are not
found in new objects.

Required params:

object => object which links_to
relation => name of the links_to relation

Optional params:
new => list of new id's or objects
    : default is to remove all.
old => list of old id's or objects
    : default is to fetch all by relation.

=cut

sub renew_links_to {
    my ( $self, %p ) = @_;

    my $p = {
        relation => undef,
        object => undef,
        new => [],
        old => undef,
        %p
    };

    return if !$p->{relation} || !$p->{object};

    my $get = $p->{relation};
    my $add = $p->{relation}.'_add';
    my $remove = $p->{relation}.'_remove';

    $p->{old} ||= eval "\$p->{object}->$get( { skip_security => 1 } )";

    $p->{new} = [] if !ref $p->{new} eq 'ARRAY';
    $p->{old} = [] if !ref $p->{old} eq 'ARRAY';

    @{ $p->{new} } = map { (ref $_) ? $_->id : $_ } @{ $p->{new} };
    @{ $p->{old} } = map { (ref $_) ? $_->id : $_ } @{ $p->{old} };

    my %new_check = map { $_ => 1 } @{ $p->{new} };
    my %old_check = map { $_ => 1 } @{ $p->{old} };

    foreach my $id ( @{ $p->{old} } ) {
        next if !$id || $new_check{$id};
        eval "\$p->{object}->$remove( \$id )";
    }

    foreach my $id ( @{ $p->{new} } ) {
        next if !$id || $old_check{$id};
        eval "\$p->{object}->$add( \$id )";
    }
};

=pod

=head2 renew_links_to_objects()

Renews links_to relations according to new information.
New objects are added and old are removed if they are not
found in new objects.
Links to is updated using the object link objects instead
of the normal links_to interface.

Required params:

object => the linker object
link_object => object representing a link
linker_key => link_objects attribute for linker object id
linked_key => link_objects attribute for linked object id

Optional params:
new => list of new linked objects or their id's (not link_objects)
    : default is to remove all.
old => list of old linked objects or their id's (not link_objects)
    : default is to fetch all by relation.

=cut

sub renew_links_to_objects {
    my ( $self, %p ) = @_;

    my $p = {
        object => undef,
        link_object => undef,
        linker_key => undef,
        linked_key => undef,
        new => undef,
        old => undef,
        %p
    };

    return if !$p->{object}|| !$p->{link_object};
    return if !$p->{linked_key}|| !$p->{linker_key};

    my $object_id = $p->{object}->id;

    $p->{old} ||= $p->{link_object}->fetch_group( {
        where => "$p->{linker_key} = ?",
        value => [ $object_id ]
    } );

    $p->{new} = [] unless ref $p->{new} eq 'ARRAY';
    $p->{old} = [] unless ref $p->{old} eq 'ARRAY';

    @{ $p->{new} } = map { (ref $_) ? $_->id : $_ } @{ $p->{new} };
    @{ $p->{old} } = map { (ref $_) ? $_->id : $_ } @{ $p->{old} };

    my %new_check = map { $_ => 1 } @{ $p->{new} };
    my %old_check = map { $_ => 1 } @{ $p->{old} };

    foreach my $id ( @{ $p->{old} } ) {
        next if !$id || $new_check{$id};

        my $link_objects = $p->{link_object}->fetch_group( {
            where => "$p->{linker_key} = ? AND $p->{linked_key} = ?",
            value => [ $object_id, $id ],
        } );

        next unless ref( $link_objects ) eq 'ARRAY';
        
        for my $link_object ( @$link_objects ) {
            $link_object->remove;
        }
    }

    foreach my $id ( @{ $p->{new} } ) {
        next if !$id || $old_check{$id};

        my $link_object = $p->{link_object}->new;

        $link_object->{ $p->{linker_key} } = $object_id;
        $link_object->{ $p->{linked_key} } = $id;

        $link_object->save;
    }
};


1;