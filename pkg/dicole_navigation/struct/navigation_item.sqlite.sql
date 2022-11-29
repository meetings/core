CREATE TABLE dicole_navigation_item (
 id             %%INCREMENT%%,
 navid      varchar(63) not null,
 navparent  varchar(63) not null default '',
 active         int unsigned not null default 1,
 persistent     int unsigned not null default 0,
 ordering       int unsigned not null default 0,
 localize       int unsigned not null default 1,
 name           text not null default '',
 link           text not null default '',
 secure         text not null default '',
 icons          text not null default '',
 type           text not null default '',
 groups_ids     text not null default '',
 users_ids     text not null default '',
 package        text not null default '',
 primary key    ( id ),
 unique         ( id )
)
