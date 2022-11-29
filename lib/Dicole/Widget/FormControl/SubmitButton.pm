package Dicole::Widget::FormControl::SubmitButton;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

SubmitButton widget

=head1 SYNOPSIS

# Just a normal submit:

my $button = Dicole::Widget::FormControl::SubmitButton->new(
    name => 'save',
    text => $self->_msg('Save this thing'),

    # optional
    id => 'save_button',
    class => 'additional classes',
    onclick => 'return "some javascript"'
);

# Confirm before submit:

my $button = Dicole::Widget::FormControl::SubmitButton->new(
    text => $self->_msg('Save this thing'),
    confirm_box =>  {
        name => 'do_something',
        title => $self->_msg('Are you sure?'),
        msg => $self->_msg('You are doing something!'),
    }

    # optional
    id => 'save_button',
    class => 'additional classes',
);

=head1 DESCRIPTION

SubmitButton class!

Returns data in format understood by the template
I<dicole_base::widget_formcontrol_submitbutton>.

=head1 INHERITS

Inherits L<Dicole::Widget>.

=cut

use base qw( Dicole::Widget::FormControl );

=pod

=head1 ACCESSORS

=head2 text( [STRING] )

Button text. Overrides value if present.

=head2 confirm_box( [HASHREF] )

Proviced a confirmation dialog for the user before submit.

Needs following keys:

 * name: Name of the button in a form.
 * title: Title of the confirm box
 * msg: Message in the confirm box

=head2 onclick( [STRING] )

Some javascript. Ignored if confirm_box is specified.

=cut

sub DEFAULT_TEMPLATE { 'widget_formcontrol_submitbutton' };

sub ACCESSORS { (
    onclick => Dicole::Widget::ACCESSOR_RAW,
    confirm_box => Dicole::Widget::ACCESSOR_RAW,
    text => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub template_params {
    my ( $self, $params ) = @_;

    $params = $self->SUPER::template_params( $params );

    $params->{text} ||= $self->text || $self->value;

    return $params;
}

=pod

=head1 METHODS

=head2 new( [ %ARGS ] )

Creates object with optionally provided attributes.

=pod

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>antti@dicole.orgE<gt>

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

1;

