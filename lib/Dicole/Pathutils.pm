
package Dicole::Pathutils;

use strict;

use URI::Escape;
use File::Spec;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::URL;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Dicole path handling utils

=head1 SYNOPSIS

  use Dicole::Pathutils;

  my $pathutils = Dicole::Pathutils->new
  my $relative_path = $pathutils->get_current_path;

=head1 DESCRIPTION

The purpose of this class is to provide virtual Apache URI path handling and
manipulation functions often needed in Dicole development. Especially useful are
the filtering methods, that allow cleaning the path of possible malicious
file system access intentions and URI escaping to create URI's that contain
information often not possible to transmit as-is.

The idea behind this is that often the URI is virtual but a similar location
exists elsewere. The virtual path is usually constructed after the action and
task in the URL. This class provides methods to access that virtual path and
doing various things with it.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=head2 new( [HASHREF] )

Initializes and creates a new I<Dicole::Pathutils> object.  Accepts an anonymous
hash of parameters for class attribute initialization.

Parameters:

See I<base_path()>, I<path()> and I<illegal_chars()>.

=head2 base_path( [PATH] )

Sets/gets the base path of the directory tree in the filesystem.

NOTE: This might be moved to L<Dicole::Files::Filesystem>.

=head2 url_base_path( [PATH] )

Sets/gets the url base path. This is used in url comparison and creation
functions in addition to action and task.

=head2 path( [PATH] )

Sets/gets the relative path to use instead of reading the relative path from the
Apache request URI.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Pathutils->mk_accessors(
    qw( base_path path url_base_path )
);

=pod

=head1 METHODS

=head2 illegal_chars( [STRING] )

Sets/gets a list of illegal characters that will be considered as illegal in
path names. The characters must be valid for a regular expression list I<[]>,
i.e. reserved regexp characters escaped with \.

Returns a default built-in list of illegal characters if a custom list of
characters was not provided.

=cut

sub illegal_chars {
    my ( $self, $chars ) = @_;
    if ( defined $chars ) {
        $self->{illegal_chars} = $chars
    }
    unless ( defined $self->{illegal_chars} ) {
        $self->{illegal_chars} = '\\\'"!\#\$\%\|\&\^\*\<\>\{\}\[\]\(\)\?';
    }
    return $self->{illegal_chars};
}

=pod

=head2 current_path_segments( [PATH] )

By default returns the current path segments
(action, task and url_base_path excluded) as an anonymous array.

Optionally accepts the path as a parameter which will be
split into segments.

=cut

sub current_path_segments {
    my ( $self, $path ) = @_;
    $path ||= CTX->request->url_relative;
    # Hack: get rid or GET parameters
    $path =~ s/\?.*$//;
    $path = URI::Escape::uri_unescape( $path );
    
    my @path = grep { defined( $_ ) && $_ ne '' } ( split "/", $path );

    # take action, task and url base path components
    # out of the path segments
    my @split = split '/', $self->url_base_path;
    foreach ( 0..( 1 + scalar @split ) ) {
        shift @path;
    }
    return \@path;
}

=pod

=head2 get_current_dir( [PATH] )

Gets the current directory. It is constructed by removing the last segment of
the path.

Optionally accepts the relative path to use, otherwise uses the path returned by
I<get_current_path()>.

=cut

sub get_current_dir {
    my ( $self, $path ) = @_;
    $path ||= $self->get_current_path;
    my @current_path = split '/', $path;
    pop @current_path;
    return join '/', @current_path;
}

=pod

=head2 escape_uri( [PATH] )

Escapes the unsafe characters in path segments according to RFC 2396 (URI).
Returns the escaped URI.

Optionally accepts the relative path to use, otherwise uses the path returned by
I<get_current_path()>.

=cut

sub escape_uri {
    my ( $self, $uri ) = @_;
    my @escaped = ();
    $uri ||= $self->get_current_path;
    my @path_segments = split '/', $uri;
    foreach my $segment ( @path_segments ) {
        push @escaped, URI::Escape::uri_escape( $segment );
    }
    return join '/', @escaped;
}

=pod

=head2 get_current_path( [ESCAPE] )

Gets the current path and returns it. Current path is the request apache URI
path without the action and task parts (first parts of the URI). If class
attribute <path()> is set, uses its value instead. The returned path is cleaned
by filtering path segments through class method I<clean_filename()>.

If passed with a true parameter, the segments are also escaped according to RFC
2396 (URI). The path segments are not filtered this time.

=cut

sub get_current_path {
    my ( $self, $escape ) = @_;

    my @path_segments = undef;
    
    if ( $self->path ) {
        @path_segments = split( '/', $self->path )
    }
    else {
        @path_segments = @{ $self->current_path_segments };
    }

    if ( $escape ) {
        my @escaped = ();
        foreach my $segment ( @path_segments ) {
            push @escaped, URI::Escape::uri_escape( $segment );
        }
        return join '/', @escaped;
    }
    else {
        my @unescaped = ();
        foreach my $segment ( @path_segments ) {
            $segment = URI::Escape::uri_unescape( $segment );
            push @unescaped, $self->clean_filename( $segment );
        }
        return join '/', @unescaped;
    }

}

=pod

=head2 get_server_url()

Returns the URL of the server. If the server.ini variable
I<server_info.server_url> is true, its value is returned.

Otherwise constructs the server url by looking the URI hostname and returning it
prefixed with I<http://>.

If you use HTTPS, it is suggested that the server.ini variable
I<server_info.server_url> is set.

=cut

sub get_server_url {
    my ( $self ) = @_;

    return 'https://' . CTX->request->server_name;
}

=pod

=head2 path_level()

Returns the path level. This is done by getting the current path, calculating
the number of path segments and returning the value.

