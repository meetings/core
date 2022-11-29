CREATE TABLE IF NOT EXISTS dicole_draft_container (
  container_id	%%INCREMENT%%,
  domain_id     int unsigned not null,
  session_id    text,
  creation_time bigint unsigned not null,
  unique        ( container_id ),
  primary key   ( container_id )
)
