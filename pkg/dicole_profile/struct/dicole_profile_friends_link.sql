CREATE TABLE IF NOT EXISTS dicole_profile_friends_link ( 
 friend_id			int unsigned not null,
 profile_id               int unsigned not null,
 key                    ( friend_id ),
 key		            ( profile_id )
)
