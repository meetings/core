CREATE TABLE dicole_profile_friends (
 friend_id            %%INCREMENT%%,
 user_id                int unsigned not null,
 date                   bigint unsigned not null,
 relationship           tinytext,
 content                text,
 show_others            tinyint unsigned not null,
 unique                 ( friend_id ),
 primary key            ( friend_id )
)
