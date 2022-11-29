CREATE TABLE IF NOT EXISTS dicole_meetings_aps_command (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,

  created_date    bigint unsigned not null,

  command_type    text,
  payload         text,

  unique          ( id ),
  primary key     ( id )
)
