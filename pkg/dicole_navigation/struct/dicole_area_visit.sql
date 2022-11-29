CREATE TABLE IF NOT EXISTS dicole_area_visit (
 visit_id           %%INCREMENT%%,
 user_id            int unsigned not null,
 target_user_id     int unsigned not null,
 target_group_id    int unsigned not null,
 domain_id          int unsigned not null,
 hit_count          int unsigned not null,
 last_visit         bigint unsigned not null,
 sticky             tinyint unsigned not null,
 visiting_disabled  tinyint unsigned not null,
 url                text,
 name               text,
 icon               text,

 primary key        ( visit_id ),
 unique             ( visit_id ),
 key                ( user_id, domain_id, hit_count ),
 key                ( user_id, domain_id, last_visit ),
 key                ( user_id, domain_id, url(64) )
)
