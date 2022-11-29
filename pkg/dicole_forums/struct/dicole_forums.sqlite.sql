CREATE TABLE dicole_forums (
 forum_id               %%INCREMENT%%,
 groups_id              int unsigned not null,
 user_id                int unsigned not null,
 metadata_id            int unsigned default 0,
 locked                 tinyint unsigned default 0,
 date                   bigint unsigned not null,
 title                  text,
 description            text,
 category               text,
 message_typeset        smallint unsigned not null default '0',
 posts                  int unsigned default '0',
 topics                 int unsigned default '0',
 updated                bigint unsigned default '0',
 type                   text,
 unique                 ( forum_id ),
 primary key            ( forum_id )
)
