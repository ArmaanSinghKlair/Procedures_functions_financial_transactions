-- 1st task
/**
 This functions checks whether current user has EXECUTE permissions on UTL_FILE
 @author Armaan Singh Klair
 @version 11/29/2020
 */
create or replace function func_permissions_okay
return CHAR
IS
k_table_name CONSTANT USER_TAB_PRIVS.TABLE_NAME%TYPE := 'UTL_FILE';
k_privilege CONSTANT USER_TAB_PRIVS.PRIVILEGE%TYPE := 'EXECUTE';
lv_count number;
BEGIN
 SELECT COUNT(*)
 INTO lv_count
 FROM USER_TAB_PRIVS
 WHERE GRANTEE = USER AND
 TABLE_NAME = k_table_name AND
 PRIVILEGE = k_privilege;
 
 IF lv_count = 0 THEN
    RETURN 'N';
 ELSE
    RETURN 'Y';
 END IF;
END;

-- 2nd task
/**
    This trigger fires before insert on PAYROLL_LOAD table and makes a transaction in NEW_TRANSACTIONS for each row that goes in 
    @author Armaan Singh Klair
    @version 29/11/2020
*/
create or replace trigger payroll_load_assist_bir
before insert on PAYROLL_LOAD
for each row
declare
k_accounts_payable CONSTANT ACCOUNT.ACCOUNT_NO%TYPE := 2050;
k_payroll_expense CONSTANT ACCOUNT.ACCOUNT_NO%TYPE := 4045;
lv_cur_trans_no NUMBER;
lv_default_trans_type ACCOUNT_TYPE.DEFAULT_TRANS_TYPE%TYPE;
begin

lv_cur_trans_no := WKIS_SEQ.NEXTVAL;

-- entry into accounts payable
select DEFAULT_TRANS_TYPE into lv_default_trans_type from ACCOUNT_TYPE natural join ACCOUNT where ACCOUNT_NO = k_accounts_payable;
INSERT INTO NEW_TRANSACTIONS VALUES 
(lv_cur_trans_no, 
:NEW.PAYROLL_DATE, 
'Accounts Payable for salary of employee having Id = ' || :NEW.EMPLOYEE_ID,
k_accounts_payable,
lv_default_trans_type,
:NEW.AMOUNT);

-- entry into payroll expense
select DEFAULT_TRANS_TYPE into lv_default_trans_type from ACCOUNT_TYPE natural join ACCOUNT where ACCOUNT_NO = k_payroll_expense;
INSERT INTO NEW_TRANSACTIONS VALUES 
(lv_cur_trans_no, 
:NEW.PAYROLL_DATE, 
'Payroll expense for employee having Id = ' || :NEW.EMPLOYEE_ID,
k_payroll_expense,
lv_default_trans_type,
:NEW.AMOUNT);

:NEW.STATUS := 'G';
exception
    when others then
    :NEW.STATUS := 'B';
end;


-- 3rd task
/**
    This procedure zeroes out the expense and revenue accounts only if the balance for account is more than zero
    @author Armaan Singh Klair
    @version 11/29/2020
    */
create or replace procedure proc_month_end
is

k_revenue_type CONSTANT ACCOUNT.ACCOUNT_TYPE_CODE%TYPE := 'RE';
k_expense_type CONSTANT ACCOUNT.ACCOUNT_TYPE_CODE%TYPE := 'EX';
k_owner_equity CONSTANT ACCOUNT.ACCOUNT_NO%TYPE := 5555;
lv_cur_account_no NEW_TRANSACTIONS.ACCOUNT_NO%TYPE;
lv_cur_trans_balance NUMBER;
lv_default_trans_type ACCOUNT_TYPE.DEFAULT_TRANS_TYPE%TYPE;
lv_opp_trans_type ACCOUNT_TYPE.DEFAULT_TRANS_TYPE%TYPE;
lv_new_trans_no NEW_TRANSACTIONS.TRANSACTION_NO%TYPE;

CURSOR main_account_c IS
select * from ACCOUNT
where account_type_code in (k_revenue_type, k_expense_type);
CURSOR main_c IS
select * from new_transactions
where account_no = lv_cur_account_no;
begin

-- select all revenue and expense accounts from ACCOUNT table
for main_account_r in main_account_c loop
    lv_cur_account_no := main_account_r.account_no;
    select default_trans_type 
    into lv_default_trans_type
    from account_type
    where account_type_code = main_account_r.account_type_code;
    lv_cur_trans_balance := 0;
    
    -- Getting TOTAL balance of current account from NEW_TRANSACTIONS
    for main_r in main_c loop
        
        if main_r.TRANSACTION_TYPE = lv_default_trans_type then
            lv_cur_trans_balance := lv_cur_trans_balance + main_r.TRANSACTION_AMOUNT;
        else
            lv_cur_trans_balance := lv_cur_trans_balance - main_r.TRANSACTION_AMOUNT;
        end if;
    end loop;
    select distinct default_trans_type 
    into lv_opp_trans_type
    from account_type 
    where default_trans_type <> lv_default_trans_type;
       
    --If balance for current account is greater than zero then create the transaction
    if lv_cur_trans_balance > 0 then
        lv_new_trans_no := WKIS_SEQ.NEXTVAL;
        
        INSERT INTO NEW_TRANSACTIONS VALUES(
        lv_new_trans_no,
        SYSDATE,
        'Zeroing out account no. ' || lv_cur_account_no,
        lv_cur_account_no,
        lv_opp_trans_type,
        lv_cur_trans_balance);
        
        INSERT INTO NEW_TRANSACTIONS VALUES(
        lv_new_trans_no,
        SYSDATE,
        'Updaing Owner equity for zeroing out account no. ' || lv_cur_account_no,
        k_owner_equity,
        lv_default_trans_type,
        lv_cur_trans_balance);
    end if;
    
end loop;

end;

/**
    This procedure exports all rows and columns in NEW_TRANSACTIONS table to an external comma-delimited file
    @author Armaan Singh Klair
    @version 11/29/2020
    
*/
create or replace procedure proc_export_csv
(p_dir in varchar,
p_filename in varchar)

is 
export_file UTL_FILE.FILE_TYPE;
CURSOR main_c IS
select * from new_transactions;
begin

export_file := UTL_FILE.FOPEN(p_dir, p_filename, 'W');
for main_r in main_c loop
UTL_FILE.PUT_LINE(
export_file,
main_r.TRANSACTION_NO || ',' || to_char(main_r.TRANSACTION_DATE,'YYYY-MM-DD') || ',' || main_r.DESCRIPTION || ',' || main_r.ACCOUNT_NO || ',' || main_r.TRANSACTION_TYPE || ',' || main_r.TRANSACTION_AMOUNT);
end loop;

UTL_FILE.FCLOSE(export_file);

exception
when others then
dbms_output.put_line(sqlerrm);


end;
