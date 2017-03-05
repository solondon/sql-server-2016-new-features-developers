/* =================== Dynamic Data Masking (DDM) =================== */

CREATE DATABASE MyDB
GO

USE MyDB
GO

/* Dynamic Data Masking Demo */

-- Create table with a few masked columns
CREATE TABLE Membership(
	MemberID int IDENTITY PRIMARY KEY,
	FirstName varchar(100) MASKED WITH (FUNCTION = 'partial(2, "...", 2)') NULL,
	LastName varchar(100) NOT NULL,
	Phone varchar(12) MASKED WITH (FUNCTION = 'default()') NULL,
	Email varchar(100) MASKED WITH (FUNCTION = 'email()') NULL)

-- Discover all masked column in the database
SELECT
	t.name AS TableName,
	mc.name AS ColumnName,
	mc.masking_function AS MaskingFunction
FROM
	sys.masked_columns AS mc
	INNER JOIN sys.tables AS t ON mc.[object_id] = t.[object_id]

-- Populate table
INSERT INTO Membership (FirstName, LastName, Phone, Email) VALUES 
 ('Roberto', 'Tamburello', '555.123.4567', 'RTamburello@contoso.com'),
 ('Janice', 'Galvin', '555.123.4568', 'JGalvin@contoso.com.co'),
 ('Dan', 'Mu', '555.123.4569', 'ZMu@contoso.net'),
 ('Jane', 'Smith', '454.222.5920', 'Jane.Smith@hotmail.com'),
 ('Danny', 'Jones', '674.295.7950', 'Danny.Jones@hotmail.com')

-- Current user dbo has UNMASK permission
SELECT * FROM Membership

-- Create view to show users and their permissions
GO
CREATE VIEW vwShowUsers AS
SELECT
	UserName		= pr.name,
	LoginName		= l.loginname,
	LoginType		= pr.type_desc,
	PermissionState	= pe.state_desc,
	PermissionName	= pe.permission_name,
	PermissionClass	= pe.class_desc,
	ObjectName		= o.name,
	ObjectType		= o.type_desc
FROM
	sys.database_principals AS pr
	INNER JOIN sys.database_permissions AS pe ON pe.grantee_principal_id = pr.principal_id
	INNER JOIN sys.sysusers AS u ON u.uid = pr.principal_id
	LEFT OUTER JOIN sys.objects AS o ON o.object_id = pe.major_id
	LEFT OUTER JOIN master..syslogins AS l ON u.sid = l.sid
WHERE
	pr.name in ('dbo', 'TestUser')
GO

-- The currently connected login is mapped to user dbo, with full permissions implied
SELECT * FROM vwShowUsers

-- Create TestUser with SELECT permission on the table, but not with UNMASK permission
CREATE USER TestUser WITHOUT LOGIN
SELECT * FROM vwShowUsers
GRANT SELECT ON Membership TO TestUser
SELECT * FROM vwShowUsers

-- As TestUser, the data is masked
EXECUTE AS USER = 'TestUser'
SELECT * FROM Membership
REVERT
GO

-- Let TestUser see unmasked data
GRANT UNMASK TO TestUser
SELECT * FROM vwShowUsers
EXECUTE AS USER = 'TestUser'
SELECT * FROM Membership
REVERT 
GO

-- Removing the UNMASK permission
REVOKE UNMASK FROM TestUser
EXECUTE AS USER = 'TestUser'
SELECT * FROM Membership
REVERT 
GO

-- Demonstrate different masking functions against different data types
CREATE TABLE MaskingSample(
	Label varchar(32) NOT NULL,
	-- "default" provides full masking of all data types
	default_varchar			varchar(100)	MASKED WITH (FUNCTION = 'default()') DEFAULT('varchar string'),
	default_char			char(20)		MASKED WITH (FUNCTION = 'default()') DEFAULT('char string'),
	default_text			text			MASKED WITH (FUNCTION = 'default()') DEFAULT('text string'),
	default_bit				bit				MASKED WITH (FUNCTION = 'default()') DEFAULT(0),
	default_int				int				MASKED WITH (FUNCTION = 'default()') DEFAULT(256),
	default_bigint			bigint			MASKED WITH (FUNCTION = 'default()') DEFAULT(2560),
	default_decimal			decimal			MASKED WITH (FUNCTION = 'default()') DEFAULT(5.5),
	default_date			date			MASKED WITH (FUNCTION = 'default()') DEFAULT(SYSDATETIME()),
	default_time			time			MASKED WITH (FUNCTION = 'default()') DEFAULT(SYSDATETIME()),
	default_datetime2		datetime2		MASKED WITH (FUNCTION = 'default()') DEFAULT(SYSDATETIME()),
	default_datetimeoffset	datetimeoffset	MASKED WITH (FUNCTION = 'default()') DEFAULT(SYSDATETIME()),
	default_varbinary		varbinary(max)	MASKED WITH (FUNCTION = 'default()') DEFAULT(0x424F),
	default_xml				xml				MASKED WITH (FUNCTION = 'default()') DEFAULT('<sample>hello</sample>'),
	default_hierarchyid		hierarchyid		MASKED WITH (FUNCTION = 'default()') DEFAULT('/1/2/3/'),
	default_geography		geography		MASKED WITH (FUNCTION = 'default()') DEFAULT('POINT(0 0)'),
	default_geometry		geometry		MASKED WITH (FUNCTION = 'default()') DEFAULT('LINESTRING(0 0, 5 5)'),
	-- "partial" provides partial masking of string data types
	partial_varchar			varchar(100)	MASKED WITH (FUNCTION = 'partial(2, "...", 2)') DEFAULT('varchar string'),
	partial_char			char(20)		MASKED WITH (FUNCTION = 'partial(2, "...", 2)') DEFAULT('char string'),
	partial_text			text			MASKED WITH (FUNCTION = 'partial(2, "...", 2)') DEFAULT('text string'),
	-- "email" provides email-format masking of string data types
	email_varchar			varchar(100)	MASKED WITH (FUNCTION = 'email()') DEFAULT('varchar string'),
	email_char				char(20)		MASKED WITH (FUNCTION = 'email()') DEFAULT('char string'),
	email_text				text			MASKED WITH (FUNCTION = 'email()') DEFAULT('text string'),
	-- "partial" can simulate "email"
	partial_email_varchar	varchar(100)	MASKED WITH (FUNCTION = 'partial(1, "XXX@XXXX.com", 0)') DEFAULT('varchar email string'),
	-- "random" provides random masking of numeric data types
	random_bit				bit				MASKED WITH (FUNCTION = 'random(0, 1)') DEFAULT(0),
	random_int				int				MASKED WITH (FUNCTION = 'random(1, 12)') DEFAULT(256),
	random_bigint			bigint			MASKED WITH (FUNCTION = 'random(1001, 999999)') DEFAULT(2560),
	random_decimal			decimal			MASKED WITH (FUNCTION = 'random(100, 200)') DEFAULT(5.5))

-- Populate table
INSERT INTO MaskingSample (Label) VALUES ('Row1'), ('Row2'), ('Row3'), ('Row4'), ('Row5'), ('Row6')

-- View unmasked data
SELECT * FROM MaskingSample

-- View masked data
GRANT SELECT ON MaskingSample TO TestUser

-- As TestUser, the data is masked
EXECUTE AS USER = 'TestUser'
SELECT * FROM MaskingSample
SELECT * FROM MaskingSample
REVERT
GO

-- Cleanup
DROP VIEW vwShowUsers
DROP USER TestUser
DROP TABLE Membership
DROP TABLE MaskingSample
