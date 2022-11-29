
CREATE TABLE dicole_dcmi_metadata (
	dcmi_id         %%INCREMENT%%,
	groups_id       int unsigned default 0,
	metadata_id	int unsigned not null,


	title		tinytext,
	creator		tinytext,
	subject		tinytext,
	description	text,
	publisher	tinytext,
	contributor	tinytext,
	date		bigint unsigned default 0,
	type		varchar(128),
	format		tinytext,
	identifier	varchar(128),
	source		tinytext,
	language	varchar(128),
	relation	tinytext,
	coverage	tinytext,
	rights		text,

	primary key	( dcmi_id )
)
