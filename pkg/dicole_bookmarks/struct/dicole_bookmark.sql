CREATE TABLE IF NOT EXISTS dicole_bookmark (
  id	         	%%INCREMENT%%,
  domain_id             int unsigned not null,
  group_id              int unsigned not null,
  creator_id		int unsigned not null,
  created_date          bigint unsigned not null default 0,
  object_id		int unsigned not null,
  object_type		TINYTEXT,
  unique                ( id ),
  key			( id ),
  key			( domain_id, group_id, creator_id ),
  key			( domain_id, group_id, object_id, object_type(40) )
)
