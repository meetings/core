package OpenInteract2::Action::DicoleTag;

use strict;
use base qw( Dicole::Action );

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Utils::JSON;
use Data::Dumper;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.39 $ =~ /(\d+)\.(\d+)/);

sub tag_name_list {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id') || 0;
    my $group_id = $self->param('group_id') || 0;
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    my $objs = $self->_fetch_tag_objects( {
        user_id => $self->param('user_id') || 0,
        group_id => $self->param('group_id') || 0,
        domain_id => Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) || 0,
    } );

    return [ map { ( $_->count > 0 ) ? $_->tag : () } @$objs ];
}

my $cached_collection_data = {};

sub tag_collection_data {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id') || 0;
    my $group_id = $self->param('group_id') || 0;
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    my $key = join( "-", $user_id, $group_id, $domain_id );
    if ( $cached_collection_data->{ $key } ) {
        return $cached_collection_data->{ $key };
    }

    my $collections = CTX->lookup_object('tag_collection')->fetch_group({
        where => 'user_id = ? AND group_id = ? AND domain_id = ?',
        value => [ $user_id, $group_id, $domain_id ],
    });

    my $data = {
        collections => [ map { {
            id => $_->id,
            title => $_->title,
            tags => [ split /\s*,\s*/, $_->tags ],
            %{ ( eval { Dicole::Utils::JSON->decode( $_->notes || '{}' ) } || {} ) },
        } } @$collections ],

        collection_id_by_tag => {},
    };

    for my $cat_data ( @{ $data->{collections} } ) {
        for my $tag ( @{ $cat_data->{tags} } ) {
            $data->{collection_id_by_tag}{ $tag } = $cat_data->{id};
        }
    }

    $cached_collection_data->{ $key } = $data;

    return $data;
}

sub merge_input_to_json_tags {
    my ( $self ) = @_;
    
    my $input = $self->param('input');
    my $json = $self->param('json');
    
    my @tags = ();
    my $values = eval { Dicole::Utils::JSON->decode( $json || '[]' ) } || [];
    
    for my $value ( @$values ) {
        my $tag = lc ( $value );
        $tag =~ s/^\s*//;
        $tag =~ s/\s*$//;
        push @tags, $tag;
    }
    
    push @tags, @{ $self->parse_input };
    
    return Dicole::Utils::JSON->encode( \@tags );
}

sub parse_input {
    my ( $self ) = @_;

    my $input = $self->param('input') || '';

    my @tags = ();

    for my $value ( split /\s*,\s*/, $input ) {
        my $tag = lc ( $value );
        $tag =~ s/^\s*//;
        $tag =~ s/\s*$//;
        push @tags, $tag if $tag;
    }

    return \@tags;
}

sub attach_tags {
    my ( $self ) = @_;
    
    # does $self->_populate_params;
    my $tags = $self->get_tags_for_object;
    my %tagkeys = map { $_ => 1 } @$tags;
    
    my $values = $self->param('values') || [];
    
    my @attached_tags = ();
    
    for my $tag ( @$values ) {
        next if $tagkeys{ $tag };
        
        push @attached_tags, $tag;
        $self->_attach_tag_using_params( $tag );
    }
    
    $self->_update_object_index_from_params;
    
    return \@attached_tags;
}

sub attach_tags_from_json {
    my ( $self ) = @_;
    
    $self->param( 'values', $self->_json_to_tags( $self->param( 'json' ) ) );
    
    return $self->attach_tags;
}

