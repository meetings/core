CREATE TABLE IF NOT EXISTS dicole_meetings_user_contact_log (
  id             %%INCREMENT%%,
  domain_id      int unsigned not null,
  user_id        int unsigned not null,
  meeting_id     int unsigned not null,
  scheduling_id  int unsigned not null,
  created_date   bigint unsigned not null,
  success_date   bigint unsigned not null,
  contact_method tinytext,
  contact_type   tinytext,
  snippet        text,
  contact_destination text,
  contact_origin text,
  notes          mediumtext,

  unique         ( id ),
  primary key    ( id ),
  key            ( user_id, created_date ),
  key            ( scheduling_id, created_date ),
  key            ( meeting_id, created_date )
)
