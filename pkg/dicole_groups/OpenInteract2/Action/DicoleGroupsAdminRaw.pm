package OpenInteract2::Action::DicoleGroupsAdminRaw;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );

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

sub _export_users_data {
    my ( $self, $extension ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group = CTX->lookup_object('groups')->fetch( $gid );

    unless ( $self->param('filename') ) {
        $self->redirect( $self->derive_url(
            additional => [
                $self->_filtered_export_filename( $extension ),
            ],
       ) );
    }

#    die "security error" unless $self->_current_user_can_manage_event( $event );

    my $users = $self->_fetch_group_users( $gid );

    my $profile_map = CTX->lookup_action('networking_api')->e( user_profile_object_map => { 
        user_id_list => [ map { $_->id } @$users ],
        domain_id => $domain_id,
    } );

    my $user_coll_map = $self->_user_special_rights_hash_for_group( $gid );
    my $admin_coll = $self->_admin_collection_id;
    my $mode_coll = $self->_moderator_collection_id;

    my $user_hashes = [];
    for my $user ( sort { lc( $a->{last_name} ) cmp lc( $b->{last_name} ) } @$users ) {

        my $level = $self->_determine_user_level_in_group(
            $user->id, $gid, $user_coll_map, $mode_coll, $admin_coll
        );

        push @$user_hashes, {
            last_name => $user->last_name,
            first_name => $user->first_name,
            private_email => $user->email,
            level => $self->USER_LEVEL_NAMES->{$level},
        };
    }

    my @lines = ( [
        $self->_msg('Last name'),
        $self->_msg('First name'),
        $self->_msg('Email'),
        $self->_msg('User level')
    ] );

    for my $info ( @$user_hashes ) {
        my @line = map { $info->{$_} } qw( last_name first_name private_email level );
        push @lines, \@line;
    }

    return \@lines
}

sub _filtered_export_filename {
    my ( $self, $extension ) = @_;
    my $dt = Dicole::Utils::Date->epoch_to_datetime;
    return join( "_", ( 'user', 'export', $dt->year, $dt->month, $dt->day, $dt->hour, $dt->minute, $dt->second ) ) . '.' . $extension;
}


1;

__END__
