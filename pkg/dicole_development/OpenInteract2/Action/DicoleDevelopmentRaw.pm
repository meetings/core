package OpenInteract2::Action::DicoleDevelopmentRaw;

use strict;
use base qw( OpenInteract2::Action::DicoleDevelopmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use IO::Compress::Gzip;

my @bundle = (
'dojo.cookie',
'dojo.regexp',
'dojo.string',

'dicole.base',
'dicole.base.globals',
'dicole.base.html',
'dicole.base.localization',
#'dojo.string',
'dicole.base.template',
'dicole.base.dom',
'dojo.fx',
'dojo.fx.Toggler',
'dojo.window',
'dojo.io.script',
'dicole.invite',
'dicole.user_manager',
#'dicole.base.globals',
'dicole.base.utils',
'dicole.base.swfobject',
'dicole.base.swfupload',
'dicole.meetings',
'dicole.meetings_common',
'dicole.comments',
'dicole.event_source',
'dicole.event_source.ServerWorker',
'dicole.event_source.ServerConnection',
#'dojo.cookie',
#'dojo.regexp',
'dicole.meetings_navigation',
'dicole.meetings.vendor.jquery',
'dicole.meetings.vendor.addressbook',
'dicole.meetings.vendor.autocomplete',
'dicole.meetings.vendor.btdcalendar',
'dicole.meetings.vendor.charcounter',
'dicole.meetings.vendor.chosen',
'dicole.meetings.vendor.guiders',
'dicole.meetings.vendor.hintlighter',
'dicole.meetings.vendor.nouislider',
'dicole.meetings.vendor.jqueryuiwidget',
'dicole.meetings.vendor.iframe_transport',
'dicole.meetings.vendor.fileupload',
);

my $htmldir = CTX->lookup_directory( 'html' );

sub bundled_javascripts {
    my ( $self ) = @_;

    my $result = '';

    my @b = $self->_get_bundle;

    for my $pkg ( @b ) {
        my $fname = $pkg;
        $fname =~ s/\./\//g;
        $fname = '/js/' . $fname . '.js';

        local $/;
        open(FILE, $htmldir . $fname) or next;
        my $document = <FILE>; 
        close (FILE);

        $result .= $document;
    }

    for my $pkg ( @b ) {
        $result =~ s/dojo\.require\(['"]$pkg['"].*//mg;
    }

    CTX->response->content_type( 'text/javascript' );
    CTX->response->header("Content-Encoding", "gzip");

    my $output = '';

    IO::Compress::Gzip::gzip( \$result, \$output );

    return $output;
}

sub _get_bundle {
    my ( $self ) = @_;

    my $fname = '/js/dicole/meetings/main.js';

    local $/;
    open(FILE, $htmldir . $fname) or next;
    my $document = <FILE>; 
    close (FILE);

    my @requires = $document =~ /require\(\"([^\"]*)\"/g;
    push @requires, 'dicole.meetings.main';

    my %bmap = map { $_ => 1 } @bundle;
    for my $require ( @requires ) {
        next if $bmap{ $require };
        push @bundle, $require;
    }

    return ( @bundle );
}

1;

