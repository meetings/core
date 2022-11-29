CREATE TABLE dicole_weblog_topics ( 
 topic_id			    %%INCREMENT%%,
 user_id                int unsigned not null,
 groups_id              int unsigned not null,
 name                   varchar(64), 
 unique                 ( topic_id ),
 primary key		    ( topic_id )
)
