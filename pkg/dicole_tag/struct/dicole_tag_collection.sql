CREATE TABLE IF NOT EXISTS dicole_tag_collection (
  id		%%INCREMENT%%,
  user_id	int unsigned not null,
  group_id	int unsigned not null,
  domain_id     int unsigned not null,
  created_date  bigint unsigned not null,
  updated_date  bigint unsigned not null,
  title		text,
  tags		text,
  notes		text,
  unique	( id ),
  primary key	( id )
)
