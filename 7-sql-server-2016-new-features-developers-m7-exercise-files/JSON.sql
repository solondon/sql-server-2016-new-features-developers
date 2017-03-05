/* =================== JSON in SQL Server 2016 =================== */

USE AdventureWorks2016CTP3
GO

-- ***********************
-- *** Generating JSON ***
-- ***********************

/*** FOR JSON AUTO ***/

-- Relational
SELECT
	Customer.CustomerID,
	Customer.AccountNumber,
	SalesOrder.SalesOrderID,
	SalesOrder.OrderDate
 FROM
	Sales.Customer AS Customer
	INNER JOIN Sales.SalesOrderHeader AS SalesOrder ON SalesOrder.CustomerID = Customer.CustomerID
 WHERE
	Customer.CustomerID BETWEEN 11001 AND 11003
 ORDER BY
	Customer.CustomerID

-- FOR JSON AUTO
SELECT
	Customer.CustomerID,
	Customer.AccountNumber,
	SalesOrder.SalesOrderID,
	SalesOrder.OrderDate
 FROM
	Sales.Customer AS Customer
	INNER JOIN Sales.SalesOrderHeader AS SalesOrder ON SalesOrder.CustomerID = Customer.CustomerID
 WHERE
	Customer.CustomerID BETWEEN 11001 AND 11003
 ORDER BY
	Customer.CustomerID
 FOR JSON AUTO

-- FOR JSON AUTO, ROOT
SELECT
	Customer.CustomerID,
	Customer.AccountNumber,
	SalesOrder.SalesOrderID,
	SalesOrder.OrderDate
 FROM
	Sales.Customer AS Customer
	INNER JOIN Sales.SalesOrderHeader AS SalesOrder ON SalesOrder.CustomerID = Customer.CustomerID
 WHERE
	Customer.CustomerID BETWEEN 11001 AND 11003
 ORDER BY
	Customer.CustomerID
 FOR JSON AUTO, ROOT

-- FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER
SELECT
	Customer.CustomerID,
	Customer.AccountNumber,
	SalesOrder.SalesOrderID,
	SalesOrder.OrderDate
 FROM
	Sales.Customer AS Customer
	INNER JOIN Sales.SalesOrderHeader AS SalesOrder ON SalesOrder.CustomerID = Customer.CustomerID
 WHERE
	Customer.CustomerID = 11003
 ORDER BY
	Customer.CustomerID
 FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER


/*** Storing JSON to variable ***/

-- FOR JSON to an NVARCHAR variable
DECLARE @jsonData AS nvarchar(max)
SET @jsonData =
(
	SELECT
		Customer.CustomerID,
		Customer.AccountNumber,
		SalesOrder.SalesOrderID,
		SalesOrder.OrderDate
	 FROM
		Sales.Customer AS Customer
		INNER JOIN Sales.SalesOrderHeader AS SalesOrder ON SalesOrder.CustomerID = Customer.CustomerID
	 WHERE
		Customer.CustomerID BETWEEN 11001 AND 11003
	 ORDER BY
		Customer.CustomerID
	 FOR JSON AUTO
)
SELECT @jsonData
GO


/*** Nested FOR JSON queries ***/

-- FOR JSON nested in another SELECT
SELECT 
	CustomerID,
	AccountNumber,
	(SELECT SalesOrderID, TotalDue, OrderDate, ShipDate
	  FROM Sales.SalesOrderHeader AS SalesOrder
	  WHERE CustomerID = Customer.CustomerID 
	  FOR JSON AUTO, ROOT('SalesOrders')) AS OrderHeaders
 FROM
	Sales.Customer AS Customer
 WHERE
	Customer.CustomerID BETWEEN 11001 AND 11003
 ORDER BY
	Customer.CustomerID


/*** FOR JSON PATH ***/

-- FOR JSON PATH (simple example)
SELECT
	BusinessEntityID AS [Id],
	JobTitle AS [ContactName.Title],
	FirstName AS [ContactName.First],
	MiddleName AS [ContactName.Middle],
	LastName AS [ContactName.Last],
	Gender AS [PersonalInfo.Gender],
	MaritalStatus AS [PersonalInfo.MaritalStatus],
	VacationHours AS [Hours.Vacation],
	SickLeaveHours AS [Hours.SickLeave]
 FROM
	HumanResources.[vEmployeePersonTemporalInfo]
 WHERE
	BusinessEntityID BETWEEN 1 AND 5
 FOR JSON PATH, ROOT('Contacts'), INCLUDE_NULL_VALUES

