package Dicole::MessageHandler;

use strict;

use base qw( Exporter );

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Handle messages usually presented to user

=head1 SYNOPSIS

 use Dicole::MessageHandler qw( :message );

 Dicole::MessageHandler->add_message( MESSAGE_ERROR, 'Error occured' );
 my $messages = Dicole::MessageHandler->get_messages;

=head1 DESCRIPTION

Handle messages usually presented to user. The purpose of this class is to
provide a framework for adding messages into user session for later retrieval.
These messages are usually displayed by L<Dicole::Tool>.

=cut

our @EXPORT_OK = qw( MESSAGE_ERROR MESSAGE_SUCCESS MESSAGE_WARNING );

our %EXPORT_TAGS = (
    message => [ qw( MESSAGE_ERROR MESSAGE_SUCCESS MESSAGE_WARNING ) ],
);

=pod

=head1 CONSTANTS

These constants can be exported with key :message .

=head2 MESSAGE_ERROR()

Return code error. This code is used for return messages that indicate that
the request had an error and did not complete successfully.

=head2 MESSAGE_SUCCESS()

Return code success. This code is used for return messages that indicate that
the request completed successfully.

=head2 MESSAGE_WARNING()

Return code warning. This code is used for return messages that indicate that
the request completed successfully but had warnings.

=cut

## constants as methods for easy inheritance
sub MESSAGE_ERROR   { return 0; }
sub MESSAGE_SUCCESS { return 1; }
sub MESSAGE_WARNING { return 2; }

sub RETURN_CODE_ERROR   { return 0; }
sub RETURN_CODE_SUCCESS { return 1; }
sub RETURN_CODE_WARNING { return 2; }

=pod

=head2 add_message( HASH | CODE, CONTENT )

Adds a tools message. Accepts either a hash (with
code & message) or code and message as parameters.

=cut

sub add_message {
    my ( $self, $var1, $var2 ) = @_;

    return unless defined $var1;

    if ( ref $var1 ne 'HASH' ) {

        $var1 = {
            code => $var1,
            content => $var2,
        };
    }

    return if !$var1->{content};

    my $lh = CTX->request->language_handle;

    $var1->{title} = ($var1->{code} )
        ? ( $var1->{code} == 1 )
            ? $lh->maketext( 'Success' )
            : $lh->maketext( 'Warning' )
        : $lh->maketext( 'Error' );

    unless ( ref( CTX->request->sessionstore->get_value( 'tool', 'messages' ) ) eq 'ARRAY' ) {
        CTX->request->sessionstore->set_value( 'tool', 'messages', [] );
    }

    push @{ CTX->request->sessionstore->get_value( 'tool', 'messages' ) }, $var1;

    return $var1;
}

=pod

=head2 get_messages()

Returns an arrayref of message hashes.

=cut

sub get_messages {
    my ( $self ) = @_;

    my $return = CTX->request->sessionstore->get_value( 'tool', 'messages' );

    return $return;
}

=pod

=head2 clear_messages()

Clears all tool messages.

=cut

sub clear_messages {
    my ( $self ) = @_;

    return CTX->request->sessionstore->delete_value( 'tool', 'messages' );
}

=pod

=head1 SEE ALSO

L<Dicole::Tool>

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>,
Antti V��otam�i E<lt>antti@ionstream.fiE<gt>,

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

