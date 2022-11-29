CREATE TABLE IF NOT EXISTS dicole_networking_contact (
 contact_id            %%INCREMENT%%,
 user_id                int unsigned not null,
 contacted_user_id      int unsigned not null,
 domain_id              int unsigned not null default 0,

 unique                 ( contact_id ),
 primary key            ( contact_id ),
 key                    ( user_id )
)
