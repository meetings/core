CREATE TABLE IF NOT EXISTS dicole_meetings_draft_participant (
  id       %%INCREMENT%%,
  domain_id      int unsigned not null,
  event_id	 int unsigned not null,
  user_id        int unsigned not null,
  creator_id     int unsigned not null,
  created_date   bigint unsigned not null,
  sent_date      bigint unsigned not null,
  removed_date   bigint unsigned not null,
  notes		 text,

  unique         ( id ),
  primary key    ( id ),
  key		 ( domain_id, event_id )
)
