CREATE TABLE IF NOT EXISTS dicole_meetings_push_device (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  user_id         int unsigned not null,

  created_date    bigint unsigned not null,

  push_address    text,
  stamp           text,
  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( user_id ),
  key             ( stamp(15) ),
  key             ( push_address(15) )
)
