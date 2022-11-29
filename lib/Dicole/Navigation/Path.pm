package Dicole::Navigation::Path;

use 5.006;
use strict;
use vars qw( $VERSION );

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

#-------------------------------------------------------------------

# $object = Dicole::Navigation::Path->new( initial_path => [ {}, {}, ... ] )
# Create new toolpath with initial path as arguments

sub new {
	my $class = shift;
	my %args = @_;
	$args{initial_path} = [] unless ref $args{initial_path} eq 'ARRAY';
	my $config = { path => $args{initial_path} };
	my $self = bless( $config, $class );
	return $self;
} 

# $object->add( name => ... )
# Add one item to toolpath (as last item)

sub add {
	my ( $self, %args ) = @_;
	push @{ $self->{path} }, { %args };
}

# $object->add_group( [ {name => ...}, {name => ...} ] )
# Add a group of items to toolpath

sub add_group {
	my ( $self, $group ) = @_;
	foreach my $arg_hash ( @$group ) {
		push @{ $self->{path} }, { %{ $arg_hash } };
	}
}

# $object->del_name( name => ... )
# Delete an item from array based on name of the item

sub del_name {
	my ( $self, %args ) = @_;

	# Remove the part from toolpath that matches name
	if ( exists $args{name} ) {
		@{ $self->{path} } =
			grep { $_->{name} ne $args{name} }
			@{ $self->{path} };
	}
}

# $object->del_order( 1 )
# Delete an item from array based on index number

sub del_order {
	my $self = shift;
	return splice ( @{ $self->{path} } ,$_[0] - 1, 1 );
}

# $object->del_last
# Remove last item from toolpath list

sub del_last {
	my $self = shift;
	return pop @{ $self->{path} };
}

# $object->count
# Counts the number of path segments and returns the value

sub count {
	my $self = shift;
	my $count = @{ $self->{path} };
	return $count;
}

# $object->del_all
# Delete all items from the path

sub del_all {
	my $self = shift;
	my $count = @{ $self->{path} };
	$self->{path} = [];
	return $count;
}

# $object->return_data
# return data object

sub return_data {
	my $self = shift;
	return \@{ $self->{path} };
}

1;
__END__

=head1 NAME

Dicole::Navigation::Path - Object oriented interface to Navigation::Path

=head1 SYNOPSIS

  use Dicole::Navigation::Path;

  @path = (
      {name => 'First Level'},
      {
           name => 'Second Level',
           href => '/url'
      }
  );
  $object = Dicole::Navigation::Path->new( initial_path => \@path );

  $object->add(name => 'Third level');
  $object->del_last;

  $data = $object->return_data;

=head1 DESCRIPTION

This package helps you to work with Dicole Navigation Path data object
in an object oriented way.

=head1 METHODS

=head2 new( %config )

The new() constructor method instantiates a new Navigation::Path object.
A hash array of configuration items may be passed as a parameter.

Currently the only accepted parameter is initial_path, which defines
the initial Navigation::Path object. See B<SYNOPSIS> for an example.

=head2 add(name => 'Item', href => 'url', ...)

Adds a new item as the last item of the Navigation::Path.

=head2 add_group( \@group )

Adds a group of items as the last items of the Navigation::Path. @group is
similar to initial_path in method new().

=head2 del_name( name => 'Item' )

Deletes an item from Navigation::Path based on item name.

=head2 del_order( 2 )

Deletes an item from Navigation::Path based on item index number in Navigation::Path.
Index number starts from 1, so $path[0] is 1 and $path[3] is 4.

Returns the removed item.

=head2 del_last

Deletes the last item in Navigation::Path.

Returns the removed item.

=head2 del_all

Deletes all items from the path.

Returns number of removed items.

=head2 count

Counts the number of path segments and returns the value.

=head2 return_data

Returns a reference to the Navigation::Path data array used by Dicole Navigation Path template.

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>

=head1 COPYRIGHT

Copyright (C) 2003 Ionstream Oy

=head1 SEE ALSO

L<OpenInteract>

=cut
