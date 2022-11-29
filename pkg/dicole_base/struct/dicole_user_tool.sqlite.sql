CREATE TABLE dicole_user_tool ( 
 id			%%INCREMENT%%,
 user_id                int unsigned not null,
 toolid                 varchar(32),

 unique                 ( id ),
 primary key		( id )
)

