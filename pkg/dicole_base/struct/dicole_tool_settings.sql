CREATE TABLE IF NOT EXISTS dicole_tool_settings (
 settings_id        %%INCREMENT%%,
 user_id            int unsigned not null default 0,
 groups_id          int unsigned not null default 0,
 tool               varchar(32),
 attribute          varchar(100) not null,
 value              text,
 primary key        ( settings_id )
)