=cut

sub path_level {
    my ( $self ) = @_;

    my @split = split( '/', $self->path );

    my $path = ( $self->path )
        ? scalar @split
        : scalar @{ $self->current_path_segments };

    return $path;
}

=pod

=head2 if_path_is_current( PATH )

Checks if the current path is the provided path. Returns true upon success,
undef upon failure.

=cut

sub if_path_is_current {
    my ( $self, $path ) = @_;

    my @path = ();

    # Current path as it is
    foreach my $path_comp ( @{ $self->current_path_segments } ) {
        push @path, URI::Escape::uri_unescape( $path_comp );
    }

    my $current_path = join '/', @path;

    return 1 if $current_path eq $path;
    return undef;
}

=pod

=head2 form_url( TASK, [NO_QUERY], [HANDLER] )

Forms the escaped URI based on the current path provided by class method
I<get_current_path()>. The provided task will be the task in the resulting URI.
Example:

  # current path is /files/tree/my/personal/file.txt?param=1
  my $url = $self->form_url( 'view' );
  # $url is /files/view/my/personal/file.txt?param=1

Notice that the current URI parameters are also in the resulting path.

Accepts optional boolean parameter which sets the no query bit. By default
I<form_url()> will add the URI query parameters (i.e. I<?param=1>) into the
resulting URI. Setting this true does not append the parameters.

Optionally accepts the handler name to use for forming the URL.

=cut

sub form_url {
    my ( $self, $task, $no_query, $action ) = @_;

    my $current_url = $self->get_current_path( 'escape' );
    $action ||= CTX->request->action_name;

    my $url = '/' . join '/', grep { defined $_ } (
        $action, $task, $self->url_base_path, $current_url
    );
    $url =~ s{//}{/}g;

    unless ( $no_query ) {
        return OpenInteract2::URL->create( $url, CTX->request->url_query );
    }
    else {
        return OpenInteract2::URL->create( $url );
    }
}

=pod

=head2 clean_path_name( [FILENAME] )

Constructs a local filesystem path based on the current virtual path. This is
done by combining class attribute I<base_path()> and return of
I<get_current_path()>. The virtual path part is cleaned in the process.

Accepts optional string parameter, which is cleaned and appended in the
resulting path.

NOTE: This function might be moved to L<Dicole::Files::Filesystem>.

=cut

sub clean_path_name {
    my ( $self, $name ) = @_;

    my $path = File::Spec->catdir(
        $self->base_path,
        $self->clean_location( $self->get_current_path ),
    );

    if ( defined $name ) {
        $path = File::Spec->catdir(
            $path,
            $self->clean_filename( $name )
        );
    }
    return $path;
}

=pod

=head2 get_current_filename()

Gets the current filename. This is done by returning the last segment of the
current path.

=cut

sub get_current_filename {
    my ( $self ) = @_;

    my $path_segment = $self->current_path_segments->[-1];

    if ( $self->path ) {
        my @segments = split( '/', $self->path );
        $path_segment = $segments[-1];
    }

    return URI::Escape::uri_unescape( $path_segment );
}

=pod

=head2 parse_distinct_paths( [PATH1, PATH2...] )

This function takes a list of paths (relative or full paths to directories
and files) and comes up with a distinct list of paths. The purpose is to drop
such paths that are located under directories already in the list. That way
we operate each path as its own, including the possible subentries.

Example, a list of:

  users/info.txt, users/inf, users/inf/diary.txt. users/inf/config/file.xml

is returned as:

  users/info.txt users/inf

..because users/inf/diary.txt and users/inf/config/file.xml reside under
users/inf already.

Cleans the resulting distinct locations in process. Returns the distinct paths
as an anonymous array.

=cut

sub parse_distinct_paths {
    my ( $self, $paths ) = @_;

    my $dirs = [];

    # This hash will be used to identify the current directory sub tree
    # we are currently in.
    my %lookup = ();

    # We sort the list first alphabetically because we rely
    # in the order of path names
    foreach my $path ( sort @{ $paths } ) {
        $path = $self->clean_location( $path ),
        $lookup{$path} = 1;

        my @path = split '/', $path;
        pop @path;
        next if $lookup{ join( '/', @path) };

        push @{ $dirs }, $path;
    }
    return $dirs;
}

=pod

=head2 clean_location( PATH )

Cleans a location to prevent possible malicious use. The path is first cleaned
out of all illegal characters listed by class method I<illegal_chars()> or by
checking the server.ini configuration I<strip.illegal_chars>. The characters are
replaced with an underscore.

Then all two-dot sequences are converted as underscore to prevent going up the
directory tree.

Then the pointing to the current directory is removed.

And finally the path is made relative instead of absolute by removing beginning
root directory names from the path.

=cut

sub clean_location {
    my ( $self, $name ) = @_;

    my $illegal_chars = eval { CTX->server_config->{strip}{illegal_chars} } ||
        $self->illegal_chars;
    $name =~ s/[$illegal_chars]/_/g;
    $name =~ s/\.\./_/g;
    $name =~ s/^\.+//;
    $name =~ s/^[:\/]+//;
    return $name;
}

=pod

=head2 clean_filename( FILENAME )

Cleans a filename to prevent malicious use. This is done by removing possible
ways to point into somewhere else other than current directory by removing
directory paths from the filename. Then the filename is filtered through class
method I<clean_location()>.

=cut

# Removes all leading directories from a filename
sub clean_filename {
    my ( $self, $name ) = @_;
    $name =~ s|^.*/(.*)$|$1|;
    $name =~ s|^.*\\(.*)$|$1|;
    return $self->clean_location( $name );
}
=pod

=head1 SEE ALSO

L<Dicole|Dicole>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,

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

