create table input(
 id number generated always as identity
,party varchar2(50 char) not null
,amount1 number not null
,amount2 number not null
,amount3 number not null
,amount4 number not null
,constraint input_pk primary key(id)
);
