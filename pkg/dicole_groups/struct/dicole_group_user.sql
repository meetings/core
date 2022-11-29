CREATE TABLE IF NOT EXISTS dicole_group_user ( 
 group_user_id		%%INCREMENT%%,
 domain_id 		int unsigned not null,
 groups_id              int unsigned not null,
 user_id                int unsigned not null,
 creator_id             int unsigned not null,
 creation_date		bigint unsigned not null,

 unique			( group_user_id ),
 key			( group_user_id ),
 key			( user_id ),
 key                    ( groups_id ),
 key                    ( domain_id, user_id, creation_date ),
 key                    ( domain_id, groups_id, creation_date )
)

