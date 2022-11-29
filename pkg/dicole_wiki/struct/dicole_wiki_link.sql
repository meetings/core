CREATE TABLE IF NOT EXISTS dicole_wiki_link ( 
 link_id                %%INCREMENT%%,
 groups_id              int unsigned not null,

 linking_page_id        int unsigned not null,
 linked_page_id         int unsigned not null,

 linking_page_title     varchar(255) not null,
 linked_page_title      varchar(255) not null,

 readable_linking_title varchar(255) not null,
 readable_linked_title  varchar(255) not null,

 unique                 ( link_id ),
 primary key            ( link_id ),
 key                    ( linking_page_id ),
 key                    ( linked_page_id ),
 key                    ( groups_id, linked_page_title )
)
