CREATE TABLE IF NOT EXISTS dicole_meetings_subscription (
  id                %%INCREMENT%%,
  domain_id         int unsigned not null,
  user_id           int unsigned not null,
  subscription_id   varchar(20) not null,

  subscription_date bigint unsigned not null,

  notes             text,

  unique            ( id ),
  primary key       ( id ),
  key               ( user_id ),
  unique            ( subscription_id )
)
