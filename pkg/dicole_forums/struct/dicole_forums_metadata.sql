
CREATE TABLE IF NOT EXISTS dicole_forums_metadata (
	metadata_id     %%INCREMENT%%,

	# Dublin Core
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

	primary key	( metadata_id )
)
