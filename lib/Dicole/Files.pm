package Dicole::Files;

use strict;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use File::MimeInfo ();
use File::Spec::Unix;
use File::Temp ();
use File::Spec;
use DateTime;
use MP3::Info qw(:all);
use HTML::Scrubber::StripScripts;
use RDF::Simple::Serialiser;

use Dicole::Pathutils;
use Dicole::Files::Filesystem;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Dicole file management functions

=head1 SYNOPSIS

  use Dicole::Files;

  my $files = Dicole::Files->new;
  $files->base_path( CTX->lookup_directory( 'dicole_files' ) );
  $files->Fileops->mkdir( 'directory_name' );

=head1 DESCRIPTION

This class provides most required file management functions for Dicole. It has a
plugin interface for implementing different storage locations for the files and
manipulating the files with a single interface, which is the purpose of this
class.

The most useful thing about this class is that it makes all the security checks,
security validation and other checks (for example checks for existence of
locations) for the file operations. It also enables you to work with relative
paths only, so you don't have to use absolute paths in your code.
L<Dicole::Files> takes care of mapping relative paths to absolute paths to what
ever resource.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Files> object.
Accepts a hash of parameters for class attribute initialization.

Parameters:

See I<Pathutils>, I<Fileops>, I<base_path> and I<path>.

=cut

use base qw( Class::Accessor );

=pod

=head1 METHODS

=head2 Pathutils( [OBJECT] )

Sets/gets the initialized Pathutils object. If the method is called the first
time and no object is provided, a new Pathutils object is initialized and
returned with class parameters I<base_path> and I<path>.

=cut

sub Pathutils {
        my ( $self, $object ) = @_;
        if ( ref $object ) {
                $self->{Pathutils} = $object;
        }
        unless ( ref $self->{Pathutils} ) {
                $self->{Pathutils} = Dicole::Pathutils->new( {
                        base_path => $self->base_path,
                        path => $self->path
                } );
        }
        return $self->{Pathutils};
}

=pod

=head2 Fileops( [OBJECT] )

Sets/gets the initialized file operations plugin object. Currently Dicole
includes two plugins: L<Dicole::Files::Filesystem> and L<Dicole::Files::Smb>.
If no plugin is provided the default plugin L<Dicole::Files::Filesystem> is
initialized. The plugin in question is initialized with the class attribute
I<Pathutils> and I<init_magic()> method of the plugin object is called.

=cut

sub Fileops {
        my ( $self, $object ) = @_;
        if ( ref $object ) {
                $self->{Fileops} = $object;
                $self->{Fileops}->Pathutils( $self->Pathutils );
        }
        unless ( ref $self->{Fileops} ) {
                $self->{Fileops} = Dicole::Files::Filesystem->new(
                        { Pathutils => $self->Pathutils }
                );
        }
        return $self->{Fileops};
}

=pod

=head2 base_path( [PATH] )

Sets/gets the base path for the files, which is passed along to
L<Dicole::Pathutils>. This is usually the absolute path to the basic file system
storage, usually defined somewhere in your I<server.ini>.

If no base_path is defined, the default is used which is the location of directory
I<dicole_files> in the I<server.ini> configuration.

=cut

sub base_path {
        my ( $self, $base_path ) = @_;
        if ( defined $base_path ) {
                $self->{base_path} = $base_path;
                $self->Pathutils->base_path( $base_path );
        }
        unless ( defined $self->{base_path} ) {
                $self->{base_path} = CTX->lookup_directory( 'dicole_files' );
        }
        return $self->{base_path};
}

=pod

=head2 path( [PATH] )

Sets/gets the relative path which is passed along to L<Dicole::Pathutils>.
If this is set, Pathutils uses the value instead of reading the relative path
from the URL.

=cut

sub path {
        my ( $self, $path ) = @_;
        if ( defined $path ) {
                $self->{path} = $path;
                $self->Fileops->Pathutils->path( $path );
                $self->Pathutils->path( $path );
        }
        return $self->{path};
}

=pod

=head2 mime_type_file( [FILENAME] )

Gets the mime type based on identification. Identification is retrieved with the
I<get_mime_type()> function through I<Fileops>. If no relative path to
the filename is provided, I<Pathutils> is used to get the relative path.

=cut

sub mime_type_file {
        my ( $self, $filename ) = @_;
        $filename ||= $self->Pathutils->get_current_path;
        return $self->Fileops->get_mime_type( $filename );
}

