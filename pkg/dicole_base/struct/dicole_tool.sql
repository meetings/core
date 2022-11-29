CREATE TABLE IF NOT EXISTS dicole_tool (
 tool_id                %%INCREMENT%%,
 type                   varchar(32) not null,
 toolid                 varchar(32) not null,

 name                   text,
 description            text,
 secure                 text,
 icon                   text,
 summary                text,
 summary_list           text,
 package                text,

 groups_ids     text not null default '',
 users_ids     text not null default '',

 unique                 ( tool_id ),
 primary key            ( tool_id ),
 key                    ( toolid )
)

