package Dicole::DateTime;

# $Id: DateTime.pm,v 1.19 2009-10-14 20:50:06 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use DateTime;
use DateTime::Locale;
use Encode;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

An utility class for playing with dates

=head1 SYNOPSIS

 use Dicole::DateTime;

 my $epoch = time - 50;

    # format of full_date is specified in server config
    # under key date_format

 print Dicole::DateTime->full_date( $epoch );
 print Dicole::DateTime->full_date_short; # uses time() as epoch
 print Dicole::DateTime->long_datetime_format; # localized

=head1 DESCRIPTION

This class handles date string generation in Dicole.
You should define the default date formats in your I<server.ini>.

=head1 METHODS

This class uses AUTOLOAD to map methods to formats defined
in server configuration under the key I<date_format>. The format
is passed to I<strftime()> method of DateTime object which is created
from the epoch received as first argument. If no epoch is received
the output of I<time()> is used.

The second parameter is optional and includes the timezone.

The third parameter is optional and includes the language handle.

Loads L<DateTime::Locale> object based on the language of the user.
Also accepts the following locale-specific methods:

=over 4

=item *

full_date_format

=item *

long_date_format

=item *

medium_date_format

=item *

short_date_format

=item *

full_time_format

=item *

long_time_format

=item *

medium_time_format

=item *

short_time_format

=item *

full_datetime_format

=item *

long_datetime_format

=item *

medium_datetime_format

=item *

short_datetime_format

=back

It is recommended that above methods are used. Server configuration specific
methods are used when the locale doesn't matter or only english is intended
(for logging, for example).

=cut

sub full_date_format       { shift->_get_dt_locale_string( date_format_full       => @_ ) }
sub long_date_format       { shift->_get_dt_locale_string( date_format_long       => @_ ) }
sub medium_date_format     { shift->_get_dt_locale_string( date_format_medium     => @_ ) }
sub short_date_format      { shift->_get_dt_locale_string( date_format_short      => @_ ) }
sub full_time_format       { shift->_get_dt_locale_string( time_format_full       => @_ ) }
sub long_time_format       { shift->_get_dt_locale_string( time_format_long       => @_ ) }
sub medium_time_format     { shift->_get_dt_locale_string( time_format_medium     => @_ ) }
sub short_time_format      { shift->_get_dt_locale_string( time_format_short      => @_ ) }
sub full_datetime_format   { shift->_get_dt_locale_string( datetime_format_full   => @_ ) }
sub long_datetime_format   { shift->_get_dt_locale_string( datetime_format_long   => @_ ) }
sub medium_datetime_format { shift->_get_dt_locale_string( datetime_format_medium => @_ ) }
sub short_datetime_format  { shift->_get_dt_locale_string( datetime_format_short  => @_ ) }

sub AUTOLOAD {
    my ( $self, $epoch, $timezone, $lang ) = @_;

    use vars qw( $AUTOLOAD );

    my $format = ( split /::/, $AUTOLOAD )[-1];
    $format = CTX->server_config->{date_format}->{$format};
    
    return $self->_get_format_string( $format, $epoch, $timezone, $lang );
}

sub _get_dt_locale_string {
    my ( $self, $format, $epoch, $timezone, $lang ) = @_;

    my $loc = $self->load_locale( undef, $lang );
    $format = $loc->$format;
    
    return $self->_get_format_string( $format, $epoch, $timezone, $lang, $loc );
}

sub _get_format_string {
    my ( $self, $format, $epoch, $timezone, $lang, $loc ) = @_;

    return unless $format;

    $loc ||= $self->load_locale( undef, $lang );

    $timezone ||= eval{ CTX->request->auth_user->{timezone} } if CTX && CTX->request && CTX->request->auth_user_id;
    $timezone ||= eval{ CTX->controller->initial_action->param('domain')->default_timezone };
    $timezone ||= (CTX && CTX->server_config->{timezone}) || 'UTC';

    my $dt = DateTime->from_epoch(
        locale => $loc,
        epoch => $epoch || time
    );
    $dt->set_time_zone( $timezone );

    return ucfirst( Encode::encode_utf8( $dt->format_cldr( $format ) ) );
}