=pod

=head2 mime_desc_file( [FILENAME], [LANG] )

Gets the mime type human readable description based on file mime type. The
optional provided relative path is identified with I<mime_type_file()>. If no
mime type is returned the default I<inode/directory> is used.

Optionally accepts the language code which to use to return the description. See
website
L<http://www2.iro.umontreal.ca/translation/registry.cgi?domain=shared-mime-info>
for information of available languages and language codes for shared-mime-info.

Returns the description of the identified mime type.

=cut

sub mime_desc_file {
        my ( $self, $filename, $lang ) = @_;
        $filename ||= $self->Pathutils->get_current_path;
        my $mime = Dicole::Files::MimeType->new;
        return $mime->mime_desc_file( $filename, $lang );
}

=pod

=head2 human_readable( SIZE_IN_BYES )

Gets the human readable version the provided size in bytes. This is done by
converting the bytes to size in gigabytes, megabytes or kilobytes depending of
what is closest to the byte size and rounding the results by one decimal.

=cut

sub human_readable {
        my ( $self, $size ) = @_;

        if ( $size >= ( 1024 * 1024 * 1024 ) ) {
                $size = sprintf( "%.1f", $size / ( 1024 * 1024 * 1024 ) );
                $size .= 'G';
        }
        elsif ( $size >= ( 1024 * 1024 ) ) {
                $size = sprintf( "%.1f", $size / ( 1024*1024 ) );
                $size .= 'M';
        }
        elsif ( $size >= 1024 ) {
                $size = sprintf( "%.1f", $size / 1024 );
                $size .= 'k';
        }
        $size = "0" if !$size;
        return $size;
}

=pod

=head2 download_file( [USE_MIME], [PATH] )

Downloads the file from the relative location. The content type to use
for returning the file is I<application/octet-stream>. If you want to return the
file with correct mime type for the file for viewing purposes, provide the
optional use mime bit as a parameter.

Also accepts a relative path to use instead of identifying the location of the
file with Pathutils.

If use mime bit is enabled the mime type is checked.

If the content type is
I<text/html> and server.ini configuration parameter I<dicole.scrub> is true, the
HTML file is stripped with L<HTML::Scrubber>. It filter possible malicious code
out the HTML. It is also good to know that this method doesn't return the cookie
so stealing the cookie with scripting would not anyway work but for avoiding
other XSS problems the dicole.scrub should always be turned on.

If the content type is I<wwwserver/redirection> the contents of the file is read
and the contents are used to direct the client to the host specified in the
content. This enables creating I<.url> files that are shortcuts to other
Internet resources.

If the content type is I<audio/mpeg> or I<application/ogg>, the file is read
with L<AudioFile::Info> to identify the record metadata. A qualified
shoutcast/icecast header is returned, which enables streaming the media with
attached metadata instead of first downloading it.

=cut

sub download_file {
        my ( $self, $mime, $path ) = @_;

        $self->path( $path ) if $path;

        CTX->response->content_type( 'application/octet-stream' );

        my $lh = CTX->request->language_handle;

    my $h_filename = $self->Pathutils->get_current_filename;
        my ( $fh, $filename ) = $self->Fileops->get_file;
        unless ( -f $filename ) {
                return [ 0,
                    $lh->maketext( "File [_1] does not exist.", $h_filename )
                ];
        }
        CTX->response->content_type( $self->mime_type_file ) if $mime;

        if ( CTX->response->content_type eq 'text/html' && CTX->server_config->{dicole}{scrub} ) {

                my $hss = HTML::Scrubber::StripScripts->new(
                        Allow_src      => 1,
                        Allow_href     => 1,
                        Allow_a_mailto => 1,
                        Whole_document => 1
                );
                my $content = $hss->scrub( $self->fh_contents( $fh ) );

                $fh = File::Temp->new;
                print $fh $content;
                seek( $fh, 0, 0 );
                $filename = $fh->filename;
        }
        elsif ( CTX->response->content_type eq 'wwwserver/redirection' ) {
                my $link = $self->fh_contents( $fh );
                $link =~ s/\r\n//gm;
                return CTX->response->redirect( $link );
        }
        elsif ( CTX->response->content_type eq 'audio/mpeg'
                || CTX->response->content_type eq 'application/ogg'
        ) {
            my ( $artist, $genre, $title ) = undef;
            if ( CTX->response->content_type eq 'audio/mpeg' ) {
                MP3::Info::use_winamp_genres;
                my $tag = MP3::Info::get_mp3tag( $filename );
                $title = $tag->{TITLE};
                $artist = $tag->{ARTIST};
                $genre = $tag->{GENRE};
            }
                my $LF = "\015\012"; # linefeed
        my $name = $artist ? $artist . '-' . $title : $h_filename;
        CTX->response->header( 'Server', 'Dicole' );
        CTX->response->header( 'icy-notice1', '<BR>This stream requires a shoutcast/icecast compatible player.<BR>"' );
                CTX->response->header( 'icy-notice2', 'Dicole MP3 stream' );
                CTX->response->header( 'icy-name', $name  );
                CTX->response->header( 'icy-genre', $genre );
                CTX->response->header( 'icy-metaint', 0 );
                CTX->response->header( 'icy-pub', 0 );
                CTX->response->header( 'x-audiocast-name', $name );
                CTX->response->header( 'x-audiocast-genre', $genre );
                CTX->response->header( 'x-audiocast-pub', 0 );
        }
    my $size = ( stat( $fh ) )[7];
        CTX->response->header( 'Content-Length', $size );
        return CTX->response->send_filehandle( $fh );
}