sub update_tags {
    my ( $self ) = @_;
    
    # does $self->_populate_params;
    my $tags = $self->get_tag_objects_for_object;
    my %tagkeys = map { $_->tag => $_ } @$tags;

    my $values = $self->param('values') || [];
    my $values_old = $self->param('values_old') || [];
    
    my %newkeys = map { $_ => 1 } @$values;
    my %oldkeys = map { $_ => 1 } @$values_old;
    
    my @attached_tags = ();
    my @detached_tags = ();
    
    for my $tag ( @$values_old ) {
        next if $newkeys{ $tag };
        next unless $tagkeys{ $tag };
        
        push @detached_tags, $tag;
        $self->_detach_tag_object_using_params( $tagkeys{ $tag } )
    }
    for my $tag ( @$values ) {
        next if $oldkeys{ $tag };
        next if $tagkeys{ $tag };
        
        push @attached_tags, $tag;
        $self->_attach_tag_using_params( $tag );
    }
    
    $self->_update_object_index_from_params;

    return ( \@attached_tags, \@detached_tags );
}

sub update_tags_from_json {
    my ( $self ) = @_;
    
    $self->param( 'values', $self->_json_to_tags( $self->param( 'json' ) ) );
    $self->param( 'values_old', $self->_json_to_tags( $self->param( 'json_old' ) ) );
    
    return $self->update_tags;
}

sub decode_json {
    my ( $self ) = @_;
    return $self->_json_to_tags( $self->param( 'json' ) );
}

sub clone_tags {
    my ( $self ) = @_;
    
    $self->_populate_object_params( 'from_object' );
    $self->_populate_object_params( 'to_object' );
    $self->_populate_domain_params( 'from_domain' );
    $self->_populate_domain_params( 'to_domain' );
    
    my $tags = $self->_get_tags_for_object( {
        user_id => $self->param('from_user_id') || 0,
        group_id => $self->param('from_group_id') || 0,
        domain_id => $self->param('from_domain_id') || 0,
        object_id => $self->param('from_object_id'),
        object_type => $self->param('from_object_type'),
    } );
    
    my ( $attached_tags, $detached_tags ) = $self->_set_tags( {
        user_id => $self->param('to_user_id') || 0,
        group_id => $self->param('to_group_id') || 0,
        domain_id => $self->param('to_domain_id') || 0,
        object_id => $self->param('to_object_id'),
        object_type => $self->param('to_object_type'),
        'values' => $tags,
    } );
    
    $self->_update_object_index( {
        user_id => $self->param('to_user_id') || 0,
        group_id => $self->param('to_group_id') || 0,
        domain_id => $self->param('to_domain_id') || 0,
        object_id => $self->param('to_object_id'),
        object_type => $self->param('to_object_type'),
    } );
    
    return [ $attached_tags, $detached_tags ];
}

sub copy_tags {
    my ( $self ) = @_;
    
    $self->_populate_object_params( 'from_object' );
    $self->_populate_object_params( 'to_object' );
    $self->_populate_domain_params( 'from_domain' );
    $self->_populate_domain_params( 'to_domain' );
    
    my $tags = $self->_get_tags_for_object( {
        user_id => $self->param('from_user_id') || 0,
        group_id => $self->param('from_group_id') || 0,
        domain_id => $self->param('from_domain_id') || 0,
        object_id => $self->param('from_object_id'),
        object_type => $self->param('from_object_type'),
    } );
    
    my $attached_tags = $self->_attach_tags( {
        user_id => $self->param('to_user_id') || 0,
        group_id => $self->param('to_group_id') || 0,
        domain_id => $self->param('to_domain_id') || 0,
        object_id => $self->param('to_object_id'),
        object_type => $self->param('to_object_type'),
        'values' => $tags,
    } );
    
    $self->_update_object_index( {
        user_id => $self->param('to_user_id') || 0,
        group_id => $self->param('to_group_id') || 0,
        domain_id => $self->param('to_domain_id') || 0,
        object_id => $self->param('to_object_id'),
        object_type => $self->param('to_object_type'),
    } );
    
    return $attached_tags;
}

sub set_tags {
    my ( $self ) = @_;

    $self->_populate_params;
    return $self->_set_tags( {
        user_id => $self->param('user_id') || 0,
        group_id => $self->param('group_id') || 0,
        domain_id => $self->param('domain_id') || 0,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        'values' => scalar( $self->param('values') ),
    } );
}

