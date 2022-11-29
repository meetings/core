CREATE TABLE dicole_profile_comments (
 comment_id            %%INCREMENT%%,
 user_id               int unsigned not null,
 profile_id            int unsigned not null,
 date                  bigint unsigned not null,
 subject                text,
 content                text,
 unique                 ( comment_id ),
 primary key            ( comment_id )
)
