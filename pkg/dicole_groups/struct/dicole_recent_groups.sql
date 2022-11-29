CREATE TABLE IF NOT EXISTS dicole_recent_groups ( 
 user_id                int unsigned not null,
 recent_groups          text,

 key                    ( user_id )
)

