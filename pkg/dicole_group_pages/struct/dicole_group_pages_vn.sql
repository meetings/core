CREATE TABLE IF NOT EXISTS dicole_group_pages_vn ( 
 version_id			    %%INCREMENT%%,
 content_id             int unsigned not null,
 creator_id             int unsigned not null,
 version_number         int unsigned not null,
 creation_time          bigint unsigned not null,

 unique                 ( version_id ),
 primary key		    ( version_id )
)
