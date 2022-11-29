CREATE TABLE IF NOT EXISTS dicole_forums_messages_unread (
 unread_id              %%INCREMENT%%,

 user_id                int unsigned not null,
 msg_id                 int unsigned not null,

 groups_id              int unsigned not null,
 thread_id              int unsigned not null,
 forum_id               int unsigned not null,
 
 unique                 ( unread_id ),
 primary key            ( unread_id ),
 key                    ( user_id, thread_id ),
 key                    ( user_id, groups_id ),
 key                    ( user_id, msg_id ),
 key                    ( user_id, forum_id )
)
