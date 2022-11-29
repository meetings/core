CREATE TABLE IF NOT EXISTS dicole_blogs_reposter (
  reposter_id   %%INCREMENT%%,
  last_update   bigint unsigned not null,
  next_update   bigint unsigned not null,

  domain_id     int unsigned not null,
  user_id       int unsigned not null,
  group_id      int unsigned not null,
  seed_id       int unsigned not null,

  title         text,

  url           text,

  username      text,
  password      text,

  filter_tags   text,
  append_tags   text,
  apply_tags    tinyint unsigned not null,
  append_title  tinyint unsigned not null,

  show_source   tinyint unsigned not null,

  fetch_error   text,
  fetch_delay   int unsigned not null,
  error_count   int unsigned not null,

  max_age       int unsigned not null,

  unique        ( reposter_id ),
  primary key   ( reposter_id ),
  key           ( last_update ),
  key           ( next_update )
)
