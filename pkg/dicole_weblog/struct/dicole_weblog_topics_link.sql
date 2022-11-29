CREATE TABLE IF NOT EXISTS dicole_weblog_topics_link ( 
 post_id			int unsigned not null,
 topic_id               int unsigned not null,
 key                    ( post_id ),
 key		            ( topic_id )
)
