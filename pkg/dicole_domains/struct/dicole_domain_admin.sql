CREATE TABLE IF NOT EXISTS dicole_domain_admin (
  domain_admin_id       %%INCREMENT%%,
  user_id               int unsigned not null,
  domain_id             int unsigned not null,
  unique                ( domain_admin_id ),
  primary key           ( domain_admin_id )
)
