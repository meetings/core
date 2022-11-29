CREATE TABLE dicole_feeds_items_users (
 useritem_id        %%INCREMENT%%,
 item_id            int unsigned not null,
 feed_id            int unsigned not null,
 user_id            int unsigned not null,
 read_date          bigint unsigned default 0,
 unique             ( useritem_id ),
 primary key        ( useritem_id )
)
