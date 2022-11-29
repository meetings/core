
CREATE TABLE files (
	file_id		%%INCREMENT%%,
	user_id         int unsigned default 0,
	path	 	tinytext not null,
        is_folder       tinyint unsigned default 0,
	

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

	size            int unsigned default 0,
	downloaded	int unsigned default 0,
	locked		int unsigned default 0,
	owner		int unsigned default 0,
	version		varchar(10) default '1.0',
	modified	bigint unsigned default 0,
	created		bigint unsigned default 0,

	metadata_type	tinytext,
	metadata	text,

	primary key	( file_id )
)
