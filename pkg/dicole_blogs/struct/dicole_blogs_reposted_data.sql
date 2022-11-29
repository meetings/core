CREATE TABLE IF NOT EXISTS dicole_blogs_reposted_data (
  reposted_data_id  %%INCREMENT%%,
  domain_id         int unsigned not null,
  reposter_id       int unsigned not null,
  raw_digest        char(40) not null,
  id_digest         char(40) not null,
  tc_digest         char(40) not null,
  posted_as_entry   int unsigned not null,

  unique        ( reposted_data_id ),
  primary key   ( reposted_data_id ),
  key           ( id_digest ),
  key           ( tc_digest ),
  key           ( raw_digest )
)
