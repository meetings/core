CREATE TABLE IF NOT EXISTS dicole_statistics_action (
 id             %%INCREMENT%%,
 domain_id       int unsigned not null,
 group_id       int unsigned not null,
 user_id        int unsigned not null,
 date           bigint unsigned not null,
 count          int unsigned not null,
 action         text not null,
  
 unique                 ( id ),
 primary key            ( id ),
 key                    ( domain_id, group_id, user_id, date ),
 key                    ( domain_id, group_id, user_id, action(16) ),
 key                    ( domain_id, group_id, action(16) )
)
