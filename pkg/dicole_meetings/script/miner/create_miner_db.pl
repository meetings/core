#!/usr/bin/env perl
my $tables = {
    sys_user => user => (),
    dicole_events_event => meeting => (),
    dicole_events_user => meeting_participant => (),
    dicole_meetings_draft_participant => meeting_draft_participant => (),
    dicole_meetings_matchmaker => matchmaker => (),
    dicole_meetings_matchmaker_url => matchmaker_url => (),
    dicole_meetings_matchmaking_event => matchmaking_event => (),
    dicole_meetings_partner => partner => (),
    dicole_meetings_meeting_suggestion => suggested_meeting => (),
    dicole_meetings_trial => trial => (),
    dicole_meetings_subscription => user_subscription => (),
    dicole_meetings_paypal_transaction => user_subscription_transaction => (),
    dicole_meetings_company_subscription => company_subscription => (),
    dicole_meetings_company_subscription_user => company_subscription_user => (),
    dicole_meetings_user_activity => user_activity => (),
    dicole_meetings_user_contact_log => user_contact_log => (),
    dicole_meetings_scheduling => scheduling => (),
    dicole_meetings_scheduling_answer => scheduling_answer => (),
    dicole_meetings_scheduling_option => scheduling_option => (),
    dicole_meetings_scheduling_log_entry => scheduling_log_entry => (),
};

my $remove_columns = {
  user => [ qw(
    removal_date
    login_disabled
    last_login
    latest_activity
    starting_page
    dicole_theme
    incomplete
    external_auth
    custom_starting_page
  ) ]
};

my $db = $ARGV[0];

die "database parameter missing" unless $db;

system mysql => -e => "UPDATE $db.sys_user set password = '', inv_secret = ''";

system mysql => -e => "DROP DATABASE IF EXISTS miner_data_cloning";
system mysql => -e => "CREATE DATABASE miner_data_cloning";
system mysql => -e => "GRANT ALL ON miner_data_cloning.* TO miner\@'%' IDENTIFIED BY 'miner'";
system mysql => -e => "FLUSH PRIVILEGES";

for my $table ( keys %$tables ) {
    system mysql => -e => "RENAME TABLE $db.$table to miner_data_cloning.$table";
}

system "mysqldump miner_data_cloning | mysql $db";

system mysql => -e => "DROP DATABASE IF EXISTS miner_data";
system mysql => -e => "CREATE DATABASE miner_data";
system mysql => -e => "GRANT ALL ON miner_data.* TO miner\@'%' IDENTIFIED BY 'miner'";
system mysql => -e => "FLUSH PRIVILEGES";

for my $table ( keys %$tables ) {
    system mysql => -e => "RENAME TABLE miner_data_cloning.$table to miner_data." . $tables->{$table};
}

for my $table ( keys %$remove_columns ) {
  for my $column ( @{ $remove_columns->{ $table } } ) {
    system mysql => -e => "ALTER TABLE miner_data.$table drop $column";
  }
}

system mysql => -e => "GRANT ALL ON miner_data.* TO miner\@'%' IDENTIFIED BY 'miner'";
system mysql => -e => "FLUSH PRIVILEGES";
