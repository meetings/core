package Dicole::Content::Image;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Chooser content object for selecting things

=head1 SYNOPSIS

..
my $image = Dicole::Content::Image->new(
    src => '/images/theme/default/tree/16x16/summary.png',
    width => 16,
    height => 16
);

=head1 DESCRIPTION

Image class!

Returns data in format understood by the template I<dicole_base::image>.

=head1 INHERITS

Inherits L<Dicole::Content>.

=cut

use base qw( Dicole::Content );

=pod

=head1 ACCESSORS

=head2 href( [STRING] )

The URL link of the image.

=head2 href_target( [STRING] )

Target where the URL is opened.

=head2 src( [STRING] )

The source URL of the image.

=head2 width( [STRING] )

The width of the image.

I<100%> by default.

=head2 height( [STRING] )

The height of the image.

I<100%> by default.

=head2 align( [STRING] )

The alignment of the image.

I<middle> by default.

=head2 alt( [STRING] )

Alt attribute. Empty by default.

=cut

my %TEMPLATE_PARAMS = map { $_ => 1 }
        qw( src width height align alt class id );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

__PACKAGE__->mk_accessors( qw( href href_target ) );

sub _init {
        my ($self, %args) = @_;
        $args{template} ||= CTX->server_config->{dicole}{base} . '::image';
        $args{align} ||= 'middle';
        $args{alt} ||= $args{title} || '';

        $self->SUPER::_init( %args );
}

sub get_template_params {
        my ($self) = @_;

        my $template_params = $self->SUPER::get_template_params;
        $template_params->{title} = $template_params->{alt};

        return {
            attributes => $template_params,
            href => $self->href,
            href_target => $self->href_target,
        };
}


=pod

=head1 METHODS

=head2 new( [ %ARGS ] )
Takes some parameters that the constructor of L<Dicole::Content::Formelement>
accepts (most of these aren't however supported by the template).

Other supported parameters are I<src>, I<alt>, I<width>, I<height> and I<align>.


=head2 title( [STRING] )

Alias for alt.

=cut

sub title {
        my ( $self, @p ) = @_;

        return $self->alt( @p );
}

=pod

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>
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

