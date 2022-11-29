CREATE TABLE IF NOT EXISTS dicole_wiki_content ( 
 content_id             %%INCREMENT%%,
 content                mediumtext,

 unique                 ( content_id ),
 primary key            ( content_id )
)
