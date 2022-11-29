CREATE TABLE IF NOT EXISTS dicole_event_source_sync_subscription (
  sub_id        %%INCREMENT%%,

  last_update_date      bigint unsigned not null,
  next_update_date      bigint unsigned not null,
  last_confirmed_event  int unsigned not null,
  gateway               text,
  session_key           text,
  last_update_error     text,
  error_count           int unsigned,

  unique    ( sub_id ),
  primary key   ( sub_id )
)