-- FOR JSON PATH (nested example)
SELECT 
	CustomerID,
	AccountNumber,
	Contact.FirstName AS [Name.First],
	Contact.LastName AS [Name.Last],
	(SELECT SalesOrderID,
			TotalDue,
			OrderDate, 
			ShipDate,
			(SELECT ProductID, 
					OrderQty, 
					LineTotal
			  FROM Sales.SalesOrderDetail
			  WHERE SalesOrderID = OrderHeader.SalesOrderID
			  FOR JSON PATH) AS OrderDetail
	  FROM Sales.SalesOrderHeader AS OrderHeader
	  WHERE CustomerID = Customer.CustomerID 
	  FOR JSON PATH) AS OrderHeader
 FROM Sales.Customer AS Customer INNER JOIN
	  Person.Person AS Contact ON Contact.BusinessEntityID = Customer.PersonID
 WHERE CustomerID BETWEEN 11001 AND 11002
 FOR JSON PATH


-- *********************************
-- *** Storing and Querying JSON ***
-- *********************************

USE MyDB
GO

/*** ISJSON ***/

DECLARE @jsonData AS nvarchar(max) = N'
[
	{
		"OrderId": 5,
		"CustomerId: 6,
		"OrderDate": "2015-10-10T14:22:27.25-05:00",
		"OrderAmount": 25.9
	},
	{
		"OrderId": 29,
		"CustomerId": 76,
		"OrderDate": "2015-12-10T11:02:36.12-08:00",
		"OrderAmount": 350.25
	}
]'

SELECT ISJSON(@jsonData)	-- Returns false because of missing closing quote on CustomerId property

/*** Store JSON orders data in a table ***/

CREATE TABLE OrdersJson(
 	OrdersId int PRIMARY KEY, 
	OrdersDoc nvarchar(max) NOT NULL DEFAULT '[]',
    CONSTRAINT [CK_OrdersJson_OrdersDoc] CHECK (ISJSON(OrdersDoc) = 1)
)

DECLARE @jsonData AS nvarchar(max) = N'
[
	{
		"OrderId": 5,
		"CustomerId: 6,
		"OrderDate": "2015-10-10T14:22:27.25-05:00",
		"OrderAmount": 25.9
	},
	{
		"OrderId": 29,
		"CustomerId": 76,
		"OrderDate": "2015-12-10T11:02:36.12-08:00",
		"OrderAmount": 350.25
	}
]'

INSERT INTO OrdersJson(OrdersId, OrdersDoc) VALUES (1, @jsonData)	-- Fails because of missing closing quote on CustomerId property

INSERT INTO OrdersJson(OrdersId) VALUES (2)	-- Accepts default empty array

SELECT * FROM OrdersJson

-- Cleanup
DROP TABLE OrdersJson

/*** Store JSON book data in a table for querying ***/

CREATE TABLE BooksJson(
 	BookId int PRIMARY KEY, 
	BookDoc nvarchar(max) NOT NULL,
    CONSTRAINT [CK_BooksJson_BookDoc] CHECK (ISJSON(BookDoc) = 1)
)