sub detach_tags {
    my ( $self ) = @_;
    
    # does $self->_populate_params;
    my $tags = $self->get_tags_for_object;
    my %tagkeys = map { $_ => 1 } @$tags;
    
    my $values = $self->param('values') || [];
    
    my @detached_tags = ();
    
    for my $tag ( @$values ) {
        next unless $tagkeys{ $tag };
        
        push @detached_tags, $tag;
        $self->_detach_tag_using_params( $tag );
    }
    
    $self->_update_object_index_from_params;
    
    return \@detached_tags;
}

sub purge_tags { remove_tags( @_ ) }

sub remove_tags {
    my ( $self ) = @_;
    
    # does $self->_populate_params;
    my $tags = $self->get_tag_objects_for_object;
    
    for my $tag ( @$tags ) {
        $self->_detach_tag_object_using_params( $tag );
        $self->_recount_tag_usage( $tag );
    }
    
    $self->_update_object_index_from_params;
    
    return 1;
}

sub get_weighted_tags {
    my ( $self ) = @_;
    
    $self->_populate_id_params;
    $self->_populate_domain_params('domain');

    my $tags = CTX->lookup_object('tag')->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND domain_id = ? AND ( count > ? OR suggested = ? )',
        value => [
            $self->param('user_id') || 0,
            $self->param('group_id') || 0,
            $self->param('domain_id') || 0,
            0,
            1
        ],
    } ) || [];
    
    my %weights = map { $_->tag => $_->count } @$tags;
    my @weights = map { [ $_, $weights{ $_ } ] } sort { $a cmp $b } keys %weights;
    
    return \@weights;
}

sub get_suggested_tags {
    my ( $self ) = @_;
    
    $self->_populate_id_params;
    $self->_populate_domain_params('domain');

    my $tags = CTX->lookup_object('tag')->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND domain_id = ? AND suggested = ?',
        value => [
            $self->param('user_id') || 0,
            $self->param('group_id') || 0,
            $self->param('domain_id') || 0,
            1
        ],
    } ) || [];
    
    my @tags = map { $_->tag } @$tags;
    
    return \@tags;
}

sub get_query_limited_weighted_tags {
    my ( $self ) = @_;
    
    $self->_populate_id_params;
    $self->_populate_domain_params('domain');
    my $object_class = $self->param('object_class');
    
    my $object_table = $object_class->base_table;
    my $object_id_field = $object_class->id_field;
    my $where = $self->param('where') || '(1=1)';
    my $value = $self->param('value') || [];
    
    my $from = $self->param('from') || [];
    for my $table ( $object_table, 'dicole_tag_attached', 'dicole_tag' ) {
        push @$from, $table unless scalar( grep { $_ eq $table } @$from );
    }

    my $attached = CTX->lookup_object('tag_attached')->fetch_group( {
        from => $from,
        where => 'dicole_tag_attached.object_type = ? AND ' .
            'dicole_tag_attached.tag_id = dicole_tag.tag_id AND ' .
            $object_table . '.' . $object_id_field . ' = dicole_tag_attached.object_id AND ' .
            'dicole_tag.user_id = ? AND ' .
            'dicole_tag.group_id = ? AND ' .
            'dicole_tag.domain_id = ? AND ' .
             $where,
        value => [
            $object_class,
            $self->param('user_id'),
            $self->param('group_id'),
            $self->param('domain_id'),
            @$value,
        ],
    } ) || [];
    
    my %tag_id_weights = ();
   
    for my $attach ( @$attached ) {
        $tag_id_weights{ $attach->tag_id }++;
    }
    
    return $self->_weighted_tags_from_id_hash( \%tag_id_weights );
}

