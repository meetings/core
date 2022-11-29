CREATE TABLE IF NOT EXISTS dicole_security_level (
 level_id           %%INCREMENT%%,

 target_type        tinyint not null default 0,

 oi_module          text,
 id_string          text,

 name               text,
 description        text,

 archetype          text,
 secure             text,

 package            text,

 primary key    ( level_id )
)

