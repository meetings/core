CREATE TABLE IF NOT EXISTS dicole_sessions (
  session_id	%%INCREMENT%%,
  uid           char(32),
  timestamp     bigint unsigned not null,
  payload          mediumtext,
  unique    ( session_id ),
  primary key   ( session_id ),
  key       ( uid ),
  key       ( timestamp )
)
