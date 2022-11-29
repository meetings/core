
CREATE TABLE dicole_metadata_fields (
	field_id         %%INCREMENT%%,
	metadata_id	int unsigned not null,

	label	        text,
	definition      text,
	comment         text,

	primary key	( field_id ),

	unique          ( metadata_id, label )
)
