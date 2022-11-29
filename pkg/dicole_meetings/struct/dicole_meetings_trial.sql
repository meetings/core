CREATE TABLE IF NOT EXISTS dicole_meetings_trial (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  user_id         int unsigned not null,
  creator_id      int unsigned not null,

  creation_date   bigint unsigned not null,
  start_date      bigint unsigned not null,

  duration_days   int unsigned not null,

  trial_type      text,

  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( user_id ),
  key             ( creator_id )
)
