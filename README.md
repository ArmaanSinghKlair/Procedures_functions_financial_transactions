# Supporting financial transactions via SQL

Background:
1. We assume NEW_TRANSACTION, TRANSACTION_HISTORY, TRANSACTION_DETAIL, ACCOUNT tables
2. ACCOUNT tables contains single records for different types of transactions eg. expense, assets, accounts_payable, account_receivables
3. NEW_TRANSACTION is the table where normal employees enter any new transactions
4. TRANSACTION_DETAIL is the table where details of every transaction is added
5. TRANSACTION_HISTORY is the table where histories of transactions are added

## Procedures_transaction.sql
This anonymous block processes transactions in the NEW_TRANSACTION to TRANSACTION_HISTORY and TRANSACTION_DETAIL and updates ACCOUNT table in the process. It also handles errors eg. if any row of the transaction has invalid transaction types or debits are not equal to credits, then that row including OTHER rows of the transaction are NOT processed.

## Triggers_procedures.sql
This file contains several functions and triggers with business logic for handling payroll entries in the database. It also has functions for checking user permissions and also for exporting data in form of csv
