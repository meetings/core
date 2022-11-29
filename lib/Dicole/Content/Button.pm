package Dicole::Content::Button;

use 5.006;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Button content class

=head1 SYNOPSIS

  $c = Dicole::Content::Button->new;
  $c->set_content( { content => 'Hello world!' } );

  return $self->generate_content(
 	{ itemparams => $c->get_template_params },
 	{ name => $c->get_template }
  );

=head1 DESCRIPTION

This is a button class, which allows handling button content
(usually using dicole_base::button template) as objects.

=head1 INHERITS

Inherits L<Dicole::Content>.

=cut

use base qw( Dicole::Content );

my %TEMPLATE_PARAMS = map { $_ => 1 } 
    qw( name value link confirm_box );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

=pod

=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Content::Button> object.
Accepts a hash of parameters for class attribute initialization.

Parameters:

See I<template()> and I<content()>.

=head2 name( [STRING] )

Accessor to set/get name of the button. This will be the form element
name used.

=head2 value( [STRING] )

Accessor to set/get value of the button. This is the readable text on
the button.

=head2 link( [STRING] )

Accessor to set/get hyperlink of the button. This method works for
button types I<link> and I<onclick_button>.

=head2 confirm_box( [STRING] )

Accessor to set/get the text in the confirmation box. Only works for
button type I<confirm_submit>.

=cut

sub KNOWN_TYPES {
	return qw( submit confirm_submit link onclick_button );
}

sub _init {
	my ($self, %args) = @_;

	$args{template} ||= CTX->server_config->{dicole}{base} . '::button';
    $args{type} ||= 'submit';

	$self->SUPER::_init( %args );
}

=pod

=head2 type( [STRING] )

Accessor to set/get type of the button. Currently available types
are I<submit, confirm_submit, link> and I<onclick_button>.

=cut

sub type {
    my ($self, $value) = @_;

    return $self->template_params->{type} unless defined $value;

    $value = 'submit' unless grep { $value eq $_ } ( $self->KNOWN_TYPES );

    return $self->template_params->{type} = $value;
}

=pod

=head1 SEE ALSO

L<Dicole::Content>,

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>
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

