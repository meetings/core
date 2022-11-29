package Dicole::Localization;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use Encode qw(is_utf8);

my %CUSTOM_LEXICONS = (
    last_refresh => 0,
    last_object_date => 0,
    lexicons => {},
);

sub get_custom_localization {
    my ( $class, $lh, $namespace_key, $namespace_area, $key, @args ) = @_;

    my $custom_value = $class->get_custom_localization_template( $lh, $namespace_key, $namespace_area, $key );

    unless ($custom_value) {
        my $translated = $lh->maketext( $key, @args );

        get_logger(LOG_APP)->debug("Maketext: " . join(" ", map { join "/", $_ => is_utf8($_) } $key, @args));
        get_logger(LOG_APP)->debug("Maketext translated: " . (is_utf8($translated) ? "HAUHAU" : "NYYH"));

        return $translated;
    }

    return $class->evaluate_template( $lh, $custom_value, @args );
}

sub get_custom_localization_template {
    my ( $class, $lh, $namespace_key, $namespace_area, $key ) = @_;

    $namespace_area ||= 0;
    $namespace_key ||= 0;

    if ( $lh && $namespace_key ) {
        $class->_refresh_custom_lexicons;
        if ( $CUSTOM_LEXICONS{lexicons}{$namespace_key} ) {
            my $lang = $lh->get_oi2_lang;
            return $CUSTOM_LEXICONS{lexicons}{$namespace_key}{$namespace_area}{$lang}{$key}
                || $CUSTOM_LEXICONS{lexicons}{$namespace_key}{0}{$lang}{$key}
                || $CUSTOM_LEXICONS{lexicons}{$namespace_key}{$namespace_area}{all}{$key}
                || $CUSTOM_LEXICONS{lexicons}{$namespace_key}{0}{all}{$key};
        }
    }

    return undef;
}

sub evaluate_template {
    my ( $class, $lh, $custom_value, @args ) = @_;

    my $value = eval { $lh->_compile( $custom_value ) };
    if ( $@ ) {
        die "malformed Maketext template: \"$custom_value\". Did you forget to escape one of [],~ with ~ if it isn't part of a substitution variable?";
    }
    return $$value if ref($value) eq 'SCALAR';
    {
        local $SIG{'__DIE__'};
        eval { $value = &$value($lh, @args) };
    }
    return $value unless $@;

    get_logger(LOG_APP)->error("Error evaluating custom translation [$namespace_key:$namespace_area:$lang] key: $key.. Reason: $@");

    return '';
}

sub _refresh_custom_lexicons {
    my ( $class ) = @_;

    return if $CUSTOM_LEXICONS{last_refresh} + 60 > time;
    $CUSTOM_LEXICONS{last_refresh} = time;

    my $objects = CTX->lookup_object('custom_localization')->fetch_group( {
        order => 'creation_date DESC',
        limit => 1,
    } );

    my $object = pop @$objects;
    return if ! $object || $object->creation_date == $CUSTOM_LEXICONS{last_object_date};

    my $all = CTX->lookup_object('custom_localization')->fetch_group({
        order => 'creation_date ASC',
    }) || [];
    $CUSTOM_LEXICONS{lexicons} = {};
    for my $a ( @$all ) {
        $CUSTOM_LEXICONS{lexicons}{ $a->namespace_key }{ $a->namespace_area }{ $a->namespace_lang || 'all' }{ $a->localization_key } = $a->localization_value;
        $CUSTOM_LEXICONS{last_object_date} = $a->creation_date if $CUSTOM_LEXICONS{last_object_date} < $a->creation_date;
    }
}


1;

