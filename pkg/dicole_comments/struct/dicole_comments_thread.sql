CREATE TABLE IF NOT EXISTS dicole_comments_thread (
  thread_id %%INCREMENT%%,
  user_id	int unsigned not null,
  group_id	int unsigned not null,
  object_id int unsigned not null,
  object_type tinytext,
  unique	( thread_id ),
  primary key	( thread_id )
)
