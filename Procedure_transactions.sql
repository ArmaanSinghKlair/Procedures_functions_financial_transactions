set serveroutput on;

/* ===================================================================================
 * Author: Armaan Singh Klair
 * Create Date: 11/10/2020
 * Description: This anonymous block transfers transactions from the NEW_TRANSACTION table to TRANSACTION_HISTORY and TRANSACTION_DETAIL  and updates ACCOUNT table in the process.
 *              It also handles error along the way such, if any row of the transaction has invalid transaction_type ( other than 'C'/'D'), invalid account_no, -ve transaction amount, Debits NOT equal to credits,
 *              then that row including OTHER rows of the transaction are NOT processed. If a row has a NULL transaction, then that row is not processed.
=======================================================================================*/
declare

k_debit_type CONSTANT CHAR(1) := 'D'; 
k_credit_type CONSTANT CHAR(1) := 'C'; 

lv_current_trans_type CHAR(1);
lv_current_trans_amount NUMBER;
lv_history_count NUMBER(1);
lv_current_trans_number number;
lv_trans_checknum NUMBER := 0;
lv_trans_to_skip NUMBER := -1;
lv_debit_credit_skip NUMBER := -1;
lv_error_msg VARCHAR(199);
lv_matching_account_num NUMBER;

CURSOR transaction_cursor IS
SELECT * FROM NEW_TRANSACTIONS FOR UPDATE NOWAIT;
CURSOR debit_credit_check IS
SELECT * FROM NEW_TRANSACTIONS
WHERE TRANSACTION_NO = lv_current_trans_number;


begin
    
--For ALL transactions
FOR row IN transaction_cursor LOOP
    
    BEGIN
            
        -- Checking whether Transaction_no is Null
            IF row.transaction_no IS NULL THEN
                RAISE_APPLICATION_ERROR(-20002, 'Transaction number not found for this transaction'); 
            END IF;
        
        IF row.transaction_no <> lv_trans_to_skip THEN           
            -- Stores current amount
            lv_current_trans_amount := row.transaction_amount;
            
            lv_current_trans_number := row.transaction_no;

            
            -- Skips Checking debit=credit if ALREADY checked
            IF lv_debit_credit_skip <> lv_current_trans_number THEN
            
            lv_trans_checknum := 0;
            -- Checking whether DEBITS = CREDITS and OTHER Checks
                FOR row_check IN debit_credit_check LOOP
                    
                    -- Checking if Transaction_type is Invalid
                    IF row_check.transaction_type NOT IN (k_debit_type, k_credit_type) THEN
                        lv_trans_to_skip := row_check.transaction_no;
                        RAISE_APPLICATION_ERROR(-20005, 'Transaction Type Invalid for this transaction. Must be either ''C'' or ''D'' '); 
                    END IF;

                    -- Checking whether transaction amount is NEGATIVE
                    IF row_check.transaction_amount < 0 THEN
                        lv_trans_to_skip := row_check.transaction_no;
                        RAISE_APPLICATION_ERROR(-20004, 'Transaction Amount is Negative for this transaction. Must be 0 or a Positive number.'); 
                    END IF;

                    -- Checking whether account number is VALID
                    SELECT COUNT(*) INTO lv_matching_account_num FROM ACCOUNT WHERE account_no = row_check.account_no;
                    IF lv_matching_account_num = 0 THEN
                         lv_trans_to_skip := row_check.transaction_no;
                         RAISE_APPLICATION_ERROR(-20003, 'Invald Account Number for this transaction. Must be one of the account numbers in the ACCOUNT table.'); 
                    END IF;

                     -- Determines whether account balance should be increased or decreased
                    IF  row_check.transaction_type = k_credit_type THEN        
                         lv_trans_checknum := lv_trans_checknum - row_check.transaction_amount;
                    ELSE   
                         lv_trans_checknum := lv_trans_checknum + row_check.transaction_amount;
            
                    END IF;
                END LOOP;
            END IF;
                
            IF lv_trans_checknum <> 0 THEN
                lv_trans_to_skip := row.transaction_no;
                RAISE_APPLICATION_ERROR(-20001, 'Debits and Credits Not Equal for this transaction.');
            ELSE
                lv_debit_credit_skip := row.transaction_no;
            END IF;
            
            
            -- Provides a way to check whether current transaction is present in TRANSACTION_HISTORY
            SELECT count(*)INTO lv_history_count FROM TRANSACTION_HISTORY WHERE transaction_no = row.transaction_no;
            
            -- SELECT INTO performed on ACCOUNT_TYPE, ACCOUNT tables, NOT NEW_TRANSACTIONS
                
            SELECT DEFAULT_TRANS_TYPE 
            INTO lv_current_trans_type 
            FROM account_type NATURAL JOIN account 
            WHERE ACCOUNT_NO = row.account_no;
            
            -- Determines whether account balance should be increased or decreased
            IF lv_current_trans_type <> row.transaction_type THEN
                 lv_current_trans_amount := lv_current_trans_amount * -1;
            END IF;
                
             -- Update Account Balance
            UPDATE ACCOUNT SET
            account_balance = account_balance + lv_current_trans_amount
            WHERE ACCOUNT_NO = row.account_no;
             
            -- Add into transaction history ONLY IF COUNT == 0 ( not already added )
            IF lv_history_count = 0 THEN
                INSERT INTO TRANSACTION_HISTORY
                VALUES (row.transaction_no, row.transaction_date, row.description);
            END IF; 
            
            -- Add into transaction detail
            INSERT INTO TRANSACTION_DETAIL
             VALUES (row.account_no, row.transaction_no, row.transaction_type, row.transaction_amount);
             
            -- Removing this transaction from original table
            DELETE FROM NEW_TRANSACTIONS
            WHERE CURRENT OF transaction_cursor;            
        END IF;
        EXCEPTION
        WHEN OTHERS THEN
            lv_error_msg := SUBSTR(SQLERRM, 1, 199);
            INSERT INTO WKIS_ERROR_LOG
            VALUES (row.transaction_no, row.transaction_date, row.description, lv_error_msg);
    END;

END LOOP;
-- Commits the changes
COMMIT;
END;