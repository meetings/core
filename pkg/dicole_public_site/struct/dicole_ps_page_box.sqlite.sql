CREATE TABLE dicole_ps_page_box ( 
 page_box_id     		%%INCREMENT%%,

 user_id		int unsigned,
 groups_id		int unsigned,

 title			text,

 page_id                int unsigned not null,
 box_id                 int unsigned not null,

 container              int unsigned not null,
 ordering		int unsigned not null,
 
 unique                 ( page_box_id ),
 primary key		    ( page_box_id )
)
