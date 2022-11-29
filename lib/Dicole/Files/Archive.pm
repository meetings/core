package Dicole::Files::Archive;

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Files;
use Archive::Zip;
use Archive::Tar;
use IO::Zlib;

use FileHandle;
use File::Spec;
use File::Path;
use File::stat;
use File::Temp;
use File::Find;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Dicole archive operations

=head1 SYNOPSIS

  use Dicole::Files;
  use Dicole::Files::Archive;

  my $files = Dicole::Files->new;
  $files->base_path( CTX->lookup_directory( 'dicole_files' ) );

  my $archive = Dicole::Files::Archive->new;
  $archive->Files( $files );

  $archive->zip_files(
    [qw( files/example.txt files/directory )],
    'files', 'test.zip'
  );

=head1 DESCRIPTION

This class provides an object oriented way to work with file archives iniside
Dicole. Currently supported archive formats are gzip, zip, tar and tar/gz.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Files::Archive> object. Accepts a hash
of parameters for class attribute initialization.

Parameters:

See I<Files>.

=head2 Files( [OBJECT] )

Sets/gets the I<Dicole::Files> object, which is used to perform file operations
against archive files.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Files::Archive->mk_accessors(
    qw( Files )
);

=pod

=head1 METHODS

=head2 uncompress( [PATH] )

Uncompresses target archive. Optionally accepts path to file as a parameter. If
path not provided, constructs the path with the help of I<Dicole::Pathutils>.

Checks existence of file. If file
exists, checks the file mime type to determine uncompression method. Currently
supported archive formats are gzip, zip, tar and tar/gz.

Returns an anonymous array where the first index is true for success, false for
failure. The second index is the returned message.

=cut

