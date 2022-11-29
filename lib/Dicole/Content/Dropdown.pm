package Dicole::Content::Dropdown;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Dropdown in content area

=head1 SYNOPSIS

..
my $dd = Dicole::Content::Dropdown->new(
    text => 'Open dropdown',
    title => 'Take your pick',
);

$dd->add_element(
    text => 'Open',
    link => Dicole::URL->create_from_current(
        task => 'open',
    ),
);

$dd->add_delimiter;

$dd->add_elements(
    {
        text => 'Open',
        link => Dicole::URL->create_from_current(
            task => 'open',
        ),
    },
    ...
);

=head1 DESCRIPTION

Dropdown class!

Returns data in format understood by the template I<dicole_base::dropdown>.

=head1 INHERITS

Inherits L<Dicole::Content>.

=cut

use base qw( Dicole::Content );

=pod

=head1 ACCESSORS

=head2 id( [STRING] )

unique id. defaults to  a random number.

=head2 text( [STRING] )

Text in the link which opens the dropdown.

=head2 title( [STRING] )

Text in the title of the dropdown.

=head2 selected( [STRING] )

Number of the selected element starting from 0. Default: 0.

=head2 elements( [STRING] )

The dropdown element hash.


=cut

my %TEMPLATE_PARAMS = map { $_ => 1 }
        qw( id text elements title selected );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );


sub _init {
        my ($self, %args) = @_;
        $args{template} ||= CTX->server_config->{dicole}{base} . '::dropdown';
        $args{id} ||= int( 1000000*rand );
        $args{text} ||= 'Open Dropdown';
        $args{selected} ||= '0';
        $args{elements} ||= [];

        $self->SUPER::_init( %args );
}




=pod

=head1 METHODS

=head2 new( [ %ARGS ] )
Takes some parameters that the constructor of L<Dicole::Content> accepts.

Other supported parameters are I<id>, I<text>, I<elements>.


=head2 add_element( text => STRING, link => STRING  )

Add one element

=cut

sub add_element {
    my ( $self, %p ) = @_;

    push @{ $self->elements }, \%p;
}

=pod

=head2 add_elements( HASHREF, ...  )

Add one or more elements in hashrefs

=cut

sub add_elements {
    my ( $self, @p ) = @_;

    push @{ $self->elements }, @p;
}

=pod

=head2 add_delimiter()

Add delimiter

=cut

sub add_delimiter {
    my ( $self ) = @_;

    push @{ $self->elements }, {
        type => 'delimiter'
    };
}

=pod

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

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

