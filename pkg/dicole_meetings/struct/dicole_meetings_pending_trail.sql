CREATE TABLE IF NOT EXISTS dicole_meetings_pending_trail (
  id                %%INCREMENT%%,
  session_id        text not null,
  user_id           int unsigned not null,
  payload           text,
  service_status    text,

  unique            ( id ),
  primary key       ( id ),
  key               ( session_id(20) ),
  key               ( user_id )
)
