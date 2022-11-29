CREATE TABLE dicole_forums_threads_read (
 read_id                %%INCREMENT%%,
 thread_id              int unsigned not null,
 groups_id              int unsigned not null,
 user_id                int unsigned not null,
 timestamp              bigint unsigned not null,
 unique                 ( read_id ),
 primary key            ( read_id )
)
