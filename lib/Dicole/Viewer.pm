package Dicole::Viewer;

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Files;
use Dicole::Content::Controlbuttons;
use Dicole::Content;
use Dicole::Content::Text;
use Dicole::Content::Formelement::Dropdown;
use Dicole::Content::Button;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Dicole inline Viewer widget

=head1 SYNOPSIS

  use Dicole::Viewer;
  use Dicole::Files;
  my = $content = Dicole::Viewer->viewer( Dicole::Files->new );

=head1 DESCRIPTION

A viewer class that allows embedding into document an inline
viewer for a specified location. The viewer is able to display atleast
the following file types inline:

=over 4

=item Images

jpg, gif, png

With browser native support.

=item Macromedia

swf, spl, dcr

With Macromedia Flash and ShockWave players.

=item Sound

wav, mid, aiff, au, mp3, wma

With browser native support or with Windows Media Player.

=item Documents

PDF, ppt, doc, xls, plain text documents

With Acrobat Reader and MS Office or file type viewers.
Plain text is displayed as pre-formatted text.

=item HTML resources

url, html, htm

Uses IFRAME to include HTML page on the page as inline.
With default resolution, resizes IFRAME height to content height.
File type I<url> is special. It is opened and the URL inside the file
is used as the IFRAME source.

=item QuickTime

qt, mov

With QuickTime-plugin.

=item Applets: class

With native browser java applet support.

=item Realmedia

smil, smi, ra, ram, rpm, rm, rmp, rt

With Realplayer.

=item Windows Media

mpg, avi, asf, wmv

With Windows Media player.

=item QuickTime other

tif, bmp, psd, sgi, tga

With QuickTime. Requires some file type modules for QuickTime.

=back

All other formats are included as IFRAME. So if your browser supports
viewing the source, then it should work with IFRAME.

The viewer also has controls for controlling the inline object resolution
(width and heigth) and the possibility to open it as full screen.

=head1 METHODS

=head2 viewer( OBJECT, [BOOLEAN] )

Constructs the viewer with some support from L<Dicole::Files> object
(either uses url to determine file or I<Dicole::Files-E<gt>path>).

Accepts a Dicole::Files object as first parameter. If second parameter
is true, no controls (resolution etc.) will be displayed.

Returns an anonymous array of L<Dicole::Content> objects.

=cut

sub viewer {
    my ( $self, $files, $no_controls ) = @_;

    my $width = undef;
    my $height = undef;

    if ( CTX->request->param( 'resolution' ) ) {
        ( $width, $height ) = split 'x', CTX->request->param( 'resolution' );
        $width =~ tr/[0-9%]+//cd;
        $height =~ tr/[0-9%]+//cd;
    }

    my $types = {
        image     => [qw( image/jpeg image/gif image/png )],
        flash     => [qw( application/x-shockwave-flash application/futuresplash )],
        sound     => [qw( audio/x-wav audio/midi audio/x-aiff audio/basic )],
        pdf       => [qw( application/pdf )],
        shockwave => [qw( application/x-director )],
        qt        => [qw( video/quicktime )],
        applet    => [qw( application/x-java-vm )],
        real      => [
            qw( application/smil application/vnd.rn-realmedia audio/x-pn-realaudio
                audio/x-pn-realaudio-plugin text/vnd.rn-realtext )
        ],
        wmp       => [
            qw( video/mpeg audio/x-mpegurl audio/mpeg video/x-msvideo
                video/x-ms-asf audio/x-ms-wma application/x-ms-wmv )
        ],
        qtelse    => [
            qw( image/tif image/x-tiff image/x-bmp image/x-photoshop
                image/x-sgi image/x-targa )
        ]
    };

    my $mime = $files->mime_type_file( $files->Pathutils->clean_path_name );

    my $content = Dicole::Content->new;
    $content->set_template( CTX->server_config->{dicole}{base} . '::viewer' );
    $content->set_content( {
        width => $width, height => $height,
        href => $files->Pathutils->form_url( 'view' ),
    } );

    foreach my $key ( keys %{ $types } ) {
        if ( $self->_check_mime_type( $mime, $types->{$key} ) ) {
            $content->set_content( {
                width => $width, height => $height, type => $key,
                href => $files->Pathutils->form_url( 'view' ),
            } );
            last;
        }
    }

    my $lh = CTX->request->language_handle;

    my $resolution_nav = undef;
    if ( $mime ne 'text/html' && $mime =~ m{^text/} ) {
        $content = Dicole::Content::Text->new;
        $content->set_content( $files->get_file_contents );
        $content->preformatted( 1 );
    }
    elsif ( !$no_controls ) {
        $resolution_nav = Dicole::Content::Controlbuttons->new( buttons => [
            Dicole::Content::Text->new( content => $lh->maketext( 'Resolution:' ) ),
            Dicole::Content::Formelement::Dropdown->new(
                autosubmit => 1,
                selected => join ( 'x', ( $width, $height ) ),
                attributes => { name => 'resolution' },
                options => [
                    { attributes => { value => '' }, content => $lh->maketext( 'Default' ) },
                    { attributes => { value => '240x200' }, content => '240 x 200' },
                    { attributes => { value => '320x240' }, content => '320 x 240' },
                    { attributes => { value => '400x300' }, content => '400 x 300' },
                    { attributes => { value => '512x384' }, content => '512 x 384' },
                    { attributes => { value => '640x480' }, content => '640 x 480' },
                    { attributes => { value => '800x600' }, content => '800 x 600' },
                    { attributes => { value => '1024x768' }, content => '1024 x 768' },
                    { attributes => { value => '1280x1024' }, content => '1280 x 1024' },
                    { attributes => { value => '100%x100%' }, content => '100% x 100%' },
                ],
            ),
            Dicole::Content::Button->new(
                type => 'link',
                link => $files->Pathutils->form_url( 'view' ),
                value => $lh->maketext( 'Full screen' )
            )
        ] );
    }

    if ( $mime eq 'wwwserver/redirection' ) {
        $content->set_content( {
            width => $width, height => $height,
            href => $files->get_file_contents,
        } );
    }

    my $content_array = [ $content ];
    if ( defined $resolution_nav ) {
        push @{ $content_array }, $resolution_nav;
    }

    return $content_array;
}

sub _check_mime_type {
    my ( $self, $mime, $types ) = @_;
    if ( grep { $_ eq $mime } @{ $types } ) {
        return 1;
    }
    else {
        return undef;
    }
}

=pod

=head1 TODO

  - Java applets
  - Some way to handle java applets inside .jar archives
    (maybe options as new database fields?)

=head1 SEE ALSO

L<Dicole::Files|Dicole::Files>

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

