CREATE TABLE IF NOT EXISTS dicole_groups ( 
 groups_id			    %%INCREMENT%%,
 domain_id		int unsigned not null,
 parent_id              int unsigned not null,
 creator_id             int unsigned not null,
 created_date		bigint unsigned not null,
 points                 int unsigned not null,

 has_area               int unsigned not null,
 joinable               int unsigned not null,
 
 name                   text,
 description            text,
 type                   text,
 meta			text,
  
 unique                 ( groups_id ),
 primary key		    ( groups_id )
)

