CREATE TABLE IF NOT EXISTS dicole_typeset_types_link ( 
 typeset_id 		int unsigned not null,
 type_id                int unsigned not null,

 key                    ( typeset_id ),
 key		        ( type_id )
)
