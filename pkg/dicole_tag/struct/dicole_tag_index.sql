CREATE TABLE IF NOT EXISTS dicole_tag_index (
  index_id	%%INCREMENT%%,
  user_id	int unsigned not null,
  group_id	int unsigned not null,
  domain_id     int unsigned not null default 0,
  object_id int unsigned not null,
  object_type tinytext,
  tags      text,
  unique	( index_id ),
  primary key	( index_id )
)
