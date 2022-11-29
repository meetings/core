CREATE TABLE dicole_group_pages_link ( 
 link_id			    %%INCREMENT%%,
 groups_id              int unsigned not null,
 linking_title          varchar(64) not null,
 linked_title           varchar(64) not null,
  
 unique                 ( link_id ),
 primary key		    ( link_id )
)
