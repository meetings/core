CREATE TABLE IF NOT EXISTS dicole_wiki_support (
 support_id             %%INCREMENT%%,
 group_id               int unsigned not null,
 domain_id              int unsigned not null,
 annotation_id          int unsigned not null,
 comment_id             int unsigned not null,

 creation_date          bigint unsigned not null,
 creator_id             int unsigned not null,

 anonymous_sid          text,

 unique                 ( support_id ),
 primary key            ( support_id ),
 key                    ( comment_id ),
 key                    ( annotation_id )
)