=pod

=head2 load_locale( [BOOLEAN], [LANGUAGE] )

Loads the current locale based on I<CTX-E<gt>request-E<gt>language_handle>
and caches the created I<DateTime::Locale> object into
I<CTX-E<gt>request-E<gt>session-E<gt>{lang}> and returns it. If object
is already found from cache, returns it.

If the first parameter is true, the fetching of the object is forced
even if it is already cached from previous operation.

The second parameter is optional and includes the language handle.

=cut

sub load_locale {
    my ( $self, $force, $lang ) = @_;

    my $lang_hash = undef;
    unless ( $lang ) {
        if ( CTX && CTX->request && CTX->request->session && CTX->request->session->{lang} ) {
            $lang_hash = CTX->request->session->{lang};
            return $lang_hash->{object} if ! $force && ref $lang_hash->{object};
        }
    }

    $lang ||= (CTX && ref( CTX->request )) ? ref( CTX->request->language_handle ) : 'en';
    $lang =~ s/^.*::(.*)$/$1/;
    my $loc = eval { DateTime::Locale->load( $lang ) };

    if ( $@ || !ref $loc ) {
        get_logger( LOG_TRANSLATE )->error( sprintf(
            'Language [%s] is not supported by DateTime::Locale! Using english.',
            $lang
        ) );
        $loc = DateTime::Locale->load( 'en' );
    }
    unless ( $lang ) {
        $lang_hash->{object} = $loc;
    }

    return $loc;
}

=pod

=head2 get_dates_between( INTEGER, INTEGER, [BOOLEAN] )

Calculates dates within a specified period of time. Returns an
anonymous array of epoch values representing each day. You may
use a scalar operator against the arrayref to get the number of
dates between.

If the optional third parameter is set, only work days are added in the
array, which means saturday and sunday get excluded.

TODO: This doesn't seem to always work!

=cut

sub get_dates_between {
    my ( $self, $start_epoch, $end_epoch, $skip ) = @_;

    my $loc = $self->load_locale;

    my $dates = [];
    my $date_time = DateTime->from_epoch( epoch => $start_epoch );
    for ( my $t = $start_epoch;
        $t <= $end_epoch;
        $t = $date_time->add( days => 1 )->epoch
    ) {
        # Skip saturday & sunday
        my $day_of_week = $date_time->day_of_week;
        next if $skip && ( $day_of_week == 6 || $day_of_week == 7 );
        push @{ $dates },  [ $t ];
    }
    return $dates;
}

=pod

=head2 start_of_week( INTEGER, INTEGER )

Calculates the start date of a specified week. Accepts the
year and week number as parameters.

Returns a L<DateTime> object.

=cut

sub start_of_week {
        my ( $self, $selected_year, $selected_week ) = @_;

        # Remember that the first week of the year is defined by ISO as the
        # one which contains the fourth day of January, which is equivalent
        # to saying that it's the first week to overlap the new year by at
        # least four days. This code might or might not result in
        # proper functionality

        # calculate the starting day of the week
        my $weekstart = DateTime->from_day_of_year(
            year => $selected_year,
            day_of_year => 3,
            locale => $self->load_locale
        );
        $weekstart->subtract( days => 1 ) until $weekstart->day_of_week == 1;
        $weekstart->add( days => 7 * ($selected_week - 1) );

        return $weekstart;
}

=pod

=head1 SEE ALSO

L<DateTime>,
L<DateTime::Locale>

=head1 AUTHOR

Antti V��otam�i E<lt>antti@ionstream.fiE<gt>,
Teemu Arina E<lt>teemu@ionstream.fiE<gt>,

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

