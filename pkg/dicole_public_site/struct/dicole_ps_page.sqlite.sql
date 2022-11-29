CREATE TABLE dicole_ps_page ( 
 page_id    			%%INCREMENT%%,

 user_id		int unsigned,
 group_id               int unsigned,

 parent_id              int unsigned not null,
 url                    text,
 type                   varchar(30) not null,
 title                  text,
 ordering               int unsigned not null, 
 
 unique                 ( page_id ),
 primary key		    ( page_id )
)
