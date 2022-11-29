CREATE TABLE dicole_groups ( 
 groups_id			    %%INCREMENT%%,
 parent_id              int unsigned not null,
 creator_id             int unsigned not null,

 has_area               int unsigned not null,
 joinable               int unsigned not null,
 
 name                   text,
 description            text,
 type                   text,
  
 unique                 ( groups_id ),
 primary key		    ( groups_id )
)

