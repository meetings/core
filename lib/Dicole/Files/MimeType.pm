package Dicole::Files::MimeType;

use strict;

use File::MimeInfo ();
use Dicole::Pathutils;
use Dicole::Files::Filesystem;
use IPC::Open2 qw(open2);
use IO::Handle;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

File MIME type detection tools

=head1 SYNOPSIS

  use Dicole::Files::MimeType;

  my $mimetype = Dicole::Files::MimeType->new;
  print $mimetype->mime_type_file( '/opt/test.txt' );

=head1 DESCRIPTION

This class provides Dicole compatible layer for identifying file MIME types.

=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Files> object. Also automatically
initializes mime magic module. Accepts a hash of parameters for class attribute
initialization.

Parameters:

See I<Pathutils>.

=cut

sub new {
	my ( $class, $args ) = @_;
	my $config = { };
	my $self = bless( $config, $class );
	$self->_init( $args );
	return $self;
}

sub _init {
	my ( $self, $args ) = @_;

	if ( ref( $args ) eq 'HASH' ) {
		foreach my $key ( keys %{ $args } ) {
			$self->{$key} = $args->{$key};
		}
	}

	$self->init_magic;
}

=pod

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

=head2 init_magic()

Initializes the L<File::MimeInfo> module, which is used to identify file types.
The object is singleton, which means it is initialized only once in an Apache
thread to save resources.

=cut

my ( $MAGIC );
sub init_magic {
    my ( $self ) = @_;
    return if ( $MAGIC );
    $MAGIC = File::MimeInfo->new;
}

=pod

=head2 simple_types( [HASH] )

Returns an anonymous hash of file extensions mapped to mime types.
I<mime_type_file()> uses this method first to identify the file type. Optionally
accepts an anonymous hash of mime types to use instead of the built-in list.

=cut

sub simple_types {
	my ( $self, $types ) = @_;
	if ( ref( $types ) eq 'HASH' ) {
		$self->{simple_types} = $types;
	}
	unless ( ref $self->{simple_types} ) {
		$self->{simple_types} = {

			flv  => 'video/x-flv',
			xls  => 'application/vnd.ms-excel',
			ppt  => 'application/vnd.ms-powerpoint',
			doc  => 'application/msword',
			xlsx  => 'application/vnd.ms-excel',
			pptx  => 'application/vnd.ms-powerpoint',
			docx  => 'application/msword',
			rtf  => 'text/rtf',

			bmp  => 'image/bmp',
			tif  => 'image/tif',

			# Acrobat reader
			pdf  => 'application/pdf',

			# Browser supported
			jpg  => 'image/jpeg',
			jpeg  => 'image/jpeg',
			gif  => 'image/gif',
			png  => 'image/png',

			mid  => 'audio/midi',
			midi => 'audio/midi',

			html => 'text/html',
			htm  => 'text/html',
			xml  => 'text/xml',
			txt  => 'text/plain',

			mmp  => 'application/x-mindmanager',

			# Quicktime
			qt   => 'video/quicktime',
			mov  => 'video/quicktime',
			psd  => 'application/x-photoshop',

			# Real player
			smil => 'application/smil',
			smi  => 'application/smil',
			ra   => 'audio/x-pn-realaudio',
			rpm  => 'audio/x-pn-realaudio-plugin',
			rm   => 'application/vnd.rn-realmedia',
			ram  => 'audio/x-pn-realaudio',
			rmm  => 'audio/x-pn-realaudio',
			rmp  => 'audio/x-pn-realaudio',
			rt   => 'text/vnd.rn-realtext',

			# Shockwave / flash
			swf  => 'application/x-shockwave-flash',
			swv  => 'application/x-shockwave-flash',
			swa  => 'application/x-shockwave-flash',
			cab  => 'application/x-shockwave-flash',
			spl  => 'application/futuresplash',

			# Shockwave / director
			dir  => 'application/x-director',
			dcr  => 'application/x-director',

			# Java applets
			class => 'application/x-java-vm',

			# Windows media player
			asf  => 'video/x-ms-asf',
			wmv  => 'application/x-ms-wmv',
			wma  => 'audio/x-ms-wma',
			mpg  => 'video/mpeg',
			mpeg => 'video/mpeg',
			avi  => 'video/x-msvideo',
			m3u  => 'audio/x-mpegurl',
			mp3  => 'audio/mpeg',
			ogg  => 'application/ogg',
			mp4  => 'video/mp4',

			# Archives
			zip  => 'application/x-zip-compressed',
			gz   => 'application/x-gzip',
			tar  => 'application/x-tar',
			tgz  => 'application/x-compressed-tar',

			# Dicole specific
			url  => 'wwwserver/redirection',

			rdf => 'application/rdf+xml',
			# Sanako specific
			vocab => 'application/sanako-vocab',
			mff => 'application/sanako-mff',
		};
	}
	return $self->{simple_types};
}

=pod

=head2 mime_type_by_extension( [FILENAME] )

Gets the mime type based on file extension. If no filename is provided,
I<Pathutils> is used to get the filename. The mime type extension is identified
with I<simple_types()>.

=cut

sub mime_type_by_extension {
	my ( $self, $filename ) = @_;

	$filename ||= $self->Pathutils->clean_path_name;

	my ( $extension ) = $filename =~ /\.(\w+)$/;

	# Special case, two dots in filename
	if ( $filename =~ /\.tar\.gz$/i ) {
		return 'application/x-compressed-tar';
	}

	return $self->simple_types->{ lc $extension };
}

=pod

=head2 mime_type_file( [FILENAME] )

Gets the mime type based on identification. Identification is first done by
using the method I<mime_type_by_extension()>, if the result was not found the
I<get_mime_type()> function through I<Fileops> is used. If no relative path to
the filename is provided, I<Pathutils> is used to get the relative path.

=cut

sub mime_type_file {
	my ( $self, $filename ) = @_;

	$filename ||= $self->Pathutils->get_current_path;

	my $mime_type = $self->mime_type_by_extension( $filename );
	return $mime_type if ( $mime_type );
	if ( -e $filename ) {
		return eval{ $MAGIC->mimetype( $filename ) };
	}
	else {
		return eval{ $MAGIC->globs( $filename ) };
	}
}

sub mime_type_filehandle {
    my ($self, $handle) = @_;

    open2 my $in, my $out, qw(file --mime-type --brief -);

    seek $handle, 0, 0;

    $out->print(<$handle>);
    $out->close;

    seek $handle, 0, 0;

    return <$in>;
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
	my $mime_type = $self->mime_type_file( $filename );
	$mime_type = 'inode/directory' unless $mime_type;
	return $MAGIC->describe( $mime_type, $lang );
}

=pod

=head1 SEE ALSO

L<Dicole::Files::Archive>,
L<Dicole::Files::Filesystem>,
L<Dicole::Files::Smb>,
L<Dicole::Files>,
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