=pod

=head2 get_dc( OBJECT_OR_HASH, [PATH] )

Gets the Dublin Core metadata for the specified location. Accepts an anonymous
hash or SPOPS object of Dublin Core metadata fields, which are used to construct
the XML/RDF feed. If relative path to the resource is not provided, Pathutils
will be used to identify the path to the resource.

L<RDF::Simple::Serialiser> is used to construct the XML/RDF feed. The resource
location is the I<Files/view> url to the resource.

Here are the rules for Dublin Core fields while constructing the feed:

=over 4

=item date

The date is provided as seconds since epoch. It is converted to YYYY-MM-DD
format as recommended in the Dublin Core specifications.

=item format

Dublin Core accepts multiple instances of fields. Format is duplicated here to
include the size of the resource as returned by I<Fileops->size>. The format is
identified similar to I<1234 bytes>.

=back

Other fields are included as-is.

=cut

sub get_dc {
        my ( $self, $object, $path ) = @_;

        $self->path( $path ) if $path;

        my $url = $self->Pathutils->get_server_url
                . $self->Pathutils->form_url( 'view' );

        my $ser = RDF::Simple::Serialiser->new;
        $ser->addns( dc => 'http://purl.org/dc/elements/1.1/' );
        $ser->addns( dcterms => 'http://purl.org/dc/terms/' );
        my @triples = ();

        if ( $object->{date} ) {
                push @triples, [
                        $url, 'dc:date',
                        DateTime->from_epoch( epoch => $object->{date} )->ymd
                ];
        }

        foreach my $field ( qw(
                title creator subject description publisher contributor
                type format identifier source language relation coverage rights
        ) ) {
                push @triples, [ $url, "dc:$field", $object->{$field} ]
                        if $object->{$field};
        }

        push @triples, [ $url, "dc:format", $self->Fileops->size . ' bytes' ];

        my $return = '<?xml version="1.0"?>' . "\n"
                . '<!DOCTYPE rdf:RDF SYSTEM ' . "\n"
                . '"http://dublincore.org/documents/2002/07/31/dcmes-xml/dcmes-xml-dtd.dtd">' . "\n"
                . $ser->serialise( @triples );

        my $LF = "\015\012"; # linefeed
        CTX->response->content_type( 'application/rdf+xml' );
        CTX->response->header( 'Content-Length', length( $return ) );
        CTX->controller->no_template( 'yes' );
        return $return;
}

=pod

=head2 stream_files( [PATH1, PATH2...] )

Gets an m3u playlist of relative paths passed as an anonymous array. The media
files are identified and a playlist is created with I<Files/view> url locations
to the files.

Notice that streaming only works for files that are publicly available,
i.e. require no cookie authentication, since the browser is not able to forward
the cookie to the media player.

=cut

