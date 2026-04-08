# Contents

This folder contains the required instructions to setup the Oracle Data Warehouse and optimize it.

# Prerequisites

## Software & Licenses
- Oracle Linux Version 8 or higher
- Oracle Enterprise Edition License
- Oracle Enterprise Manager

## Packages

- Python 3.11 (or above)
- pip
- sqlplus

# Database Creation

## Oracle RDBMS installer
The Oracle 19C Database installation was run on Oracle Linux 8. Download the oracle-database-preinstall-19c package and run the installer (either in GUI or silent mode). Create the database using Oracle Database Setup Wizard, with a global database name of scikey.orcl.ca, SID scikey, a pluggable database pdb, a 16KB block size, and about 9.2 GB of combined SGA/PGA using ASMM, followed by executing the root scripts the installer generates. Then configure post-install settings like enabling OMF and setting the PDB to auto-start. Finally, edit your bash profile to ensure all environment variables are set.

## Tuning Initialization Parameters
**Huge Pages**

Operating System

    # Calculate and set huge pages
    echo "vm.nr_hugepages = 3850" >> /etc/sysctl.conf
    sysctl -p

    # Verify
    grep HugePages /proc/meminfo

Oracle

    -- Connect as SYSDBA
    sqlplus / as sysdba
    
    -- SGA and PGA targets (~60% of 15.3 GB RAM)
    ALTER SYSTEM SET sga_target = 7680M SCOPE=SPFILE;
    ALTER SYSTEM SET pga_aggregate_target = 1536M SCOPE=SPFILE;
    
    -- Force Oracle to use huge pages (won't start if unavailable)
    ALTER SYSTEM SET use_large_pages = ONLY SCOPE=SPFILE;
    
    -- Restart the instance for SPFILE changes to take effect
    SHUTDOWN IMMEDIATE;
    STARTUP;

**Redo Logs**

    -- Check current redo log groups and members
    SELECT group#, bytes/1024/1024 AS size_mb, status FROM v$log;
    SELECT group#, member FROM v$logfile ORDER BY group#;
    
    -- Add new 600 MB groups (multiplexed across two locations)
    ALTER DATABASE ADD LOGFILE GROUP 4 (
        '/u01/oradata/redo04.log',
        '/u02/oradata/redo04.log'
    ) SIZE 600M;
    
    ALTER DATABASE ADD LOGFILE GROUP 5 (
        '/u01/oradata/redo05.log',
        '/u02/oradata/redo05.log'
    ) SIZE 600M;
    
    ALTER DATABASE ADD LOGFILE GROUP 6 (
        '/u01/oradata/redo06.log',
        '/u02/oradata/redo06.log'
    ) SIZE 600M;
    
    -- Drop old 300 MB groups (must not be CURRENT or ACTIVE)
    -- Force a log switch and checkpoint first
    ALTER SYSTEM SWITCH LOGFILE;
    ALTER SYSTEM CHECKPOINT;
    
    -- Repeat as needed until old groups show INACTIVE
    ALTER DATABASE DROP LOGFILE GROUP 1;
    ALTER DATABASE DROP LOGFILE GROUP 2;
    ALTER DATABASE DROP LOGFILE GROUP 3;
    
    -- Clean up old physical files from OS
    -- rm /u01/oradata/redo01.log /u02/oradata/redo01.log
    -- rm /u01/oradata/redo02.log /u02/oradata/redo02.log
    -- rm /u01/oradata/redo03.log /u02/oradata/redo03.log

**Connection Pooling**

    -- Enable DRCP with 2 brokers and default pool size of 40
    -- Connect as SYSDBA
    BEGIN
        DBMS_CONNECTION_POOL.CONFIGURE_POOL(
            pool_name => 'SYS_DEFAULT_CONNECTION_POOL',
            minsize   => 4,
            maxsize   => 40,
            num_cbrok => 2
        );
    END;
    /
    
    -- Start the connection pool
    EXEC DBMS_CONNECTION_POOL.START_POOL;
    
    -- Verify pool status
    SELECT connection_pool_name, status, maxsize, num_cbrok
    FROM dba_cpool_info;

# Database Architecture

Ensure you are in the current directory within the terminal for the following steps.

## TableSpace and User Creation

Login to sqlplus using OS level authentication with the command: `sqlplus / as sysdba`

Within the sqlplus terminal run the command: `@TableSpace.sql`

## Table Creation

Login to sqlplus as the newly created "scikey" user with the command: `sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca`

Within the sqlplus terminal run the command: `@PartitionedTables.sql`

# Data Manipulation

## Data retreival
Prerequisite: Python 3.10+

Navigate to either the Full_HAL or UPEC_Only directory, depending on which dataset you would like to fetch. The NEED_N field in main.py is the number of records to retrieve. Several fields can be commented out or edited to tweak the type of records retrieved:

**In main.py:**

Filter disciplines:

    FIELD ="Civil Engineering" #"Chemical Engineering", "Computer Science","Political Science","Marketing","Civil Engineering"

and

    if discipline != FIELD:
         continue


**In apimodule.py**

Language filter:

    LANG_FILTER  = 'language_s:en'  # English only
    

    "fq": [LANG_FILTER, KEYWORD_FQ],   # English + must have keywords

If language filter is disabled, the following print statements must be disabled:

    print("HAL English only:", probe([LANG_FILTER]))
    print("HAL English + keywords:", probe([LANG_FILTER, KEYWORD_FQ]))
       
The script is executed as follows:
`python main.py`

## Data Insertion

Before this insertion script is run you must ensure you have the oracledb library installed via: 
`sudo python3.11 -m pip install oracledb`

Data is then loaded via the **dataLoader.py** script. For the following command please fill in the correct JSON file path after the "--file" flag:

`sudo python3.11 dataLoader.py --file <JSON/File/Path>`

NOTE: The script may appear to be hanging after the connection is established with the database but it is working. It takes some time to load and parse the JSON data into memory.

# Advanced Indexes

Indexes are added after data is loaded to save time (for bulk data loading). If indexes were built first, they would have to constantly rebuild themselves after insertions which is slow.

Login to sqlplus as the "scikey" user with the command: `sqlplus scikey/scikeycosc416@localhost:1521/pdb.orcl.ca`

Within the sqlplus terminal run the command: `@AdvancedIndexes.sql`


