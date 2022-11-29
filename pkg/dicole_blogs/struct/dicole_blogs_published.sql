CREATE TABLE IF NOT EXISTS dicole_blogs_published (
  published_id	%%INCREMENT%%,
  post_id   int unsigned not null,
  group_id   int unsigned not null,
  seed_id   int unsigned not null default 0,
  unique	( published_id ),
  primary key	( published_id ),
  key ( group_id, post_id ),
  key ( post_id )
)
