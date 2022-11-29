CREATE TABLE IF NOT EXISTS dicole_blogs_draft_entry (
  entry_id      %%INCREMENT%%,
  group_id      int unsigned not null,
  seed_id       int unsigned not null default 0,
  user_id       int unsigned not null,
  title         text,
  content       text,
  unique        ( entry_id ),
  primary key   ( entry_id ),
  key           ( group_id, user_id )
)
