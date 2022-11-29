CREATE TABLE IF NOT EXISTS dicole_wiki_version ( 
 version_id             %%INCREMENT%%,
 groups_id              int unsigned not null,
 page_id                int unsigned not null,
 content_id             int unsigned not null,
 creator_id             int unsigned not null,
 version_number         int unsigned not null,
 creation_time          bigint unsigned not null,

 change_position        int unsigned not null,
 change_old_size        int unsigned not null,
 change_new_size        int unsigned not null,

 change_type            int unsigned not null,
 change_description     text,

 unique                 ( version_id ),
 primary key            ( version_id ),
 key                    ( page_id, version_number ),
 key                    ( groups_id, change_type )
)
