CREATE TABLE IF NOT EXISTS dicole_security_meta (
 meta_id      %%INCREMENT%%,

 name               text,
 idstring           text,

 package            text,
 ordering           int unsigned,

 primary key        ( meta_id )
)

