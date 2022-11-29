CREATE TABLE IF NOT EXISTS dicole_weblog_trackbacks (
 trackback_id           %%INCREMENT%%,
 post_id                int unsigned not null,
 reply_id               int unsigned not null,

 unique                 ( trackback_id ),
 unique                 ( post_id, reply_id ),
 primary key            ( trackback_id ),
 key                    ( post_id ),
 key                    ( reply_id )
)
