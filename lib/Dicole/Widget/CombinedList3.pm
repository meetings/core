package Dicole::Widget::CombinedList3;

use strict;
use base qw( Dicole::Widget::Element );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Storable;

sub DEFAULT_TEMPLATE { 'widget_combined_list_3' };

sub ACCESSORS { (
    elements => Dicole::Widget::ACCESSOR_SPECIAL,
    separator1 => Dicole::Widget::ACCESSOR_SPECIAL,
    separator2 => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{elements} = [] unless ref $args{elements} eq 'ARRAY';

    $args{separator1} ||= sub {''};
    $args{separator2} ||= sub {''};

    $self->SUPER::_init( %args );
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    $params->{elements} = [];

    my $last_s1 = undef;
    my $last_s2 = undef;
    
    for my $element ( @{ $self->elements } ) {
        my $s1 = $self->separator1->( $element->{params} );
        my $s2 = $self->separator2->( $element->{params} );

        my $s1_content = $self->content_params( $s1 );
        if ( ! defined $last_s1 || ! $self->_equals( $last_s1, $s1_content ) ) {
            push @{ $params->{elements} }, {
                content => $s1_content,
                elements => [],
            };
            $last_s1 = $s1_content;
            $last_s2 = undef;
        }

        my $s2_content = $self->content_params( $s2 );
        if ( ! defined $last_s2 || ! $self->_equals( $last_s2, $s2_content ) ) {
            push @{ $params->{elements}->[-1]->{elements} }, {
                content => $s2_content,
                elements => [],
            };
            $last_s2 = $s2_content;
        }

        push @{ $params->{elements}->[-1]->{elements}->[-1]->{elements} }, {
            content => $self->content_params( $element->{content} ),
            params => $element->{params},
        };
    }

    return $params;
}

sub _equals {
    my ( $self, $a, $b ) = @_;
    return 0 if ref $a ne ref $b;
    if ( ! ref $a ) { return $a eq $b ? 1 : 0; }
    return Storable::freeze( $a ) eq Storable::freeze( $b ) ? 1 : 0;
}

1;

=pod
=head1 NAME

Dated list of items

=head1 SYNOPSIS

   my $container = Dicole::Widget::CombinedList3->new(
      elements => [
        {
          params => { .. },
          content => Dicole::Widget::Text->new( text => 'Hello', ... ),
        }
      ],
      separator1 => sub { my $params = shift; return '';},
      separator2 => sub { my $params = shift; return '';},
   );

=head1 DESCRIPTION

This is a widget for listing elements in a compact way.
If separators formed for consecutive elements are the same, only the first
one will be displayed.

Widget does not sort elements so be sure to add the elements in the order
you wish for them to be shown.

=head1 INHERITS

Inherits L<Dicole::Widget::Element>.

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>
L<Dicole::Widget::Element|Dicole::Widget::Element>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>antti@dicole.comE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2005 Ionstream Oy / Dicole
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
