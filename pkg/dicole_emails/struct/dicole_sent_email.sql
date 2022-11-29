CREATE TABLE IF NOT EXISTS dicole_sent_email (
    sent_email_id  %%INCREMENT%%,
    domain_id      int unsigned not null,
    sent_date      bigint unsigned not null,
    from_email     text,
    to_email       text,
    reply_email    text,
    subject        text,
    raw_data       text,
    unique         (sent_email_id),
    primary key    (sent_email_id),
    key            (sent_date)
);
