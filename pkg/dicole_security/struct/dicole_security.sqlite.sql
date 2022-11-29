CREATE TABLE dicole_security (
 security_id        %%INCREMENT%%,

 receiver_type      tinyint unsigned not null default 0,
 target_type        tinyint unsigned not null default 0,
 
 receiver_group_id  int unsigned not null default 0,
 receiver_user_id   int unsigned not null default 0,

 target_group_id    int unsigned not null default 0,
 target_user_id     int unsigned not null default 0,
 target_object_id   int unsigned not null default 0,

 collection_id      int unsigned not null default 0,

 primary key    ( security_id )
)
