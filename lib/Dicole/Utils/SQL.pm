package Dicole::Utils::SQL;
use strict;

use OpenInteract2::Context   qw( CTX );
use DBI                      qw( :sql_types );
use SPOPS::SQLInterface;

sub column_in_strings {
    my ( $class, $column, $array ) = @_;
    my $quoted = $class->quoted_string_array( $array );

    return $quoted ? "$column IN $quoted" : '1=0';
}

sub column_not_in_strings {
    my ( $class, $column, $array ) = @_;
    my $quoted = $class->quoted_string_array( $array );

    return $quoted ? "$column NOT IN $quoted" : '1=1';
}

sub column_in {
    my ( $class, $column, $array ) = @_;
    my $quoted = $class->quoted_array( $array );

    return $quoted ? "$column IN $quoted" : '1=0';
}

sub column_not_in {
    my ( $class, $column, $array ) = @_;
    my $quoted = $class->quoted_array( $array );

    return $quoted ? "$column NOT IN $quoted" : '1=1';
}

sub quoted_string_array {
    my ( $class, $array ) = @_;
    return undef unless ref $array eq 'ARRAY' && scalar( @$array );
    my $dbh = CTX->datasource( CTX->lookup_system_datasource_name );
    my @escaped = ();

    for my $value ( @$array ) {
        push @escaped, $class->quoted_string( $value, $dbh );
    }

    return '(' . join(',', @escaped) . ')';
}

sub quoted_string {
    my ( $class, $string, $dbh ) = @_;

    $dbh ||= CTX->datasource( CTX->lookup_system_datasource_name );

    return $dbh->quote( $string, SQL_VARCHAR );
}

sub quoted_array {
    my ( $class, $array ) = @_;
    return undef unless ref $array eq 'ARRAY' && scalar( @$array );

    return '(' . join(',', @$array) . ')';
}

sub sth { shift->_sqlinterface_select( 'sth', @_ ) }

sub hashes { shift->_sqlinterface_select( 'hash', @_ ) || [] }

sub arrays { shift->_sqlinterface_select( 'list', @_ ) || [] }

sub _sqlinterface_select {
    my ( $class, $return, %params ) = @_;
    $params{db} ||= $class->datasource;

    return SPOPS::SQLInterface->db_select({
            return => $return,
            %params,
    });
}

sub datasource {
    my ( $class, $key ) = @_;
    return CTX->datasource( $key || CTX->lookup_system_datasource_name );
}

sub execute_sql {
    my ( $class, $sql, $values, $key ) = @_;
    $values ||= [];
    my $db = $class->datasource( $key );
    # let these die
    my $sth = $db->prepare( $sql );
    $sth->execute( @$values );
    return $sth;
}

1;