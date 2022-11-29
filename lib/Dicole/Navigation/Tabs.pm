package Dicole::Navigation::Tabs;

use 5.006;
use strict;

$Dicole::Navigation::Tabs::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Navigation ); # make methods available from parent

use OpenInteract2::Context   qw( CTX );

# Some constants that should be used when initializing new object:
use constant TAB_TYPE_MAINTAB => 1;
use constant TAB_TYPE_TOOLTAB => 2;

# $c = Dicole::Navigation::Tabs->new( options => [ 
#                                                  { name => '', href => '', arguments => { (XHTML arguments for the element) } },
#                                                  { name => '', href => '', arguments => { (XHTML arguments for the element) } },
#					         ],
#                                     selected => 0, # the index of the selected tab element
#                                     tab_type => Dicole::Navigation::Tabs::TAB_TYPE_MAINTAB
#                                   );					   
# new() calls _init()
sub _init {
	my ($self, %args) = @_;
	$self->SUPER::_init(%args);
	$self->set_tab_type($args{tab_type}); 
	$self->{_selected} = $args{selected} || 0;
    return if $self->{_selected} >= scalar( @{ $self->{_options} } );
	$self->{_options}->[$self->{_selected}]->{active} = 1; # set 'active' attribute for the correct tab in options array
}

sub set_selected {
    my ($self,$value) = @_;
    undef $self->{_options}->[$self->{_selected}]->{active}
        unless ( $self->{_selected} >= scalar( @{ $self->{_options} } ) );# clear previous value
    return if $value >= scalar( @{ $self->{_options} } );
    $self->{_selected} = $value;
    $self->{_options}->[$self->{_selected}]->{active} = 1; # insert new value
}

sub get_selected {
	my $self = @_;
	return $self->{_selected};
}

sub set_tab_type {
	my ($self,$value) = @_;
	$value = TAB_TYPE_TOOLTAB unless ($value);
	if    ($value == TAB_TYPE_MAINTAB) { $self->{_template} = CTX->server_config->{dicole}{base} . '::navigation_tabs_main'; }
	elsif ($value == TAB_TYPE_TOOLTAB) { $self->{_template} = CTX->server_config->{dicole}{base} . '::tool_prinav'; }
	else {die 'Invalid tab type';}
	$self->{_tab_type} = $value;
}

sub get_tab_type {
	my $self = shift;
	return $self->{_tab_type};
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Navigation::Tabs - Tab navigation class

=head1 SYNOPSIS

  use Dicole::Navigation::Tabs;
  my $navi = Dicole::Navigation::Tabs->new(options => [ 
                                                        { name => 'Tab1', link => 'http://tab1.org' },
                                                        { name => 'Tab2', link => 'http://tab2.org' },
					              ],
                                           selected => 0, # the index of the selected tab element
                                           tab_type => Dicole::Navigation::Tabs::TAB_TYPE_TOOLTAB);

=head1 DESCRIPTION

This is a tab navigation class. It is derived from Dicole::Navigation.

=head1 METHODS

B<new( options => ARRAYREF, selected => SCALAR, tab_type => SCALAR )>
'options' parameter is described in the documentation of Dicole::Navigation class. The 'selected' scalar defines which of
the given tabs is selected. It is an index number to the array defined in 'options' argument.

'tab_type' parameter must be one of predefined constants 
Dicole::Navigation::Tabs::TAB_TYPE_TOOLTAB or Dicole::Navigation::Tabs::TAB_TYPE_MAINTAB . If none is given, default
value Dicole::Navigation::Tabs::TAB_TYPE_TOOLTAB is used.

B<set_selected( SCALAR )>
Sets the index of the selected tab.

B<get_selected()>
Returns the index number of the selected tab.

B<set_tab_type( SCALAR )>
Sets the tab type.

B<get_tab_type()>
Returns the tab type (the value of the constant).

=head1 SEE ALSO

L<Dicole::Navigation|Dicole::Navigation>
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

