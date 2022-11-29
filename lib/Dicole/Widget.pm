package Dicole::Widget;

use strict;
use base qw( Class::Accessor );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Class::ISA;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/ );

use constant ACCESSOR_SPECIAL => 0;
use constant ACCESSOR_RAW => 1;
use constant ACCESSOR_WIDGET => 2;
use constant ACCESSOR_WIDGET_ARRAY => 3;


sub DEFAULT_TEMPLATE { 'null' }
sub DEFAULT_CONTENT_GENERATOR { 'TT' }

sub ACCESSORS { (
    raw => ACCESSOR_RAW,
    template => ACCESSOR_SPECIAL,
    content_generator => ACCESSOR_SPECIAL,
) };

 __PACKAGE__->mk_widget_accessors;

=pod

=head1 NAME

Generic widget base class

=head1 SYNOPSIS

  # Inheritable superclass for widget objects

  my $w = Dicole::Widget::Object->new;
  
  $w->raw( 'raw html' );

  print $w->raw || $w->generate_content;
   or
  print $tt->generate_content( {
      template => $w->template,
      template_params => $w->template_params,
  } );

=head1 DESCRIPTION

A base class for all Dicole widget objects.

=head1 ACCESSORS

=item
template - Contains the name of the template used to generate content.

=item
raw - Contains the generated content after content generation.

=item
content_generator - Contains the generator. Default: TT.

=cut

=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Content> object.  Accepts a hash
of parameters for class attribute initialization and populates
accessors using the _init method.

=cut

sub new {
    my ($class, %args) = @_;

    my $config = {};
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

sub _init {
    my ($self, %args) = @_;
    
    $args{template} ||= CTX->server_config->{dicole}{base} . '::' .
        $self->DEFAULT_TEMPLATE;
    $args{content_generator} ||= CTX->content_generator(
        $self->DEFAULT_CONTENT_GENERATOR );

    for my $accessor ( keys %args ) {
        if ( $self->can( $accessor ) ) {
            $self->set( $accessor, $args{ $accessor } );
        }
    }
}

=pod

=head2 generate_content

Generates widget content into 'raw' accessor if it is not already
generated. Returns the raw content.

=cut

sub generate_content {
    my ($self) = @_;

    return defined $self->raw ? $self->raw : $self->raw(
        $self->content_generator->generate(
            {},
            { itemparams => $self->template_params },
            { name => $self->template }
        )
    );
}

=pod

=head2 template_params

Gathers and returns the needed information to be passed to
the items template. 

=cut

sub template_params {
    my ( $self, $params ) = @_;

    $params ||= {};

    my $accessors = $self->_all_accessors;

    while ( (my $accessor_name, my $accessor_type) = each %$accessors ) {
        if ( $accessor_type ) {
            if ( $accessor_type == ACCESSOR_RAW ) {
                $params->{ $accessor_name } = $self->get( $accessor_name );
            }
            elsif ( $accessor_type == ACCESSOR_WIDGET ) {
                $params->{ $accessor_name } = $self->content_params(
                    $self->get( $accessor_name )
                );
            }
            elsif ( $accessor_type == ACCESSOR_WIDGET_ARRAY){
                $params->{$accessor_name} = [];
                
                my $check_array = $self->get($accessor_name);
                if(ref($check_array) eq 'ARRAY') {
                    for my $widget ( @{ $self->get( $accessor_name) } ) {;
                        push @{ $params-> {$accessor_name} }, $self->content_params( $widget );
                    };
                }
            }
        }
    }

    return $params;
}

# Loops through all the ACCESSORS -method found in all base classes
# and returns a hashref of those accessors combined.
sub _all_accessors {
    my ( $self ) = @_;
    my $class = ref $self;
    my @accessors = ();
    for my $base ( reverse( $class, Class::ISA::super_path( $class ) ) ) {
        next if $base !~ /^Dicole::Widget/;
        push @accessors, $base->ACCESSORS if $base->can( 'ACCESSORS' );
    }
    return { @accessors };
}

=pod

=head2 content_params

If the argument given is a Dicole::Widget::? -object returns a
hash reference containing either raw data in key 'raw' or
template name and paremeters in keys 'template' and 'params'.

Otherwise creates a Dicole::Widget::Text element with the given
content as text and returns a hash reference containing it's
template and params.

=cut

sub content_params {
    my ( $self, $content ) = @_;

    return undef unless defined $content;

    my $hash = {};

    if ( ref( $content ) =~ /^Dicole::Widget::/ ) {

        $hash->{raw} = $content->raw;

        if ( ! $hash->{raw} ) {
            $hash->{template} = $content->get_template;
            $hash->{params} = $content->get_template_params;
        }
    }
    elsif ( ref( $content ) =~ /^Dicole::Content::/ ) {
        $hash->{template} = $content->get_template;
        $hash->{params} = $content->get_template_params;
    }
    else {
        my $text = Dicole::Widget::Text->new( text => $content );
        $hash->{template} = $text->get_template;
        $hash->{params} = $text->get_template_params;
    }

    return $hash;
}

=pod

=head2 mk_widget_accessors

Looks for the ACCESSORS -method and adds keys from the returned
array as Class::Accessor accessors.

=cut

sub mk_widget_accessors {
    my ( $class, %accessors ) = @_;
    if ( $class->can( 'ACCESSORS' ) ) {
        my %accessors = $class->ACCESSORS;
        $class->mk_accessors( keys %accessors );
    }
}

# COMPATIBILITY METHODS FOR Dicole::Box

sub get_template_params { my $self = shift; return $self->template_params; }
sub get_template { my $self = shift; return $self->template; }


=pod

=head1 SEE ALSO

=head1 AUTHOR

Antti V��otam�i E<lt>antti@ionstream.fi<gt>

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

