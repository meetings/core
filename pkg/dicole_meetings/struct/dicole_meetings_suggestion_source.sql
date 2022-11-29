CREATE TABLE IF NOT EXISTS dicole_meetings_suggestion_source (
  id                %%INCREMENT%%,
  domain_id         int unsigned not null,
  user_id           int unsigned not null,
  created_date      bigint unsigned not null,
  verified_date     bigint unsigned not null,
  vanished_date     bigint unsigned not null,
  uid               text,
  name              text,
  provider_id       text,
  provider_type     text,
  provider_name     text,
  notes             text,

  unique            ( id ),
  primary key       ( id ),
  key               ( user_id, provider_id(16) )
)
