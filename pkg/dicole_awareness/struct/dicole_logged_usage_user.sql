CREATE TABLE dicole_logged_usage_user (
 user_usage_id			%%INCREMENT%%,
 user_id                int unsigned not null,
 domain_id              int unsigned not null,
 wiki_total		int not null default 0,
 comment_total		int not null default 0,
 blog_total		int not null default 0,
 activity               int not null default 0,

 unique                 ( user_usage_id ),
 primary key        	( user_usage_id ),
 key			( domain_id )
)
