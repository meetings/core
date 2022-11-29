CREATE TABLE dicole_summary_layout ( 
 layout_id              %%INCREMENT%%,

 user_id                int unsigned not null,
 group_id               int unsigned not null,
 action                 char(32) not null,

 col                    tinyint unsigned not null,
 row                    tinyint unsigned not null,
 open                   tinyint unsigned not null,

 box_id                 text,

 unique          ( layout_id ), 
 primary key     ( layout_id )
)

