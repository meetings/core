CREATE TABLE dicole_forums_versions (
 version_id             %%INCREMENT%%,
 forum_id               int unsigned not null,
 thread_id              int unsigned not null,
 metadata_id            int unsigned default 0,
 groups_id              int unsigned not null,
 user_id                int unsigned not null,
 parent_id              int unsigned default 0,
 msg_id                 int unsigned default 0,
 date                   bigint unsigned not null,
 title                  text,
 unique                 ( version_id ),
 primary key            ( version_id )
)
