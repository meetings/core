CREATE TABLE IF NOT EXISTS dicole_profile_comments_link ( 
 comment_id			int unsigned not null,
 profile_id               int unsigned not null,
 key                    ( comment_id ),
 key		            ( profile_id )
)
