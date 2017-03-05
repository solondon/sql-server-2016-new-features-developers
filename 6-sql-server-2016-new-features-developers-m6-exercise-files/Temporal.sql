/* =================== Temporal Data =================== */

USE MyDB
GO


/* Creating a new temporal table */

-- Create system-versioned user table (temporal table) with auto-generated history table name
CREATE TABLE Department 
(
	DepartmentID        int NOT NULL IDENTITY(1,1) PRIMARY KEY, 
	DepartmentName      varchar(50) NOT NULL, 
	ManagerID           int NULL, 
	ValidFrom           datetime2 GENERATED ALWAYS AS ROW START NOT NULL, 
	ValidTo             datetime2 GENERATED ALWAYS AS ROW END   NOT NULL,   
	PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)   
)
WITH (SYSTEM_VERSIONING = ON)
GO

-- Show tables (parent table and temporal history table)
SELECT
	object_id,
	name,
	temporal_type,
	temporal_type_desc,
	history_table_id
 FROM
	sys.tables
 WHERE
	object_id = OBJECT_ID('dbo.Department', 'U') OR
	object_id = ( 
		SELECT history_table_id 
		FROM sys.tables
		WHERE object_id = OBJECT_ID('dbo.Department', 'U')
)

GO

-- To delete, first turn off system versioning, then drop the tables individually
ALTER TABLE Department SET (SYSTEM_VERSIONING = OFF)
DROP TABLE Department
DROP TABLE MSSQL_TemporalHistoryFor_xxxxxxxxx

-- Create system-versioned user table (temporal table) with custom history table name (must specify schema)
CREATE TABLE Department 
(
	DepartmentID        int NOT NULL IDENTITY(1,1) PRIMARY KEY, 
	DepartmentName      varchar(50) NOT NULL, 
	ManagerID           int NULL, 
	ValidFrom           datetime2 GENERATED ALWAYS AS ROW START NOT NULL, 
	ValidTo             datetime2 GENERATED ALWAYS AS ROW END   NOT NULL,   
	PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)   
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.DepartmentHistory))

-- Cleanup
ALTER TABLE Department SET (SYSTEM_VERSIONING = OFF)
DROP TABLE Department
DROP TABLE DepartmentHistory
GO


/* Converting an existing table to temporal */

CREATE TABLE Employee(
	EmployeeId int PRIMARY KEY,
	FirstName varchar(20) NOT NULL,
	LastName varchar(20) NOT NULL,
	DepartmentName varchar(50) NOT NULL
)
GO

INSERT INTO Employee (EmployeeId, FirstName, LastName, DepartmentName) VALUES
 (1, 'Ken', 'Sanchez', 'Executive'),
 (2, 'Terri', 'Duffy', 'Engineering'),
 (3, 'Roberto', 'Tamburello', 'Engineering'),
 (4, 'Rob', 'Walters', 'Engineering'),
 (5, 'Gail', 'Erickson', 'Engineering'),
 (6, 'Jossef', 'Goldberg', 'Engineering'),
 (7, 'Dylan', 'Miller', 'Support'),
 (8, 'Diane', 'Margheim', 'Support'),
 (9, 'Gigi', 'Matthew', 'Support'),
 (10, 'Michael', 'Raheem', 'Support')
GO

SELECT * FROM Employee

-- Convert to temporal table by adding required datetime2 column pair in PERIOD FOR SYSTEM_TIME
ALTER TABLE Employee ADD
    StartDate datetime2 GENERATED ALWAYS AS ROW START NOT NULL DEFAULT CAST('1900-01-01 00:00:00.0000000' AS datetime2),
    EndDate   datetime2 GENERATED ALWAYS AS ROW END   NOT NULL DEFAULT CAST('9999-12-31 23:59:59.9999999' AS datetime2),
	PERIOD FOR SYSTEM_TIME (StartDate, EndDate)
GO

-- Turn on temporal (table must have a PK and SYSTEM_TIME period)
ALTER TABLE Employee 
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO


/* Querying temporal data */

-- History table starts out empty with no changes in parent table
SELECT * FROM Employee
SELECT * FROM EmployeeHistory

-- Update row #5 three times (FirstName once, and DepartmentName twice)
UPDATE Employee SET FirstName = 'Gabriel' WHERE EmployeeId = 5

-- (wait)
UPDATE Employee SET DepartmentName = 'Support' WHERE EmployeeId = 5

-- (wait)
UPDATE Employee SET DepartmentName = 'Executive' WHERE EmployeeId = 5

-- Delete row #8
DELETE Employee WHERE EmployeeId = 8
GO
 
-- History table shows the changes
SELECT * FROM Employee
SELECT * FROM EmployeeHistory ORDER BY EmployeeId, StartDate
GO

-- *** Simulate longer time lapses ***

-- Disable temporal
ALTER TABLE Employee SET (SYSTEM_VERSIONING = OFF)
GO

-- First update was 35 days ago
UPDATE EmployeeHistory SET
	EndDate = DATEADD(D, -35, EndDate)
		WHERE FirstName = 'Gail'

-- Second was 25 days ago
UPDATE EmployeeHistory SET
	StartDate = DATEADD(D, -35, StartDate),
	EndDate = DATEADD(D, -25, EndDate)
		WHERE FirstName = 'Gabriel' AND DepartmentName = 'Engineering'

-- Third was just now
UPDATE EmployeeHistory SET
	StartDate = DATEADD(D, -25, StartDate)
		WHERE FirstName = 'Gabriel' AND DepartmentName = 'Support'
 
