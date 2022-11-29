package Dicole::Excel;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use File::stat;
use IO::File;
use Spreadsheet::WriteExcel;
use Spreadsheet::WriteExcel::Utility;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my $log = ();

=pod

=head1 NAME

A class for easy creation of Excel reports

=head1 SYNOPSIS

  use Dicole::Excel;

=head1 DESCRIPTION

blabla

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=head2 workbook( [OBJECT] )

Accessor to the I<Spreadsheet::WriteExcel> object. This is set automatically
during I<new()>.

=head2 workbook_fh( [HANDLE] )

Accessor to the filehandle of the Excel file.

=head2 sheet( [OBJECT] )

Accessor to the worksheet object. This is usuall
created with I<create_sheet()> method.

=cut

use base qw( Class::Accessor );

Dicole::Excel->mk_accessors(
    qw( workbook workbook_fh sheet )
);

=pod

=head1 METHODS

=head2 new()

Initializes and creates a new I<Dicole::Excel> object.

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

    $log ||= get_logger( LOG_APP );

    # Open new excel workbook in an anonymous tempfile
    my $fh = IO::File->new_tmpfile
        or $log->error( "Opening temp file failed: [". $@ ."]" );
    binmode $fh;
    $fh->autoflush( 1 );
    $self->workbook( Spreadsheet::WriteExcel->new( $fh ) );
    $self->workbook_fh( $fh );
}

=pod

=head2 get_excel_styles()

Returns some useful excel styles as an anomymous hash.
Available styles:

=over 4

=item *

date_ddmm

=item *

num_normal

=item *

num_bold

=item *

num_color

=item *

text_vertical

=item *

text_multiline

=item *

text_center

=item *

text_top

=item *

text_gray

=item *

text_bold

=item *

page_title

=item *

column_title

=item *

separator

=back

=cut

sub get_excel_styles {

    my ( $self ) = @_;

        my $bg_color = $self->workbook->set_custom_color(40, '#FFEBC1');
        my $section_color = $self->workbook->set_custom_color(41, '#FFB009');

        my $styles = {
            date_ddmm       => $self->workbook
                ->addformat( num_format => 'dd.mm' ),
            num_normal      => $self->workbook
                ->addformat( num_format => '# ##0.00' ),
            num_bold        => $self->workbook
                ->addformat( bold => 1, num_format => '# ##0.00' ),
            num_color       => $self->workbook
                ->addformat( num_format => '[Color 10]# ##0.00;[Red]-# ##0.00;# ##0.00' ),
            text_vertical   => $self->workbook
                ->addformat( rotation => 90 ),
            text_multiline  => $self->workbook
                ->addformat( text_wrap => 1, align => 'top' ),
            text_center     => $self->workbook
                ->addformat( align => 'center' ),
            text_top        => $self->workbook
                ->addformat( align => 'top' ),
            text_gray       => $self->workbook
                ->addformat( color => 'gray' ),
            text_bold       => $self->workbook
                ->addformat( bold => 1 ),
            page_title      => $self->workbook
                ->addformat( size  => 12, bold => 1 ),
            column_title    => $self->workbook
                ->addformat( bold => 1, bg_color => $bg_color, border => 1 ),
            column_title_vertical => $self->workbook
                ->addformat( rotation => 90, bold => 1, bg_color => $bg_color, border => 1 ),
            section_title   => $self->workbook
                ->addformat( color => $section_color, size => 12, bold => 1 ),
            separator       => $self->workbook
                ->addformat( top => 1 ),
        };

        return $styles;
}

=pod

=head2 create_sheet( STRING )

Creates a new sheet and returns the sheet object.
Accepts the sheet name as a parameter. The sheet is also stored
into accessor I<sheet()>.

=cut

sub create_sheet {
    my ( $self, $sheet_name ) = @_;
    $self->sheet( $self->workbook->addworksheet( $sheet_name ) );
    return $self->sheet;
}

=pod

=head2 long_string( STRING )

Excel 95 format has a problem with strings longer than 255 characters.

Some older versions of I<Spreadsheet::WriteExcel> are not able to work
around this problem. Latest version (as of writing, 2.0.1) has support
for strings up to 32767 characters.

To overcome this problem we use a formula instead of a string to write
the contents of a long string text field.
We create a formula that joins together a collection of strings that
are no longer than 255 characters. This allows us to overcome the
string length problem.

It is suggested that contents of all multiline fields that use word
wrap are filtered through this method.

=cut

