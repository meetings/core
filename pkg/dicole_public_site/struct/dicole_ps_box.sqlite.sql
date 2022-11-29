CREATE TABLE dicole_ps_box ( 
 box_id     			%%INCREMENT%%,

 idstring               varchar(30),

 type                   varchar(30) not null,

 title                  text,

 location		int unsigned not null,
 ordering               int unsigned not null, 

 content		text,

 unique                 ( box_id ),
 primary key		    ( box_id )

)
