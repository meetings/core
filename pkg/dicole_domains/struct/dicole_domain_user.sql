CREATE TABLE IF NOT EXISTS dicole_domain_user (
  domain_user_id        %%INCREMENT%%,
  user_id 		int unsigned not null,
  domain_id             int unsigned not null,
  unique		( domain_user_id ),
  primary key           ( domain_user_id )
)
