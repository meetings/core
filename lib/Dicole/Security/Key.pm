package Dicole::Security::Key;

=pod

=head1 NAME

Create a random 256-bit key

=head1 DESCRIPTION

Defined in the [system_class] section in server.ini to generate a new
random 256-bit key upon server startup that all the apache child processes
are sharing.

=cut

our $KEY = set_key();

=pod

=head1 METHODS

=head2 KEY()

Returns the 32-bit key.

=cut

sub KEY {
    return $KEY;
}

=pod

=head2 set_key()

Sets the 256-bit key. This function is called automatically when this module
gets loaded.

=cut

sub set_key {
    my @chars = ( 'a'..'f', 0 .. 9 );
    return join '', @chars[ map { rand @chars } ( 1..32 ) ];
}

=pod

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

