CREATE TABLE IF NOT EXISTS dicole_meetings_company_subscription (
  id              %%INCREMENT%%,
  domain_id       int unsigned not null,
  partner_id      int unsigned not null,

  admin_id        int unsigned not null,
  creator_id      int unsigned not null,
  remover_id      int unsigned not null,

  created_date    bigint unsigned not null,
  removed_date    bigint unsigned not null,
  updated_date    bigint unsigned not null,
  cancelled_date  bigint unsigned not null,
  expires_date    bigint unsigned not null,
  is_trial        tinyint unsigned not null,
  is_pro          tinyint unsigned not null,
  user_amount      int unsigned not null,

  external_company_id   text,
  company_name          text,
  notes                 text,

  unique          ( id ),
  primary key     ( id ),
  key             ( external_company_id(15) )
)

