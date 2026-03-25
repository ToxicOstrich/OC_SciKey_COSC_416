ALTER SESSION SET CONTAINER = pdb;

DROP TABLESPACE scikey_data INCLUDING CONTENTS AND DATAFILES;

DROP TABLESPACE scikey_index INCLUDING CONTENTS AND DATAFILES;

DROP USER scikey CASCADE;

CREATE TABLESPACE scikey_data DATAFILE '/u01/app/oracle/oradata/SCIKEY/scikey_data01.dbf' SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE 25G;

CREATE TABLESPACE scikey_index DATAFILE '/u01/app/oracle/oradata/SCIKEY/scikey_index01.dbf' SIZE 2G AUTOEXTEND ON MAXSIZE 5G;

CREATE USER scikey IDENTIFIED BY scikeycosc416 DEFAULT TABLESPACE scikey_data TEMPORARY TABLESPACE temp QUOTA UNLIMITED ON scikey_data QUOTA UNLIMITED ON scikey_index; 

GRANT CREATE SESSION TO scikey;
GRANT RESOURCE TO scikey;
GRANT CREATE VIEW TO scikey;
GRANT UNLIMITED TABLESPACE TO scikey;

------------------------------------------------------------------

-- sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca

-- sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca <<EOF
-- SELECT table_name FROM user_tables 
-- WHERE table_name IN ('DOCUMENT','AUTHOR','KEYWORD','ORGANISM','DOC_AUTHOR','DOC_KEYWORD','AUTHOR_ORGANISM');

-- sudo -E python3.11 dataLoader.py --file ./hal_750k.json

sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca
SELECT table_name FROM user_tables 
WHERE table_name IN ('DOCUMENT','AUTHOR','KEYWORD','ORGANISM','DOC_AUTHOR','DOC_KEYWORD','AUTHOR_ORGANISM');

