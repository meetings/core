package Dicole::Box;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Represent boxes inside containers

=head1 SYNOPSIS

 use Dicole::Box;
 my $lb = Dicole::Box->new(
      name => 'Box',
      content => [
          Dicole::Content::List->new(),
          Dicole::Content::Formelement::Dropdown->new()
      ],
      class => 'profile_common_box',
 );

 return $self->generate_content(
     { itemparams => $lb->output },
     { name => $lb->template }
 );

=head1 DESCRIPTION

Box class is used to represent and generate boxes which are used as
containers for L<Dicole::Content> objects. Box objects are usually
inside L<Dicole::Container> objects.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 ACCESSORS

=head2 template( [STRING] )

Sets/gets the name of the template for which the resulting data structure
representing the box will be provided.

=head2 name( [STRING] )

Sets/gets the name of the box. This is printed on the top of the box.

=head2 form_params( [HASHREF] )

Sets/gets a reference to a hash which contains attributes for the form the box
is wrapped in. If this is undefined, the form is not created around the box.

=head2 content( [ARRAYREF|OBJECT] )

Sets/gets the arrayref of content objects in the box. Accepts
an arrayref of content objects or a single content object as a
parameter. Replaces the existing content objects.

=cut

Dicole::Box->mk_accessors( qw( name template form_params class ) );

sub content {
    my ( $self, $content ) = @_;
    if ( defined $content ) {
        $self->{content} = (ref $content eq 'ARRAY')
            ? $content : [ $content ];
    }
    unless ( defined $self->{content} ) {
        $self->{content} = [];
    }
    return $self->{content};
}

=pod

=head1 METHODS

=head2 new( [HASH] )

Creates and returns a new Box object.

Accepts a hash of parameters:

=over 4

=item B<name> I<string>

Name of the box. This is displayed as the title at the top of the box.

=item B<content> I<arrayref>

An array which contains any number of L<Dicole::Content> objects. These
are the content inside the box, e.g. a collection of form objects.

=item B<form_params> I<hashref>

A reference to a hash which contains attributes for the form the box
is wrapped in. If this is undefined, the form is not created around the box.

This is often unnecessary, because L<Dicole::Tool> is able to wrap a form around
the whole container, in other words around all the boxes.

=item B<template> I<string>

The name of the template for which the resulting data structure representing the box
will be provided. By default this is I<dicole_base::tool_content> and it is often
not necessary to change it.

=back

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

sub _init {
    my ($self, %args) = @_;
    $args{template} = CTX->server_config->{dicole}{base} . '::tool_content'
        unless defined $args{template};
    $args{name} = '' unless (defined ($args{name}) && ref $args{name} eq '');
    $self->template( $args{template} );
    $self->content( $args{content} );
    $self->name( $args{name} );
    $self->class( $args{class} );
    $self->form_params( $args{form_params} )
        if ref $args{form_params} eq 'HASH';
}

=pod

=head2 get_content_count()

Returns the number of content objects in the box.

=cut

sub get_content_count {
    my $self = shift;
    my $count = @{ $self->{content} };
    return $count;
}

=pod

=head2 add_content( ARRAYREF|OBJECT )

Adds new content object(s) in the box. Accepts
an arrayref of content objects or a single content
object as a parameter.

=cut

sub add_content {
    my ( $self, $content ) = @_;
    push @{ $self->{content} }, (ref $content eq 'ARRAY')
        ? @{ $content }
        : $content;
}

=pod

=head2 clear_content()

Removes all the content objects in the box.

=cut

sub clear_content {
    my $self = shift;
    $self->{content} = [];
}

=pod

=head2 has_form_params()

Returns true if the form has parameters.

=cut

sub has_form_params {
    my $self = shift;
    return defined $self->{form_params};
}

=pod

=head2 clear_form_params()

Clears the form parameters.

=cut

sub clear_form_params {
    my $self = shift;
    undef $self->{form_params};
}

=pod

=head2 output()

Returns the data structure according to the internal status of the object.
The output is in the format that template I<dicole_base::tool_content> expects.
The returned value is in the following format:
 {
    name => the name that appears on top of the container
    form_params => {
        form parameters (if the box is wrapped in a form)
    }
    content => [
        # a hashref for each element inside the box
        {
            template => name of the template
            params => { ... }
        },
        ...
    ]
 }

=cut

sub output {
    my $self = shift;
    my $output = {
        name => $self->name,
        class => $self->class,
        template => $self->template,
        content => []
    };
    $output->{form_params} = $self->form_params if $self->has_form_params;

    foreach my $object ( @{ $self->content } ) {
        push @{$output->{content}}, {
            template => $object->get_template,
            params => $object->get_template_params,
        } if defined $object;
    }

    return $output;
}

=pod

=head1 SEE ALSO

L<Dicole::Container>, L<Dicole::Content>.

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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

