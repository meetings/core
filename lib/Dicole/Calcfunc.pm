package Dicole::Calcfunc;

use strict;
use base qw( Exporter );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
our @EXPORT = qw( two_digits if_int );

=pod

=head1 NAME

An utility class for playing with numbers

=head1 SYNOPSIS

 use Dicole::Calcfunc;

 my number = 5;
 $number = two_digits( $number ); # 05

 my $text = '34.32';
 print "true" if if_int( $number ); # true
 print "true" if if_int( $text ); # false

=head1 DESCRIPTION

This class provides a couple of useful functions for playing around
with numbers. Exports all the methods in this class.

=head1 METHODS

=head2 two_digits( INTEGER )

Converts a number to include two digits if the number is less
than 10.

Examples:
5 becomes 05
15 becomes 15

=cut

sub two_digits {

        my ( $digit ) = @_;

        if ( $digit < 10 ) {
                return '0' . $digit;
        } else {
                return $digit;
        }
}

=pod

=head2 if_int( VAR )

Checks if a variable is a simple positive integer or not.
Does not accept decimal numbers or text.

Returns true upon success, undef upon failure.

=cut

sub if_int {

        my ( $number ) = @_;

        unless ( $number =~ /^(\d+)$/ ) {
                return undef;
        } else {
                return $number;
        }
}

=pod

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>,

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
