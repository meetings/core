CREATE TABLE IF NOT EXISTS dicole_meetings_pin (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  user_id         int unsigned not null,

  creation_date   bigint unsigned not null,
  disabled_date   bigint unsigned not null,
  used_date       bigint unsigned not null,

  pin             text,
  creator_ip      text,
  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( user_id ),
  key             ( creation_date ),
  key             ( creator_ip(15) )
)
