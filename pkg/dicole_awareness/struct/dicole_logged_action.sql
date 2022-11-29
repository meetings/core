CREATE TABLE IF NOT EXISTS dicole_logged_action (
 logged_action_id		%%INCREMENT%%,
 domain_id              int unsigned not null,
 time                   bigint unsigned not null,
 user_id                int unsigned not null,
 target_group_id        int unsigned not null,
 target_user_id         int unsigned not null,
 action                 text not null,
 task                   text not null,
 url                    text not null,
  
 unique                 ( logged_action_id ),
 primary key		    ( logged_action_id ),
 key                    ( time ),
 key                    ( time, domain_id ),
 key                    ( time, user_id ),
 key                    ( time, target_group_id )
)
