CREATE TABLE IF NOT EXISTS dicole_vc_presence (
  presence_id 		%%INCREMENT%%,
  room_id		int unsigned not null,
  user_id		int unsigned not null,
  timestamp		int unsigned,
  in_room		tinyint unsigned default null,
  unique		( presence_id ),
  primary key           ( presence_id )
)
