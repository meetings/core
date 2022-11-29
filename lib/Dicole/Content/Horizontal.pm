package Dicole::Content::Horizontal;

use 5.006;
use strict;

$Dicole::Content::Horizontal::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content );
use OpenInteract2::Context   qw( CTX );

my %TEMPLATE_PARAMS = map { $_ => 1 } 
    qw( content );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );



sub _init {
	my ($self, %args) = @_;
    $args{template} ||= CTX->server_config->{dicole}{base} . "::horizontal";
    $args{content} = [] unless ref $args{content} eq 'ARRAY';
    
	$self->SUPER::_init( %args );
}

sub add_content {
	my ($self, $content) = @_;
	push @{ $self->content }, $content;
}

sub get_template_params {
	my $self = shift;

	my $template_params = [];
	
	foreach my $item ( @{ $self->content } ) {
		if( ref( $item ) =~ /^Dicole::Content/ ) { # if there is a Content object defined
			my $key = {};
			$key->{template} = $item->get_template;
			$key->{params} = $item->get_template_params;
			push @{ $template_params }, $key;
		} else {
			push @{ $template_params }, $item;
		}
	}

    $self->template_params( $template_params );

    return $self->template_params;
}

1;
__END__

=head1 NAME

Dicole::Content::Horizontal - A class for creating a horizontal list of elements

=head1 SYNOPSIS

  use Dicole::Content::Horizontal;
  my $horizontal = Dicole::Content::Horizontal->new;

  $horizontal->add_content( Dicole::Content::Text->new );    
  $horizontal->add_content( Dicole::Content::Text->new );    

  return $self->generate_content(
 	{ itemparams => $horizontal->get_template_params },
 	{ name => $horizontal->get_template }

=head1 DESCRIPTION

This is a general purpose horizontal list class that can be used to make a horizontal list of
templates. Especially useful if you want one template return multiple processed templates
that appear one after another. For example, you want multiple textfields to appear in one 
table column that accepts only one template.

=head1 INHERITS

Inherits the L<Dicole::Content|Dicole::Content> class gaining its' methods.

=head1 METHODS

=head2 new( content => [ OBJECTS ... (Dicole::Content::*) ] )

Creates a new Horizontal object. The parameter content is optional, which defines initial list of objects that
are set as the content of the Horizontal object.


=head2 add_content( OBJECT )

Adds a new object as the last item of our horizontal list.

=head2 get_template_params()

Goes through the list of contents in the class and calls get_template and get_template_params for all objects
in it. Returns the data structure ready for submitting to Template Toolkit as 'itemparams'.

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>

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

