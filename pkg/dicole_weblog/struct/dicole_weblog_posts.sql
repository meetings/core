CREATE TABLE IF NOT EXISTS dicole_weblog_posts (
 post_id            %%INCREMENT%%,
 groups_id              int unsigned not null,
 user_id                int unsigned not null,
 writer                 int unsigned not null,
 date                   bigint unsigned not null,
 publish_date           bigint unsigned not null,
 edited_date            bigint unsigned not null,
 removal_date           bigint unsigned not null,
 removal_date_enable    int unsigned default 0,
 title                  text,
 abstract               text,
 content                mediumtext,
 unique                 ( post_id ),
 primary key            ( post_id ),
 key                    ( groups_id )
)
