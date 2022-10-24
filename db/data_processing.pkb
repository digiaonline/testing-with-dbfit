create or replace package body data_processing is
/* Record transformation logic:

amount1 only - value is no commission sales
amount2 only - value is commission sales
both amount1 + amount2 only - no commission sales (amount1) is converted to commission sales (amount2)
  no commission value is ignored and all previous no commission values are reverted
amount3 only - no commission sales cancelled (not implemented)
amount4 only - commission sales cancelled (not implemented)
*/

  ex_configuration_error exception;
  ex_configuration_error_num constant number := -20100;
  pragma exception_init(ex_configuration_error, ex_configuration_error_num);

  procedure raise_(p_errnum in number, p_message in varchar2)
  is
  begin
    raise_application_error(p_errnum, substrb(p_message, 0, 2048), true);
  end;
  
  function is_no_commission_sales_only(p_input input%rowtype)
  return boolean is
  begin
    return
          p_input.amount1 != 0
      and p_input.amount2  = 0
      and p_input.amount3  = 0
      and p_input.amount4  = 0
    ;
  end;

  function is_commission_sales_only(p_input input%rowtype)
  return boolean is
  begin
    return
          p_input.amount1  = 0
      and p_input.amount2 != 0
      and p_input.amount3  = 0
      and p_input.amount4  = 0
    ;
  end;

  function is_no_commission_to_commission_sales(p_input input%rowtype)
  return boolean is
  begin
    return
          p_input.amount1 != 0
      and p_input.amount2 != 0
      and p_input.amount3  = 0
      and p_input.amount4  = 0
    ;
  end;

  function config_value(p_party in varchar2, p_key varchar2)
  return varchar2 result_cache is
    v_value party_config.value%type;
  begin
    select value
    into v_value
    from party_config
    where party = p_party
    and key = p_key
    ;
    return v_value;
  exception
    when no_data_found
    then
      raise_(
        p_errnum  => ex_configuration_error_num
       ,p_message => 'Configuration error: (party ' || p_party || ')(key '|| p_key || ')'
      );
  end;

  procedure mark_processed_ok(p_id in number)
  is
  begin
    insert into input_meta(input_id, processing_status)
    values(p_id, 'PROCESSED_OK');
  end;

  procedure mark_processed_error(p_id in number)
  is
  begin
    -- TODO UTL_CALL_STACK
    insert into input_meta(input_id, processing_status, processing_details)
    values(p_id, 'PROCESSED_ERROR', substrc(dbms_utility.format_error_stack, 0, 1000));
  end;
  
  procedure process_input(p_id in number)
  is
    v_input input%rowtype;
  begin
    select * into v_input from input where id = p_id;

    if is_no_commission_sales_only(v_input)
    then
      begin
        declare
          v_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_SALES_NO_COMMISSION');
        begin
          insert into output(input_id, account, amount)
          values(p_id, v_account, v_input.amount1);

          mark_processed_ok(p_id);
        end;
      exception
        when others
        then
          mark_processed_error(p_id);
      end;
    end if;

    if is_commission_sales_only(v_input)
    then
      begin
        declare
          v_commission_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_SALES_COMMISSION');

          v_reward_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_REWARD');
          v_reward_percent constant number := (to_number(config_value(v_input.party, 'REWARD_PERCENT'))) / 100;
          v_reward_amount constant number := v_reward_percent * v_input.amount2;
        begin
          insert into output(input_id, account, amount)
          values(p_id, v_commission_account, v_input.amount2);
        
          insert into output(input_id, account, amount)
          values(p_id, v_reward_account, v_reward_amount);

          mark_processed_ok(p_id);
        end;
      exception
        when others
        then
          mark_processed_error(p_id);
      end;
    end if;

    if is_no_commission_to_commission_sales(v_input)
    then
      begin
        declare
          v_no_commission_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_SALES_NO_COMMISSION');
          v_no_commission_amount constant number := -(v_input.amount2 - v_input.amount1);

          v_commission_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_SALES_COMMISSION');
        
          v_reward_account constant varchar2(32756) := config_value(v_input.party, 'ACCOUNT_REWARD');
          v_reward_percent constant number := (to_number(config_value(v_input.party, 'REWARD_PERCENT'))) / 100;
          v_reward_amount constant number := v_reward_percent * v_input.amount2;
        begin
          insert into output(input_id, account, amount)
          values(p_id, v_no_commission_account, v_no_commission_amount);

          insert into output(input_id, account, amount)
          values(p_id, v_commission_account, v_input.amount2);

          insert into output(input_id, account, amount)
          values(p_id, v_reward_account, v_reward_amount);

          mark_processed_ok(p_id);
        end;
      exception
        when others
        then
          mark_processed_error(p_id);
      end;
    end if;

  end;

end;
/
