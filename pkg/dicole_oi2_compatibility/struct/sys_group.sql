CREATE TABLE IF NOT EXISTS sys_group (
 group_id      %%INCREMENT%%,
 name          varchar(30) not null,
 notes         varchar(255) null,
 primary key   ( group_id )
)
