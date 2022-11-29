package Dicole::Controller::Popup;

# $Id: Popup.pm,v 1.11 2008-08-18 23:29:58 amv Exp $

use strict;
use base qw( OpenInteract2::Controller::MainTemplate Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use Dicole::Security;

my ( $log );

sub init {
    my ( $self ) = @_;

    $self->SUPER::init;

    Dicole::Security->init;
}

sub execute {
    my ( $self ) = @_;

    return unless $self->common_check_firewall;

    $self->common_set_language;

    return if $self->common_default_task_redirect;

    $self->common_register_activity;

    $self->common_set_last_active_group;
    $self->common_register_group_visit;

    my $r = $self->SUPER::execute;

    $self->clean_used_htmltrees;

    return $r;
}

sub _action_error_content {
    my $self = shift @_;
    return $self->common_action_error_content( @_ );
}

## a hack before themes

sub main_template {

    return 'dicole_base::base_popup';
}

1;
