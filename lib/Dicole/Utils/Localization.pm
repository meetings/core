package Dicole::Utils::Localization;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::I18N;
use Dicole::Localization;

use Locale::gettext_dumb qw(:locale_h :libintl_h);
use POSIX qw' setlocale ';

my %tds = ();

sub email_ntranslate {
    my ( $self, $template_vars, $key, $plural_key, $args, $in_opts ) = @_;

    return $self->ntranslate( $template_vars->{I18N_CONFIG}, $key, $plural_key, $args, $in_opts, { in_text => $template_vars->{in_text} } );
}

sub ntranslate {
    my ( $self, $conf, $key, $plural_key, $args, $in_opts, $opts_override ) = @_;

    $conf ||= {};

    my @shiftable_params = ( $plural_key, $args, $in_opts );
    my $opts = $self->_default_ntranslate_opts;

    if ( $shiftable_params[2] || ( $shiftable_params[0] && ! ref( $shiftable_params[0] ) ) ) {
        $opts->{plural_key} = shift( @shiftable_params ) || '';
    }
    if ( $shiftable_params[1] || ( $shiftable_params[0] && ref( $shiftable_params[0] ) eq 'ARRAY' ) ) {
        $opts->{params} = shift( @shiftable_params ) || [];
    }
    if ( $shiftable_params[0] ) {
        $opts = { %$opts, %{ $shiftable_params[0] } };
    }

    $opts = { %$opts, %{ $opts_override || {} } };

    my $lang = $conf->{lang};

    if ( ! $lang ) {
        my $user = $conf->{user} || $conf->{user_id};
        if ( $user ) {
            $user = Dicole::Utils::User->ensure_object( $user );
            $lang = $user->language;
        }
    }

    if ( ! $lang && CTX->{current_job_language} ) {
        $lang = CTX->{current_job_language};
    }

    if ( ! $lang ) {
        my $action = $conf->{action} || eval{ CTX->controller->initial_action };

        $lang = eval {
            return $action ? $action->{current_job_language} || $action->language : undef;
        };
    }
    $lang ||= 'en';

    # NOTE: some country code is needed for gettext to work so we consistently use this XX
    $lang .= '_XX';

    # NOTE: This is pretty much the same logic as Locale::Simple has.. I hope it works ;)
    unless (defined $tds{desktop_back}) {
        bindtextdomain( 'desktop_back', CTX->repository->fetch_package( "dicole_meetings" )->directory . '/template/locale' );
        bind_textdomain_codeset( 'desktop_back', 'utf-8');
        $tds{desktop_back} = 1;
    }
    textdomain( 'desktop_back' );

    my $oldlocale = eval{ LC_MESSAGES } ? setlocale( LC_MESSAGES ) : undef;
    my %oldenv = ();
    for my $ev ( qw( LANGUAGE LANG LC_ALL LC_MESSAGES ) ) {
        $oldenv{ $ev } = $ENV{ $ev };
        $ENV{ $ev } = $lang;
    }
    setlocale( LC_MESSAGES, $lang ) if eval { LC_MESSAGES };

    utf8::encode($key);
    my $template = $opts->{plural_key} ?
        dnpgettext('desktop_back', undef, $key, $opts->{plural_key}, $opts->{plural}) :
        dnpgettext('desktop_back', undef, $key, undef, undef );
    utf8::decode($key);

    for my $ev ( qw( LANGUAGE LANG LC_ALL LC_MESSAGES ) ) {
        $ENV{ $ev } = $oldenv{ $ev };
    }
    setlocale( LC_MESSAGES, $oldlocale ) if eval { LC_MESSAGES };

    $template =~ s/\s*\/\/context\:.*//;

    # Ensure that this is proper format for dcp
    $template = Dicole::Utils::Text->ensure_utf8( $template );

    $template = $self->_execute_sprintf_functions( $template, $opts );

    if ( $opts->{params} ) {
        return sprintf( $template, @{ $opts->{params} } );
    }
    else {
        return $template;
    }
}

sub _default_ntranslate_opts {
    my ( $self ) = @_;
    return {
        params => [],
        default_functions => $self->_default_ntranslate_functions,
    };
}

my $opts_func_cache;
sub _default_ntranslate_functions {
    my ( $self ) = @_;
    return $opts_func_cache ||= {
        B => $self->_create_tag_default_function( 'b' ),
        I => $self->_create_tag_default_function( 'i' ),
        L => $self->_create_tag_default_function( 'a', [ 'href' ] ),
        N => sub { my ( $content, $p ) = @_; return $content; },
        TL => sub { my ( $content, $p ) = @_; return $content . ': ' . $p->{href}; },
    };
}

sub _create_tag_default_function {
    my ( $self, $tag, $extra_attr_list ) = @_;

    return sub {
         my ( $content, $p ) = @_;
         return $content if $p->{in_text};
         my $start = $tag;
         for my $attr ( qw( id class style ), @{ $extra_attr_list || [] } ) {
            if ( $p->{ $attr } ) {
                $start .= ' ' . $attr . '="'. $p->{ $attr } .'"';
            }
         }
         for my $attr ( keys %{ $p->{ attributes } || {} } ) {
            if ( $p->{ attributes }->{ $attr } ) {
                $start .= ' ' . $attr . '="'. $p->{ attributes }->{ $attr } .'"';
            }
         }
         return '<' . $start . '>' . $content . '</'. $tag .'>'
    };
}

