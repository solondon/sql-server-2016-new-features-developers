/* =================== Stretch Database in SQL Server 2016 =================== */

CREATE DATABASE MyStretchedDB
GO

USE MyStretchedDB 
GO

/* Demo 1 - entire table */

-- Create a local table and populate it with a few rows
CREATE TABLE StretchTest (
	Id int IDENTITY,
	FirstName varchar(20),
	LastName varchar(20),
	CreatedAt datetime2
)

INSERT INTO StretchTest(FirstName, LastName, CreatedAt) VALUES
 ('John', 'Smith', DATEFROMPARTS(2016, 1, 1)),
 ('Steven', 'Jacobs', DATEFROMPARTS(2016, 1, 3)),
 ('Nick', 'Morrison', DATEFROMPARTS(2016, 1, 20)),
 ('Andy', 'Martin', DATEFROMPARTS(2016, 1, 1))

SELECT * FROM StretchTest ORDER BY Id

/* Enable stretch on the local server */

-- Configure the local server to enable stretch
EXEC sp_configure 'remote data archive', 1
RECONFIGURE 

/* Enable stretch on the local database */

-- Create master key
CREATE MASTER KEY
 ENCRYPTION BY PASSWORD = 'Hrd2GessP@ssw0rd!'

-- Create credential for communication between local and Azure servers (uses master key for encryption)
CREATE DATABASE SCOPED CREDENTIAL MyStretchedDBScopedCredentialName
    WITH IDENTITY = 'lenni' , SECRET = 'Big$ecret1'

-- Alter the local database to enable stretch (~ 3 min)
ALTER DATABASE MyStretchedDB
    SET REMOTE_DATA_ARCHIVE = ON (
        SERVER = 'lennistretchdemo.database.windows.net',
        CREDENTIAL = MyStretchedDBScopedCredentialName)

-- *** view remote database - has no tables yet ***

-- Discover databases enabled for stretch
SELECT name, is_remote_data_archive_enabled FROM sys.databases

-- Discover cloud databases being used for stretch
SELECT * FROM sys.remote_data_archive_databases

/* Enable stretch on the local table */

-- Enable stretch, but don't start migration
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = PAUSED))

-- Discover tables enabled for stretch
SELECT name, is_remote_data_archive_enabled FROM sys.tables

-- Monitor migration status
SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

-- Start migration
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = OUTBOUND))

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

SELECT * FROM StretchTest ORDER BY Id

-- *** view remote data ***

-- Load another 100 rows and monitor
INSERT INTO StretchTest
 SELECT TOP 100 FirstName, LastName, DATEFROMPARTS(2016, 2, 1)
 FROM AdventureWorks2016CTP3.Person.Person

SELECT * FROM StretchTest ORDER BY Id

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

-- *** view remote data ***

-- Can't UPDATE/DELETE
DELETE FROM StretchTest WHERE Id = 2
UPDATE StretchTest SET FirstName = 'Jim' WHERE Id = 3

/* Disable stretch */

-- Unmigrate before disabling
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = INBOUND))

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

SELECT * FROM StretchTest ORDER BY Id

-- Disable stretch on the table
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = OFF (MIGRATION_STATE = PAUSED))

-- *** delete remote table ***

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'
SELECT * FROM StretchTest ORDER BY Id
GO

-- Add "IsOld" for partially stretched table
ALTER TABLE StretchTest
 ADD IsOld bit
GO

UPDATE StretchTest SET IsOld = 0

SELECT * FROM StretchTest ORDER BY Id
GO

-- Create filter predicate
CREATE FUNCTION dbo.fnStretchPredicate(@IsOld bit)
RETURNS TABLE
WITH SCHEMABINDING 
AS 
RETURN
	SELECT 1 AS is_eligible
	 WHERE @IsOld = 1
GO

-- Enable stretch with filter predicate
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = ON (
		FILTER_PREDICATE = dbo.fnStretchPredicate(IsOld),
		MIGRATION_STATE = OUTBOUND))
GO

-- Mark 2 "cold" rows
UPDATE StretchTest
 SET IsOld = 1 WHERE Id IN (1, 3)

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

SELECT * FROM StretchTest ORDER BY Id

-- *** view remote data ***

-- Mark 3 more "cold" rows
UPDATE StretchTest
 SET IsOld = 1 WHERE Id IN (6, 8, 9)

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

SELECT * FROM StretchTest ORDER BY Id

-- SQL Server knows when it needs to run a remote database query and when it doesn't
SELECT * FROM StretchTest WHERE LastName > 'M' ORDER BY Id
SELECT * FROM StretchTest WHERE LastName > 'M' AND IsOld = 0 ORDER BY Id

-- Can't reverse the status once migrated
UPDATE StretchTest
 SET IsOld = 0 WHERE Id = 3

-- Disable stretch on the table
ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = INBOUND))

SELECT * FROM sys.dm_db_rda_migration_status WHERE migrated_rows > 0
EXEC sp_spaceused @objname = 'dbo.StretchTest'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused @objname = 'dbo.StretchTest', @mode = 'REMOTE_ONLY'

ALTER TABLE StretchTest
	SET (REMOTE_DATA_ARCHIVE = OFF (MIGRATION_STATE = PAUSED))

-- Disable stretch on the database
ALTER DATABASE MyStretchedDB
    SET REMOTE_DATA_ARCHIVE = OFF

-- Cleanup
EXEC sp_configure 'remote data archive', 0
RECONFIGURE 
GO

DROP TABLE StretchTest
DROP DATABASE SCOPED CREDENTIAL MyStretchedDBScopedCredentialName
DROP MASTER KEY
GO

-- DROP both databases

