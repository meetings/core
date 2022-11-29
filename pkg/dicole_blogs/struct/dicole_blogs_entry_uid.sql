CREATE TABLE IF NOT EXISTS dicole_blogs_entry_uid (
  entry_uid_id  %%INCREMENT%%,
  entry_id  int unsigned not null,
  uid       text,
  unique    ( entry_uid_id ),
  primary key   ( entry_uid_id ),
  key           ( entry_id )
)
