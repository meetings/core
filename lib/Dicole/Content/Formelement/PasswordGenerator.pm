package Dicole::Content::Formelement::PasswordGenerator;

use strict;

use DateTime;
use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Chooser content object for selecting things

=head1 SYNOPSIS

  use Dicole::Content::Formelement::PasswordGenerator;
  $p = Dicole::Content::Formelement::PasswordGenerator->new();
  $p->button_text('Generate password');

  $self->generate_content(
        { itemparams => $p->get_template_params },
        { name => $p->get_template }
  );

=head1 DESCRIPTION

This is the Dicole password content class, which can output a password
input field with password generation button. 
Returns data in the format that the template I<dicole_base::input_password>
accepts.

Returns data in format understood by template I<dicole_base::input_password_generator>.

=head1 INHERITS

Inherits L<Dicole::Content::Formelement>, which provides some methods for our class.

=cut

use base qw( Dicole::Content::Formelement );

=pod

=head1 ACCESSORS

=head2 button_text( [STRING] )

The text for the button that generates the random password.

Default is I<Generate>

=head2 password_length( [INTEGER] )

The length of the password being generated.

Default is I<6>

=cut

my %TEMPLATE_PARAMS = map { $_ => 1 } 
        qw( button_text password_length );

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
        
        $args{template} ||= CTX->server_config->{dicole}{base} . '::input_password_generator';
        $args{modifyable} = 1 if ! defined $args{modifyable};

        $self->SUPER::_init( %args );
}

=pod

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>
L<Dicole::Content::Formelement|Dicole::Content::Formelement>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@dicole.orgE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2006 Dicole Oy
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

