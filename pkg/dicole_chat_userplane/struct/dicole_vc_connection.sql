CREATE TABLE IF NOT EXISTS dicole_vc_connection (
  connection_id		%%INCREMENT%%,
  user_id		int unsigned not null,
  group_id		int unsigned not null,
  timestamp		varchar(32),
  status		tinyint unsigned not null,
  unique		( connection_id ),
  primary key           ( connection_id )
)