sub stream_files {
        my ( $self, $paths ) = @_;

# Disabled for now
#       my ( $paths ) = $self->validate_paths( $paths );

        my $full_path = $self->Pathutils->clean_path_name;

        my $content = "#EXTM3U\n";

        foreach my $path ( @{ $paths } ) {
                my $mime = $self->mime_type_file( $path );
                my ( undef, $filepath ) = $self->Fileops->get_file( $path );
                my @current_path = split '/', $path;
                if ( -e $filepath && ( $mime eq 'audio/mpeg' || $mime eq 'application/ogg' ) ) {
                        my $song = AudioFile::Info->new( $filepath );
                    my $name = $song->artist ? $song->artist . '-' . $song->title : pop( @current_path );
                        $content .= "#EXTINF:-1,$name\n";
                }
                else {
                        $content .= "#EXTINF:-1 " . pop( @current_path ) . "\n";
                }
                $content .= $self->Pathutils->get_server_url . '/personal_files/view/'
                        . $self->Pathutils->escape_uri( $path ) . "\n";
        }

        my $m3u_filename = int rand 1000000;

        my $LF = "\015\012"; # linefeed

        CTX->response->content_type( "audio/x-mpegurl" );
        CTX->response->header( 'Content-Length', length( $content ) );

    my $file_prefix = CTX->server_config->{dicole}{playlist_prefix};
    $file_prefix ||= 'Dicole';

        CTX->response->header(
                'Content-Disposition',
                "attachment; filename=$file_prefix-$m3u_filename.m3u"
        );
        CTX->controller->no_template( 'yes' );
        return $content;
}

=pod

=head2 get_file_contents( [PATH] )

Returns the contents of a file. If a relative path is not provided, Pathutils
will be used. Returns undef if the file was unaccessible.

=cut

sub get_file_contents {
        my ( $self, $path ) = @_;
        my ( $fh ) = $self->Fileops->get_file( $path );

        if ( defined $fh ) {
                return $self->fh_contents( $fh );
        }
        else {
                return undef;
        }
}

=pod

=head2 set_file_contents( CONTENT, [PATH] )

Sets the contents of a file. If the file does not exist, it will be created. The
content may be provided as text or as a filehandle. Optionally accepts the
relative path of the file, otherwise Pathutils will be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub set_file_contents {
        my ( $self, $content, $path ) = @_;

        $path ||= $self->Pathutils->get_current_path;

        my @path = split '/', $path;
        my $doc_name = pop @path;
        $path = join '/', @path;

        my $lh = CTX->request->language_handle;

        my $return = $self->Fileops->mkfile( $doc_name, $content, 1, $path );
        if ( $return == 1 ) {
                return [ 1, $lh->maketext( "Document [_1] written.", $doc_name ) ];
        }
        else {
                return [ 0,
                        $lh->maketext( "Writing document [_1] failed: [_2]", $doc_name, $return )
                ];
        }
}

=pod

=head2 fh_contents( FILEHANDLE )

Returns the filehandle contents.

=cut

sub fh_contents {
        my ( $self, $fh ) = @_;
        local $/ = undef;
        my $content = <$fh>;
        return $content;
}

=pod

=head2 rename_location( NEW_FILENAME, [PATH] )

Renames a location. Accepts the new filename as the first parameter. Optionally
accepts the relative path of the file, otherwise Pathutils will be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub rename_location {
        my ( $self, $new_name, $path ) = @_;

        $path ||= $self->Pathutils->get_current_path;

        my @full = split '/', $path;
        my $oldname = pop @full;
        my $clean_name = $self->Pathutils->clean_filename( $new_name );
        push @full, $clean_name;
        my $newname = join '/', @full;

        my $return = $self->Fileops->rename( $newname );

        my $lh = CTX->request->language_handle;

        if ( $return eq '2' ) {
                return [ 0,
                    $lh->maketext( "[_1] already exists.", $new_name )
                ];
        }
        elsif ( $return eq '1' ) {
                return [ 1,
                    $lh->maketext( "Renamed [_1] as [_2].", $oldname, $new_name )
                ];
        }
        else {
                return [ 0,
                    $lh->maketext( "Renaming location failed: [_1]", $return )
                ];
        }
}

=pod

=head2 copy_files( [PATH1, PATH2...], [PATH] )

Copies recursively an anonymous array of files and folders to a new location.
Optionally accepts the relative path of the new location, otherwise Pathutils
will be used.

The anynymous array of locations will be first validated for existence before
performing the operation.

=cut

sub copy_files {
        my ( $self, $paths, $path ) = @_;

        ( $paths ) = $self->validate_paths( $paths );
        $self->Fileops->copy_recursive( $paths, $path );
}

=pod

=head2 move_files( [PATH1, PATH2...], [PATH] )

