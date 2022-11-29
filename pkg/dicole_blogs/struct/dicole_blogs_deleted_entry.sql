CREATE TABLE IF NOT EXISTS dicole_blogs_deleted_entry (
  deleted_entry_id	%%INCREMENT%%,
  entry_id int unsigned not null,
  group_id   int unsigned not null,
  seed_id   int unsigned not null,
  post_id   int unsigned not null,
  user_id	int unsigned not null,
  date      bigint unsigned not null,
  last_updated bigint unsigned not null,
  deleted_date bigint unsigned not null,
  unique    ( deleted_entry_id ),
  primary key   ( deleted_entry_id ),
  key       ( group_id, date ),
  key       ( group_id, user_id ),
  key       ( group_id, seed_id, date ),
  key       ( group_id, seed_id, user_id )
)
