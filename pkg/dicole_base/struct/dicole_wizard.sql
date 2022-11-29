CREATE TABLE IF NOT EXISTS dicole_wizard ( 
 wizard_id			int unsigned not null,
 user_id			int unsigned not null,
 expire_time		int unsigned not null,
 
 primary key		( wizard_id )
)

