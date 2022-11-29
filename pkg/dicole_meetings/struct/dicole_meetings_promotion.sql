CREATE TABLE IF NOT EXISTS dicole_meetings_promotion (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,
  creator_id      int unsigned not null,

  creation_date   bigint unsigned not null,
  start_date      bigint unsigned not null,
  end_date        bigint unsigned not null,

  duration        int unsigned not null,
  duration_unit   text,

  dollar_price    text,

  promotion_name  text,
  promotion_code  text,

  notes           text,

  unique          ( id ),
  primary key     ( id ),
  key             ( promotion_code(16) )
)
