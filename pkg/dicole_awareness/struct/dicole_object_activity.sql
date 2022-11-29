CREATE TABLE IF NOT EXISTS dicole_object_activity (
 id		%%INCREMENT%%,
 domain_id              int unsigned not null,
 time                   bigint unsigned not null,
 user_id                int unsigned not null,
 target_group_id        int unsigned not null,
 target_user_id         int unsigned not null,
 object_id		int unsigned not null,
 object_type		text,
 act			text,
 from_ip		text,
 referrer		text,
 user_agent		text,
  
 unique                 ( id ),
 primary key	        ( id ),
 key                    ( time, domain_id ),
 key			( object_id )
)