Moves recursively an anonymous array of files and folders to a new location.
Optionally accepts the relative path of the new location, otherwise Pathutils
will be used.

The anynymous array of locations will be first validated for existence before
performing the operation.

=cut

sub move_files {
        my ( $self, $paths, $path ) = @_;

        ( $paths ) = $self->validate_paths( $paths );
        $self->Fileops->move_recursive( $paths, $path );
}

=pod

=head2 create_new_dir( FOLDER_NAME, [PATH] )

Creates a new folder in the specified location.

Optionally accepts the relative path of the path where to folder will be
created, otherwise Pathutils will be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub create_new_dir {
        my ( $self, $folder_name, $path ) = @_;

        my $return = $self->Fileops->mkdir( $folder_name, $path );

        my $lh = CTX->request->language_handle;

        if ( $return eq '1' ) {
                return [ 1, $lh->maketext( "Folder [_1] created.", $folder_name ) ];
        }
        elsif ( $return eq '2' ) {
                return [ 0, $lh->maketext( "Folder [_1] already exists.", $folder_name ) ];
        }
        else {
                return [ 0,
                        $lh->maketext( "Creating folder [_1] failed: [_2]", $folder_name, $return )
                ];
        }
}

=pod

=head2 create_new_doc( FILENAME, CONTENT, [PATH] )

Creates a new document in the specified location. Accepts the document name to
create and the document content as text or as a filehandle.

Optionally accepts the relative path of the path where to file will be
created, otherwise Pathutils will be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub create_new_doc {
        my ( $self, $doc_name, $content, $path ) = @_;

        my $return = $self->Fileops->mkfile( $doc_name, $content, undef, $path );

        my $lh = CTX->request->language_handle;

        if ( $return eq '1' ) {
                return [ 1, $lh->maketext( "New document [_1] created.", $doc_name ) ];
        }
        elsif ( $return eq '2' ) {
                return [ 0, $lh->maketext( "[_1] already exists.", $doc_name ) ];
        }
        else {
                return [ 0,
                        $lh->maketext( "Creating document [_1] failed: [_1]", $doc_name, $return )
                ];
        }
}

=pod

=head2 delete_path( [PATH] )

Deletes the target location recursively.

Optionally accepts the relative path to the location, otherwise Pathutils will
be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub delete_path {
        my ( $self, $path ) = @_;

        $self->Fileops->delete( $path );
}

=pod

=head2 validate_paths( [PATH1, PATH2...] )

Validates existence of provided relative paths. Returns two parameters:

Anonymous array of relative paths which exist and an anonymous array of relative
paths that did not exist.

=cut

sub validate_paths {
        my ( $self, $paths ) = @_;

        my @relative_paths = ();
        my @trashed = ();

        my $oldpath = $self->Pathutils->path;

        foreach my $path ( @{ $paths } ) {
                $self->Pathutils->path( $path );
                if ( $self->Fileops->check_existence( $path ) ) {
                        push @relative_paths, $self->Pathutils->clean_location( $path );
                }
                else {
                        push @trashed, $self->Pathutils->clean_location( $path )
                }
        }

        $self->Pathutils->path( $oldpath );

        return ( \@relative_paths, \@trashed );
}

=pod

=head2 upload_file( FIELD, [PATH] )

Uploads and creates a new file. The first parameter is the request parameter
of the file upload field.

Optionally accepts the relative path of the path where to file will be
created, otherwise Pathutils will be used.

Returns an anonymous array, where the first index is true for success, false for
failure and the second index is the returned message.

=cut

sub upload_file {
        my ( $self, $upload, $path ) = @_;

        my $upload_obj = CTX->request->upload( $upload );

        my $lh = CTX->request->language_handle;

        if ( ref( $upload_obj ) ) {
                my $filename = $upload_obj->filename;
                my $return = $self->create_new_doc(
                        $filename, $upload_obj->filehandle, $path
                );
                if ( $return->[0] == 1 ) {
                        return [ 1, $lh->maketext( "File [_1] uploaded.", $filename ) ];
                }
                else {
                        return $return;
                }
        }
        else {
                return [ 0, $lh->maketext( 'File upload field does not exist.' ) ];
        }
}

=pod

=head1 SEE ALSO

L<Dicole::Files::Archive>,
L<Dicole::Files::Filesystem>,
L<Dicole::Files::Smb>,
L<Dicole>,
L<OpenInteract>

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

