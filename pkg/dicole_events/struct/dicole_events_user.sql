CREATE TABLE IF NOT EXISTS dicole_events_user (
  event_user_id  %%INCREMENT%%,
  domain_id      int unsigned not null,
  group_id       int unsigned not null,
  user_id        int unsigned not null,
  event_id       int unsigned not null,
  created_date   bigint unsigned not null,
  removed_date   bigint unsigned not null,
  creator_id     int unsigned not null,
  rsvp_state     int unsigned not null,
  was_invited    int unsigned not null,
  is_planner     int unsigned not null,
  attend_date    bigint unsigned not null,
  attend_info    text,

  notes          text,

  unique         ( event_user_id ),
  primary key    ( event_user_id ),
  key            ( domain_id, event_id, rsvp_state ),
  key            ( domain_id, user_id )
)