sub _weighted_tags_from_id_hash {
    my ( $self, $tag_id_weights ) = @_;
    
    my $tags = CTX->lookup_object('tag')->fetch_group( {
        where => Dicole::Utils::SQL->column_in(
            'tag_id', [ keys %$tag_id_weights ]
        ),
    } ) || [];
    
    my %weights = map { $_->tag => $tag_id_weights->{ $_->id } } @$tags;
    my @weights = map { [ $_, $weights{ $_ } ] } sort { $a cmp $b } keys %weights;
    
    return \@weights;
}

sub get_weighted_tags_for_objects {
    my ( $self ) = @_;
    
    $self->_populate_id_params;
    $self->_populate_domain_params('domain');
    
    my $objects = $self->param('objects') || [];
    my %idhash = ();
    
    for my $obj ( @$objects ) {
        my $type = ref( $obj );
        push @{$idhash{$type}}, $obj->id;
    }
    
    my @queries = ();
    my @extra_values = ();
    
    for my $type ( keys %idhash ) {
        push @extra_values, $type;
        push @queries,
            '( dicole_tag_attached.object_type = ? AND ' .
            Dicole::Utils::SQL->column_in(
                'dicole_tag_attached.object_id', $idhash{$type}
            ) .
            ' )';
    }
    
    my $tags = CTX->lookup_object('tag')->fetch_group( {
        from => [ 'dicole_tag', 'dicole_tag_attached' ],
        where => 
            'dicole_tag_attached.tag_id = dicole_tag.tag_id AND ' .
            'dicole_tag.user_id = ? AND ' .
            'dicole_tag.group_id = ? AND ' .
            'dicole_tag.domain_id = ? AND ( ' .
            join( ' OR ', @queries ) . ' )',
        value => [
            $self->param('user_id'),
            $self->param('group_id'),
            $self->param('domain_id'),
            @extra_values,
        ],
    } ) || [];
    
    my %weights = ();
    for my $tag ( @$tags ) {
        $weights{ $tag->tag }++;
    }
    
    my @weights = map { [ $_, $weights{ $_ } ] } sort { $a cmp $b } keys %weights;
    
    return \@weights;
}

sub get_tag_objects_for_object {
    my ( $self ) = @_;
    
    $self->_populate_params;
    
    my $params = {};
    $params->{$_} = $self->param( $_ ) for ( qw(
        object_id object_type user_id group_id domain_id
    ) );
    
    return $self->_get_tag_objects_for_object( $params );
}

sub get_tags { return shift->get_tags_for_object( $@ ) }

sub get_tags_for_object {
    my ( $self ) = @_;
    
    # does $self->_populate_params;
    my $tobjs = $self->get_tag_objects_for_object;
    my @tags = map { $_->tag } @$tobjs;
    
    return \@tags;
}

sub get_tags_for_object_as_json {
    my ( $self ) = @_;

    # does $self->_populate_params;
    my $objs = $self->get_tags_for_object;
    return Dicole::Utils::JSON->encode( $objs );
}

sub tag_limited_fetch_group {
    my ( $self ) = @_;

    return $self->_tag_limited_fetch_group( 'objects' );
}

sub tag_or_limited_fetch_group {
    my ( $self ) = @_;

    return $self->_tag_limited_fetch_group( 'objects', 'or' );
}

sub tag_limited_fetch_group_weighted_tags {
    my ( $self ) = @_;

    my $indexes = $self->_tag_limited_fetch_group( 'indexes' );
    return $self->_indexes_to_weighted_tags( $indexes );
}

sub tag_limited_fetch_group_objects_and_weighted_tags {
    my ( $self ) = @_;
    
    my ( $objects, $indexes ) = $self->_tag_limited_fetch_group( 'both' );
    return ( $objects, $self->_indexes_to_weighted_tags( $indexes ) );
}

sub _indexes_to_weighted_tags {
    my ( $self, $indexes ) = @_;

    my %index_count = ();
    for my $index ( @$indexes ) {
        my @tag_ids = $index->tags =~ /\:(\d+)\:/g;
        $index_count{ $_ }++ for @tag_ids;
    }

    return $self->_weighted_tags_from_id_hash( \%index_count );
}

