CREATE TABLE dicole_logged_usage_daily (
 daily_id 			%%INCREMENT%%,
 date 			bigint unsigned not null,
 domain_id              int unsigned not null,		
 comment_count	int not null default 0,
 blog_count		int not null default 0,
 wiki_count		int not null default 0, 
 activity		int not null default 0,

 unique                 ( daily_id ),
 primary key        	( daily_id ),
 key			( domain_id, date)
)