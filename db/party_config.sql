create table party_config(
 id    number generated always as identity
,party varchar2(50 char) not null
,key   varchar2(50 char) not null
,value varchar2(50 char) not null
,constraint party_config_pk primary key (party, key)
);