sub _tag_limited_fetch_group {
    my ( $self, $which, $type ) = @_;

    $self->_populate_id_params;
    $self->_populate_domain_params('domain');

    my $tags = $self->param('tags') || [];
    my $object_class = $self->param('object_class');
    
    return [] unless $object_class;
    
    my $object_table = $object_class->base_table;
    my $object_id_field = $object_class->id_field;

    my $from = $self->param('from') || [ $object_table ];
    push @$from, $object_table unless scalar( grep { $_ eq $object_table } @$from );

    if ( $which eq 'objects' && ( $type ne 'or' ) && ! scalar( @$tags ) ) {
        return $object_class->fetch_group( {
            from => $from,
            where => $self->param('where'),
            value => scalar( $self->param('value') ),
            order => $self->param('order'),
            limit => $self->param('limit'),
        } ) || [];
    }
    
    my $tag_objects = $self->_fetch_tag_objects( {
        user_id => $self->param('user_id'),
        group_id => $self->param('group_id'),
        domain_id => $self->param('domain_id'),
        tags => $tags,
    } );

    # This would mean that a tag has been provided which does not exist in the system so
    # no results can be found with it.
    return [] unless $type eq 'or' || scalar( @$tag_objects ) == scalar( @$tags );
    
    my @ids = map { $_->id } @$tag_objects;
    @ids = sort { $a <=> $b } @ids;
    
    my @like_values = ();

    my $where = 'dicole_tag_index.user_id = ? AND dicole_tag_index.group_id = ? AND dicole_tag_index.domain_id = ? AND ' .
        $object_table . '.' . $object_id_field . ' = dicole_tag_index.object_id AND ' .
        'dicole_tag_index.object_type = ?';

    if ( $type && $type eq 'or' ) {
        $where .= ' AND (';

        my @or_list = ();
        for my $id ( @ids ) {
            push @or_list, 'dicole_tag_index.tags LIKE ?';
            push @like_values, "%:" . $id . ":%";
        }

        $where .= scalar( @ids ) ? join(" OR ", @or_list ) : '1=0';
        $where .= ' )';

    }
    else {
        $where .= ' AND dicole_tag_index.tags LIKE ?';
        push @like_values, scalar(  @$tag_objects ) ? '%' . join('%', map( { ':'.$_.':' } @ids) ) . '%' : '%';
    }

    $where = $where . ' AND ' . $self->param('where') if $self->param('where');
  
    my $value = [
        $self->param('user_id'), $self->param('group_id'), $self->param('domain_id'),
        $object_class, @like_values,
        @{ $self->param('value') || [] },
    ];
    
    if ( $which eq 'objects' ) {
        return $object_class->fetch_group( {
                from => [ @$from, 'dicole_tag_index' ],
                where => $where,
                value => $value,
                order => $self->param('order'),
                limit => $self->param('limit'),
        } ) || [];
    }
    elsif ( $which eq 'indexes' ) {
        return CTX->lookup_object('tag_index')->fetch_group( {
                from => [ @$from, 'dicole_tag_index' ],
                where => $where,
                value => $value,
                order => $self->param('order'),
        } ) || [];
    }
    else {
        return (
            $object_class->fetch_group( {
                    from => [ @$from, 'dicole_tag_index' ],
                    where => $where,
                    value => $value,
                    order => $self->param('order'),
                    limit => $self->param('limit'),
            } ) || [],
            CTX->lookup_object('tag_index')->fetch_group( {
                    from => [ @$from ],
                    where => $where,
                    value => $value,
                    order => $self->param('order'),
            } ) || []
        );
    }
}

sub _update_object_index_from_params {
    my ( $self ) = @_;
    
    return $self->_update_object_index( {
        user_id => $self->param('user_id') || 0,
        group_id => $self->param('group_id') || 0,
        domain_id => $self->param('domain_id') || 0,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
    } );
}

