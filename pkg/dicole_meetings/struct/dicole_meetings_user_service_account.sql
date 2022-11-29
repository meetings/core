CREATE TABLE IF NOT EXISTS dicole_meetings_user_service_account (
  id             %%INCREMENT%%,
  domain_id      int unsigned not null,
  user_id        int unsigned not null,
  created_date   bigint unsigned not null,
  verified_date  bigint unsigned not null,
  service_type   text,
  service_uid    text,
  notes          text,

  unique         ( id ),
  primary key    ( id ),
  key		 ( domain_id, user_id ),
  key            ( domain_id, service_type(32), service_uid(32) )
)
