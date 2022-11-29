CREATE TABLE IF NOT EXISTS dicole_meetings_meeting_suggestion (
  id                %%INCREMENT%%,
  domain_id         int unsigned not null,
  user_id           int unsigned not null,
  created_date      bigint unsigned not null,
  disabled_date     bigint unsigned not null,
  vanished_date     bigint unsigned not null,
  removed_date      bigint unsigned not null,
  begin_date        bigint unsigned not null,
  end_date          bigint unsigned not null,
  uid               text,
  title             text,
  location          text,
  description       text,
  participant_list  text,
  organizer         text,
  source            text,
  notes             text,

  unique            ( id ),
  primary key       ( id ),
  key               ( user_id, begin_date )
)
