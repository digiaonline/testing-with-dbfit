create table input_meta(
 input_id number not null
,processed_at timestamp with time zone not null default current_timestamp
,processing_status varchar2(50 char) not null
,processing_details varchar2(1000 char)
,foreign key (input_id) references input(id)
);
