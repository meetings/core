CREATE TABLE IF NOT EXISTS dicole_wizard_data ( 
 id					%%INCREMENT%%,
 wizard_id			int unsigned not null,
 http_name			varchar(100) not null,
 http_value			text not null,
 
 primary key		( id )
)

