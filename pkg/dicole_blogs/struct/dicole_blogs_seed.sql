CREATE TABLE IF NOT EXISTS dicole_blogs_seed (
  seed_id       %%INCREMENT%%,
  group_id      int unsigned not null,
  active_date   bigint unsigned not null,
  promoted_date bigint unsigned not null,
  closed_date   bigint unsigned not null,
  opened_date   bigint unsigned not null,
  creator_id    int unsigned not null,
  title         text,
  description   text,
  image         text,
  enable_promoting  int,
  enable_rating     int,
  post_count        int,
  seed_closed       int,
  exclude_from_digest  int,
  exclude_from_summary int,
  closing_comment   text,
  override_creator  text,
  
  unique    ( seed_id ),
  primary key   ( seed_id ),
  key       ( group_id, active_date, promoted_date, closed_date )
)