-- Delete was 25 days ago
UPDATE EmployeeHistory SET
	EndDate = DATEADD(D, -25, EndDate)
		WHERE EmployeeId = 8

-- Re-enable temporal
ALTER TABLE Employee 
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO
 
-- View the datetime changes
SELECT * FROM Employee
SELECT * FROM EmployeeHistory ORDER BY EmployeeId, StartDate
GO

-- *** now run point-in-time queries ***

-- See how the data changed over time
DECLARE @TwoMinutesAgo datetime2 = DATEADD(s, -120, SYSDATETIME())
DECLARE @ThirtyDaysAgo datetime2 = DATEADD(d, -30, SYSDATETIME())
DECLARE @FourtyDaysAgo datetime2 = DATEADD(d, -40, SYSDATETIME())
																				-- as of		#5								#8
																				-- ------------	-------------------------------	---------
SELECT * FROM Employee ORDER BY EmployeeId										-- now			Gabriel Erickson, Executive		Deleted
SELECT * FROM Employee FOR SYSTEM_TIME AS OF @TwoMinutesAgo ORDER BY EmployeeId	-- 2 min ago	Gabriel Erickson, Support		Deleted
SELECT * FROM Employee FOR SYSTEM_TIME AS OF @ThirtyDaysAgo ORDER BY EmployeeId	-- 30 days ago	Gabriel Erickson, Engineering	Exists
SELECT * FROM Employee FOR SYSTEM_TIME AS OF @FourtyDaysAgo ORDER BY EmployeeId	-- 40 days ago	Gail Erickson, Engineering		Exists


/* Combining temporal with stretch */

-- Configure the local server to enable stretch
EXEC sp_configure 'remote data archive', 1
RECONFIGURE 

-- Create master key
CREATE MASTER KEY
 ENCRYPTION BY PASSWORD = 'Hrd2GessP@ssw0rd!'

-- Create credential for communication between local and Azure servers (uses master key)
CREATE DATABASE SCOPED CREDENTIAL MyDBScopedCredentialName
    WITH IDENTITY = 'lenni' , SECRET = 'Big$ecret1'

-- Alter the local database to enable stretch (~ 3 min)
ALTER DATABASE MyDB
    SET REMOTE_DATA_ARCHIVE = ON (
        SERVER = 'lennistretchdemo.database.windows.net',
        CREDENTIAL = MyDBScopedCredentialName)

-- Enable stretch on the temporal history table
ALTER TABLE EmployeeHistory	SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = OUTBOUND))

-- Monitor migration status
SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory'
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory', @mode = 'REMOTE_ONLY'

SELECT * FROM Employee
SELECT * FROM EmployeeHistory

GO

-- Create filter predicate
CREATE FUNCTION dbo.fnStretchPredicate(@EndDate datetime2)
RETURNS TABLE
WITH SCHEMABINDING 
AS 
RETURN
	SELECT 1 AS is_eligible
	 WHERE @EndDate <= DATEFROMPARTS(2016, 8, 1)
GO

-- Enable stretch with filter predicate
ALTER TABLE EmployeeHistory
	SET (REMOTE_DATA_ARCHIVE = ON (
		MIGRATION_STATE = INBOUND))
GO
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory', @mode = 'LOCAL_ONLY'
-- (drop remote table)
ALTER TABLE EmployeeHistory
	SET (REMOTE_DATA_ARCHIVE = ON (
		FILTER_PREDICATE = dbo.fnStretchPredicate(EndDate),
		MIGRATION_STATE = OUTBOUND))
GO
SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory'
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.EmployeeHistory', @mode = 'REMOTE_ONLY'

-- Cleanup

ALTER TABLE EmployeeHistory SET (REMOTE_DATA_ARCHIVE = OFF (MIGRATION_STATE = PAUSED))
ALTER DATABASE MyDB SET REMOTE_DATA_ARCHIVE = OFF
EXEC sp_configure 'remote data archive', 0
RECONFIGURE 

ALTER TABLE Employee SET (SYSTEM_VERSIONING = OFF)
DROP TABLE Employee
DROP TABLE EmployeeHistory
DROP DATABASE SCOPED CREDENTIAL MyDBScopedCredentialName
DROP MASTER KEY
GO

-- DROP both databases

/* Hidden period columns */

USE MyDB
GO

-- Create and populate a system-versioned table with hidden period columns
CREATE TABLE Employee(
	EmployeeId int PRIMARY KEY,
	FirstName varchar(20) NOT NULL,
	LastName varchar(20) NOT NULL,
	DepartmentName varchar(50) NOT NULL,
    StartDate datetime2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    EndDate   datetime2 GENERATED ALWAYS AS ROW END HIDDEN   NOT NULL,
	PERIOD FOR SYSTEM_TIME (StartDate, EndDate)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO

INSERT INTO Employee (EmployeeId, FirstName, LastName, DepartmentName) VALUES
 (1, 'Ken', 'Sanchez', 'Executive'),
 (2, 'Terri', 'Duffy', 'Engineering'),
 (3, 'Roberto', 'Tamburello', 'Engineering')

-- Hidden period columns are not returned with SELECT *
SELECT * FROM Employee

-- Hidden period columns can be returned explicitly
SELECT EmployeeId, LastName, StartDate, EndDate FROM Employee


/* Schema changes */

-- Add a column (gets added to history table automatically)
ALTER TABLE Employee
   ADD RegionID int NULL

SELECT * FROM Employee
SELECT * FROM EmployeeHistory

-- Cleanup
ALTER TABLE Employee SET (SYSTEM_VERSIONING = OFF)
DROP TABLE Employee
DROP TABLE EmployeeHistory
