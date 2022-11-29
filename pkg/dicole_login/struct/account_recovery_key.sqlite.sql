CREATE TABLE account_recovery_key (
  key_id        %%INCREMENT%%,
  user_id       int unsigned not null,
  recovery_key  varchar(48) not null,
  timestamp     int unsigned not null,
  used		int unsigned not null,
  primary key   (key_id)
)