INSERT INTO BooksJson VALUES (1, '
	{
		"category": "ITPro",
		"title": "Programming SQL Server",
		"author": "Lenni Lobel",
		"price": {
			"amount": 49.99,
			"currency": "USD"
		},
		"purchaseSites": [
			"amazon.com",
			"booksonline.com"
		]
	}
')

INSERT INTO BooksJson VALUES (2, '
	{
		"category": "Developer",
		"title": "Developing ADO .NET",
		"author": "Andrew Brust",
		"price": {
			"amount": 39.93,
			"currency": "USD"
		},
		"purchaseSites": [
			"booksonline.com"
		]
	}
')

INSERT INTO BooksJson VALUES (3, '
	{
		"category": "ITPro",
		"title": "Windows Cluster Server",
		"author": "Stephen Forte",
		"price": {
			"amount": 59.99,
			"currency": "CAD"
		},
		"purchaseSites": [
			"amazon.com"
		]
	}
')

SELECT * FROM BooksJson

/*** JSON_VALUE ***/

-- Get all ITPro books
SELECT *
 FROM BooksJson
 WHERE JSON_VALUE(BookDoc, '$.category') = 'ITPro'

-- Index the category property
ALTER TABLE BooksJson
 ADD BookCategory AS JSON_VALUE(BookDoc, '$.category')

CREATE INDEX IX_BooksJson_BookCategory
 ON BooksJson(BookCategory)

SELECT *
 FROM BooksJson
 WHERE JSON_VALUE(BookDoc, '$.category') = 'ITPro'

-- Extract other properties
SELECT
	BookId,
	JSON_VALUE(BookDoc, '$.category') AS Category,
	JSON_VALUE(BookDoc, '$.title') AS Title,
	JSON_VALUE(BookDoc, '$.price.amount') AS PriceAmount,
	JSON_VALUE(BookDoc, '$.price.currency') AS PriceCurrency
 FROM
	BooksJson

/*** JSON_QUERY ***/

SELECT
	BookId,
	JSON_VALUE(BookDoc, '$.category') AS Category,
	JSON_VALUE(BookDoc, '$.title') AS Title,
	JSON_VALUE(BookDoc, '$.price.amount') AS PriceAmount,
	JSON_VALUE(BookDoc, '$.price.currency') AS PriceCurrency,
	JSON_QUERY(BookDoc, '$.purchaseSites') AS PurchaseSites
 FROM
	BooksJson

-- Cleanup
DROP TABLE BooksJson

-- **********************
-- *** Using OPENJSON ***
-- **********************

/*** OPENJSON (simple example) ***/

-- Store books as JSON array
DECLARE @BooksJson nvarchar(max) = N'
[
  {
    "category": "ITPro",
    "title": "Programming SQL Server",
    "author": "Lenni Lobel",
    "price": 49.99
  },
  {
    "category": "Developer",
    "title": "Developing ADO .NET",
    "author": "Andrew Brust",
    "price": 39.93
  },
  {
    "category": "ITPro",
    "title": "Windows Cluster Server",
    "author": "Stephen Forte",
    "price": 59.99
  }
]
'

-- Shred the JSON array into multiple rows
SELECT * FROM OPENJSON(@BooksJson)

-- Shred the JSON array into multiple rows with filtering and sorting
SELECT *
 FROM		OPENJSON(@BooksJson, '$') AS b
 WHERE		JSON_VALUE(b.value, '$.category') = 'ITPro'
 ORDER BY	JSON_VALUE(b.value, '$.author') DESC
	
-- Shred the properties of the first object in the JSON array into multiple rows
SELECT *
 FROM		OPENJSON(@BooksJson, '$[0]')

--	0 = null
--	1 = string
--	2 = int
--	3 = bool
--	4 = array
--  5 = object

/*** OPENJSON (parent/child example) ***/

-- Store a person with multiple contacts as JSON object
DECLARE @PersonJson nvarchar(max) = N'
	{
		"Id": 236,
		"Name": {
			"FirstName": "John",
			"LastName": "Doe"
		},
		"Address": {
			"AddressLine": "137 Madison Ave",
			"City": "New York",
			"Province": "NY",
			"PostalCode": "10018"
		},
		"Contacts": [
			{
				"Type": "mobile",
				"Number": "917-777-1234"
			},
			{
				"Type": "home",
				"Number": "212-631-1234"
			},
			{
				"Type": "work",
				"Number": "212-635-2234"
			},
			{
				"Type": "fax",
				"Number": "212-635-2238"
			}
		]
	}
'

-- The header values can be extracted directly from the JSON source
SELECT
	PersonId		= JSON_VALUE(@PersonJson, '$.Id'),
	FirstName		= JSON_VALUE(@PersonJson, '$.Name.FirstName'),
	LastName		= JSON_VALUE(@PersonJson, '$.Name.LastName'),
	AddressLine		= JSON_VALUE(@PersonJson, '$.Address.AddressLine'),
	City			= JSON_VALUE(@PersonJson, '$.Address.City'),
	Province		= JSON_VALUE(@PersonJson, '$.Address.Province'),
	PostalCode		= JSON_VALUE(@PersonJson, '$.Address.PostalCode')

-- To produce multiple child rows for each contact, use OPENJSON
SELECT
	PersonId		= JSON_VALUE(@PersonJson, '$.Id'),	-- FK
	ContactType		= JSON_VALUE(c.value, '$.Type'),
	ContactNumber	= JSON_VALUE(c.value, '$.Number')
 FROM
	OPENJSON(@PersonJson, '$.Contacts') AS c

/*** OPENJSON (with schema) ***/

-- Store a batch of orders in JSON
DECLARE @json nvarchar(max) = N'
{
  "BatchId": 442,
  "Orders": [
    {
      "OrderNumber": "SO43659",
      "OrderDate": "2011-05-31T00:00:00",
      "AccountNumber": "AW29825",
      "Item": {
        "Quantity": 1,
        "Price": 2024.9940
      }
    },
    {
      "OrderNumber": "SO43661",
      "OrderDate": "2011-06-01T00:00:00",
      "AccountNumber": "AW73565",
      "Item": {
        "Quantity": 3,
        "Price": 2024.9940
      }
    }
  ]
}
'

-- Query with default schema
SELECT *
 FROM OPENJSON (@json, '$.Orders')

-- Query with explicit schema
SELECT *
 FROM OPENJSON (@json, '$.Orders')
 WITH ( 
	OrderNumber	varchar(200),
	OrderDate	datetime,
	Customer	varchar(200)    '$.AccountNumber',
	Item		nvarchar(max)	'$.Item' AS JSON,
	Quantity	int				'$.Item.Quantity',
	Price		money			'$.Item.Price'
) 