sub _execute_sprintf_functions {
    my ( $self, $template, $opts ) = @_;

    my @total = ();
    my ( $current, $rest ) = $self->_execute_next_sprintf_function( $template, $opts );
    my @all = ( $current );
    while ( $rest ) {
        ( $current, $rest ) = $self->_execute_next_sprintf_function( $rest, $opts );
        push @all, $current;
    }

    return join "", @all;
}

sub _execute_next_sprintf_function {
    my ( $self, $template, $opts ) = @_;

    my ( $start, $delim, $rest ) = $template =~ /^((?:\%.|[^\%])*?)(\%\([^\$]+\$)(.*)$/;

    if ( $delim ) {
        my ( $func ) = $delim =~ /^..(.*).$/;
        my ( $content, $end ) = $self->_find_function_end_and_return_execution_results_along_with_remainder( $rest, $opts, $func );
        return ( $start . $content, $end );
    }
    return $template;
}

sub _find_function_end_and_return_execution_results_along_with_remainder {
    my ( $self, $string, $opts, $func, $processed_start ) = @_;

    $processed_start ||= '';

    my ( $start, $delim, $rest ) = $string =~ /^((?:\%.|[^\%])*?)(\%\([^\$]+\$|\%\))(.*)$/;
    if ( $delim ) {
        if ( $delim eq '%)' ) {
            my $content = '';
            if ( ref( $opts->{ $func } ) eq 'CODE' ) {
                $content = $opts->{ $func }->( $processed_start . $start );
            }
            elsif ( my $use_func = $opts->{ $func }->{ use_default_function } ) {
                if ( $opts->{ default_functions }->{ $use_func } ) {
                    $content = $opts->{ default_functions }->{ $use_func }->( $processed_start . $start, $self->_opts_for_func( $opts, $func ) );
                }
                else {
                    $content = "[[ Syntax error: unknown used default function $use_func ]]";
                }
            }
            elsif ( $opts->{ default_functions }->{ $func } ) {
                $content = $opts->{ default_functions }->{ $func }->( $processed_start . $start, $self->_opts_for_func( $opts, $func ) );
            }
            else {
                $content = "[[ Syntax error: unknown function $func ]]";
            }

            return ( $content, $rest );
        }
        else {
            my ( $inner_func ) = $delim =~ /^..(.*).$/;
            my ( $inner_content, $inner_end ) = $self->_find_function_end_and_return_execution_results_along_with_remainder( $rest, $opts, $inner_func );
            return $self->_find_function_end_and_return_execution_results_along_with_remainder( $inner_end, $opts, $func, $processed_start . $start . $inner_content );
        }
    }
    else {
        return "[[ Syntax error: missing function end delimiter ]]"
    }
}

sub _opts_for_func {
    my ( $self, $opts, $func ) = @_;

    my $o = $opts->{ $func } || {};
    $o->{in_text} = $opts->{in_text} ? 1 : 0;

    return $o;
}

sub translate {
    my ( $self, $conf, $key, @args ) = @_;
    $conf ||= {};

    my $domain = eval { Dicole::Utils::Domain->guess_current( $conf->{domain_id}, $conf->{action}, 1 ); };
    my $action = $conf->{action} || eval{ CTX->controller->initial_action };

    my $partner = $action ? $action->param('partner') : undef;
    if ( my $pid = $conf->{partner_id} ) {
        $partner = eval { CTX->lookup_action('meetings_api')->e( get_partner_for_id => { id => $pid } ) };
    }

    my $lh = $conf->{language_handle};
    $lh ||= OpenInteract2::I18N->get_handle( $conf->{lang} ) if $conf->{lang};
    $lh ||= $conf->{action}->language_handle if $conf->{action};
    $lh ||= eval{ CTX->controller->initial_action->language_handle };
    $lh ||= OpenInteract2::I18N->get_handle( $domain ? $domain->default_language || 'en' : 'en' );

    my $group_id = $conf->{group_id};
    $group_id = $conf->{action}->param('group_id') if $conf->{action} && ! defined( $group_id );
    $group_id = $conf->{action}->param('target_group_id') if $conf->{action} && ! defined( $group_id );
    $group_id = eval{ CTX->controller->initial_action->param('group_id') } if ! defined( $group_id );
    $group_id = eval{ CTX->controller->initial_action->param('target_group_id') } if ! defined( $group_id );
    $group_id = 0 if ! defined( $group_id );

    my $localization_namespace = $partner ? $partner->localization_namespace : '';
    $localization_namespace ||= ref( $domain ) ? $domain->localization_namespace : '';

    if ( $localization_namespace ) {
        return Dicole::Localization->get_custom_localization(
            $lh, $localization_namespace, $group_id, $key, @args
        ) || Dicole::Localization->evaluate_template( $lh, $key, @args );
    }

    return $lh->maketext( $key, @args ) || Dicole::Localization->evaluate_template( $lh, $key, @args );
}

1;
