CREATE TABLE IF NOT EXISTS dicole_url_alias ( 
 alias_id              %%INCREMENT%%,
 domain_id       int unsigned not null,
 user_id         int unsigned not null,
 group_id        int unsigned not null,
 creation_date   bigint unsigned not null,
 action          text,
 task            text,
 alias           text,

 unique          ( alias_id ),
 primary key     ( alias_id ),
 key             ( domain_id, group_id, user_id, creation_date )
)

