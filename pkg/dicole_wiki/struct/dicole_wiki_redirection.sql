CREATE TABLE IF NOT EXISTS dicole_wiki_redirection (
 redirection_id         %%INCREMENT%%,
 group_id               int unsigned not null,
 page_id                int unsigned not null,
 date                   bigint unsigned not null,

 title                  varchar(255) not null,
 readable_title         varchar(255) not null,

 unique                 ( redirection_id ),
 primary key            ( redirection_id ),
 key                    ( group_id, title )
)
