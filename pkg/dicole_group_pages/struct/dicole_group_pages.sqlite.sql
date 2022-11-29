CREATE TABLE dicole_group_pages ( 
 group_page_id			%%INCREMENT%%,
 groups_id              int unsigned not null,
 current_version        int unsigned not null,
 content_id             int unsigned not null,
 locked                 int unsigned not null,
 last_author            int unsigned not null,
 last_modified          bigint unsigned not null,
 
 title                  varchar(255) not null,
  
 unique                 ( group_page_id ),
 primary key		    ( group_page_id )
)
