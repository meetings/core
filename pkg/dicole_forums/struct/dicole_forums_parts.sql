CREATE TABLE IF NOT EXISTS dicole_forums_parts (
 part_id                 %%INCREMENT%%,
 version_id             int unsigned not null,
 forum_id               int unsigned not null,
 groups_id              int unsigned not null,
 thread_id              int unsigned not null,
 metadata_id            int unsigned default 0,
 user_id                int unsigned not null,
 origin_version_id      int unsigned default 0,
 origin_part_id         int unsigned default 0,
 content                text,
 unique                 ( part_id ),
 primary key            ( part_id )
)
