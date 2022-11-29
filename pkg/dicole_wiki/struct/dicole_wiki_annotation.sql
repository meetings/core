CREATE TABLE IF NOT EXISTS dicole_wiki_annotation (
 annotation_id          %%INCREMENT%%,
 group_id               int unsigned not null,
 domain_id              int unsigned not null,
 page_id                int unsigned not null,

 creator_id             int unsigned not null,
 creation_date          bigint unsigned not null,

 comment_count          int unsigned not null,

 unique                 ( annotation_id ),
 primary key            ( annotation_id ),
 key                    ( page_id )
)
