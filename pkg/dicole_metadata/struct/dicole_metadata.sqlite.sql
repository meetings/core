
CREATE TABLE dicole_metadata (
	metadata_id     %%INCREMENT%%,
	groups_id       int unsigned default 0,
	machine_name    varchar(20),
	title           text,
	copyright       text,
	description     text,
	status          text,
	machine_url     text,
	url             text, 
	primary key	( metadata_id ),

	unique ( groups_id, machine_name )
)
