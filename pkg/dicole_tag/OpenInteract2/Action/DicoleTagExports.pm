package OpenInteract2::Action::DicoleTagExports;

use strict;
use base qw/ OpenInteract2::Action::DicoleTag /;

# Get the attached tags for one content item
sub get_attached {
	my ($self) = @_;

	return $self->_get_attached_tags(
		$self->param('object_id'),
		$self->param('object_type'),
	);
}

sub edit {
	my ($self) = @_;

	return $self->_handle_request(
		$self->param('object_id'),
		$self->param('object_type')
	);
}

1;
