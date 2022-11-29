CREATE TABLE IF NOT EXISTS dicole_wiki_lock ( 
 lock_id                %%INCREMENT%%,
 page_id                int unsigned not null,
 user_id                int unsigned not null,
 version_number         int unsigned not null,
 lock_position          int unsigned not null,
 lock_size              int unsigned not null,

 lock_created           bigint unsigned not null,
 lock_renewed           bigint unsigned not null,

 autosave_content       text,

 unique                 ( lock_id ),
 primary key            ( lock_id ),
 key                    ( page_id )
)
