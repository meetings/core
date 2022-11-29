CREATE TABLE IF NOT EXISTS dicole_wiki_search (
 search_id              %%INCREMENT%%,
 page_id                int unsigned not null,
 text                   mediumtext,

 unique                 ( search_id ),
 primary key            ( page_id ),
 key                    ( page_id )
)
