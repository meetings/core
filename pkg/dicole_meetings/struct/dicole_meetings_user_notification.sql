CREATE TABLE IF NOT EXISTS dicole_meetings_user_notification (
  id             %%INCREMENT%%,
  domain_id      int unsigned not null,
  user_id        int unsigned not null,
  created_date   bigint unsigned not null,
  removed_date   bigint unsigned not null,
  seen_date      bigint unsigned not null,
  read_date      bigint unsigned not null,
  is_important   tinyint unsigned not null,
  notification_type tinytext,
  notes          mediumtext,

  unique         ( id ),
  primary key    ( id ),
  key            ( domain_id, user_id, created_date ),
  key            ( domain_id, user_id, seen_date, created_date ),
  key            ( domain_id, user_id, is_important, created_date ),
  key            ( domain_id, user_id, notification_type(16), created_date )
)
