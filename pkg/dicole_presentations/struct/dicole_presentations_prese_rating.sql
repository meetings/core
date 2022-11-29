CREATE TABLE IF NOT EXISTS dicole_presentations_prese_rating (
  vote_id       %%INCREMENT%%,
  group_id      int unsigned not null,
  object_id     int unsigned not null,
  user_id       int unsigned not null,
  date          bigint unsigned not null,
  rating        int not null,
  unique        ( vote_id ),
  primary key   ( vote_id ),
  key           ( object_id, user_id )
)
