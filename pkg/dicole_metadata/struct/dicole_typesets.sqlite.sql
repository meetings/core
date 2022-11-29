
CREATE TABLE dicole_typesets (
	typeset_id      %%INCREMENT%%,
	groups_id	int unsigned default 0,
	machine_name    varchar(30),
	title		text,
	url		text,
	machine_url     text,
	description	text,
	status          text,
	copyright	text,
	primary key	( typeset_id ),

	unique          ( groups_id, machine_name )
)
