CREATE TABLE IF NOT EXISTS dicole_vc_rooms (
  room_id 		%%INCREMENT%%,
  room_name		varchar(255) default null,
  group_id		int unsigned not null,
  enabled		int unsigned,
  unique		( room_id ),
  primary key           ( room_id )
)

