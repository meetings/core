package Dicole::Content;

use strict;
use base qw( Class::Accessor );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Generic content class

=head1 SYNOPSIS

  $c = Dicole::Content->new(
    template => 'dicole_base::null',
  );
  $c->template_params->{content} = 'Hello world!';

  print $c->generate_content;

=head1 DESCRIPTION

A base class for all Dicole content objects. They are a bit like widgets.

=head1 ACCESSORS

=item template
=item template_params

=cut

sub TEMPLATE_PARAMS { return {} };

__PACKAGE__->mk_accessors(
    qw( template params raw )
);

# COMPAT:
__PACKAGE__->mk_accessors(
    qw( content template_params )
);



=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Content> object.  Accepts a hash
of parameters for class attribute initialization:

=item template
=item template_params

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
    
    $args{template} ||= CTX->server_config->{dicole}{base} . '::null';
    $args{template_params} ||= $args{content} if ref $args{content} eq 'HASH';
    $args{template_params} ||= {};
    
    $self->template_params( $args{template_params} );
    delete $args{template_params};

    for my $accessor ( keys %args ) {
        if ( $self->can( $accessor ) ) {
            eval "\$self->$accessor( \$args{ \$accessor } )";
        }
    }    
}

sub set {
	my ( $self, $key, $value ) = @_;

    if ( $self->can( 'TEMPLATE_PARAMS' ) &&
        defined $self->TEMPLATE_PARAMS->{ $key } ) {
        
        return $self->{template_params}{ $key } = $value;
    }

    return $self->SUPER::set( $key, $value );
}

sub get {
	my ( $self, $key ) = @_;

    if ( $self->can( 'TEMPLATE_PARAMS' ) &&
        defined $self->TEMPLATE_PARAMS->{ $key } ) {

    	return $self->{template_params}{$key};
    }
    
    return $self->SUPER::get( $key );
}


=pod

=head2 generate_content

Generates the content of this class.

=cut

sub generate_content {

    return 'generated content';

}

=pod


=head2 get_template

Selectsand returns the apropriate template for this object.

=cut

sub get_template {
    my ( $self ) = @_;
    return $self->template;
}


=pod

=head2 get_template_params

Gathers and returns the needed information
to be passed to the items template.

=cut

sub get_template_params {
    my ( $self ) = @_;

    # In the future here we will assign parameters classified
    # as template params to a hash and return it.
    # How for compatibility reasons we gather them in the hash
    # (actually two) during the lifetime of the object.

    my $compat = $self->content;
    $compat = {} if ref $compat ne 'HASH';

    for my $key ( keys %$compat ) {
        unless ( defined $self->template_params->{$key} ) {
            $self->template_params->{$key} = $compat->{$key}
        }
    }

#    get_logger( LOG_ACTION )->error( Data::Dumper::Dumper( $self->template ) );
#    get_logger( LOG_ACTION )->error( Data::Dumper::Dumper( $self->template_params ) );

    return $self->template_params;
}

#####
# COMPAT:


sub set_content {
    my ( $self, $content ) = @_;
    $self->template_params( $content );
}

sub set_template {
    my ( $self, $template ) = @_;
    return $self->template( $template );
}

sub get_content {
    my ( $self ) = @_;
    return $self->template_params;
}

sub clear_content {
    my ( $self ) = @_;
    $self->template_params( {} );
}


=pod

=head1 SEE ALSO

See documentation of other I<Dicole::Content> classes.

=head1 AUTHOR

Antti Vähäkotamäki E<lt>antti@ionstream.fi<gt>

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

