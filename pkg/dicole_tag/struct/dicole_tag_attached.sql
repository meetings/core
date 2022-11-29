CREATE TABLE IF NOT EXISTS dicole_tag_attached (
  attach_id		%%INCREMENT%%,
  object_id		int unsigned not null,
  tag_id		int unsigned not null,
  domain_id             int unsigned not null default 0,
  attached_date         bigint unsigned not null default 0,
  object_type		TINYTEXT,
  key			( attach_id )
)
