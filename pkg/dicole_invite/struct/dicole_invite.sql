CREATE TABLE IF NOT EXISTS dicole_invite ( 
 invite_id          %%INCREMENT%%,
 secret_code        varchar(255) not null,
 domain_id          int unsigned not null,
 group_id           int unsigned not null,
 user_id            int unsigned not null,
 email              text,
 level              text,
 invite_date        bigint unsigned not null,
 disabled           int unsigned not null,
 primary key        ( invite_id )
)
