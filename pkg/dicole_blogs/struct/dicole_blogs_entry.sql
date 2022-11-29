CREATE TABLE IF NOT EXISTS dicole_blogs_entry (
  entry_id	%%INCREMENT%%,
  group_id   int unsigned not null,
  seed_id   int unsigned not null default 0,
  post_id   int unsigned not null,
  user_id	int unsigned not null,
  date      bigint unsigned not null,
  last_updated bigint unsigned not null,
  featured bigint unsigned not null,
  points    int not null,
  rating    int not null,
  close_comments int not null,
  unique    ( entry_id ),
  primary key   ( entry_id ),
  key       ( group_id, date ),
  key       ( group_id, user_id ),
  key       ( group_id, points ),
  key       ( group_id, rating ),
  key       ( group_id, featured ),
  key       ( group_id, seed_id, date ),
  key       ( group_id, seed_id, user_id ),
  key       ( group_id, seed_id, points ),
  key       ( group_id, seed_id, rating ),
  key       ( group_id, seed_id, featured )
)