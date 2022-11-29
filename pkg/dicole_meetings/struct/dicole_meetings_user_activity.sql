CREATE TABLE IF NOT EXISTS dicole_meetings_user_activity (
  id              %%INCREMENT%%,
  stamp           char(40) not null,
  user_id         int unsigned not null,
  floored_date    bigint unsigned not null,
  unmanned        tinyint not null,

  user_agent      text,
  app_version     tinytext,
  ip              tinytext,

  country         tinytext,
  device          tinytext,

  unique          ( id ),
  primary key     ( id ),
  key             ( user_id ),
  key             ( stamp(8) ),
  key             ( floored_date )
)
