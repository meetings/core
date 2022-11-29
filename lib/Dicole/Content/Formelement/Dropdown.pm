package Dicole::Content::Formelement::Dropdown;

use 5.006;
use strict;

$Dicole::Content::Formelement::Dropdown::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content::Formelement );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

my %TEMPLATE_PARAMS = map { $_ => 1 } 
        qw( options autosubmit autourl selected );

sub TEMPLATE_PARAMS { 
    my $self = shift;

    return {
        %{$self->SUPER::TEMPLATE_PARAMS},
        %TEMPLATE_PARAMS
    };
}

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

#-------------------------------------------------------------------

# Dicole::Content::Formelement::Dropdown->new(required => 1, 
#   error => 0, 
#   modifyable => 1, 
#   attributes => { name => 'blah' },
#   options => [  
#                  { attributes => { value => 'e1' }, content => 'element1' },
#                  { attributes => { value => 'e2' }, content => 'element2' }
#   ],
#   selected => 'e2' # one of the options->[$i]->{attributes}->{value}
# );
#

sub _init {
	my ($self, %args) = @_;
    
	$args{template} ||= CTX->server_config->{dicole}{base} . '::input_select'; 
	$args{options} = [] unless ref $args{options} eq 'ARRAY';
    
    $self->SUPER::_init(%args);

	$self->_create_all_missing_refs;

#    get_logger( LOG_ACTION)->error( Data::Dumper::Dumper( $self ) );

}

sub get_template_params {
    my ( $self ) = @_;
    
    $self->attributes->{value} =
        $self->get_content( $self->_get_selected_index );
    
    return $self->SUPER::get_template_params;
}


## Mostly compatibility stuff below..


# creates hashrefs (to anonymous hashes) if they aren't defined for a given option index.
# First it is confirmed that $self->options->[$index] points to a hash (and the hash is created if not).
# Then $self->options->[$index]->{attributes} is set to point to a hash if it isn't already pointing to one.
sub _create_missing_refs {
	my ($self, $index) = @_;
	$self->options->[$index] = {}
		unless( ref $self->options->[$index] eq 'HASH' );
	$self->options->[$index]->{attributes} = {}
		unless( ref $self->options->[$index]->{attributes} eq 'HASH' );
}

# checks all elements in the options array, and modifies their structure if needed by calling _create_missing_refs();
sub _create_all_missing_refs {
	my $self = shift;
	my $tot_count = $self->get_options_count;
	foreach my $i ( 0..($tot_count - 1) ) {
		$self->_create_missing_refs( $i );
	}
}

# $c->set_value($i,'new'); # replaces the scalar in $c->options->[$i]->{attributes}->{value};
# If the option element in index $i doesn't exist, a new option structure is first created by calling _create_missing_refs()
sub set_value {
	my ( $self, $index, $content ) = @_;
	$self->_create_missing_refs( $index );
	$self->options->[$index]->{attributes}->{value} = $content;
}

sub add_value {
	my ($self, $index, $content) = @_;
	$self->_create_missing_refs( $index );
	$self->options->[$index]->{attributes}->{value} .= $content;
}

sub get_value {
	my ($self, $index) = @_;
	return $self->options->[$index]->{attributes}->{value};
}

sub clear_value {
	my ($self, $index) = @_;
	undef $self->options->[$index]->{attributes}->{value};
}

# $c->set_content($i,'new'); # replaces the scalar in $c->options->[$i]->{content};
# If the option element in index $i doesn't exist, a new option structure is first created by calling _create_missing_refs()
sub set_content {
	my ($self, $index, $content) = @_;
	$self->_create_missing_refs( $index );
	$self->options->[$index]->{content} = $content;
}

sub add_content {
	my ($self, $index, $content) = @_;
	$self->_create_missing_refs( $index );
	$self->options->[$index]->{content} .= $content;
}

sub get_content {
	my ($self, $index) = @_;
	return $self->options->[$index]->{content};
}

sub clear_content {
	my ($self, $index) = @_;
	undef $self->options->[$index]->{content};
}

sub get_options_count {
	my $self = shift;
	my $count = @{$self->options};
	return $count;
}

# $c->set_options( [ {attributes => {value => ''}, content => '' }, {}, {} ] ); # replaces the options arrayref
sub set_options {
	my ($self, $content) = @_;
	$self->options = $content if ( ref $content eq 'ARRAY' );
	$self->_create_all_missing_refs; # check the structure of the new options array

}

# $c->add_options( [ {attributes => {value => ''}, content => '' }, {}, {} ] ); # pushes additional elements to the options arrayref
# (1) The options are added only if the parameter is an arrayref
# (2) The index of the next option element (the one that is about to be pushed to the array in step 4.) is always stored in scalar $last
# (3) If the current element in the array given as parameter (@{$content}) is not a hashref, skip to the next one (only valid 
#     parameters are accepted).
# (4) Push the hashref to the end of the option element array @{$self->options}. The index of this
#     new element is now in $last.
# (5) Check the structure of the new element (which is in index $last), and create missing structure elements if needed.
# (6) Update $last to point to the index of the next element to be added.
sub add_options {
	my ($self, $content) = @_;
	if ( ref $content eq 'ARRAY' ) { # (1)
		my $last = $self->get_options_count; # (2)
		foreach my $element ( @{$content} ) {
			next unless ( ref $element eq 'HASH' ); # (3)
			push @{$self->options}, $element; # (4)
			$self->_create_missing_refs( $last ); # (5) update the last element in the list
			$last++; # (6)
		}
	}
}

