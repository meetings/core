CREATE TABLE IF NOT EXISTS dicole_events_invite (
 invite_id          %%INCREMENT%%,
 secret_code        varchar(255) not null,
 domain_id          int unsigned not null,
 group_id           int unsigned not null,
 event_id           int unsigned not null,
 creator_id         int unsigned not null,
 user_id            int unsigned not null,
 email              text,
 email_original     text,
 email_greeting     text,
 invite_date        bigint unsigned not null,
 consumed_date      bigint unsigned not null,
 disabled_date      bigint unsigned not null,
 planner            int unsigned not null,

 unique             ( invite_id ),
 primary key        ( invite_id )
)
