package Dicole::Files::Filesystem;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use DirHandle;
use FileHandle;
use Dicole::Pathutils;
use File::Path;
use File::Find;
use File::Spec::Unix;
use File::NCopy;

use Dicole::Navigation::Tree::Element;
use Dicole::Files::MimeType;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Dicole basic filesystem functions

=head1 SYNOPSIS

  use Dicole::Files;

  my $files = Dicole::Files->new;
  $files->base_path( CTX->lookup_directory( 'dicole_files' ) );
  $files->Fileops->mkdir( 'directory_name' );

=head1 DESCRIPTION

This a simple simple filesystem plugin for L<Dicole::Files>. It is meant to be
used through L<Dicole::Files> method I<Fileops()>. The purpose is to
provide a way to map relative paths as full paths to files and directories that
reside in the real filesystem and perform simple file and directory operations
against them. The plugin uses L<Dicole::Pathutils> to find out the full path to
a location in the filesystem.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Files::Filesystem> object. Accepts a hash
of parameters for class attribute initialization.

Parameters:

=over 4

=item B<dir_tree_flat> I<boolean>

If this is set true, the directory structure will be flat when reading tree structure
with I<get_dir_tree()>. This means only one level is read from the specified root.
Useful for creating flat file directory browsing views.

May also be set through accessor I<dir_tree_flat()>.

=back

For other parameters, see I<Pathutils>.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Files::Filesystem->mk_accessors(
    qw( dir_tree_flat )
);

=pod

=head1 METHODS

=head2 Pathutils( [OBJECT] )

Sets/gets the L<Dicole::Pathutils> object. This must be set so that our
filesystem object is able to convert relative paths to filesystem paths.

If the Pathutils is not defined, a new L<Dicole::Pathutils> object is created.

=cut

sub Pathutils {
    my ( $self, $object ) = @_;
    if ( ref $object ) {
        $self->{Pathutils} = $object;
    }
    unless ( ref $self->{Pathutils} ) {
        $self->{Pathutils} = Dicole::Pathutils->new;
    }
    return $self->{Pathutils};
}

=pod

=head2 get_full_path( [PATH], [FILENAME] )

Gets the full filesystem path for a relative path. This is constructed with the
help of L<Dicole::Pathutils>.

Optionally accepts the relative path to construct
as the first parameter.

Optionally accepts a filename which resides in the
provided path for which a full filesystem path will be constructed.

=cut

sub get_full_path {
    my ( $self, $path, $filename ) = @_;
    my $oldpath = $self->Pathutils->path;
    $self->Pathutils->path( $path ) if $path;
    my $full_path = $self->Pathutils->clean_path_name( $filename );
    $self->Pathutils->path( $oldpath );
    return $full_path;
}

=pod

=head2 get_file( [PATH] )

Gets a filehandle for a file path. Optionally accepts a relative path
to use which is passed along to I<get_full_path()>.

Returns the filehandle and the real filesystem path to the file.

=cut

sub get_file {
    my ( $self, $path ) = @_;

    $path = $self->get_full_path( $path );

    my $fh = FileHandle->new( $path, 'r' );

    return ( $fh, $path );
}

=pod

=head2 size( [PATH] )

Gets the size of a file or directory path. Optionally accepts a relative path
to use which is passed along to I<get_full_path()>.

=cut

sub size {
    my ( $self, $path ) = @_;

    my $full_path = $self->get_full_path( $path );

    if ( -e $full_path ) {
        if ( -d $full_path ) {
            return $self->dir_size( $path );
        }
        else {
            return $self->file_size( $path );
        }
    }
    else {
        return undef;
    }
}

=pod

=head2 dir_size( [PATH] )

Gets the complete size of a directory. Optionally accepts a relative path
to use which is passed along to I<get_full_path()>.

=cut

sub dir_size {
    my ( $self, $path ) = @_;

    $path = $self->get_full_path( $path );

    my $count = 0;
    my $size = 0;

    File::Find::find( sub {
        if ( -f ) {
            unless ( /^\./ ) {
                $size += -s;
                $count++;
            }
        }
    }, $path );
    return ( $size, $count );
}

=pod

=head2 file_size( [PATH] )

Gets the size of a file. Optionally accepts a relative path
to use which is passed along to I<get_full_path()>.

=cut

