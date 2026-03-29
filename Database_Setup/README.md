#Contents

This folder contains the required instructions to setup the Oracle Data Warehouse and optimize it.

#Prerequisites

##Software & Licenses
- Oracle Linux Version 8 or higher
- Oracle Enterprise Edition License
- Oracle Enterprise Manager

##Packages

- Python 3.11 (or above)
- pip
- sqlplus

#Database Creation

##Oracle RDBMS installer
-James

##Tuning Initialization Parameters
-James

#Database Architecture

Ensure you are in the current directory for the following steps.

##TableSpace and User Creation

Login to sqlplus using OS level authentication with the command: `sqlplus / as sysdba`

Within the sqlplus terminal run the command: `@TableSpace.sql`

##Table Creation

Login to sqlplus as the newly created "scikey" user with the command: `sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca`

Within the sqlplus terminal run the command: `@PartitionedTables.sql`

#Data Manipulation

##Data retreival
-James

##Data Insertion

Before this insertion script is run you must ensure you have the oracledb library installed via: 
`sudo python3.11 -m pip install oracledb`

Data is then loaded via the **dataLoader.py** script. For the following command please fill in the correct JSON file path after the "--file" flag:

`sudo python3.11 dataLoader.py --file <JSON/File/Path>`

NOTE: The script may appear to be hanging after the connection is established with the database but it is working. It takes some time to load and parse the JSON data into memory.

#Advanced Indexes

Indexes are added after data is loaded to save time (for bulk data loading). If indexes were built first, they would have to constantly rebuild themselves after insertions which is slow.

Login to sqlplus as the "scikey" user with the command: `sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca`

Within the sqlplus terminal run the command: `@AdvancedIndexes.sql`


