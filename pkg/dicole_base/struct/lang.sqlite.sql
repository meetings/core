CREATE TABLE lang (
 lang_id	%%INCREMENT%%,
 lang_code	varchar(6) not null,
 lang_name	varchar(30) not null,
 charset	varchar(30) not null,
 primary key   ( lang_id ),
 unique        ( lang_code )
)
