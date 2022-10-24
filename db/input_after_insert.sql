create or replace trigger input_after_insert
after insert on input
for each row
begin
  insert into input_meta(input_id, processing_status)
  values(:new.id, 'INSERTED');
end;
/
