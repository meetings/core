CREATE TABLE IF NOT EXISTS dicole_attachment (
  attachment_id	%%INCREMENT%%,
  owner_id      int unsigned not null,
  creation_time bigint unsigned not null,
  user_id       int unsigned not null,
  group_id      int unsigned not null,
  domain_id	int unsigned not null,
  object_id     int unsigned not null,
  byte_size	int unsigned not null,
  object_type   TINYTEXT,
  filename      TINYTEXT,
  mime          TINYTEXT,
  unique        ( attachment_id ),
  primary key   ( attachment_id )
)
