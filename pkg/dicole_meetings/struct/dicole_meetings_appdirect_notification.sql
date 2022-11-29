CREATE TABLE IF NOT EXISTS dicole_meetings_appdirect_notification (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,

  created_date    bigint unsigned not null,

  payload         text,
  event_url       text,

  unique          ( id ),
  primary key     ( id )
)
