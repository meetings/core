CREATE TABLE IF NOT EXISTS dicole_digest_source (
 digest_id              %%INCREMENT%%,

 type                   varchar(32) not null,
 idstring               varchar(32) not null,
 ordering               int unsigned not null,
 active                 int unsigned not null,
 modified               int unsigned not null,

 name                   text,
 description            text,
 action                 text,
 secure                 text,
 package                text,

 unique                 ( digest_id ),
 primary key            ( digest_id ),
 key                    ( idstring )
)
