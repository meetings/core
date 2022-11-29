
CREATE TABLE IF NOT EXISTS dicole_domain_group (
  domain_group_id        %%INCREMENT%%,
  group_id 		int unsigned not null,
  domain_id             int unsigned not null,
  unique		( domain_group_id ),
  primary key           ( domain_group_id )
)
