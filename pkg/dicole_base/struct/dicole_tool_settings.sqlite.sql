CREATE TABLE dicole_tool_settings (
 settings_id        %%INCREMENT%%,
 user_id            int unsigned default 0,
 groups_id          int unsigned default 0,
 tool               varchar(32),
 attribute          varchar(100) not null,
 value              text,
 primary key        ( settings_id )
)
