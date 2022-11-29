package Dicole::Content::Formelement::Chooser;

use strict;

use DateTime;
use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Chooser content object for selecting things

=head1 SYNOPSIS

  use Dicole::Content::Formelement::Chooser;
  $p = Dicole::Content::Formelement::Chooser->new( autosubmit => 1 );
  $p->chooser('/file_select/');
  $p->button_text('Browse...');

  $self->generate_content(
        { itemparams => $p->get_template_params },
        { name => $p->get_template }
  );

=head1 DESCRIPTION

This is a chooser class, which implements a way to spawn a selection dialog.
A chooser is in two parts: a normal input box for manually entering the chosen
item and a button for selecting the item with the help of a selection dialog.

Example implementations for a selection dialog would be selection of files,
groups, usernames and dates.

Returns data in format understood by the template I<dicole_base::input_chooser>.

=head1 INHERITS

Inherits L<Dicole::Content::Formelement>, which provides some methods for our class.

=cut

use base qw( Dicole::Content::Formelement );

=pod

=head1 ACCESSORS

=head2 autosubmit( [BOOLEAN] )

If this is set on, the chooser dialog expects it should automatically
submit the calling parent window form once the selection has been made.

The default is false.

=head2 chooser( [STRING] )

The URL to the chooser dialog application.

=head2 path( [STRING] )

The relative path for the selection dialog.
The path will be added to the URL of the chooser application.

Not set by default.

=head2 dialog_name( [STRING] )

The name of the dialog which will popup. This is used for uniquely identifying
the correct dialog.

The default is I<chooser>.

=head2 button_text( [STRING] )

The text for the button that spawns the selection dialog.

The default is I<Browse...>.

=cut

my %TEMPLATE_PARAMS = map { $_ => 1 } 
        qw( autosubmit chooser path dialog_name button_text );

sub TEMPLATE_PARAMS { 
    my ($self) = @_;

    return {
        %{$self->SUPER::TEMPLATE_PARAMS},
        %TEMPLATE_PARAMS
    }
}

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

=pod

=head1 METHODS

=head2 new( [ %ARGS ] )
Takes some parameters that the constructor of L<Dicole::Content::Formelement>
accepts (most of these aren't however supported by the template).

Other supported parameters are 
I<dialog_name>, I<button_text>, I<autosubmit>, I<path> and I<chooser>.

=cut

sub _init {
        my ($self, %args) = @_;
        
        $args{template} ||= CTX->server_config->{dicole}{base} . '::input_chooser';
        $args{modifyable} = 1 if ! defined $args{modifyable};

        $self->SUPER::_init( %args );
}

=pod

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>
L<Dicole::Content::Formelement|Dicole::Content::Formelement>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>antti@ionstream.fiE<gt>
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

