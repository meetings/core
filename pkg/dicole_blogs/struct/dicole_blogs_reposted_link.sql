CREATE TABLE IF NOT EXISTS dicole_blogs_reposted_link (
  link_id       %%INCREMENT%%,
  entry_id      int unsigned not null,
  domain_id     int unsigned not null,
  reposter_id   int unsigned not null,
  reposter_name text,
  original_date bigint unsigned not null,
  original_link text,
  original_name text,
  source_link   text,
  source_name   text,
  show_source   int,

  unique    ( link_id ),
  primary key   ( link_id ),
  key       ( reposter_id ),
  key       ( entry_id )
)
