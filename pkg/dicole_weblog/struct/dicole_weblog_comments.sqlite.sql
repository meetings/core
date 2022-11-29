CREATE TABLE dicole_weblog_comments (
 comment_id            %%INCREMENT%%,
 user_id               int unsigned not null,
 post_id               int unsigned not null,
 date                  bigint unsigned not null,
 title                  text,
 name                   text,
 subject                text,
 email                  varchar(100),
 url                    tinytext,
 content                text,
 unique                 ( comment_id ),
 primary key            ( comment_id )
)