sub _update_object_index {
    my ( $self, $params ) = @_;

    my $tag_objects = $self->_get_tag_objects_for_object( $params );
    
    my $index_object = CTX->lookup_object('tag_index')->fetch_group( {
        where => 'object_id = ? AND ' .
            'object_type = ? AND ' .
            'user_id = ? AND ' .
            'group_id = ? AND ' .
            'domain_id = ?',
        value => [
            $params->{object_id},
            $params->{object_type},
            $params->{user_id},
            $params->{group_id},
            $params->{domain_id},
        ],
    } ) || [];
    
    $index_object = $index_object->[0];

    my $save_needed = 0;
    if ( ! $index_object ) {
        $index_object = CTX->lookup_object('tag_index')->new;
        $index_object->{$_} = $params->{$_} for ( qw/
            object_id object_type user_id group_id domain_id
        / );
        $save_needed = 1;
    }
    
    my @ids = map { $_->id } @$tag_objects;
    @ids = sort { $a <=> $b } @ids;
    my $idstring = ':' . join( '::', @ids ) . ':';
    
    if ( $index_object->{tags} ne $idstring || $save_needed ) {
        $index_object->{tags} = $idstring;
        $index_object->save;
    }
    
    return 1;
}

sub _get_tag_objects_for_object {
    my ( $self, $params ) = @_;
    
    my $tags = CTX->lookup_object('tag')->fetch_group( {
        from => [ 'dicole_tag', 'dicole_tag_attached' ],
        where => 
            'dicole_tag_attached.tag_id = dicole_tag.tag_id AND ' .
            'dicole_tag_attached.object_id = ? AND ' .
            'dicole_tag_attached.object_type = ? AND ' .
            'dicole_tag.user_id = ? AND ' .
            'dicole_tag.group_id = ? AND ' .
            'dicole_tag.domain_id = ?',
        value => [
            $params->{object_id},
            $params->{object_type},
            $params->{user_id},
            $params->{group_id},
            $params->{domain_id},
        ],
    } ) || [];

    return $tags;
}

sub _get_tags_for_object {
    my ( $self, $params ) = @_;
    
    # does $self->_populate_params;
    my $tobjs = $self->_get_tag_objects_for_object( $params );
    my @tags = map { $_->tag } @$tobjs;
    
    return \@tags;
}

sub _set_tags {
    my ( $self, $params ) = @_;

    # does $self->_populate_params;
    my $tags = $self->_get_tag_objects_for_object( $params );
    my $values = $params->{'values'} || [];

    my %oldkeys = map { $_->tag => 1 } @$tags;
    my %newkeys = map { $_ => 1 } @$values;
    
    my @attached_tags = ();
    my @detached_tags = ();

    for my $tag_object ( @$tags ) {
        next if $newkeys{ $tag_object->tag };
        push @detached_tags, $tag_object->tag;
        $self->_detach_tag_object( {
            tag_object => $tag_object,
            object_type => $params->{object_type},
            object_id => $params->{object_id},
        } );
    }

    for my $tag ( @$values ) {
        next if $oldkeys{ $tag };
        push @attached_tags, $tag;
        $self->_attach_tag( {
            tag => $tag,
            object_type => $params->{object_type},
            object_id => $params->{object_id},
            user_id => $params->{user_id},
            group_id => $params->{group_id},
            domain_id => $params->{domain_id},
        } );
    }
    
    return ( \@attached_tags, \@detached_tags );
}

sub _detach_tag_using_params {
    my ( $self, $tag ) = @_;

    return $self->_detach_tag( {
        tag => $tag,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        user_id => $self->param('user_id') || 0,
        group_id => $self->param('group_id') || 0,
        domain_id => $self->param('domain_id') || 0,
    } );
}

