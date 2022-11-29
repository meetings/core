CREATE TABLE IF NOT EXISTS dicole_feeds_users (
 userfeed_id        %%INCREMENT%%,
 user_id            int unsigned default 0,
 group_id           int unsigned default 0,
 feed_id            int unsigned,
 folder             text,
 notes              text,
 icon		        text,
 date               bigint unsigned not null,
 title              text,
 keywords           text,
 public             int unsigned not null default 0,
 unique             ( userfeed_id ),
 primary key        ( userfeed_id ),
 key                ( user_id )
)
