CREATE TABLE IF NOT EXISTS dicole_meetings_stripe_event (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,

  stored_date     bigint unsigned not null,
  created_date    bigint unsigned not null,
  event_id        varchar(40),

  payload         text,

  unique          ( id ),
  primary key     ( id ),
  key             ( event_id(20) )
)