sub _detach_tag_object_using_params {
    my ( $self, $tag_object ) = @_;

    return $self->_detach_tag_object( {
        tag_object => $tag_object,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
    } );
}

sub _attach_tag_using_params {
    my ( $self, $tag ) = @_;

    return $self->_attach_tag( {
        tag => $tag,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        user_id => $self->param('user_id') || 0,
        group_id => $self->param('group_id') || 0,
        domain_id => $self->param('domain_id') || 0,
    } );
}

sub _attach_tag_object_using_params {
    my ( $self, $tag_object ) = @_;

    return $self->_attach_tag_object( {
        tag_object => $tag_object,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        domain_id => $self->param('domain_id') || 0,
    } );
}

sub _attach_tag {
    my ( $self, $params ) = @_;
    
    my $tag_object = $self->_fetch_or_create_tag_object( $params );

    $self->_attach_tag_object( {
        tag_object => $tag_object,
        object_id => $params->{object_id},
        object_type => $params->{object_type},
        domain_id => $params->{domain_id},
    } );
}

sub _detach_tag {
    my ( $self, $params ) = @_;
    
    my $tag_object = $self->_fetch_tag_object( $params );

    $self->_detach_tag_object( {
        tag_object => $tag_object,
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
    } );
}

sub _detach_tag_object {
    my ( $self, $params ) = @_;
    
    return 0 unless $params->{tag_object};
    
    my $tags = CTX->lookup_object('tag_attached')->fetch_group( {
        where => 'object_id = ? AND object_type = ? AND tag_id = ?',
        value => [
            $params->{object_id},
            $params->{object_type},
            $params->{tag_object}->id,
       ],
    } ) || [];

    for my $tag (@$tags) {
        #CTX->lookup_action('search_api')->execute(remove => {object => $tag});
        $tag->remove;
    }
    
    if ( scalar( @$tags ) ) {
        $self->_recount_tag_usage( $params->{tag_object} );
    }
    
    return 1;
}

sub _attach_tag_object {
    my ( $self, $params ) = @_;
    
    my $tags = CTX->lookup_object('tag_attached')->fetch_group( {
        where => 'object_id = ? AND object_type = ? AND tag_id = ?',
        value => [
            $params->{object_id},
            $params->{object_type},
            $params->{tag_object}->id,
       ],
    } ) || [];
    
    if ( ! scalar( @$tags ) ) {
        my $tag = CTX->lookup_object( 'tag_attached' )->new;
        $tag->{$_} = $params->{$_} for ( qw( object_id object_type ) );
        $tag->{tag_id} = $params->{tag_object}->id;
        $tag->{domain_id} = $params->{domain_id} || 0;
        $tag->{attached_date} = time;
        $tag->save;
        
        #CTX->lookup_action('search_api')->execute(process => {object => $tag, domain_id => $tag->{domain_id}});
        
        $self->_recount_tag_usage( $params->{tag_object} );
    }
    
    return 1;
}

sub _populate_params {
    my ( $self ) = @_;
    
    $self->_populate_object_params( 'object' );
    $self->_populate_id_params;
    $self->_populate_domain_params( 'domain' );
}

sub _populate_id_params {
    my ( $self ) = @_;
    
    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $self->param( 'user_id', $ia->param('target_type') eq 'user' ? $ia->param('target_user_id') : 0 )
            unless defined $self->param( 'user_id' );
        $self->param( 'group_id', $ia->param('target_type') eq 'group' ? $ia->param('target_group_id') : 0 )
            unless defined $self->param( 'group_id' );
    }
}

sub _populate_object_params {
    my ( $self, $param ) = @_;
    
    if ( my $object = $self->param( $param ) ) {
        $self->param( $param . '_id', $object->id )
            unless defined $self->param( $param . '_id' );
        $self->param( $param . '_type', ref( $object ) )
            unless defined $self->param( $param . '_type' );
    }
}

