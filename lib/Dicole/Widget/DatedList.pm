package Dicole::Widget::DatedList;

use strict;
use base qw( Dicole::Widget::CombinedList3 );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{elements} = [] unless ref $args{elements} eq 'ARRAY';
    
    if ( $args{separator_set} eq 'date & time' ) {
        $args{separator1} = sub {
            return Dicole::DateTime->date_long( shift->{date} );
        };
        $args{separator2} = sub {
            return Dicole::DateTime->time( shift->{date} );
        };
    }
    elsif ( $args{separator_set} eq 'month & day' ) {
        $args{separator1} = sub {
            return Dicole::DateTime->month_year_long( shift->{date} );
        };
        $args{separator2} = sub {
            return Dicole::DateTime->day( shift->{date} );
        };
    }
    elsif ( $args{separator_set} eq 'month & day time' ) {
        $args{separator1} = sub {
            return Dicole::DateTime->month_year_long( shift->{date} );
        };
        $args{separator2} = sub {
            my $date = shift->{date};
            return Dicole::Widget::Vertical->new( contents => [
                Dicole::DateTime->day( $date ),
                Dicole::DateTime->time( $date ),
            ] );
        };
    }
    else {
        # defaults separately to 'date & time' but either one can be overridden with args
        $args{separator1} ||= sub {
            return Dicole::DateTime->date_long( shift->{date} );
        };
        $args{separator2} ||= sub {
            return Dicole::DateTime->time( shift->{date} );
        };
    }

    $self->SUPER::_init( %args );
}

1;

=pod
=head1 NAME

Dated list of items

=head1 SYNOPSIS

   my $container = Dicole::Widget::DatedList->new(
      elements => [
        {
          params => { date => $datetime->epoch },
          content => Dicole::Widget::Text->new( text => 'Hello', ... ),
        }
      ],
   );

=head1 DESCRIPTION

This is a widget for listing elements sorted by date in a nice way.

Widget does not sort elements so be sure to add the elements in the order
you wish for them to be shown.

=head1 INHERITS

Inherits L<Dicole::Widget::CobinedList3>.

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>
L<Dicole::Widget::Element|Dicole::Widget::Element>
L<Dicole::Widget::CobinedList3|Dicole::Widget::CobinedList3>

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
