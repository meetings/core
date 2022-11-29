CREATE TABLE IF NOT EXISTS dicole_security_collection (
 collection_id      %%INCREMENT%%,

 target_type        tinyint not null default 0,
 allowed            tinyint not null default 0,
 idstring           text,

 name               text,

 archetype          text,
 meta               text,
 secure             text,

 package            text,
 modified           tinyint not null default 0,

 primary key        ( collection_id )

)

