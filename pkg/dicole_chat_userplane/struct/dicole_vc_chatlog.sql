CREATE TABLE IF NOT EXISTS dicole_vc_chatlog (
  entry_id 		%%INCREMENT%%,
  room_id		int unsigned,
  timestamp		varchar(16),
  content		text,
  type			varchar(16),
  userID		varchar(255),
  invisible		int unsigned,
  displayName		varchar(255),
  unique		( entry_id ),
  primary key           ( entry_id )
)
