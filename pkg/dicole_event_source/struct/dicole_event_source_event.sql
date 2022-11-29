CREATE TABLE IF NOT EXISTS dicole_event_source_event (
  event_id      %%INCREMENT%%,

  version       int unsigned not null,
  author        int unsigned not null,
  user_id       int unsigned not null,
  group_id      int unsigned not null,
  domain_id     int unsigned not null,
  timestamp     bigint unsigned not null,
  updated	bigint unsigned not null,
  coordinates   text,
  event_type    text,
  classes       text,
  tags          text,
  interested    text,
  topics        text,
  payload       text,
  secure        text,

  unique    ( event_id ),
  primary key   ( event_id ),
  key ( updated )
)
