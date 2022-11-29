CREATE TABLE IF NOT EXISTS dicole_networking_profile (
 profile_id            %%INCREMENT%%,
 user_id                int unsigned not null,
 domain_id              int unsigned not null default 0,

 portrait               text,
 portrait_thumb         text,
 
 contact_organization   text,
 contact_title          text,
 
 contact_address_1      text,
 contact_address_2      text,

 contact_email          text,
 contact_skype          text,
 contact_phone          text,

 personal_blog          text,
 personal_facebook      text,
 personal_jaiku         text,
 personal_twitter       text,
 personal_linkedin      text,
 personal_motto         text,
 about_me		text,
 meta_info		text,

 prof_description       text,

 employer_title         text,
 employer_name          text,
 employer_address_1     text,
 employer_address_2     text,
 employer_phone         text,

 educ_school            text,
 educ_degree            text,
 educ_other_degree      text,
 educ_target_degree     text,

 educ_skill_profile     text,

 gmaps_location         text,
 gmaps_lat              double,
 gmaps_lng              double,

 unique                 ( profile_id ),
 primary key            ( profile_id ),
 key                    ( user_id )
)
