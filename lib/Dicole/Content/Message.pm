package Dicole::Content::Message;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;
use Dicole::Content::Button;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Content class that forms messages.

=head1 SYNOPSIS

  $c = Dicole::Content::Message->new;
  $c->title( 'Me, Myself and I' );
  $c->icon( 'smiley.gif' );
  $c->date( '2004-02-10' );
  $c->author_name( 'John' );

  $c->add_meta( 'Category', 'Personal' );
  $c->add_message( 'Welcome to my world...blah...blah' );

  return $self->generate_content(
        { itemparams => $c->get_template_params },
        { name => $c->get_template }
  );

=head1 DESCRIPTION

A content class for creating simple messages. Messages usually contain an
author, date of creation, subject and content.

This class also allows creating message specific control buttons, icon and
additional meta descriptions of the message, making it very useful for creating
something like comments, diaries, articles etc.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

Parameters:

template, author_name, author_href, meta, controls, message, title, icon and date.

=head2 title( [STRING] )

The title or subject of the message.

=head2 title_url( [STRING] )

URL link in the title.

=head2 icon( [STRING] )

The graphical icon of the message.

=head2 date( [SCALAR] )

The date of the message in form as it will be displayed.

=cut

use base qw( Dicole::Content );

my %TEMPLATE_PARAMS = map { $_ => 1 }
        qw( title date icon title_url );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

__PACKAGE__->mk_accessors( qw( message meta author_name author_href controls ) );

sub _init {
        my ($self, %args) = @_;

        $args{template} ||= CTX->server_config->{dicole}{base} . '::message';

        for ( qw( meta controls message ) ) {
            $args{$_} = [] unless ref $args{$_} eq 'ARRAY';
        }

        $self->SUPER::_init( %args );
}

=pod

=head1 METHODS

=head2 meta( [ARRAYREF] )

Sets/gets the meta descriptions of the message. The optional first parameter is
an anonymous array of hashes. Each hash looks like the following:

  {
        key => 'Title',
        value => OBJECT
  }

Where object is a I<Dicole::Content::*> object.

This allows defining visible meta data information for the message, which will
be displayed along the title and content of the message.


=head2 add_meta( STRING, CONTENT )

Adds new meta description to the list of meta descriptions.

Accepts the title of the meta description as the first parameter.

Accepts the content of the meta description as the second parameter. If this is
a string, the default L<Dicole::Content::Text> object will be used with content
as the value of this parameter.

If it is an object that is able to answer to methods I<get_template()> and
I<get_template_params()> it will be used as the meta description content object.

=cut

sub add_meta {
        my ( $self, $title, $content ) = @_;

        $content = $self->_set_content_object( $content );

        push @{ $self->{meta} }, {
                key => $title,
                value => $content
        };
}

=pod

=head2 controls( [ARRAYREF] )

Sets/gets the control navigation of the message. The optional first parameter is
an anonymous array of I<Dicole::Content::*> objects, usually control buttons
like I<Edit> or I<Remove>.


=head2 add_controls( CONTENT|HASHREF )

Adds new control to the message controls.

Accepts the control content object as a parameter.
If it is an object that is able to answer to methods I<get_template()> and
I<get_template_params()> it will be used as the control content object.

If provided with a hashref, a new L<Dicole::Content::Button> will be created
by providing the hashref to I<new()> constructor of the Button class.

=cut

sub add_controls {
        my ( $self, $content ) = @_;
        if ( ref( $content ) eq 'HASH' ) {
            push @{ $self->controls }, Dicole::Content::Button->new(
                %{ $content }
            );
        }
        elsif ( ref $content && $content->can( 'get_template' )
                        && $content->can( 'get_template_params' )
        ) {
                push @{ $self->controls }, $content;
        }
        else {
                die ref( $content ) . ' is not a Dicole Content object.';
        }
}


=pod

=head2 message( [ARRAYREF] )

Sets/gets the content of the message. The optional first parameter is
an anonymous array of I<Dicole::Content::*> objects.

=head2 add_message( CONTENT )

Adds a new message content block.

Accepts the content of the message block as a parameter. If this is
a string, the default L<Dicole::Content::Text> object will be used with content
as the value of this parameter.

If it is an object that is able to answer to methods I<get_template()> and
I<get_template_params()> it will be used as the content of the message block.

=cut

sub add_message {
        my ( $self, $content ) = @_;
        $content = $self->_set_content_object( $content );
        push @{ $self->{message} }, $content;
}


sub get_template_params {
        my ( $self ) = @_;

        my $content = [];
        foreach my $object ( @{ $self->message } ) {
                push @{ $content }, {
                        template => $object->get_template,
                        params => $object->get_template_params
                };
        }

        my $navigation = [];
        foreach my $object ( @{ $self->controls } ) {
                push @{ $navigation }, {
                        template => $object->get_template,
                        params => $object->get_template_params
                };
        }

        my $meta = [];
        foreach my $object ( @{ $self->meta } ) {
                push @{ $meta }, {
                        key => $object->{key},
                        value => {
                                template => $object->{value}->get_template,
                                params => $object->{value}->get_template_params
                        }
                };
        }

        my $params = $self->SUPER::get_template_params;

        $params->{content} = $content;
        $params->{meta} = $meta;
        $params->{navigation} = $navigation;
        $params->{author} = {
            name => $self->author_name,
            href => $self->author_href,
        };

        return $params;
}

=pod

=head1 PRIVATE METHODS

=head2 _set_content_object( CONTENT )

Accepts content as a parameter and constructs an appropriate content object if
necessary.

If this is a string, the default L<Dicole::Content::Text> object will be used
with content as the value of this parameter.

If it is an object that is able to answer to methods I<get_template()> and
I<get_template_params()> it will be used as is.

=cut

sub _set_content_object {
        my ( $self, $content ) = @_;

        if ( ref $content ) {
                if ( $content->can( 'get_template' )
                        && $content->can( 'get_template_params' )
                ) {
                        return $content;
                }
                else {
                        die ref( $content ) . ' is not a Dicole Content object.';
                }
        }
        else {
                return Dicole::Content::Text->new( content => $content );
        }
}


=pod

=head1 SEE ALSO

L<Dicole::Content>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>
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

