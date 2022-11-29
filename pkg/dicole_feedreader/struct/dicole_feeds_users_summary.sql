CREATE TABLE IF NOT EXISTS dicole_feeds_users_summary (
 summary_id        %%INCREMENT%%,
 user_id            int unsigned default 0,
 group_id           int unsigned default 0,
 summary            text not null,
 unique             ( summary_id ),
 primary key        ( summary_id ),
 key                ( user_id )
)
