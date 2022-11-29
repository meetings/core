package OpenInteract2::SQLInstall::DicoleMeetings;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_meetings_agent_object_log.sql',
                         'dicole_meetings_agent_object_state.sql',
                         'dicole_meetings_appdirect_notification.sql',
                         'dicole_meetings_aps_command.sql',
                         'dicole_meetings_beta_signup.sql',
                         'dicole_meetings_company_subscription.sql',
                         'dicole_meetings_company_subscription_user.sql',
                         'dicole_meetings_date_proposal.sql',
                         'dicole_meetings_dispatched_email.sql',
                         'dicole_meetings_draft_participant.sql',
                         'dicole_meetings_matchmaker_lock.sql',
                         'dicole_meetings_matchmaker.sql',
                         'dicole_meetings_matchmaker_url.sql',
                         'dicole_meetings_matchmaking_event.sql',
                         'dicole_meetings_matchmaking_location.sql',
                         'dicole_meetings_meeting_suggestion.sql',
                         'dicole_meetings_partner.sql',
                         'dicole_meetings_paypal_transaction.sql',
                         'dicole_meetings_pending_trail.sql',
                         'dicole_meetings_pin.sql',
                         'dicole_meetings_promotion_code.sql',
                         'dicole_meetings_promotion.sql',
                         'dicole_meetings_push_device.sql',
                         'dicole_meetings_quickmeet.sql',
                         'dicole_meetings_scheduling_answer.sql',
                         'dicole_meetings_scheduling_log_entry.sql',
                         'dicole_meetings_scheduling_option.sql',
                         'dicole_meetings_scheduling.sql',
                         'dicole_meetings_shortened_url.sql',
                         'dicole_meetings_stripe_event.sql',
                         'dicole_meetings_subscription.sql',
                         'dicole_meetings_suggestion_source.sql',
                         'dicole_meetings_trial.sql',
                         'dicole_meetings_user_activity.sql',
                         'dicole_meetings_user_contact_log.sql',
                         'dicole_meetings_user_email.sql',
                         'dicole_meetings_user_notification.sql',
                         'dicole_meetings_user_service_account.sql'
                       ]
);

sub get_structure_set {
    return [
          'meetings_user_email',
          'meetings_dispatched_email',
          'meetings_beta_signup',
          'meetings_date_proposal',
          'meetings_paypal_transaction',
          'meetings_trial',
          'meetings_subscription',
          'meetings_partner',
          'meetings_promotion_code',
          'meetings_promotion',
          'meetings_user_service_account',
          'meetings_draft_participant',
          'meetings_matchmaker',
          'meetings_matchmaking_event',
          'meetings_matchmaker_lock',
          'meetings_matchmaking_location',
          'meetings_meeting_suggestion',
          'meetings_pending_trail',
          'meetings_pin',
          'meetings_matchmaker_url',
          'meetings_suggestion_source',
          'meetings_company_subscription_user',
          'meetings_company_subscription',
          'meetings_appdirect_notification',
          'meetings_aps_command',
          'meetings_user_notification',
          'meetings_quickmeet',
          'meetings_user_activity',
          'meetings_stripe_event',
          'meetings_scheduling',
          'meetings_scheduling_option',
          'meetings_scheduling_answer',
          'meetings_shortened_url',
          'meetings_scheduling_log_entry',
          'meetings_user_contact_log',
          'meetings_push_device',
          'meetings_agent_object_state',
          'meetings_agent_object_log'
    ];
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{sqlite} if ( $type eq 'SQLite' );
    return $FILES{default};
}

sub get_data_file {
    return [

    ];
}

1;
