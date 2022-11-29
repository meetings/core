CREATE TABLE IF NOT EXISTS dicole_blogs_promotion (
  vote_id	%%INCREMENT%%,
  group_id  int unsigned not null,
  entry_id   int unsigned not null,
  user_id	int unsigned not null,
  date      bigint unsigned not null,
  points    int not null,
  unique	( vote_id ),
  primary key	( vote_id ),
  key ( entry_id, user_id )
)