sub file_size {
    my ( $self, $path ) = @_;
    $path = $self->get_full_path( $path );
    return -s $path;
}

=pod

=head2 stat( [PATH] )

Gets the I<stat()> for a file. Optionally accepts a relative path
to use which is passed along to I<get_full_path()>.

=cut

sub stat {
    my ( $self, $path ) = @_;
    $path = $self->get_full_path( $path );
    return stat( $path );
}

=pod

=head2 mkdir( FOLDER, [PATH] )

Creates a new folder. Accepts the folder name as the first parameter.
Optionally accepts a relative path to use as a second parameter, which is passed
along to I<get_full_path()>.

Creates the new directory with permissions 0750. Returns the evaled error upon
failure, I<1> upon success.

=cut

sub mkdir {
    my ( $self, $folder, $path ) = @_;

    my $dir = $self->get_full_path( $path, $folder );

    if ( -e $folder ) {
        return 2;
    }
    eval { File::Path::mkpath( $dir, undef, 0750 ) };
    return $@ if $@;
    return 1;
}

=pod

=head2 mkfile( FILENAME, CONTENT, [OVERWRITE], [PATH] )

Creates a new file. Accepts the filename as the first parameter and the content
as second parameter. If the content is a filehandle instead of text, the
contents of the filehandle will be read and written to the file instead.

Optionally accepts the overwrite bit as the third parameter. If it is set to
true and the file already exists, it will be overwritten.

Optionally accepts a relative path to use as a fourth parameter, which is passed
along to I<get_full_path()>.

Creates the new file with permissions 0640. Returns the evaled error upon
failure, I<1> upon success and I<2> if the file already exists.

=cut

sub mkfile {
    my ( $self, $doc, $content, $force, $path ) = @_;

    $path = $self->get_full_path( $path, $doc );

    if ( !$force && -e $path ) {
        return 2;
    }

    my $fh = eval { FileHandle->new( $path, 'w' ) };
    if ( defined $fh ) {
        if ( ref( $content ) ) {
            while ( my $line = <$content> ) {
                $fh->print( $line );
            }
        }
        else {
            $fh->print( $content );
        }
        undef $fh; # close file
        chmod( 0640, $path );
        return 1;
    }
    else {
        return $@;
    }
}

=pod

=head2 rename( OLDNAME, NEWNAME )

Renames a file or directory. Accepts the original relative path to the file and
relative path to the new filename as parameters.

Renames the file. Upon failure, returns the error, I<1> upon success and I<2> if
the new filename already exists.

=cut

sub rename {
    my ( $self, $newname, $oldname ) = @_;

    $oldname ||= $self->Pathutils->get_current_path;

    $oldname = $self->get_full_path( $oldname );
    $newname = $self->get_full_path( $newname );

    return 2 if -e $newname;
    rename( $oldname, $newname ) || return $!;
    return 1;
}

=pod

=head2 check_existence( [PATH] )

Checks existence of a location.

Optionally accepts a relative path to use as a parameter, which is passed
along to I<get_full_path()>.

Returns true upon success, returns undef upon failure.

=cut

sub check_existence {
    my ( $self, $path ) = @_;
    $path = $self->get_full_path( $path );
    ( -e $path ) ? return 1 : return undef;
}

=pod

=head2 delete( [PATH] )

Remove location. If the location is a directory, it will be removed recursively.

Optionally accepts a relative path to use as a parameter, which is passed
along to I<get_full_path()>.

Returns the error upon failure and I<1> upon success.

=cut

sub delete {
    my ( $self, $path ) = @_;

    $path = $self->get_full_path( $path );

    if ( -d $path ) {
        # 0: don't print file information while processing
        # 1: Skip files that do not have delete/write access
        File::Path::rmtree( $path, 0, 1 );
        return 1;
    }
    elsif ( -f $path ) {
        unlink( $path ) || return $!;
        return 1;
    }
    else {
        get_logger( LOG_DS )->error( sprintf(
            'Filesystem: Target %s does not exist',
            $path
        ) );
    }
}

=pod

=head2 copy_recursive( [PATH1, PATH2...], TARGET )

Copies files and directories recursively to target location. Accepts an
anonymous array of relative paths of files and directories to copy and the
target directory as the second parameter.

Returns I<1> upon success.

=cut

