CREATE TABLE IF NOT EXISTS dicole_wiki_summary_page (
 summary_page_id              %%INCREMENT%%,
 group_id                     int unsigned not null,
 page_id                      int unsigned not null,

 unique                 ( summary_page_id ),
 primary key            ( summary_page_id ),
 key                    ( group_id )
)
