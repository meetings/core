CREATE TABLE IF NOT EXISTS dicole_blogs_summary_seed (
 summary_seed_id              %%INCREMENT%%,
 group_id                     int unsigned not null,
 seed_id                      int unsigned not null,

 unique                 ( summary_seed_id ),
 primary key            ( summary_seed_id ),
 key                    ( group_id )
)
