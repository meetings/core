CREATE TABLE dicole_theme (
 theme_id            %%INCREMENT%%,
 ident                  varchar(100),

 version		text,

 name			text,
 description            text,
 author			text,
 screenshot		text,

 groups_id		int unsigned not null default 0,
 user_id		int unsigned not null default 0,
 parent_theme		varchar(100),

 css_all		text,
 css_aural		text,
 css_braille		text,
 css_embossed		text,
 css_handheld		text,
 css_print		text,
 css_projection		text,
 css_screen		text,
 css_tty		text,
 css_tv			text,

 theme_images		text,

 modifyable		int unsigned not null default 0,
 default_theme		int unsigned not null default 0,

 unique                 ( theme_id ),
 primary key            ( theme_id )
)
