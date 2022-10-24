create table output(
 id number generated always as identity
,input_id number not null
,account varchar(50 char) not null
,amount number not null
);
