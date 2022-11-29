CREATE TABLE IF NOT EXISTS dicole_meetings_shortened_url (
  id              %%INCREMENT%%,
  creator_id      int unsigned not null,
  created_date    bigint unsigned not null,
  removed_date    bigint unsigned not null,

  code            varchar(16),

  url             text,
  notes           mediumtext,

  unique          ( id ),
  primary key     ( id ),
  key             ( code )
)
