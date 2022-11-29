package Dicole::Content::Formelement::Date;

use strict;
use base qw( Dicole::Content::Formelement );

use DateTime;
use Dicole::DateTime;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my %TEMPLATE_PARAMS = map { $_ => 1 }
    qw( date show_time hide_date );

sub TEMPLATE_PARAMS {
    my $self = shift;

    return {
        %{$self->SUPER::TEMPLATE_PARAMS},
        %TEMPLATE_PARAMS
    };
}

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

__PACKAGE__->mk_accessors( qw( datetime ) );

# ---------------------------------------------------------------------------------------

# Dicole::Content::Formelement::Date->new(required => 1, error => 0, modifyable => 1, attributes => { name => 'blah', value => {} },
#                                         timezone => '', epoch => '107301873918', date => {day => '', month => '', year => '', hour => '', minute => ''} );
# Epoch overrides date
# new() calls _init() and passes the arguments.
sub _init {
        my ($self, %args) = @_;

        $args{template} ||= CTX->server_config->{dicole}{base} . '::input_date';
        $args{timezone} ||= '+0000';

        $self->SUPER::_init(%args);

        if ( $args{epoch} ) {
            $self->datetime(
                DateTime->from_epoch(
                    epoch => $args{epoch},
                    time_zone => $args{timezone},
                )
            );
        }
        elsif ( $args{date} ) {
            $self->datetime(
                DateTime->new(
                    %{ $args{date} },
                    time_zone => $args{timezone},
                )
            );
        }
        else {
            $self->datetime(
                DateTime->from_epoch(
                    epoch => time,
                    time_zone => $args{timezone},
                )
            );
        }

}

sub _date_hash {
        my $self = shift;

        return {
            day    => $self->datetime->day,
            month  => $self->datetime->month,
            year   => $self->datetime->year,
            minute => $self->datetime->minute,
            hour   => $self->datetime->hour
        };
}

sub set_date {
        my ($self, $date) = @_;

        $self->datetime->set(
            %$date
        );
}

sub get_date {
        my $self = shift;

        return $self->_date_hash();
}

sub clear_date { $_[0]->set_epoch( time() ); }

sub set_timezone {
        my ($self, $tz) = @_;

        $self->datetime->set_time_zone($tz);
}

sub get_timezone {
        my $self = shift;

        return $self->datetime->time_zone_long_name;
}

sub set_epoch {
        my ($self, $epoch) = @_;

        $self->datetime(
            DateTime->from_epoch(
                epoch => $epoch,
                time_zone => $self->datetime->time_zone,
            )
        );
}

sub get_epoch {
        my $self = shift;

        return $self->datetime->epoch;
}

sub get_template_params {
        my $self = shift;

        if ( $self->modifyable ) {
            $self->set_value( $self->_date_hash );
            $self->date( {
                days    => [ 1 .. 31 ],
                months  => [ 1 .. 12 ],
                years   => [
                    $self->datetime->year-5 ..
                    $self->datetime->year+10
                ],
            } );
        }
        else {
             $self->set_value( $self->_get_date_as_plaintext );
        }

        return $self->SUPER::get_template_params;
}

sub _get_date_as_plaintext {
        my $self = shift;

	    my $epoch = $self->datetime->epoch;

        if ( $self->hide_date ) {
	    	return Dicole::DateTime->short_time_format( $epoch );
    	}
    	elsif ( $self->show_time ) {
	    	return Dicole::DateTime->medium_datetime_format( $epoch );
        }
    	else {
		    return Dicole::DateTime->long_date_format( $epoch );
	    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Formelement::Date - Date object

=head1 SYNOPSIS

  use Dicole::Content::Formelement::Date;
  $d = Dicole::Content::Formelement::Date->new(date => {day => 1, month => 2, year => 2003} );
  $d->set_epoch(54239124321);
  $d->set_timezone('+0200');

  return $self->generate_content(
        { itemparams => $d->get_template_params },
        { name => $d->get_template }
  );


=head1 DESCRIPTION

This is the Dicole date class, which can be given timezone and date in several formats, and which
returns data in the format that the template dicole_base::input_date wants.

=head1 METHODS

B<new( timezone => SCALAR, epoch => SCALAR, date => { day => SCALAR, month => SCALAR, year => SCALAR, hour => SCALAR, minute => SCALAR } )>
Also takes some parameters that the constructor of Dicole::Content::Formelement accepts (these aren't however yet supported by
the template).

The timezone must be given in format that perl module DateTime accepts (either some text like 'America/Chicago' or
a time offset like '+0200'). If none is given, the default timezone is '+0000' (GMT).

The date can be given using either epoch or date attribute. The values specified in the date hash must be a valid date. If the
epoch is defined, it overrides the date hash. If neither one is given, the current time is used to initialize the DateTime object.

B<set_date( { day => SCALAR, month => SCALAR, year => SCALAR, hour => SCALAR, minute => SCALAR } )>
Sets the date. If any value in the hash is undefined, the current value for it in the DateTime object is used.
Example:
$self->set_date( { day => 1, month => 2, year => 3, hour => 23, minute => 50 } );
$self->set_date( { year => 2003 } ); # day is still 1, month is still 2, hour is still 23 and minute is still 50 after this command

B<get_date()>
Returns hashref containing the same elements that are accepted by set_date.

B<clear_date()>
Resets the date to the current (server) time.

B<set_timezone( SCALAR )>
Sets the timezone. The argument can be in the same format that the constructor timezone parameter accepts.

B<get_timezone()>
Returns a timezone string.

B<set_epoch( SCALAR )>
Sets the date using epoch value.

B<get_epoch()>
Returns the epoch value.

B<get_template_params()>
Converts the data stored in DateTime object to the format that dicole_base::input_date template wants, and returns the output.

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>
L<Dicole::Content::Formelement|Dicole::Content::Formelement>
L<DateTime|DateTime>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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