sub long_string {

    my ( $self, $str ) = @_;

    $str =~ s/\r\n/\n/gs;
    $str =~ s/\r//gs;
    $str =~ s/\t/ /gs;
    $str =~ s/"/''/gs;
    chomp( $str );

    my $orig = $str;

    my $limit = 255;

    return $str if $Spreadsheet::WriteExcel::VERSION =~ /^0\.49/;

    # Return short strings
    return $str if length $str <= $limit;

    $str = substr( $str, 0, 1000 ) . '...' if length $str <= 1000;

    # Split the line at word boundaries where possible
    my @segments = $str =~ m[.{1,$limit}$|.{1,$limit}\b|.{1,$limit}]sog;

    # Join the string back together with quotes and Excel concatenation
    $str = join '"&"', @segments;

    $str = qq( ="$str" );

    # Remember to add formatting to convert the string to a formula string
    return $str;
}

=pod

=head2 write_columns( HASH )

A simple column writer. Eases the writing of a collection of columns.

Hash arguments:

=over 4

=item B<columns> I<arrayref>

An anonymous array of arrays. Each array contains the title of the column
and the width of the column.

=item B<row> I<integer>

The row number where to start writing the columns.

=item B<col> I<integer>

The column number where to start writing the columns.

=item B<style> I<style>

An Excel style to use for the columns (I<column_title> is suggested).

=back

=cut

sub write_columns {

    my $self = shift;

    my $args = {
        columns   => [ [] ],
        row       => 1,
        col       => 3,
        style     => '',
        @_
    };

    # Create columns
    my $col_count = $args->{col};
    foreach my $col ( @{ $args->{columns} } ) {
        # set column width
        $self->sheet->set_column( $col_count, $col_count, $col->[1] );
        $self->sheet->write( $args->{row}, $col_count, $col->[0], $args->{style} );
        $col_count++;
    }
}

=pod

=head2 set_printing( [HASH] )

Sets some useful printing options for the worksheet.

Hash parameters:

=over 4

=item B<auto_fit_width> I<boolean>

Automatically fits the sheet width to one page.

This is on by default.

=item B<landscape> I<boolean>

Landscape printing instead of portrait.

=item B<auto_fit_page> I<boolean>

Automatically fits the contents of the sheet
to one page.

=item B<no_auto_fit> I<boolean>

Does not automatically fit the contents to the page
in any way.

=item B<show_grid> I<boolean>

Displays grid lines in the output.

=back

=cut

sub set_printing {
    my $self = shift;

    my %args = (
        auto_fit_width => 1,
        @_
    );

    $self->sheet->set_paper( 9 ); # A4
    $self->sheet->set_landscape if $args{landscape};
    $self->sheet->hide_gridlines unless $args{show_grid};

    # 1 page wide and as long as necessary
    $self->sheet->fit_to_pages( 1, 0 ) if $args{auto_fit_width};
    # Fit on one page
    $self->sheet->fit_to_pages( 1, 1 ) if $args{auto_fit_page};
    # No fitting
    $self->sheet->fit_to_pages( 0, 0 ) if $args{no_auto_fit};

    # Default margins
    $self->sheet->set_margins_LR( 0.40 );
    $self->sheet->set_margins_TB( 0.60 );
}

=pod

=head2 set_header( STRING )

Sets the header of the page to user specified string. Also sets
the footer of the page to I< page number / total pages>.

=cut

sub set_header {

    my ( $self, $header_text ) = @_;

    my $header = '&C&"Verdana,Bold"';

    $header_text =~ s/\&/\&\&/g;
    $header_text =~ tr/\"\'//d;
    $header .= $header_text;

    $self->sheet->set_header( $header, '0.30' ) if $header_text;
    $self->sheet->set_footer( '&P / &N', '0.30' );
}

=pod

=head2 get_excel( FILENAME, [VIEW] )

Returns the excel file to the client. Accepts the filename as the
first parameter. Optionally accepts the boolean view parameter, which
tells the method to return content type I<application/vnd.ms-excel> instead
of I<application/octet-stream>:

Returns the binary data of the excel file.

=cut

sub get_excel {

    my ( $self, $filename, $view ) = @_;

    $filename =~ tr/0-9,.a-zA-Z_\-//cd;

    $self->workbook->close;

    seek( $self->workbook_fh, 0, 0);

    my $st = stat( $self->workbook_fh );

    CTX->response->header(
       'Content-Disposition',
       "attachment; filename=$filename"
    );
    CTX->response->header( 'Content-Length', $st->size );

    # Choose content type
    if ( $view ) {
        CTX->response->content_type( 'application/vnd.ms-excel' );
    }
    else {
        CTX->response->content_type( 'application/octet-stream' );
    }
    CTX->controller->no_template( 'yes' ) if CTX->controller->can( 'no_template' );

    # slurp the file
    local $/ = undef;
    my $fh = $self->workbook_fh;
    return CTX->response->send_filehandle( $fh );
}

=pod

=head1 SEE ALSO

L<Spreadsheet::WriteExcel|Spreadsheet::WriteExcel>

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

