package Dicole::Content::Hyperlink;

use strict;
use base qw( Dicole::Content );
use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my %TEMPLATE_PARAMS = map { $_ => 1 } 
    qw( text content attributes );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

sub _init {
    my ($self, %args) = @_;

    $args{template} = CTX->server_config->{dicole}{base} . '::hyperlink';
    $args{attributes} = {} if ref $args{attributes} ne 'HASH';

    $self->SUPER::_init( %args );
}


#####
#
# These are here only for backwards compatibility (?):
#

sub add_content {
    my ($self, $content) = @_;
    $self->content( $self->content . $content );
}


1;

__END__

=head1 NAME

Dicole::Content::Hyperlink - A class that defines Dicole hyperlink content objects

=head1 SYNOPSIS

 use Dicole::Content::Hyperlink;
 $object = Dicole::Content::Hyperlink->new(
     content => 'Hello world of links!'
     attributes => {
         # XHTML attributes:
         href => 'http://www.dicole.org',
         class => 'link'
     }
 );

  return $self->generate_content(
    { itemparams => $object->get_template_params },
    { name => $object->get_template }

=head1 DESCRIPTION

This is a hyperlink class, which returns given content in the form that the template
dicole_base::hyperlink wants. The class is derived from Dicole::Content.

=head1 METHODS

B<new( content => SCALAR, attributes => HASHREF )>

 Dicole::Content::Hyperlink->new(
    content => 'This is my text',
    attributes => {
             href => 'http://www.dicole.org',
             # Other XHTML attributes
              }
 );

Content argument must be a scalar. Attributes argument must be a hashref.

B<add_content( SCALAR )>

appends to content.


=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

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

