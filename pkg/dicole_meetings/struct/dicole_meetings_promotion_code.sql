CREATE TABLE IF NOT EXISTS dicole_meetings_promotion_code (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  promotion_id    int unsigned not null,
  creator_id      int unsigned not null,
  creation_date   bigint unsigned not null,

  consumed_date   bigint unsigned not null,
  consumer_id     int unsigned not null,

  promotion_code  text,

  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( promotion_code(16) )
)