sub _populate_domain_params {
    my ( $self, $param ) = @_;
    
    unless ( defined( $self->param( $param . '_id' ) ) ) {
        eval { $self->param( $param . '_id', CTX->controller->initial_action->param('target_domain')->id ) };
        # might fail because of old action resolver code or no initial action present
        if ( $@ ) {
            eval { $self->param( $param . '_id', CTX->lookup_action('dicole_domains')->execute( get_current_domain => {} )->id ) };
            if ( $@ ) {
                $self->param( $param . '_id', 0 );
            }
        }
    }
}

sub _json_to_tags {
    my ( $self, $json ) = @_;
    
    my @tags = ();
    my $values = Dicole::Utils::JSON->decode( $json || '[]' ) || [];
    
    for my $value ( @$values ) {
        my $tag = lc ( $value );
        $tag =~ s/^\s*//;
        $tag =~ s/\s*$//;
        push @tags, $tag;
    }
    
    return \@tags;
}

sub _normalize_tag {
    my ( $self, $tag ) = @_;

    $tag = Dicole::Utils::Text->ensure_internal( $tag );
    $tag = lc ( $tag );
    $tag =~ s/^\s*//;
    $tag =~ s/\s*$//;

    # for now i think we should just strip commas if they end up here for some reason
    # it would also be beneficial to log a stack trace..
    if ( $tag =~ /\,/ ) {
        # TODO: log a stack trace too
        get_logger(LOG_APP)->error("Commas should not end up here. Stripped comma from tag: $tag");
        $tag =~ s/\,//g;
    }

    return Dicole::Utils::Text->ensure_utf8( $tag );
}

sub _normalize_tags {
    my ( $self, $tags ) = @_;

    $tags ||= [];

    return [ map { $self->_normalize_tag( $_ ) } @$tags ];
}

sub _fetch_tag_object {
    my ( $self, $params ) = @_;
    
    my $objs = CTX->lookup_object( 'tag' )->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND domain_id = ? AND tag = ?',
        value => [ $params->{user_id}, $params->{group_id}, $params->{domain_id}, $self->_normalize_tag( $params->{tag} ) ]
    } ) || [];
    
    return $objs->[0];
}

sub _fetch_tag_objects {
    my ( $self, $params ) = @_;

    my $append_query = $params->{tags} ?
        ' AND ' . Dicole::Utils::SQL->column_in_strings( 'tag', $self->_normalize_tags( $params->{tags} ) )
        :
        '';
    
    my $objs = CTX->lookup_object( 'tag' )->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND domain_id = ?' . $append_query,
        value => [ $params->{user_id}, $params->{group_id}, $params->{domain_id} ]
    } ) || [];
    
    return $objs;
}

sub _fetch_or_create_tag_object {
    my ( $self, $params ) = @_;
    
    my $tobj = $self->_fetch_tag_object( $params );
    
    if ( ! $tobj ) {
        $tobj = CTX->lookup_object( 'tag' )->new;
        $tobj->{tag} = $self->_normalize_tag( $params->{tag} );
        $tobj->{user_id} = $params->{user_id} || 0;
        $tobj->{group_id} = $params->{group_id} || 0;
        $tobj->{domain_id} = $params->{domain_id} || 0;
        $tobj->{count} = 0;
        $tobj->{suggested} = 0;
        $tobj->save;
    }
    
    return $tobj;
}

sub _recount_tag_usage {
    my ( $self, $tag_object ) = @_;
    
    my $count = CTX->lookup_object('tag_attached')->fetch_count( {
        where => 'tag_id = ?',
        value => [ $tag_object->id ],
    } ) || 0;
    
    if ( $tag_object->{count} != $count ) {
        $tag_object->{count} = $count;
        $tag_object->save;
    }
}


=pod

=head1 NAME

Dicole tag system.

=head1 DESCRIPTION

System for handling tags on different content.

=head1 BUGS
=head1 TODO
=head1 AUTHORS

Antti Vähäkotamäki

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2007 Dicole Oy
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;
