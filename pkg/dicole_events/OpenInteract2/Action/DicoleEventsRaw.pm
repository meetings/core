package OpenInteract2::Action::DicoleEventsRaw;

use strict;

use base qw( OpenInteract2::Action::DicoleEventsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Excel;
use Date::ICal;
use Data::ICal;
use Data::ICal::Entry::Event;

sub export_users { return shift->export_users_xls }

sub export_users_xls {
    my ( $self ) = @_;

    my $lines = $self->_export_users_data('xls');

    my $excel = Dicole::Excel->new;
#    $excel->workbook->keep_leading_zeros(1);
    $excel->create_sheet( Dicole::Utils::Text->utf8_to_latin( $self->_msg( 'List of users' ) ) );
    $excel->set_printing;
    $excel->set_header( Dicole::Utils::Text->utf8_to_latin( $self->_msg( 'List of users' ) ) );

    my $columns = [];
    my $fields = shift @$lines;
    foreach my $field ( @$fields ) {
        push @$columns, [
            Dicole::Utils::Text->utf8_to_latin( $field ),
            20
        ];
    }

    $excel->write_columns(
        columns => $columns,
        row   => 0,
        col   => 0,
        style => $excel->get_excel_styles->{column_title}
    );

    my $row_count = 1;
    for my $line ( @$lines ) {
        my $row = [];
        my $col_count = 0;

        for my $field ( @$line ) {
            $excel->sheet->write_string( $row_count, $col_count++, Dicole::Utils::Text->utf8_to_latin( $field ), $excel->get_excel_styles->{text_top} );
        }

        $row_count++;
#         foreach my $field ( @$line ) {
#             push @$row, [
#                 Dicole::Utils::Text->utf8_to_latin( $field ),
#                 20,
#             ];
#         }
#         $excel->write_columns(
#             columns => $row,
#             row   => $row_count++,
#             col   => 0,
#             style => $excel->get_excel_styles->{text_top}
#         );
    }

    # Return the final excel sheet and set the browser
    # output headers correctly.
    return $excel->get_excel( $self->_filtered_export_filename( 'xls' ) );
}

sub export_users_csv {
    my ( $self ) = @_;

    my $lines = $self->_export_users_data('csv');

    CTX->response->content_type( 'text/csv; charset=utf8' );

    return join( "\n", map { '"' . join( '","', map { $_ =~ s/"/""/g; "'" . $_ } @$_ ) . '"' } @$lines );
}

# This is just a test..
sub ics_list {
    my ( $self ) = @_;

    my $events = CTX->lookup_object('events_event')->fetch_group( {
        where => 'group_id = ? AND event_state = ?',
        value => [ $self->param('target_group_id'), $self->STATE_PUBLIC ],
    } );

    my $calendar = Data::ICal->new();

    for my $event ( @$events ) {
        my $vevent = Data::ICal::Entry::Event->new();
        $vevent->add_properties(
            summary => $event->title,
            description => $event->abstract . "\n\n" . Dicole::Utils::HTML->html_to_text( $event->description ),
            dtstart => Date::ICal->new( epoch => $event->begin_date )->ical,
            ( $event->end_date ) ? ( dtend  => Date::ICal->new( epoch => $event->end_date )->ical ) : (),
        );
        $calendar->add_entry($vevent);
    }

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/calendar' );

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub ics {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_see_event( $event );

    my $vevent = Data::ICal::Entry::Event->new();
    $vevent->add_properties(
        summary => $event->title,
        description => $event->abstract . "\n\n" . Dicole::Utils::HTML->html_to_text( $event->description ),
        dtstart => Date::ICal->new( epoch => $event->begin_date )->ical,
        ( $event->end_date ) ? ( dtend  => Date::ICal->new( epoch => $event->end_date )->ical ) : (),
    );

    my $calendar = Data::ICal->new();
    $calendar->add_entry($vevent);

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/calendar' );

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub _export_users_data {
    my ( $self, $extension ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_manage_event( $event );

    my $infos = $self->_fetch_valid_event_user_infos_using_request( $event );

    unless ( $self->param('user_id_list') && $self->param('filename') ) {
        $self->redirect( $self->derive_url( additional => [
            $event->id,
            join( "_", map { $_->{id} } @$infos ),
            $self->_filtered_export_filename( $extension ),
        ] ) );
    }

    my %trans = (
        $self->RSVP_WAITING() => $self->_msg( 'Waiting (manage)' ),
        $self->RSVP_YES() => $self->_msg( 'Attending (manage)' ),
        $self->RSVP_NO() => $self->_msg( 'Not attending (manage)' ),
        $self->RSVP_MAYBE() => $self->_msg( 'Maybe (manage)' ),
    );

    my @lines;

    if ( $self->param('domain')->domain_name =~ /work\-dev|onlineitk/ ) {
        @lines =  ( [
            $self->_msg('Last name'),
            $self->_msg('First name'),
            $self->_msg('Organization'),
            $self->_msg('Title'),
            $self->_msg('Email'),
            $self->_msg('Phone'),
            'Osoite', 'Alue', 'Ikä', 'Sukupuoli', 'Koulutustaso',
            $self->_msg('Attending status'),
            $self->_msg('Attend info'),
            $self->_msg('Event name')
        ] );
    }
    else {
        @lines =  ( [
            $self->_msg('Last name'),
            $self->_msg('First name'),
            $self->_msg('Organization'),
            $self->_msg('Title'),
            $self->_msg('Email'),
            $self->_msg('Phone'),
            $self->_msg('Attending status'),
            $self->_msg('Attend info'),
            $self->_msg('Event name')
        ] );
    }

    for my $info ( @$infos ) {
        my @line = map { $info->{$_} } qw( last_name first_name organization organization_title private_email phone );

        if ( $self->param('domain')->domain_name =~ /work\-dev|onlineitk/ ) {
            my $itkdata = eval { Dicole::Utils::JSON->decode( $info->{attend_info} || {} ) };
            $itkdata = { itk_info => $info->{attend_info} } if $@;
            push @line, map { $itkdata->{ $_ } } ( qw( itk_address itk_area itk_age itk_gender itk_education ) );
            push @line, ( $trans{ $info->{rsvp_state} }, $itkdata->{itk_info}, $event->title );
        }
        else {
            push @line, ( $trans{ $info->{rsvp_state} }, $info->{attend_info}, $event->title );    
        }
        push @lines, \@line;
    }

    return \@lines
}

sub _filtered_export_filename {
    my ( $self, $extension ) = @_;
    my $dt = Dicole::Utils::Date->epoch_to_datetime;
    return join( "_", ( 'filtered', 'export', $dt->year, $dt->month, $dt->day, $dt->hour, $dt->minute, $dt->second ) ) . '.' . $extension;
}


1;
