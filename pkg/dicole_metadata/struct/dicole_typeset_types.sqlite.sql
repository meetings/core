
CREATE TABLE dicole_typeset_types (
	type_id         %%INCREMENT%%,
	typeset_id      int unsigned not null,
	type_id_string  text,
	title		text,
	description	text,
	icon            text,
	machine_url     text,
	primary key	( type_id ),
	unique          ( typeset_id, title )
)
