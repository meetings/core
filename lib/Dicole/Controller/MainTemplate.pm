package Dicole::Controller::MainTemplate;

# $Id: MainTemplate.pm,v 1.27 2010-03-14 19:15:34 amv Exp $

use strict;
use base qw( OpenInteract2::Controller::MainTemplate Dicole::Controller::Common Dicole::RuntimeLogger );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use Dicole::Summary;
use Dicole::Utils::JSON;
use CGI::Cookie;

my ( $log );

sub init {
    my ( $self ) = @_;

    $self->rlog( 'Controller default init' );
    $self->SUPER::init;
    $self->rlog;

    $self->common_set_language;

    $self->rlog( 'Controller update_desktop_positions' );
    $self->common_update_desktop_positions;
    $self->rlog;
}

sub execute {
    my ( $self ) = @_;

    $self->rlog('Controller custom execute start');
    return unless $self->common_check_firewall;

    return if $self->common_default_task_redirect;
    return if $self->common_url_version_redirect;

    # this is a bit heavy currently.. maybe cache domain & settings?
    # return if $self->common_forced_actions_redirect;

    $self->rlog('Controller register_activity');
    $self->common_register_activity;
    $self->rlog;

    $self->rlog('Controller set_last_active_group');
    $self->common_set_last_active_group;
    $self->rlog;

    $self->rlog('Controller register_group_visit');
    $self->common_register_group_visit;
    $self->rlog;

    my $r = $self->SUPER::execute;

    eval {
        if (Dicole::Utils::User->is_developer) {
            my $content = CTX->response->content;

            $$content .= '<script type="text/javascript">'
                       . 'var dicoleTrace = ' . eval { Dicole::Utils::JSON->encode(Dicole::Utils::Trace->get_trace) } . ';'
                       . '</script>';

            CTX->response->content($content);
        }
    };

    $self->clean_used_htmltrees;

    return $r;
}

sub _action_error_content {
    my $self = shift @_;
    return $self->common_action_error_content( @_ );
}

## a hack before themes

sub set_main_template {
    my ( $self, $template ) = @_;
    $self->{_main_template} = $template;
}

sub main_template {
    my ( $self ) = @_;
    return $self->{_main_template} || 'dicole_base::base_main';
}

1;
