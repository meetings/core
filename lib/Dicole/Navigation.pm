package Dicole::Navigation;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

$Dicole::Navigation::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# $c = Dicole::Navigation->new( options => [ 
#                                             { name => '', link => '', arguments => { (XHTML arguments for the element) } },
#                                             { name => '', link => '', arguments => { (XHTML arguments for the element) } },
#					   ],
#                               template => ''				
#                             );					   
sub new {
	my ($class, %args) = @_;
	my $config = { };
	my $self = bless( $config, $class );
	$self->_init(%args);
	return $self;
} 

sub _init {
	my ($self, %args) = @_;
	$args{template} = CTX->server_config->{dicole}{base} . '::navigation' unless (defined ($args{template}));
	$args{options} = [] unless (ref $args{options} eq 'ARRAY');
	$self->{_template} = $args{'template'};
	$self->{_options} = $args{'options'};
}

sub set_options {
	my ($self,$content) = @_;
	$self->{'_options'} = $content if (ref $content eq 'ARRAY');
}

sub add_options {
	my ($self,$content) = @_;
	push @{$self->{'_options'}}, @{$content} if (ref $content eq 'ARRAY');
}

sub get_options {
	my $self = shift;
	return $self->{'_options'};
}

sub clear_options {
	my $self = shift;
	$self->{'_options'} = [];
}

# $object->set_template($t); 
# sets (replaces) the template
sub set_template {
	my $self = shift;
	$self->{'_template'} = shift;
}

# returns the contents of the 'template' attribute
sub get_template {
	my $self = shift;
	return $self->{'_template'};
}

# Returns list of navigation template arguments in the following form:
# [ 
#   { name => '', link => '', arguments => { (XHTML arguments for the element) } },
#   { name => '', link => '', arguments => { (XHTML arguments for the element) } },
# ]
sub output {
	my $self = shift;
	return $self->{'_options'};
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Navigation - A base class for Dicole::Navigation::* classes

=head1 SYNOPSIS

  use Dicole::Navigation;
  my $n = Dicole::Navigation->new( options => [ {name => 'Tab', link => 'http://tab.org'} ], template => OpenInteract::Request->instance->config->{dicole}{base} . '::tool_prinav' );

  my $template = $n->get_template();
  my $tabs = $n->output();

=head1 DESCRIPTION

This is a base class for all Dicole::Navigation::* classes, and it is not normally used.

=head1 METHODS

B<new( options => [ HASHREF, ...], template => SCALAR )>
The 'options' array contains a hashref for each navigation element (link). The can should contain the following elements:
- name, a scalar containing the displayed name of the link
- link, a scalar containing the link which is followed when this element is clicked
- attributes, hashref containing XHTML arguments for the link

'template' scalar contains the name of the used template.

B<set_options( ARRAYREF )>
Sets the array of option hashrefs. The format is the same as in the 'options' field of the constructor.

B<add_options( ARRAYREF )>
Adds the given array of option hashrefs to the end of the previous options. The format is the same as in 
the 'options' field of the constructor.

B<get_options()>
Returns the option arrayref.

B<clear_options()>
Clears the array of options.

B<set_template( SCALAR )>
Sets the template.

B<get_template()>
Returns the template.

B<output()>
Returns the list (arrayref) of navigation template arguments.

=head1 SEE ALSO

L<Dicole::Tool|Dicole::Tool>

=head1 AUTHOR

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

