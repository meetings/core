CREATE TABLE IF NOT EXISTS dicole_meetings_scheduling_log_entry (
  id             %%INCREMENT%%,
  domain_id      int unsigned not null,
  meeting_id     int unsigned not null,
  scheduling_id  int unsigned not null,
  author_id      int unsigned not null,
  created_date   bigint unsigned not null,
  entry_date     bigint unsigned not null,
  entry_type     tinytext,
  notes          mediumtext,

  unique         ( id ),
  primary key    ( id ),
  key            ( meeting_id, scheduling_id, created_date )
)
