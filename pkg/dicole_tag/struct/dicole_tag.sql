CREATE TABLE IF NOT EXISTS dicole_tag (
  tag_id	%%INCREMENT%%,
  user_id	int unsigned not null,
  group_id	int unsigned not null,
  domain_id     int unsigned not null default 0,
  count     int unsigned not null,
  suggested int unsigned not null,
  tag		TINYTEXT,
  unique	( tag_id ),
  primary key	( tag_id )
)