sub copy_recursive {
    my ( $self, $paths, $target_path ) = @_;

    my $full_path = $self->get_full_path( $target_path );
    -d $full_path || return undef;

    my $file = File::NCopy->new( recursive => 1, force_write => 1 );
    foreach my $path ( @{ $paths } ) {
        $path = $self->get_full_path( $path );
        # Make sure we are not copying any parents into a sub folder
        next if $full_path =~ /$path[:\/]/;
        # Workaround for NCopy problems with spaces in path names
        my $new_path = $path;
        $new_path =~ s/ /\\ /g;
        $file->copy( $new_path, $full_path );
    }
    return 1;
}

=pod

=head2 move_recursive( [PATH1, PATH2...], TARGET )

Moves files and directories recursively to target location. Accepts an
anonymous array of relative paths of files and directories to move and the
target directory as the second parameter.

Returns I<1> upon success, undef upon failure.

=cut

sub move_recursive {
    my ( $self, $paths, $target_path ) = @_;

    if ( $self->copy_recursive( $paths, $target_path ) ) {
        # 0: don't print file information while processing
        # 1: Skip files that do not have delete/write access
        foreach my $path ( @{ $paths } ) {
            File::Path::rmtree( $path, 0, 1 );
        }
        return 1;
    }
    else {
        return undef;
    }
}

=pod

=head2 get_mime_type( [PATH], [FULL_PATH] )

gets mime type for a location.

Optionally accepts a relative path to use as a parameter, which is passed
along to I<get_full_path()>.

If the optional second parameter full path is provided, it is used instead of
constructing a new path with I<get_full_path()>.

=cut

sub get_mime_type {
    my ( $self, $path, $full ) = @_;

    unless ( $full ) {
        $path = $self->get_full_path( $path );
    }

    my $mime = Dicole::Files::MimeType->new;

    return $mime->mime_type_file( $path );
}

=pod

=head2 read_dir( PATH, [sub{ SORT }], [ROOT_PATH] )

Reads a file system directory and returns its contents,
file and directory names.

The first parameter is the path to a directory from which the
contents will be read.

The optional second parameter is the sorting to use. The default sorting is
to first sort the files in a directory in an order where the directories come
first and both files and directories sorted ascending. Here is the code which
is used by default:

  -d $b->[2] <=> -d $a->[2] || lc( $a->[1] ) cmp lc( $b->[1] )

The third parameter is optional. It defines the original root of the file
area. This part is taken out of the orginal directory path in order to construct
a relative directory path for each file and directory.

Returns an array of anonymous arrays. Each anonymous array contains the relative
path according to provided root, filename and the full path to the target
filename.

=cut

sub read_dir {
    my ( $self, $path, $sort, $root ) = @_;

    $root ||= $self->Pathutils->base_path;

    return undef unless -e $root;
    return undef unless -e $path;

    my @files = ();
    my $dir = DirHandle->new( $path );
    unless ( defined $dir ) {
        my $log = get_logger( LOG_DS );
        $log->error( sprintf(
            'Filesystem: Error reading directory %s: %s',
            $path, $!
        ) );
        return $!;
    }
    while ( defined( $_ = $dir->read ) ) {
        next if /^\./;
        my $full_path = File::Spec->catdir( $path, $_ );
        my $relative_path = $full_path;
        $relative_path =~ s/^$root[\/:]?//;
        push @files, [ $relative_path, $_, $full_path ]
            if -e $full_path;
    }
    undef $dir;
    unless ( ref( $sort ) ) {
        $sort = sub { $self->if_dir( $b->[2] ) <=> $self->if_dir( $a->[2] )
            || lc( $a->[1] ) cmp lc( $b->[1] ) };
    }
    return sort { &$sort } @files;
}

=pod

=head2 if_dir( FILE )

Accepts a string representing the path. Returns success if the path
is a directory, otherwise returns undef.

=cut

sub if_dir {
    my ( $self, $file ) = @_;
    if ( -d $file ) {
        return 1;
    }
    else {
        return undef;
    }
}

=pod

=head2 if_file( TYPE )

Accepts a string representing the path. Returns success if the path
is a file, otherwise returns undef.

=cut

sub if_file {
    my ( $self, $file ) = @_;
    if ( -f $file ) {
        return 1;
    }
    else {
        return undef;
    }
}

=pod

=head1 SEE ALSO

L<Dicole::Files|Dicole::Files>,
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

