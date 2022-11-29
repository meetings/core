package Dicole::Content::Text;

use 5.006;
use strict;
use base qw( Dicole::Content );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my %TEMPLATE_PARAMS = map { $_ => 1 } 
    qw( attributes preformatted no_filter text html_line_break );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );


sub _init {
    my ($self, %args) = @_;

    $args{text} ||= $args{content};
    delete $args{content};
    
    $args{template} ||= CTX->server_config->{dicole}{base} . '::null';

    $self->SUPER::_init( %args );
}


# Compat.. Date and Dropdown for example use this
sub set_content {
    my ( $self, @params ) = @_;
    $self->text( @params );
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Text - A class that defines Dicole text object

=head1 SYNOPSIS

  use Dicole::Content::Text;
  
  $textobject = Dicole::Content::Text->new(
    text => 'Hello');

  return $self->generate_content(
    { itemparams => $textobject->template_params },
    { name => $textobject->template }


=head1 DESCRIPTION

This is a text class, which returns given content in the form that the template
dicole_base::text wants. The class is derived from Dicole::Content.

=head1 METHODS

B<new( content => SCALAR )>

 Dicole::Content::Text->new(
    content => 'This is my text'
 );

=head1 ACCESSORS

text, attributes, no_filter, text

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>
Antti Vähäkotamäki, E<lt>antti@ionstream.fiE<gt>

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

