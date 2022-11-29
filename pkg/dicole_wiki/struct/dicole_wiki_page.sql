CREATE TABLE IF NOT EXISTS dicole_wiki_page ( 
 page_id                %%INCREMENT%%,
 groups_id              int unsigned not null,
 last_version_number    int unsigned not null,
 last_version_id        int unsigned not null,
 last_content_id        int unsigned not null,
 last_author_id         int unsigned not null,
 last_modified_time     bigint unsigned not null,
 created_date           bigint unsigned not null,
 creator_id		int unsigned not null,

 moderator_lock         int unsigned not null,
 hide_comments          int unsigned not null,
 hide_annotations       int unsigned not null,

 title                  varchar(255) not null,
 readable_title         varchar(255) not null,

 unique                 ( page_id ),
 primary key            ( page_id ),
 key                    ( groups_id, title ),
 key			( groups_id, created_date ),
 key                    ( groups_id, last_modified_time )
)
