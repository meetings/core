CREATE TABLE IF NOT EXISTS dicole_meetings_quickmeet (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,
  matchmaker_id   int unsigned not null,
  creator_id      int unsigned not null,
  created_date    bigint unsigned not null,
  updated_date    bigint unsigned not null,
  expires_date    bigint unsigned not null,
  removed_date    bigint unsigned not null,

  url_key         text,

  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( url_key(12) )
)