# returns the arrayref
sub get_options {
	my $self = shift;
	return $self->options;
}

# Removes $length elements from the options list starting from the $index:th element.
# If $index isn't given, will start from index 0. If $length isn't given, will
# delete all elements from the given $index onwards.
# Note: returns the output of the last evaluated statement -- that is, returns the array containing the removed elements.
# In scalar context returns the number of removed options.

sub remove_options {
	my ($self, $index, $length) = @_;
	splice @{$self->options}, ($index ? $index : 0), ($length ? $length : undef);
}

sub clear_options {
	my $self = shift;
	$self->options( [] );
}

# $c->set_selected('e1'); # replaces the scalar in $c->selected;
sub set_selected {
	my ($self, $content) = @_;
    $self->selected( $content );
}

sub get_selected {
	my $self = shift;
	return $self->selected;
}

sub clear_selected {
	my $self = shift;
	$self->selected( '' );
}

sub _get_selected_index {
	my $self = shift;

	my $selected = $self->get_selected;

	my $tot_count = $self->get_options_count;

	foreach my $i ( 0..($tot_count - 1) ) {
		return $i if $self->get_value( $i ) eq $selected;
	}
	return undef;
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Formelement::Dropdown - A form dropdown class

=head1 SYNOPSIS

  use Dicole::Content::Formelement::Dropdown;
  my $object = Dicole::Content::Formelement::Dropdown->new(required => 1, 
		                                           error => 0, 
		                                           modifyable => 1, 
							   attributes => { name => 'blah' },
							   options => [  
							                  { attributes => { value => 'e1' }, content => 'element1' },
							                  { attributes => { value => 'e2' }, content => 'element2' }
								      ],
		                                           selected => 'e2' # one of the options->[$i]->{attributes}->{value}
							  );
  return $self->generate_content(
 	{ itemparams => $object->get_template_params },
 	{ name => $object->get_template }

=head1 DESCRIPTION

This is a class defining a form dropdown object. It returns the output in the form that template
dicole_base::input_select wants. Is derived from Dicole::Content::Formelement.

=head1 METHODS

B<new( options => [ HASHREF, ... ], selected => SCALAR )>
Also takes the same arguments as the Dicole::Content::Formelement besides the ones specified here. 'options' is an arrayref
containing hashrefs. Each hashref defines one option in the dropdown. The hashref contains the following elements:
- attributes, a HASHREF which contains the XHTML attributes for the select element (e.g. 'value' is the value returned when the
  form is submitted).
- content, a SCALAR which contains the text inside the dropdown element

The attribute 'selected' contains information on the selected dropdown item. The value of this scalar must be one of
the {options}->[$i]->{attributes}->{value} . The corresponding element is then set as selected.

B<set_value( SCALAR, SCALAR )>
$object->set_value($index,$value); 
Sets the value of the $index:th dropdown element to $value. Modifies {options}->[$index]->{attributes}->{value}

B<get_value( SCALAR )>
$object->get_value($index);
Returns the value of the $index:th dropdown element.

B<clear_value( SCALAR )>
Clears the value of the dropdown element with the given index.

B<set_content( SCALAR, SCALAR )>
$object->set_content($i, $value);
Sets the content of the $i:th dropdown element. Modifies {options}->[$i]->{content}.

B<add_content( SCALAR, SCALAR )>
$object->add_content($i, $value);
Appends the content of the $i:th dropdown element. Modifies {options}->[$i]->{content}.

B<get_content( SCALAR )>
Returns the content of the $index:th dropdown element.

B<clear_content( SCALAR )>
Clears the content of the $index:th dropdown element.

B<set_options( ARRAYREF )>
The array contains HASHREFs. The format of the argument is the same as the 'options' argument in the constructor.

B<add_options( ARRAYREF )>
The array contains HASHREFs. The format of the argument is the same as the 'options' argument in the constructor.
The given array of elements is pushed to the end of the array of previously set dropdown elements.

B<get_options()>
Returns an arrayref.

B<get_options_count()>
Returns the number of defined dropdown elements.

B<remove_options( SCALAR, SCALAR )>
$object->remove_options($index,$length);
Removes $length dropdown elements starting from index number $index. If $length isn't given, removes all elements
starting from $length. If $index isn't given, starting index is set to 0 (that is, $object->remove_options() removes
all the dropdown elements). Returns an array containing the removed hashrefs, or in scalar context the number of 
removed elements.

B<clear_options()>
Clears the list of dropdown elements.

B<set_selected( SCALAR )>
Sets the value of 'selected' attribute. This should be one of the {options}->[$i]->{attributes}->{value} .

B<get_selected()>
Returns the value of the selected dropdown element.

B<clear_selected()>
Clears the 'selected' attribute.

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>
L<Dicole::Content::Formelement|Dicole::Content::Formelement>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>hannes@ionstream.fiE<gt>
Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
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

