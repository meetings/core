CREATE TABLE IF NOT EXISTS dicole_meetings_company_subscription_user (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,
  subscription_id int unsigned not null,

  user_id         int unsigned not null,
  creator_id      int unsigned not null,
  remover_id      int unsigned not null,

  created_date    bigint unsigned not null,
  removed_date    bigint unsigned not null,
  verified_date   bigint unsigned not null,
  is_admin        tinyint unsigned not null,

  external_user_id  text,
  notes             text,

  unique          ( id ),
  primary key     ( id ),
  key             ( user_id ),
  key             ( subscription_id ),
  key             ( external_user_id(15) )
)


