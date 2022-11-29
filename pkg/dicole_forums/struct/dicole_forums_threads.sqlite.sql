CREATE TABLE dicole_forums_threads (
 thread_id              %%INCREMENT%%,
 forum_id               int unsigned not null,
 groups_id              int unsigned not null,
 metadata_id            int unsigned default 0,
 user_id                int unsigned not null,
 readcount              int unsigned default 0,
 rating                 int unsigned default 0,
 num_of_ratings         int unsigned default 0,
 date                   bigint unsigned not null,
 sticky                 tinyint unsigned default 0,
 locked                 tinyint unsigned default 0,
 posts                  int unsigned default 0,
 title                  text,
 type                   varchar(128),
 updated                bigint unsigned not null,
 unique                 ( thread_id ),
 primary key            ( thread_id )
)