sub uncompress {
    my ( $self, $full_path ) = @_;

    $full_path ||= $self->Files->Pathutils->clean_path_name;

    my $lh = CTX->request->language_handle;

    unless ( -f $full_path ) {
        return [ 0,
            $lh->maketext( "File [_1] does not exist.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    my $mime = $self->Files->mime_type_file( $full_path );

    if ( $mime eq 'application/x-gzip' ) {
        return $self->gunzip( $mime, $full_path );
    }
    elsif ( $mime eq 'application/x-zip-compressed' ) {
        return $self->unzip( $mime, $full_path );
        }
    elsif ( $mime eq 'application/x-tar'
        || $mime eq 'application/x-compressed-tar'
    ) {
        return $self->untar( $mime, $full_path );
    }
    else {
        return [ 0,
            $lh->maketext( "Uncompression method for file [_1] is not supported.", $self->Files->Pathutils->get_current_filename )
        ];
    }

}

=pod

=head2 gunzip( [MIME], [PATH] )

Uncompressed target gzip file. Optionally accepts mime type and/or path to file
as parameters.If path not provided, constructs the path the the help of
I<Dicole::Pathutils>.

Removes file extension, which is usually I<gz>.
Checks existence of the file and mime type to determine if the file is a gzip
archive or not. Uncompresses file upon success and changes the permissions of
the resulting file to 0640.

Returns an anonymous array where the first index is true for success, false for
failure. The second index is the returned message.

=cut

sub gunzip {
    my ( $self, $mime, $full_path ) = @_;

    $full_path ||= $self->Files->Pathutils->clean_path_name;
    $mime ||= $self->Files->mime_type_file( $full_path );

    my $lh = CTX->request->language_handle;

    unless ( -f $full_path ) {
        return [ 0,
            $lh->maketext( "File [_1] does not exist.", $self->Files->Pathutils->get_current_filename )
        ];
    }
    unless ( $mime eq 'application/x-gzip' ) {
        return [ 0,
            $lh->maketext( "File [_1] is not in GZIP format.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    my $fh = IO::Zlib->new( $full_path, 'rb' );

    my @full = split '/', $full_path;
    my $filename = pop @full;
    $filename =~ s/\.(\w+)$//;
    push @full, $self->Files->Pathutils->clean_filename( $filename );
    my $new_path = join '/', @full;
    if ( -e $new_path ) {
        return [ 0, $lh->maketext( "[_1] already exists.", $filename ) ];
    }

    my $new_fh = FileHandle->new( $new_path, 'w' );

    if (defined $fh) {
        $new_fh->print( $fh->getlines );
        undef $fh;       # close the file
        undef $new_fh;
        if ( -f $new_path ) {
            unlink( $full_path );
            chmod( 0640, $new_path );
        }
        return [ 1,
            $lh->maketext( "File [_1] uncompressed.", $self->Files->Pathutils->get_current_filename )
        ];
    }
    return [ 0, $lh->maketext( "An error occured: [_1]", $! ) ];
}

=pod

=head2 unzip( [MIME], [PATH] )

Uncompressed target zip file. Optionally accepts mime type and/or path to file
as parameters.If path not provided, constructs the path the the help of
I<Dicole::Pathutils>.

Checks existence of the file and mime type to determine if the file is a zip
archive or not. Uncompresses the file upon success. Sets permissions to 0640 for
files and 0750 for directories.

Returns an anonymous array where the first index is true for success, false for
failure. The second index is the returned message.

=cut

sub unzip {
    my ( $self, $mime, $full_path ) = @_;

    $full_path ||= $self->Files->Pathutils->clean_path_name;
    $mime ||= $self->Files->mime_type_file( $full_path );

    my $lh = CTX->request->language_handle;

    unless ( -f $full_path ) {
        return [ 0,
            $lh->maketext( "File [_1] does not exist.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    unless ( $mime eq 'application/x-zip-compressed' ) {
        return [ 0,
            $lh->maketext( "File [_1] is not in ZIP format.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    my $zip = Archive::Zip->new( $full_path );

    my @exists = ();
    foreach my $member ( $zip->members ) {

        my $new_path = File::Spec->catdir(
            $self->Files->base_path,
            $self->Files->Pathutils->clean_location(
                $self->Files->Pathutils->get_current_dir
            ),
            $self->Files->Pathutils->clean_location( $member->fileName ),
        );

        if ( -e $new_path ) {
            push @exists, $self->Files->Pathutils->clean_location(
                $member->fileName
            );
        }
        else {
            $member->extractToFileNamed( $new_path );
            if ( -f $new_path ) {
                chmod( 0640, $new_path );
            }
            elsif ( -d $new_path ) {
                chmod( 0750, $new_path );
            }
        }
    }

    my $return = [ 1,
        $lh->maketext( "File [_1] uncompressed.", $self->Files->Pathutils->get_current_filename )
    ];

    if ( @exists ) {
        my $joined = join( ', ', @exists );
        $return->[1] .= ' ' . $lh->maketext( "The following files already exist: [_1]", $joined );
    }
    return $return;
}

=pod

=head2 untar( [MIME], [PATH] )

Uncompressed target tar file. Optionally accepts mime type and/or path to file
as parameters.If path not provided, constructs the path the the help of
I<Dicole::Pathutils>.

Checks existence of the file and mime type to determine if the file truly is tar
of tar/gz archive. Uncompresses the file upon success. Sets permissions to 0640 for
files and 0750 for directories.

Returns an anonymous array where the first index is true for success, false for
failure. The second index is the returned message.

=cut

sub untar {
    my ( $self, $mime, $full_path ) = @_;

    $full_path ||= $self->Files->Pathutils->clean_path_name;
    $mime ||= $self->Files->mime_type_file( $full_path );

    my $lh = CTX->request->language_handle;

    unless ( -f $full_path ) {
        return [ 0,
            $lh->maketext( "File [_1] does not exist.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    unless ( $mime eq 'application/x-tar'
        || $mime eq 'application/x-compressed-tar'
    ) {
        return [ 0,
            $lh->maketext( "File [_1] is not in TAR format.", $self->Files->Pathutils->get_current_filename )
        ];
    }

    my $compressed = ( $mime eq 'application/x-compressed-tar' )
        ? 1 : undef;

    my $tar = Archive::Tar->new( $full_path, $compressed );

    $Archive::Tar::CHOWN = 0;

    my @exists = ();
    my @extract = ();
    foreach my $member ( $tar->get_files ) {

        $member->rename( $self->Files->Pathutils->clean_location(
            $member->name
        ) );

        my $file_path = File::Spec->catdir(
            $self->Files->base_path,
            $self->Files->Pathutils->clean_location(
                $self->Files->Pathutils->get_current_dir
            ),
            $member->name
        );

        if ( -e $file_path ) {
            push @exists, $member->name;
        }
        else {
            if ( $member->is_dir ) {
                $member->mode( 0750 );
            }
            else {
                $member->mode( 0640 );
            }
            push @extract, $member->name;
        }
    }

    if ( @extract ) {
        chdir( File::Spec->catdir(
            $self->Files->base_path,
            $self->Files->Pathutils->clean_location(
                $self->Files->Pathutils->get_current_dir
            )
        ) );

        # Archive::Tar creates directories with 0777.. We
        # have to do it instead of letting Archive::Tar
        # handle it
        foreach my $file ( @extract ) {
            my @file = split '/', $file;
            pop @file;
            my $dir = join '/', @file;
            if ( $dir ) {
                File::Path::mkpath( $dir, 0, 0750 );
            }
        }
        $tar->extract( @extract );
        foreach my $file ( @extract ) {

        }
    }

    my $return = [ 1,
        $lh->maketext( "File [_1] uncompressed.", $self->Files->Pathutils->get_current_filename )
    ];

    if ( @exists ) {
        my $joined = join( ', ', @exists );
        $return->[1] .= ' ' . $lh->maketext( "The following files already exist: [_1]", $joined );
    }
    return $return;
}

=pod

=head2 zip_files( [PATH1, PATH2...], [STRIP_PATH], [FILENAME] )

Archives target files into a zip archive. Accepts an anonymous array of relative
paths to files as a parameter to determine what files to compress. Uses
I<Dicole::Files::Filesystem> to validate existence of paths and to construct
full paths to files.

Second parameter is optional. It is used to strip part of the relative path used
in the archive itself. Example:

  root/example/test/example.txt  # Relative path
  test/example.txt # Resulting path after "root/example" was stripped

The third parameter is the optional filename where to store the files.

A filename is constructed based on the provided I<path to strip>. Example:

  root/example # path to strip
  Dicole-root-example.zip # resulting path

Notice: all files must reside under the path to strip, otherwise this doesn't
work.

If no I<path to strip> was provided a random number is used in place of it.
Example:

  Dicole-1734632.zip

This compression function uses compression level 9 (best). Once the files are
compressed the archive is buffered directly to the client.

=cut

sub zip_files {
    my ( $self, $paths, $strip_path, $filename ) = @_;

    my $zip = Archive::Zip->new;

    ( $paths ) = $self->Files->validate_paths( $paths );

    foreach my $path ( @{ $paths } ) {
        my $full_path = $self->Files->Fileops->get_full_path( $path );
        $path =~ s/^$strip_path\///;
        if ( -d $full_path ) {
            $zip->addTree( $full_path, $path );
        }
        else {
            $zip->addFile( $full_path, $path );
        }
    }

    $zip->zipfileComment( 'Downloaded from Dicole' );

    foreach my $member ( $zip->members ) {
        $member->desiredCompressionLevel( 9 );
    }

    my ( $fh, $tempfile ) = File::Temp::tempfile();

    $zip->writeToFileHandle( $fh );

    seek( $fh, 0, 0 );

    CTX->response->content_type( 'application/x-zip-compressed' );

    unless ( $filename ) {
        $filename = $strip_path;
        $filename =~ s{/}{-}g;
        $filename = int rand 1000000 unless $filename;
        $filename = 'Dicole-' . $filename;
    }

    CTX->response->header(
        'Content-Disposition',
        'attachment; filename=' . $filename . '.zip'
    );

    my $stats = stat( $fh );

    CTX->response->header( 'Content-Length', $stats->size );
    unlink( $tempfile ); # Remove tempfile
    return CTX->response->send_filehandle($fh );
}

=pod

=head2 tar_files( [PATH1, PATH2...], [STRIP_PATH], [FILENAME] )

Archives target files into a tar/gz archive. Accepts an anonymous array of relative
paths to files as a parameter to determine what files to compress. Uses
I<Dicole::Files::Filesystem> to validate existence of paths and to construct
full paths to files.

Second parameter is optional. It is used to strip part of the relative path used
in the archive itself. Example:

  root/example/test/example.txt  # Relative path
  test/example.txt # Resulting path after "root/example" was stripped

Notice: all files must reside under the path to strip, otherwise this doesn't
work.

The third parameter is the optional filename where to store the files.

A filename is constructed based on the provided I<path to strip>. Example:

  root/example # path to strip
  Dicole-root-example.tar.gz # resulting path

If no I<path to strip> was provided a random number is used in place of it.
Example:

  Dicole-1734632.tar.gz

This compression function uses compression level 9 (best). Once the files are
compressed the archive is buffered directly to the client.

=cut

sub tar_files {
    my ( $self, $paths, $strip_path, $filename ) = @_;

    my $tar = Archive::Tar->new;

    ( $paths ) = $self->Files->validate_paths( $paths );

    chdir( $self->Files->base_path );
    chdir( $strip_path );

    foreach my $path ( @{ $paths } ) {
        my $full_path = $self->Files->Fileops->get_full_path( $path );
        $path =~ s/^$strip_path\///;
        if ( -d $full_path ) {
            File::Find::find( {
                wanted => sub {
                    return if $_ =~ m{/\.};
                    $tar->add_files( $_ ) if -f $_;
            }, no_chdir => 1 }, $path );
        }
        else {
            $tar->add_files( $path );
        }
    }

    my ( $fh, $tempfile ) = File::Temp::tempfile();

    $tar->write( $tempfile, 9 );

    seek( $fh, 0, 0 );

    CTX->response->content_type( 'application/x-compressed-tar' );

    unless ( $filename ) {
        $filename = $strip_path;
        $filename =~ s{/}{-}g;
        $filename = int rand 1000000 unless $filename;
        $filename = 'Dicole-' . $filename;
    }

    CTX->response->header(
        'Content-Disposition',
        'attachment; filename='. $filename . '.tar.gz'
    );

    my $stats = stat( $fh );

    CTX->response->header( 'Content-Length', $stats->size );
    unlink( $tempfile ); # Remove tempfile
    return CTX->response->send_filehandle( $fh );
}

=pod

=head1 SEE ALSO

L<Dicole|Dicole>,
L<OpenInteract|OpenInteract>

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

