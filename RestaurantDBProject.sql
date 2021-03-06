USE [master]
GO
/****** Object:  Database [u_kroczek]    Script Date: 19-01-2021 21:22:02 ******/
/*Authors: Marcin Kroczek, Adam Niemiec*/
CREATE DATABASE [u_kroczek]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'u_kroczek', FILENAME = N'/var/opt/mssql/data/u_kroczek.mdf' , SIZE = 73728KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'u_kroczek_log', FILENAME = N'/var/opt/mssql/data/u_kroczek_log.ldf' , SIZE = 66048KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
ALTER DATABASE [u_kroczek] SET COMPATIBILITY_LEVEL = 150
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [u_kroczek].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [u_kroczek] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [u_kroczek] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [u_kroczek] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [u_kroczek] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [u_kroczek] SET ARITHABORT OFF 
GO
ALTER DATABASE [u_kroczek] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [u_kroczek] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [u_kroczek] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [u_kroczek] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [u_kroczek] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [u_kroczek] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [u_kroczek] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [u_kroczek] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [u_kroczek] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [u_kroczek] SET  ENABLE_BROKER 
GO
ALTER DATABASE [u_kroczek] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [u_kroczek] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [u_kroczek] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [u_kroczek] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [u_kroczek] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [u_kroczek] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [u_kroczek] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [u_kroczek] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [u_kroczek] SET  MULTI_USER 
GO
ALTER DATABASE [u_kroczek] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [u_kroczek] SET DB_CHAINING OFF 
GO
ALTER DATABASE [u_kroczek] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [u_kroczek] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [u_kroczek] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [u_kroczek] SET QUERY_STORE = OFF
GO
USE [u_kroczek]
GO
/****** Object:  UserDefinedFunction [dbo].[CanAddDishToMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[CanAddDishToMenu](@DishID int, @MenuID int)
RETURNS bit
AS
BEGIN
	DECLARE @CurrentMenu int, @RemovalDate datetime, @InsertionDate datetime
	EXEC @InsertionDate = dbo.GetMenuInsertionDate @MenuID --Data w ktorej planujemy wprowadzic nowe menu
	EXEC @CurrentMenu = dbo.GetCurrentMenu --Aktualnie obowiazujace menu
	EXEC @RemovalDate = dbo.GetDishRemovalDate @DishID --Data wycofania dania z jakiegos menu
	IF (DATEDIFF(MONTH, @RemovalDate, @InsertionDate) < 1)
	BEGIN
		RETURN 0;
	END
	ELSE IF ((SELECT COUNT(*) FROM MenuDetails WHERE MenuID = @CurrentMenu AND DishID = @DishID) != 0)
	--Danie bylo w poprzednim menu
	BEGIN
		DECLARE @SimilarDishes int, @NumberOfDIshes int
		EXEC @SimilarDishes = dbo.GetNumberOfSimilarDishes @CurrentMenu, @MenuID
		EXEC @NumberOfDIshes = dbo.GetNumberOfDishesInMenu @CurrentMenu
		IF ((@SimilarDishes+1) > @NumberOfDIshes/2)
		BEGIN
			RETURN 0;
		END
	END
	RETURN 1;
END
GO
/****** Object:  UserDefinedFunction [dbo].[CanAddDishToOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--ORDER_DETAILS

CREATE FUNCTION [dbo].[CanAddDishToOrder](@DishID int, @OrderID int)
RETURNS bit
AS
BEGIN
	DECLARE @CurrentMenu int, @SeafoodID int, @DoesIncludeSeafood bit, @BookedDate datetime, @OrderDate datetime
	EXEC @CurrentMenu = dbo.GetCurrentMenu --Aktualnie obowiazujace menu
	EXEC @SeafoodID = dbo.GetCategoryID 'seafood'
	EXEC @DoesIncludeSeafood = dbo.DoesDishIncludeCategory @DishID, @SeafoodID
	EXEC @BookedDate = dbo.GetBookedDate @OrderID
	EXEC @OrderDate = dbo.GetOrderDate @OrderID
	IF (@DoesIncludeSeafood = 1)
	BEGIN
		IF (DATENAME(DW, @BookedDate) IN ('Thursday', 'Friday', 'Saturday') AND DATEDIFF(DAY, @OrderDate, @BookedDate) >= DATEPART(DW, @BookedDate)-1)
		BEGIN
			RETURN 1;
		END
	END
	ELSE IF ((SELECT Availability FROM MenuDetails WHERE MenuID = @CurrentMenu AND DishID = @DishID) = 1)
	--Danie jest dostepne
	BEGIN
		RETURN 1;
	END
	RETURN 0;
END
GO
/****** Object:  UserDefinedFunction [dbo].[CheckIfIndividual]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[CheckIfIndividual] (@CustomerID int)
RETURNS BIT
AS
BEGIN
    DECLARE @result bit

    IF ((SELECT CustomerType FROM Customers WHERE CustomerID = @CustomerID) = 'individual')
        SET @result = 1
    ELSE SET @result = 0

    RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[CheckReservationConditions]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
------------------Reservations--------------------

CREATE FUNCTION [dbo].[CheckReservationConditions] (@CustomerID int, @OrderID int, @NumberOfPeople int)
RETURNS bit
AS
BEGIN
    DECLARE @result bit, @isIndividual bit, @AvailablePlaces int

    EXEC @AvailablePlaces = GetNumberOfFreeSeats

    EXEC @isIndividual = CheckIfIndividual @CustomerID

    IF (@CustomerID IS NULL OR @OrderID IS NULL OR @AvailablePlaces < @NumberOfPeople)
        SET @result = 0
    ELSE IF @isIndividual = 0
        SET @result = 1
    ELSE
        BEGIN 
            DECLARE @OrderValue int, @NumberOfCustomerOrders int
            SELECT @OrderValue = Orders.Value FROM Orders WHERE OrderID = @OrderID
            SELECT @NumberOfCustomerOrders = COUNT(*) FROM Orders WHERE CustomerID = @CustomerID

            IF (@OrderValue >= 200 OR (@OrderValue >=50 AND @NumberOfCustomerOrders >= 5))
                SET @result = 1
            ELSE SET @result = 0 
        END
    
    RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[DoesDishIncludeCategory]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DISH_DETAILS

CREATE FUNCTION [dbo].[DoesDishIncludeCategory](@DishID int, @CategoryID int)
RETURNS bit
AS
BEGIN
	IF (SELECT COUNT(*) FROM DishDetails DD
		 INNER JOIN Products P
		 ON DD.ProductID = P.ProductID
		 WHERE DishID = @DishID AND P.CategoryID = @CategoryID) > 0
	BEGIN
		RETURN 1;
	END
	RETURN 0;
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetBookedDate]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBookedDate](@OrderID int)
RETURNS datetime
AS
BEGIN
	RETURN(SELECT ReceiveDate FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetCategoryID]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetCategoryID](@CategoryName nvarchar(30))
RETURNS int
AS
BEGIN
	RETURN (SELECT CategoryID FROM Categories WHERE CategoryName = @CategoryName)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentDishPrice]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetCurrentDishPrice](@DishID int)
RETURNS decimal(20,2)
AS
BEGIN
	DECLARE @Result decimal(20,2) = (SELECT DishPrice FROM Dishes WHERE DishID = @DishID)
	RETURN @Result
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--MENU

CREATE FUNCTION [dbo].[GetCurrentMenu]() --zwraca obecnie obowiazujace menu
RETURNS int
AS
BEGIN
	RETURN (SELECT MenuID FROM Menu WHERE InsertionDate <= GETDATE() AND RemovalDate >= GETDATE());
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetCustomerFromOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetCustomerFromOrder](@OrderID int)
RETURNS int
AS
BEGIN
	RETURN(SELECT CustomerID FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetDishRemovalDate]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetDishRemovalDate](@DishID int)
RETURNS datetime
AS
BEGIN
	RETURN (SELECT RemovalDate FROM Dishes WHERE DishID = @DishID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetMenuInsertionDate]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetMenuInsertionDate](@MenuID int)
RETURNS datetime
AS
BEGIN
	RETURN (SELECT InsertionDate FROM Menu WHERE MenuID = @MenuID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetNumberOfDishesInMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--MENU_DETAILS

CREATE FUNCTION [dbo].[GetNumberOfDishesInMenu](@MenuID int)
RETURNS int
AS
BEGIN
	RETURN (SELECT COUNT(*) FROM MenuDetails WHERE MenuID = @MenuID);
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetNumberOfFreeSeats]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetNumberOfFreeSeats]()
RETURNS int
AS
BEGIN
	RETURN (SELECT SUM(NumberOfSeats) FROM Tables WHERE Availability = 1)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetNumberOfSimilarDishes]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetNumberOfSimilarDishes](@Menu1 int, @Menu2 int)
RETURNS int
AS
BEGIN
	DECLARE @result int
	SET @result = (SELECT COUNT (*) 
				   FROM MenuDetails MD1 
				   CROSS JOIN MenuDetails MD2
				   WHERE MD1.MenuID = @Menu1 AND MD2.MenuID = @Menu2 AND MD1.DishID = MD2.DishID);
	RETURN @result
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetOrderDate]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetOrderDate](@OrderID int)
RETURNS datetime
AS
BEGIN
	RETURN(SELECT OrderDate FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetOrderDiscount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetOrderDiscount](@OrderID int)
RETURNS decimal(20,2)
AS
BEGIN
	RETURN(SELECT Discount FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetOrderReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetOrderReceipt](@OrderID int)
RETURNS int
AS
BEGIN
	RETURN (SELECT ReceiptID FROM ReceiptDetails WHERE OrderID = @OrderID);
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetOrderValue]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetOrderValue](@OrderID int)
RETURNS bit
AS
BEGIN
	RETURN (SELECT Value FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetReceiptValue]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--RECEIPT_DETAILS

-------------------RECEIPT------------------------

CREATE FUNCTION [dbo].[GetReceiptValue](@ReceiptID int)
RETURNS decimal(20,2)
AS
BEGIN
	RETURN (SELECT Value FROM Receipt WHERE ReceiptID = @ReceiptID);
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetUpcomingMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetUpcomingMenu]() --zwraca zaplanowane menu
RETURNS int
AS
BEGIN
	RETURN (SELECT TOP(1) MenuID FROM Menu WHERE InsertionDate > GETDATE() AND RemovalDate >= GETDATE());
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetValueAfterDiscount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----------------ORDERS---------------

CREATE FUNCTION [dbo].[GetValueAfterDiscount](@OrderID int)
RETURNS decimal(20,2)
AS
BEGIN
	RETURN(SELECT Value-Discount FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  UserDefinedFunction [dbo].[IsCollectiveInvoice]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--COLLECTIVE_INVOICES

CREATE FUNCTION [dbo].[IsCollectiveInvoice](@ReceiptID int)
RETURNS bit
AS
BEGIN
	IF ((SELECT COUNT(*) FROM CollectiveInvoices WHERE ReceiptID = @ReceiptID) = 1)
	BEGIN
		RETURN 1;
	END
	RETURN 0;
END
GO
/****** Object:  UserDefinedFunction [dbo].[IsReceived]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[IsReceived](@OrderID int)
RETURNS bit
AS
BEGIN
	IF ((SELECT Received FROM Orders WHERE OrderID = @OrderID) IS NULL OR (SELECT Received FROM Orders WHERE OrderID = @OrderID) = 0)
	BEGIN
	RETURN 0;
	END
	RETURN 1;
END
GO
/****** Object:  UserDefinedFunction [dbo].[IsSettled]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--ORDERS

CREATE FUNCTION [dbo].[IsSettled](@OrderID int)
RETURNS bit
AS
BEGIN
	RETURN (SELECT Settled FROM Orders WHERE OrderID = @OrderID)
END
GO
/****** Object:  Table [dbo].[Reservations]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Reservations](
	[ReservationID] [int] IDENTITY(1,1) NOT NULL,
	[OrderID] [int] NOT NULL,
	[CustomerID] [int] NOT NULL,
	[NumberOfPeople] [int] NOT NULL,
 CONSTRAINT [PK_Reservations] PRIMARY KEY CLUSTERED 
(
	[ReservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[AllReservationsCount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[AllReservationsCount] AS
SELECT dbo.Reservations.CustomerID, COUNT(dbo.Reservations.ReservationID) AS AmountOfReservations
FROM dbo.Reservations
GROUP BY dbo.Reservations.CustomerID
GO
/****** Object:  Table [dbo].[GrantedDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GrantedDiscounts](
	[GrantedDiscountID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerID] [int] NOT NULL,
	[DiscountID] [int] NOT NULL,
	[DiscountValue] [decimal](6, 2) NOT NULL,
	[GrantedDate] [datetime] NOT NULL,
	[ExpirationDate] [datetime] NULL,
	[Used] [bit] NOT NULL,
 CONSTRAINT [PK_GrantedDiscounts] PRIMARY KEY CLUSTERED 
(
	[GrantedDiscountID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[ActiveCustomerDiscountCount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ActiveCustomerDiscountCount] AS
SELECT dbo.GrantedDiscounts.CustomerID, COUNT(dbo.GrantedDiscounts.GrantedDiscountID) AS AmountOfDiscounts
FROM dbo.GrantedDiscounts
WHERE dbo.GrantedDiscounts.Used = 0
GROUP BY dbo.GrantedDiscounts.CustomerID
GO
/****** Object:  Table [dbo].[ReceiptDetails]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ReceiptDetails](
	[ReceiptID] [int] NOT NULL,
	[OrderID] [int] NOT NULL,
 CONSTRAINT [PK_ReceiptDetails] PRIMARY KEY CLUSTERED 
(
	[ReceiptID] ASC,
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[GetOrdersFromReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------

CREATE FUNCTION [dbo].[GetOrdersFromReceipt](@ReceiptID int)
RETURNS TABLE
AS
	RETURN (SELECT OrderID FROM ReceiptDetails WHERE ReceiptID = @ReceiptID);
GO
/****** Object:  Table [dbo].[Orders]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Orders](
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerID] [int] NOT NULL,
	[EmployeeID] [int] NULL,
	[ReceptionType] [nvarchar](11) NOT NULL,
	[PaymentType] [nvarchar](11) NOT NULL,
	[OrderDate] [datetime] NULL,
	[ReceiveDate] [datetime] NOT NULL,
	[Value] [decimal](20, 2) NOT NULL,
	[Discount] [decimal](20, 2) NULL,
	[Completed] [bit] NOT NULL,
	[Received] [bit] NULL,
	[Settled] [bit] NOT NULL,
 CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customers]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customers](
	[CustomerID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerType] [nvarchar](10) NOT NULL,
	[Phone] [nvarchar](9) NOT NULL,
	[Mail] [nvarchar](30) NOT NULL,
 CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED 
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[LastWeekReservations]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[LastWeekReservations] AS
SELECT dbo.Reservations.ReservationID, 
dbo.Customers.CustomerID,
dbo.Reservations.NumberOfPeople,
dbo.Orders.OrderDate,
dbo.Orders.ReceiveDate
FROM dbo.Reservations
INNER JOIN dbo.Customers
ON dbo.Reservations.CustomerID = dbo.Customers.CustomerID
INNER JOIN dbo.Orders
ON dbo.Orders.OrderID = dbo.Reservations.OrderID
WHERE (DATEPART(week, dbo.Orders.OrderDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.Orders.OrderDate) = 53 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  View [dbo].[LastMonthReservations]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[LastMonthReservations] AS
SELECT dbo.Reservations.ReservationID, 
dbo.Customers.CustomerID,
dbo.Reservations.NumberOfPeople,
dbo.Orders.OrderDate,
dbo.Orders.ReceiveDate
FROM dbo.Reservations
INNER JOIN dbo.Customers
ON dbo.Reservations.CustomerID = dbo.Customers.CustomerID
INNER JOIN dbo.Orders
ON dbo.Orders.OrderID = dbo.Reservations.OrderID
WHERE (MONTH(dbo.Orders.OrderDate) = MONTH(GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (MONTH(GETDATE()) = 1 AND MONTH(dbo.Orders.OrderDate) = 12 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  Table [dbo].[IndividualCustomers]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndividualCustomers](
	[IndividualCustomerID] [int] IDENTITY(1,1) NOT NULL,
	[CompanyID] [int] NULL,
	[FirstName] [nvarchar](24) NOT NULL,
	[LastName] [nvarchar](30) NOT NULL,
	[Age] [int] NULL,
	[PersonalDataAgreement] [bit] NOT NULL,
	[NumberOfOrders] [int] NOT NULL,
	[OrdersInRow] [int] NOT NULL,
	[SumOfOrders] [decimal](20, 2) NOT NULL,
 CONSTRAINT [PK_IndividualCustomers] PRIMARY KEY CLUSTERED 
(
	[IndividualCustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[LastWeekIndividualCustomerDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[LastWeekIndividualCustomerDiscounts] AS
SELECT dbo.IndividualCustomers.IndividualCustomerID,
dbo.GrantedDiscounts.DiscountID,
dbo.GrantedDiscounts.DiscountValue,
dbo.GrantedDiscounts.GrantedDate,
dbo.GrantedDiscounts.ExpirationDate,
dbo.GrantedDiscounts.Used
FROM dbo.IndividualCustomers
LEFT JOIN dbo.GrantedDiscounts
ON dbo.IndividualCustomers.IndividualCustomerID = dbo.GrantedDiscounts.CustomerID
WHERE (DATEPART(week, dbo.GrantedDiscounts.GrantedDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.GrantedDiscounts.GrantedDate) = 53 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  View [dbo].[LastMonthIndividualCustomerDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[LastMonthIndividualCustomerDiscounts] AS
SELECT dbo.IndividualCustomers.IndividualCustomerID,
dbo.GrantedDiscounts.DiscountID,
dbo.GrantedDiscounts.DiscountValue,
dbo.GrantedDiscounts.GrantedDate,
dbo.GrantedDiscounts.ExpirationDate,
dbo.GrantedDiscounts.Used
FROM dbo.IndividualCustomers
LEFT JOIN dbo.GrantedDiscounts
ON dbo.IndividualCustomers.IndividualCustomerID = dbo.GrantedDiscounts.CustomerID
WHERE (MONTH(dbo.GrantedDiscounts.GrantedDate) = MONTH(GETDATE())-1 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()))
OR (MONTH(GETDATE()) = 1 AND MONTH(dbo.GrantedDiscounts.GrantedDate) = 12 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  Table [dbo].[Companies]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Companies](
	[CompanyID] [int] IDENTITY(1,1) NOT NULL,
	[CompanyName] [nvarchar](30) NOT NULL,
	[NIP] [nvarchar](10) NOT NULL,
	[Country] [nvarchar](40) NOT NULL,
	[ZipCode] [nchar](6) NOT NULL,
	[Address] [nvarchar](40) NOT NULL,
	[City] [nvarchar](40) NOT NULL,
	[InvoicePeriod] [int] NOT NULL,
	[NumberOfOrdersInMonth] [int] NOT NULL,
	[SumOfOrdersInMonth] [decimal](20, 2) NOT NULL,
	[NumberOfMonthsInRow] [int] NOT NULL,
	[SumOfOrdersInQuarter] [decimal](20, 2) NOT NULL,
 CONSTRAINT [PK_Companies] PRIMARY KEY CLUSTERED 
(
	[CompanyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UniqueNIP_Companies] UNIQUE NONCLUSTERED 
(
	[NIP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Address] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[NIP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[LastWeekCompanyDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[LastWeekCompanyDiscounts] AS
SELECT dbo.Companies.CompanyID,
dbo.GrantedDiscounts.DiscountID,
dbo.GrantedDiscounts.DiscountValue,
dbo.GrantedDiscounts.GrantedDate,
dbo.GrantedDiscounts.ExpirationDate,
dbo.GrantedDiscounts.Used
FROM dbo.Companies
LEFT JOIN dbo.GrantedDiscounts
ON dbo.Companies.CompanyID = dbo.GrantedDiscounts.CustomerID
WHERE (DATEPART(week, dbo.GrantedDiscounts.GrantedDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.GrantedDiscounts.GrantedDate) = 53 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  View [dbo].[LastMonthCompanyDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[LastMonthCompanyDiscounts] AS
SELECT dbo.Companies.CompanyID,
dbo.GrantedDiscounts.DiscountID,
dbo.GrantedDiscounts.DiscountValue,
dbo.GrantedDiscounts.GrantedDate,
dbo.GrantedDiscounts.ExpirationDate,
dbo.GrantedDiscounts.Used
FROM dbo.Companies
LEFT JOIN dbo.GrantedDiscounts
ON dbo.Companies.CompanyID = dbo.GrantedDiscounts.CustomerID
WHERE (MONTH(dbo.GrantedDiscounts.GrantedDate) = MONTH(GETDATE())-1 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()))
OR (MONTH(GETDATE()) = 1 AND MONTH(dbo.GrantedDiscounts.GrantedDate) = 12 AND YEAR(dbo.GrantedDiscounts.GrantedDate) = YEAR(GETDATE()) -1)
GO
/****** Object:  Table [dbo].[MenuDetails]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MenuDetails](
	[MenuID] [int] NOT NULL,
	[DishID] [int] NOT NULL,
	[DishPrice] [decimal](20, 2) NOT NULL,
	[Availability] [bit] NOT NULL,
 CONSTRAINT [PK_MenuDetails] PRIMARY KEY CLUSTERED 
(
	[MenuID] ASC,
	[DishID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Dishes]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Dishes](
	[DishID] [int] IDENTITY(1,1) NOT NULL,
	[DishName] [nvarchar](40) NOT NULL,
	[DishPrice] [decimal](20, 2) NOT NULL,
	[RemovalDate] [datetime] NULL,
 CONSTRAINT [PK_Dishes] PRIMARY KEY CLUSTERED 
(
	[DishID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[DishName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[CurrentMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[CurrentMenu] AS
SELECT D.DishName, MD.DishPrice, MD.Availability
FROM dbo.MenuDetails AS MD
INNER JOIN Dishes AS D
ON MD.DishID = D.DishID
WHERE MD.MenuID = dbo.GetCurrentMenu()
GO
/****** Object:  UserDefinedFunction [dbo].[GetSixthDiscount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetSixthDiscount] (@CustomerID int)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM GrantedDiscounts gd
    WHERE gd.CustomerID = @CustomerID AND gd.DiscountID = 6 AND gd.Used = 0
);
GO
/****** Object:  View [dbo].[AverageOrderPriceInd]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[AverageOrderPriceInd] AS
SELECT ROUND(AVG(Value),2) AS 'Average price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 1
GO
/****** Object:  View [dbo].[AverageOrderPriceComp]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[AverageOrderPriceComp] AS
SELECT ROUND(AVG(Value),2) AS 'Average price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 0
GO
/****** Object:  View [dbo].[AverageOrderPriceIndWeek]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[AverageOrderPriceIndWeek] AS
SELECT ROUND(AVG(Value),2) AS 'Average price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 1
AND ((DATEPART(week, dbo.Orders.OrderDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.Orders.OrderDate) = 53 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1))
GO
/****** Object:  View [dbo].[AverageOrderPriceCompWeek]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[AverageOrderPriceCompWeek] AS
SELECT ROUND(AVG(Value),2) AS 'Average price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 0
AND ((DATEPART(week, dbo.Orders.OrderDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.Orders.OrderDate) = 53 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1))
GO
/****** Object:  View [dbo].[SumOrderPriceIndWeek]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[SumOrderPriceIndWeek] AS
SELECT SUM(Value) AS 'Sum price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 1
AND ((DATEPART(week, dbo.Orders.OrderDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.Orders.OrderDate) = 53 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1))
GO
/****** Object:  View [dbo].[SumOrderPriceCompWeek]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[SumOrderPriceCompWeek] AS
SELECT SUM(Value) AS 'Sum price'
FROM Orders
WHERE dbo.CheckIfIndividual(CustomerID) = 0
AND ((DATEPART(week, dbo.Orders.OrderDate) = DATEPART(week, GETDATE())-1 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()))
OR (DATEPART(week, GETDATE()) = 1 AND DATEPART(week, dbo.Orders.OrderDate) = 53 AND YEAR(dbo.Orders.OrderDate) = YEAR(GETDATE()) -1))
GO
/****** Object:  UserDefinedFunction [dbo].[OrdersPerClient]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[OrdersPerClient] (@CustomerID int)
RETURNS TABLE
AS
RETURN (SELECT *
		FROM Orders
		WHERE CustomerID = @CustomerID);
GO
/****** Object:  UserDefinedFunction [dbo].[DiscountsPerClient]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DiscountsPerClient] (@CustomerID int)
RETURNS TABLE
AS
RETURN (SELECT *
		FROM GrantedDiscounts
		WHERE CustomerID = @CustomerID);
GO
/****** Object:  Table [dbo].[Categories]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Categories](
	[CategoryID] [int] IDENTITY(1,1) NOT NULL,
	[CategoryName] [nvarchar](30) NOT NULL,
 CONSTRAINT [PK_Categories] PRIMARY KEY CLUSTERED 
(
	[CategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[CategoryName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CollectiveInvoices]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CollectiveInvoices](
	[ReceiptID] [int] NOT NULL,
	[ValidFrom] [datetime] NOT NULL,
	[ValidTo] [datetime] NOT NULL,
	[InProgress] [bit] NOT NULL,
 CONSTRAINT [PK_CIReceipt] PRIMARY KEY CLUSTERED 
(
	[ReceiptID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Discounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Discounts](
	[DiscountID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerType] [nvarchar](10) NOT NULL,
	[DiscountValue] [decimal](3, 2) NOT NULL,
	[DiscountType] [nvarchar](11) NOT NULL,
 CONSTRAINT [PK_Discounts] PRIMARY KEY CLUSTERED 
(
	[DiscountID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DishDetails]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DishDetails](
	[DishID] [int] NOT NULL,
	[ProductID] [int] NOT NULL,
	[UnitPrice] [decimal](20, 2) NOT NULL,
	[Quantity] [int] NOT NULL,
 CONSTRAINT [PK_DishDetails] PRIMARY KEY CLUSTERED 
(
	[DishID] ASC,
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employees]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employees](
	[EmployeeID] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [nvarchar](30) NOT NULL,
	[LastName] [nvarchar](30) NOT NULL,
	[Pesel] [nchar](11) NOT NULL,
	[BirthDate] [datetime] NOT NULL,
	[HireDate] [datetime] NOT NULL,
	[Address] [nvarchar](60) NOT NULL,
	[Phone] [nchar](9) NOT NULL,
	[Mail] [nvarchar](40) NOT NULL,
	[Post] [nvarchar](20) NOT NULL,
	[Salary] [decimal](20, 2) NOT NULL,
 CONSTRAINT [PK_Employees] PRIMARY KEY CLUSTERED 
(
	[EmployeeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UniqueMail_Employees] UNIQUE NONCLUSTERED 
(
	[Mail] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UniquePesel_Employees] UNIQUE NONCLUSTERED 
(
	[Pesel] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UniquePhone_Employees] UNIQUE NONCLUSTERED 
(
	[Phone] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Mail] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Pesel] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Phone] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Menu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Menu](
	[MenuID] [int] IDENTITY(1,1) NOT NULL,
	[InsertionDate] [datetime] NOT NULL,
	[RemovalDate] [datetime] NOT NULL,
 CONSTRAINT [PK_Menu] PRIMARY KEY CLUSTERED 
(
	[MenuID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OrderDetails]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrderDetails](
	[OrderID] [int] NOT NULL,
	[DishID] [int] NOT NULL,
	[UnitPrice] [decimal](20, 2) NOT NULL,
	[Quantity] [smallint] NOT NULL,
 CONSTRAINT [PK_OrderDetails] PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC,
	[DishID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Products]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Products](
	[ProductID] [int] IDENTITY(1,1) NOT NULL,
	[ProductName] [nvarchar](50) NOT NULL,
	[CategoryID] [int] NOT NULL,
	[UnitPrice] [decimal](20, 2) NOT NULL,
	[UnitsInStock] [smallint] NOT NULL,
 CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED 
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Receipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Receipt](
	[ReceiptID] [int] IDENTITY(1,1) NOT NULL,
	[InvoicedCustomer] [int] NOT NULL,
	[InvoiceDate] [datetime] NULL,
	[AccountNumber] [nvarchar](26) NULL,
	[ReceiptType] [nvarchar](20) NOT NULL,
	[PaymentMethod] [nvarchar](8) NOT NULL,
	[Value] [decimal](20, 2) NOT NULL,
	[Settled] [bit] NOT NULL,
	[Cancelled] [bit] NOT NULL,
	[SaleDate] [datetime] NULL,
 CONSTRAINT [PK_Receipt] PRIMARY KEY CLUSTERED 
(
	[ReceiptID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Refunds]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Refunds](
	[ReceiptID] [int] NOT NULL,
	[OrderID] [int] NOT NULL,
	[Value] [decimal](20, 2) NOT NULL,
	[Refunded] [bit] NOT NULL,
 CONSTRAINT [PK_Refunds] PRIMARY KEY CLUSTERED 
(
	[ReceiptID] ASC,
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ReservationDetails]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ReservationDetails](
	[ReservationID] [int] NOT NULL,
	[TableID] [int] NOT NULL,
 CONSTRAINT [PK_ReservationDetails] PRIMARY KEY CLUSTERED 
(
	[ReservationID] ASC,
	[TableID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tables]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tables](
	[TableID] [int] IDENTITY(1,1) NOT NULL,
	[NumberOfSeats] [int] NOT NULL,
	[Availability] [bit] NOT NULL,
 CONSTRAINT [PK_Tables] PRIMARY KEY CLUSTERED 
(
	[TableID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [GrantedDiscounts_CustomerID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [GrantedDiscounts_CustomerID_Index] ON [dbo].[GrantedDiscounts]
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [GrantedDiscounts_DiscountID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [GrantedDiscounts_DiscountID_Index] ON [dbo].[GrantedDiscounts]
(
	[DiscountID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IndividualCustomers_CompanyID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [IndividualCustomers_CompanyID_Index] ON [dbo].[IndividualCustomers]
(
	[CompanyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Orders_CustomerID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [Orders_CustomerID_Index] ON [dbo].[Orders]
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Orders_EmployeeID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [Orders_EmployeeID_Index] ON [dbo].[Orders]
(
	[EmployeeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Products_CategoryID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [Products_CategoryID_Index] ON [dbo].[Products]
(
	[CategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Receipt_InvoicedCustomer_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [Receipt_InvoicedCustomer_Index] ON [dbo].[Receipt]
(
	[InvoicedCustomer] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Reservations_CustomerID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE NONCLUSTERED INDEX [Reservations_CustomerID_Index] ON [dbo].[Reservations]
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [Reservations_OrderID_Index]    Script Date: 19-01-2021 21:22:03 ******/
CREATE UNIQUE NONCLUSTERED INDEX [Reservations_OrderID_Index] ON [dbo].[Reservations]
(
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CollectiveInvoices] ADD  DEFAULT ((1)) FOR [InProgress]
GO
ALTER TABLE [dbo].[Companies] ADD  DEFAULT ((-1)) FOR [InvoicePeriod]
GO
ALTER TABLE [dbo].[Companies] ADD  DEFAULT ((0)) FOR [NumberOfOrdersInMonth]
GO
ALTER TABLE [dbo].[Companies] ADD  DEFAULT ((0)) FOR [SumOfOrdersInMonth]
GO
ALTER TABLE [dbo].[Companies] ADD  DEFAULT ((0)) FOR [NumberOfMonthsInRow]
GO
ALTER TABLE [dbo].[Companies] ADD  DEFAULT ((0)) FOR [SumOfOrdersInQuarter]
GO
ALTER TABLE [dbo].[Customers] ADD  DEFAULT ('individual') FOR [CustomerType]
GO
ALTER TABLE [dbo].[Customers] ADD  DEFAULT ('forbidden') FOR [Phone]
GO
ALTER TABLE [dbo].[Customers] ADD  DEFAULT ('forbidden') FOR [Mail]
GO
ALTER TABLE [dbo].[Discounts] ADD  DEFAULT ('individual') FOR [CustomerType]
GO
ALTER TABLE [dbo].[DishDetails] ADD  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Dishes] ADD  DEFAULT (NULL) FOR [RemovalDate]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ('other') FOR [Post]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((2600)) FOR [Salary]
GO
ALTER TABLE [dbo].[GrantedDiscounts] ADD  CONSTRAINT [DF__GrantedDi__Grant__64B7E415]  DEFAULT (getdate()) FOR [GrantedDate]
GO
ALTER TABLE [dbo].[GrantedDiscounts] ADD  CONSTRAINT [DF__GrantedDi__Expir__65AC084E]  DEFAULT (NULL) FOR [ExpirationDate]
GO
ALTER TABLE [dbo].[GrantedDiscounts] ADD  CONSTRAINT [DF__GrantedDis__Used__66A02C87]  DEFAULT ((0)) FOR [Used]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__Compa__4CE05A84]  DEFAULT (NULL) FOR [CompanyID]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__First__4DD47EBD]  DEFAULT ('forbidden') FOR [FirstName]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__LastN__4EC8A2F6]  DEFAULT ('forbidden') FOR [LastName]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__IndividualC__Age__4FBCC72F]  DEFAULT (NULL) FOR [Age]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__Perso__50B0EB68]  DEFAULT ((0)) FOR [PersonalDataAgreement]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__Numbe__51A50FA1]  DEFAULT ((0)) FOR [NumberOfOrders]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__Order__529933DA]  DEFAULT ((0)) FOR [OrdersInRow]
GO
ALTER TABLE [dbo].[IndividualCustomers] ADD  CONSTRAINT [DF__Individua__SumOf__538D5813]  DEFAULT ((0)) FOR [SumOfOrders]
GO
ALTER TABLE [dbo].[Menu] ADD  DEFAULT (dateadd(day,(1),getdate())) FOR [InsertionDate]
GO
ALTER TABLE [dbo].[MenuDetails] ADD  DEFAULT ((0)) FOR [DishPrice]
GO
ALTER TABLE [dbo].[MenuDetails] ADD  DEFAULT ((1)) FOR [Availability]
GO
ALTER TABLE [dbo].[OrderDetails] ADD  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Orders] ADD  DEFAULT ('takeaway') FOR [ReceptionType]
GO
ALTER TABLE [dbo].[Orders] ADD  DEFAULT (getdate()) FOR [OrderDate]
GO
ALTER TABLE [dbo].[Orders] ADD  DEFAULT ((0)) FOR [Completed]
GO
ALTER TABLE [dbo].[Orders] ADD  DEFAULT (NULL) FOR [Received]
GO
ALTER TABLE [dbo].[Orders] ADD  DEFAULT ((0)) FOR [Settled]
GO
ALTER TABLE [dbo].[Products] ADD  DEFAULT ((0)) FOR [UnitsInStock]
GO
ALTER TABLE [dbo].[Receipt] ADD  DEFAULT ((0)) FOR [Settled]
GO
ALTER TABLE [dbo].[Receipt] ADD  DEFAULT ((0)) FOR [Cancelled]
GO
ALTER TABLE [dbo].[Refunds] ADD  DEFAULT ((0)) FOR [Value]
GO
ALTER TABLE [dbo].[Refunds] ADD  DEFAULT ((0)) FOR [Refunded]
GO
ALTER TABLE [dbo].[Tables] ADD  DEFAULT ((0)) FOR [Availability]
GO
ALTER TABLE [dbo].[CollectiveInvoices]  WITH CHECK ADD FOREIGN KEY([ReceiptID])
REFERENCES [dbo].[Receipt] ([ReceiptID])
GO
ALTER TABLE [dbo].[Companies]  WITH CHECK ADD FOREIGN KEY([CompanyID])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[DishDetails]  WITH CHECK ADD FOREIGN KEY([DishID])
REFERENCES [dbo].[Dishes] ([DishID])
GO
ALTER TABLE [dbo].[DishDetails]  WITH CHECK ADD FOREIGN KEY([ProductID])
REFERENCES [dbo].[Products] ([ProductID])
GO
ALTER TABLE [dbo].[GrantedDiscounts]  WITH CHECK ADD  CONSTRAINT [FK__GrantedDi__Custo__192BAC54] FOREIGN KEY([CustomerID])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[GrantedDiscounts] CHECK CONSTRAINT [FK__GrantedDi__Custo__192BAC54]
GO
ALTER TABLE [dbo].[GrantedDiscounts]  WITH CHECK ADD  CONSTRAINT [FK__GrantedDi__Disco__1A1FD08D] FOREIGN KEY([DiscountID])
REFERENCES [dbo].[Discounts] ([DiscountID])
GO
ALTER TABLE [dbo].[GrantedDiscounts] CHECK CONSTRAINT [FK__GrantedDi__Disco__1A1FD08D]
GO
ALTER TABLE [dbo].[IndividualCustomers]  WITH CHECK ADD  CONSTRAINT [FK__Individua__Compa__1DF06171] FOREIGN KEY([CompanyID])
REFERENCES [dbo].[Companies] ([CompanyID])
GO
ALTER TABLE [dbo].[IndividualCustomers] CHECK CONSTRAINT [FK__Individua__Compa__1DF06171]
GO
ALTER TABLE [dbo].[IndividualCustomers]  WITH CHECK ADD  CONSTRAINT [FK__Individua__Indiv__6265874F] FOREIGN KEY([IndividualCustomerID])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[IndividualCustomers] CHECK CONSTRAINT [FK__Individua__Indiv__6265874F]
GO
ALTER TABLE [dbo].[MenuDetails]  WITH CHECK ADD FOREIGN KEY([DishID])
REFERENCES [dbo].[Dishes] ([DishID])
GO
ALTER TABLE [dbo].[MenuDetails]  WITH CHECK ADD FOREIGN KEY([MenuID])
REFERENCES [dbo].[Menu] ([MenuID])
GO
ALTER TABLE [dbo].[OrderDetails]  WITH CHECK ADD FOREIGN KEY([DishID])
REFERENCES [dbo].[Dishes] ([DishID])
GO
ALTER TABLE [dbo].[OrderDetails]  WITH CHECK ADD FOREIGN KEY([OrderID])
REFERENCES [dbo].[Orders] ([OrderID])
GO
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD FOREIGN KEY([CustomerID])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD FOREIGN KEY([EmployeeID])
REFERENCES [dbo].[Employees] ([EmployeeID])
GO
ALTER TABLE [dbo].[Products]  WITH CHECK ADD FOREIGN KEY([CategoryID])
REFERENCES [dbo].[Categories] ([CategoryID])
GO
ALTER TABLE [dbo].[Receipt]  WITH CHECK ADD FOREIGN KEY([InvoicedCustomer])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[ReceiptDetails]  WITH CHECK ADD FOREIGN KEY([OrderID])
REFERENCES [dbo].[Orders] ([OrderID])
GO
ALTER TABLE [dbo].[ReceiptDetails]  WITH CHECK ADD FOREIGN KEY([ReceiptID])
REFERENCES [dbo].[Receipt] ([ReceiptID])
GO
ALTER TABLE [dbo].[Refunds]  WITH CHECK ADD FOREIGN KEY([OrderID])
REFERENCES [dbo].[Orders] ([OrderID])
GO
ALTER TABLE [dbo].[Refunds]  WITH CHECK ADD FOREIGN KEY([ReceiptID])
REFERENCES [dbo].[Receipt] ([ReceiptID])
GO
ALTER TABLE [dbo].[ReservationDetails]  WITH CHECK ADD FOREIGN KEY([ReservationID])
REFERENCES [dbo].[Reservations] ([ReservationID])
GO
ALTER TABLE [dbo].[ReservationDetails]  WITH CHECK ADD FOREIGN KEY([TableID])
REFERENCES [dbo].[Tables] ([TableID])
GO
ALTER TABLE [dbo].[Reservations]  WITH CHECK ADD FOREIGN KEY([CustomerID])
REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[Reservations]  WITH CHECK ADD FOREIGN KEY([OrderID])
REFERENCES [dbo].[Orders] ([OrderID])
GO
ALTER TABLE [dbo].[CollectiveInvoices]  WITH CHECK ADD  CONSTRAINT [CHK_CollectiveInvoices] CHECK  (([ValidTo]>[ValidFrom]))
GO
ALTER TABLE [dbo].[CollectiveInvoices] CHECK CONSTRAINT [CHK_CollectiveInvoices]
GO
ALTER TABLE [dbo].[Companies]  WITH CHECK ADD  CONSTRAINT [CHK_Companies] CHECK  ((len([NIP])=(10) AND [NIP] like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND [ZipCode] like '[0-9][0-9]-[0-9][0-9][0-9]' AND [InvoicePeriod]>=(-1) AND [InvoicePeriod]<>(0) AND [InvoicePeriod]<=(12) AND [NumberOfOrdersInMonth]>=(0) AND [SumOfOrdersInMonth]>=(0) AND [NumberOfMonthsInRow]>=(0) AND [SumOfOrdersInQuarter]>=(0)))
GO
ALTER TABLE [dbo].[Companies] CHECK CONSTRAINT [CHK_Companies]
GO
ALTER TABLE [dbo].[Customers]  WITH CHECK ADD  CONSTRAINT [CHK_Customers] CHECK  ((len([Phone])=(9) AND [Phone] like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND [Mail] like '%@%.%'))
GO
ALTER TABLE [dbo].[Customers] CHECK CONSTRAINT [CHK_Customers]
GO
ALTER TABLE [dbo].[Customers]  WITH CHECK ADD CHECK  (([CustomerType]='company' OR [CustomerType]='Individual'))
GO
ALTER TABLE [dbo].[Discounts]  WITH CHECK ADD CHECK  (([CustomerType]='company' OR [CustomerType]='individual'))
GO
ALTER TABLE [dbo].[Discounts]  WITH CHECK ADD CHECK  (([DiscountType]='amount' OR [DiscountType]='percentage'))
GO
ALTER TABLE [dbo].[DishDetails]  WITH CHECK ADD  CONSTRAINT [CHK_DishDetails] CHECK  (([UnitPrice]>=(0) AND [Quantity]>=(1)))
GO
ALTER TABLE [dbo].[DishDetails] CHECK CONSTRAINT [CHK_DishDetails]
GO
ALTER TABLE [dbo].[Dishes]  WITH CHECK ADD  CONSTRAINT [CHK_Dishes] CHECK  (([DishPrice]>=(0)))
GO
ALTER TABLE [dbo].[Dishes] CHECK CONSTRAINT [CHK_Dishes]
GO
ALTER TABLE [dbo].[Employees]  WITH CHECK ADD  CONSTRAINT [CHK_Employees] CHECK  (((datepart(year,[HireDate])-datepart(year,[BirthDate]))>=(16) AND [Salary]>=(2600) AND len([Phone])=(9) AND len([PESEL])=(11) AND [Pesel] like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND [Phone] like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND [Mail] like '%@%.%'))
GO
ALTER TABLE [dbo].[Employees] CHECK CONSTRAINT [CHK_Employees]
GO
ALTER TABLE [dbo].[Employees]  WITH CHECK ADD CHECK  (([Post]='other' OR [Post]='delivery' OR [Post]='waiter' OR [Post]='customer service' OR [Post]='cook' OR [Post]='manager'))
GO
ALTER TABLE [dbo].[GrantedDiscounts]  WITH CHECK ADD  CONSTRAINT [CHK_GrantedDiscounts] CHECK  (([GrantedDate]<=[ExpirationDate]))
GO
ALTER TABLE [dbo].[GrantedDiscounts] CHECK CONSTRAINT [CHK_GrantedDiscounts]
GO
ALTER TABLE [dbo].[IndividualCustomers]  WITH CHECK ADD  CONSTRAINT [CHK_IndividualCustomers] CHECK  (([Age]>=(12) AND [NumberOfOrders]>=(0) AND [OrdersInRow]>=(0) AND [SumOfOrders]>=(0)))
GO
ALTER TABLE [dbo].[IndividualCustomers] CHECK CONSTRAINT [CHK_IndividualCustomers]
GO
ALTER TABLE [dbo].[Menu]  WITH CHECK ADD  CONSTRAINT [CHK_Menu] CHECK  (([InsertionDate]<=[RemovalDate] AND [RemovalDate]<=dateadd(week,(2),[InsertionDate])))
GO
ALTER TABLE [dbo].[Menu] CHECK CONSTRAINT [CHK_Menu]
GO
ALTER TABLE [dbo].[MenuDetails]  WITH CHECK ADD  CONSTRAINT [CHK_MenuDetails] CHECK  (([DishPrice]>=(0)))
GO
ALTER TABLE [dbo].[MenuDetails] CHECK CONSTRAINT [CHK_MenuDetails]
GO
ALTER TABLE [dbo].[OrderDetails]  WITH CHECK ADD  CONSTRAINT [CHK_OrderDetails] CHECK  (([Quantity]>=(0) AND [UnitPrice]>=(0)))
GO
ALTER TABLE [dbo].[OrderDetails] CHECK CONSTRAINT [CHK_OrderDetails]
GO
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD  CONSTRAINT [CHK_Orders] CHECK  (([OrderDate]<=[ReceiveDate] AND [Value]>=(0) AND [Discount]>=(0) AND [Discount]<=[Value]))
GO
ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT [CHK_Orders]
GO
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD CHECK  (([PaymentType]='in-advance' OR [PaymentType]='on-delivery'))
GO
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD CHECK  (([ReceptionType]='reservation' OR [ReceptionType]='delivery' OR [ReceptionType]='takeaway'))
GO
ALTER TABLE [dbo].[Products]  WITH CHECK ADD  CONSTRAINT [CHK_Products] CHECK  (([UnitPrice]>=(0) AND [UnitsInStock]>=(0)))
GO
ALTER TABLE [dbo].[Products] CHECK CONSTRAINT [CHK_Products]
GO
ALTER TABLE [dbo].[Receipt]  WITH CHECK ADD  CONSTRAINT [CHK_Receipt] CHECK  ((len([AccountNumber])=(26)))
GO
ALTER TABLE [dbo].[Receipt] CHECK CONSTRAINT [CHK_Receipt]
GO
ALTER TABLE [dbo].[Receipt]  WITH CHECK ADD CHECK  (([PaymentMethod]='transfer' OR [PaymentMethod]='card' OR [PaymentMethod]='cash'))
GO
ALTER TABLE [dbo].[Receipt]  WITH CHECK ADD CHECK  (([ReceiptType]='collective invoice' OR [ReceiptType]='one-time invoice' OR [ReceiptType]='receipt'))
GO
ALTER TABLE [dbo].[Reservations]  WITH CHECK ADD  CONSTRAINT [CHK_Reservations] CHECK  (([NumberOfPeople]>=(1) AND [NumberOfPeople]<=(100)))
GO
ALTER TABLE [dbo].[Reservations] CHECK CONSTRAINT [CHK_Reservations]
GO
ALTER TABLE [dbo].[Tables]  WITH CHECK ADD  CONSTRAINT [CHK_Tables] CHECK  (([NumberOfSeats]>=(1) AND [NumberOfSeats]<=(10)))
GO
ALTER TABLE [dbo].[Tables] CHECK CONSTRAINT [CHK_Tables]
GO
/****** Object:  StoredProcedure [dbo].[AddCategory]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--CATEGORIES

CREATE PROCEDURE [dbo].[AddCategory]
	@CategoryName nvarchar(30)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddCategory
			INSERT INTO Categories(CategoryName)
			VALUES (@CategoryName);
		COMMIT TRAN TAddCategory
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddCategory
		DECLARE @msg nvarchar(2048) = 
		'Blad dodania kategorii:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddCollectiveInvoice]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddCollectiveInvoice]
	@ReceiptID int,
	@ValidFrom datetime,
	@ValidTo datetime,
	@InProgress bit = 1

AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		BEGIN TRAN TAddCollectiveInvoice
			INSERT INTO CollectiveInvoices(ReceiptID, ValidFrom, ValidTo, InProgress)
			VALUES (@ReceiptID, @ValidFrom, @ValidTo, @InProgress)
		COMMIT TRAN TAddCollectiveInvoice
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddCollectiveInvoice
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania rachunku zbiorczego:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddCompany]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
--------------------Companies---------------------

CREATE PROCEDURE [dbo].[AddCompany]
	@CompanyName nvarchar(30),
	@NIP nvarchar(10),
	@Country nvarchar(40),
	@ZipCode nvarchar(30),
	@Address nvarchar(40),
	@City nvarchar(40),
	@InvoicePeriod int,
	@NumberOfOrdersInMonth int = 0,
    @SumOfOrdersInMonth int = 0,
	@NumberOfMonthsInRow int = 0,
	@SumOfOrdersInQuarter decimal(20,2) = 0,
    @Phone nvarchar(9) = 'forbidden',
    @Mail nvarchar(30) = 'forbidden',
    @CustomerID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddCompany
            EXEC AddCustomer
            'company',
            @Phone,
            @Mail,
            @CustomerID = @CustomerID OUTPUT
			SET IDENTITY_INSERT Companies ON
            INSERT INTO Companies(CompanyID, CompanyName, NIP, Country, ZipCode, Address, City, InvoicePeriod, NumberOfOrdersInMonth, NumberOfMonthsInRow, SumOfOrdersInQuarter)
            VALUES (@CustomerID, @CompanyName, @NIP, @Country, @ZipCode, @Address, @City, @InvoicePeriod, @NumberOfOrdersInMonth, @NumberOfMonthsInRow, @SumOfOrdersInQuarter);
			SET IDENTITY_INSERT Companies OFF
		COMMIT TRAN TAddCompany
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddCompany
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania firmy:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddCustomer]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
-------------------Customers----------------------

CREATE PROCEDURE [dbo].[AddCustomer]
    @CustomerType nvarchar (10) = 'individual',
    @Phone nvarchar(9) = 'forbidden',
    @Mail nvarchar(30) = 'forbidden',
    @CustomerID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddCustomer
            INSERT INTO Customers(CustomerType, Phone, Mail)
            VALUES (@CustomerType, @Phone, @Mail);
            SET @CustomerID = @@IDENTITY
        COMMIT TRAN TAddCustomer
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddCustomer
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania klienta:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddDiscount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
--------------------Discounts---------------------
CREATE PROCEDURE [dbo].[AddDiscount]
    @CustomerType nvarchar (10),
    @DiscountValue decimal(6, 2),
    @DiscountType nvarchar(11)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddDiscount
            INSERT INTO Discounts(CustomerType, DiscountValue, DiscountType)
            VALUES (@CustomerType, @DiscountValue, @DiscountType);
        COMMIT TRAN TAddDiscount
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddDiscount
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania znizki:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddDiscountToOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddDiscountToOrder]
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddDiscountToOrder
			DECLARE @CustomerID int, @DiscountPercent decimal(6, 2) = 0.00, 
			@SixthDiscountValue decimal(6,2) = 0.00, 
			@SixthDiscountID int, @ReceiptID int, 
			@DiscountValue decimal(20,2) = 0.00, @OrderValue decimal(20,2)
			SET @CustomerID = dbo.GetCustomerFromOrder(@OrderID)
			EXEC dbo.GetDiscountValue @CustomerID, @result = @DiscountPercent OUTPUT;
			(SELECT @SixthDiscountValue = DiscountValue, @SixthDiscountID = GrantedDiscountID FROM dbo.GetSixthDiscount(@CustomerID));
			SET @OrderValue = dbo.GetOrderValue(@OrderID);

			IF @DiscountPercent IS NULL
			BEGIN
				SET @DiscountPercent = 0.00
			END

			SET @DiscountValue = @DiscountPercent*@OrderValue
			
			IF @SixthDiscountValue IS NOT NULL
			BEGIN
				IF ((@OrderValue - @DiscountValue - @SixthDiscountValue) >= 0)
				BEGIN
					EXEC dbo.UpdateUsed @SixthDiscountID
					SET @DiscountValue += @SixthDiscountValue
				END
			END

			UPDATE Orders
			SET Discount = @DiscountValue
			WHERE OrderID = @OrderID

		COMMIT TRAN TUpdateReceived
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateReceived
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania rabatu do zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddDish]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DISHES

CREATE PROCEDURE [dbo].[AddDish]
	@DishName nvarchar(40),
	@DishPrice decimal(20,2) = 0,
	@RemovalDate datetime = NULL

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddDish
			INSERT INTO Dishes (DishName, DishPrice, RemovalDate)
			VALUES (@DishName, @DishPrice, @RemovalDate);
		COMMIT TRAN TAddDish
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddDish
		DECLARE @msg nvarchar(2048) = 
		'Blad utworzenia dania:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddDishToMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddDishToMenu]
	@MenuID int,
	@DishID int,
	@DishPrice decimal(20,2) = NULL,
	@Availability bit = 1

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddDishToMenu
			DECLARE @CanAdd bit
			EXEC @CanAdd = dbo.CanAddDishToMenu @DishID, @MenuID
			IF (@DishPrice IS NULL)
			BEGIN
				SET @DishPrice = (SELECT DishPrice FROM Dishes WHERE DishID = @DishID)
			END
			IF ((SELECT COUNT(*) FROM MenuDetails WHERE MenuID = @MenuID AND DishID = @DishID) != 0)
			BEGIN
				;THROW 52000, 'Danie juz widnieje w menu', 1;
			END
			ELSE IF(@CanAdd = 0)
			BEGIN
				;THROW 52000, 'Danie nie spelnia warunkow', 1;
			END
			ELSE
			BEGIN
				INSERT INTO MenuDetails(MenuID, DishID, DishPrice, Availability)
				VALUES (@MenuID, @DishID, @DishPrice, @Availability)
			END
		COMMIT TRAN TAddDishToMenu
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddDishToMenu
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania dania do menu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddDishToOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddDishToOrder]
	@OrderID int,
	@DishID int,
	@Quantity smallint = 1

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddDishToOrder
			DECLARE @UnitPrice decimal(20,2), @CurrentMenu int, 
					@CanBeAdded bit, @OrderValue decimal(20,2), @NewValue decimal(20,2)
			EXEC @CurrentMenu = dbo.GetCurrentMenu
			EXEC @CanBeAdded = dbo.CanAddDishToOrder @DishID, @OrderID
			SET @UnitPrice = (SELECT DishPrice FROM MenuDetails WHERE DishID = @DishID AND MenuID = @CurrentMenu)
			SET @OrderValue = dbo.GetOrderValue(@OrderID)
			IF (@CanBeAdded = 1)
			BEGIN
				INSERT INTO OrderDetails(OrderID, DishID, UnitPrice, Quantity)
				VALUES (@OrderID, @DishID, @UnitPrice, @Quantity);
				SET @NewValue = @OrderValue + @UnitPrice*@Quantity
				EXEC dbo.UpdateValue @OrderID, @NewValue
			END
			ELSE
			BEGIN
				;THROW 52000, 'Danie nie spelnia warunkow', 1;
			END
		COMMIT TRAN TAddDishToOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddDishToOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania dania do zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddEmployee]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
-------------------Employees----------------------

CREATE PROCEDURE [dbo].[AddEmployee]
    @FirstName nvarchar(30),
    @LastName nvarchar(30),
    @Pesel nvarchar(11),
    @BirthDate date,
    @HireDate date,
    @Address nvarchar(60),
    @Phone nvarchar(9),
    @Mail nvarchar(30),
    @Post nvarchar(20),
    @Salary decimal(20,2) = 2600
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddEmployee
            INSERT INTO Employees(FirstName, LastName, Pesel, BirthDate, HireDate, Address, Phone, Mail, Post, Salary)
            VALUES (@FirstName, @LastName, @Pesel, @BirthDate, @HireDate, @Address, @Phone, @Mail, @Post, @Salary);
        COMMIT TRAN TAddEmployee
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddEmployee
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania pracownika:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddGrantedDiscount]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
-----------------GrantedDiscounts-----------------
CREATE PROCEDURE [dbo].[AddGrantedDiscount]
    @CustomerID int,
	@DiscountID int,
	@DiscountValue decimal(6, 2),
    @ExpirationDate datetime = NULL,
	@Used bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddGrantedDiscount
            DECLARE @GrantedDate datetime = GETDATE()
            INSERT INTO GrantedDiscounts(CustomerID, DiscountID, DiscountValue, GrantedDate, ExpirationDate, Used)
            VALUES (@CustomerID, @DiscountID, @DiscountValue, @GrantedDate, @ExpirationDate, @Used);
        COMMIT TRAN TAddGrantedDiscount
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddGrantedDiscount
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania przyznanej znizki:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddIndividualCustomer]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
----------------IndividualCustomers---------------

CREATE PROCEDURE [dbo].[AddIndividualCustomer]
	@CompanyID int = null,
	@FirstName nvarchar(24) = 'forbidden',
	@LastName nvarchar(30) = 'forbidden',
    @Age int = NULL,
	@PersonalDateAgreement bit = 0,
	@NumberOfOrders int =0,
	@OrdersInRow int = 0,
	@SumOfOrders decimal(20,2) = 0,
    @CustomerType nvarchar(10) = 'individual',
    @Phone nvarchar(9) = 'forbidden',
    @Mail nvarchar(30) = 'forbidden',
    @CustomerID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddIndCustomer
            EXEC AddCustomer
            @CustomerType,
            @Phone,
            @Mail,
            @CustomerID = @CustomerID OUTPUT
			SET IDENTITY_INSERT dbo.IndividualCustomers ON
            INSERT INTO IndividualCustomers(IndividualCustomerID, CompanyID, FirstName, LastName, Age, PersonalDataAgreement, NumberOfOrders, OrdersInRow, SumOfOrders)
            VALUES (@CustomerID, @CompanyID, @FirstName, @LastName, @Age, @PersonalDateAgreement, @NumberOfOrders, @OrdersInRow, @SumOfOrders);
			SET IDENTITY_INSERT dbo.IndividualCustomers OFF
		COMMIT TRAN TAddIndCustomer
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddIndCustomer
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania klienta indywidualnego:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddMenu]
	@InseritonDate datetime = NULL,
	@RemovalDate datetime = NULL

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddMenu
			IF (@InseritonDate IS NULL)
			BEGIN
				SET @InseritonDate = (SELECT DATEADD(DAY, 1, GETDATE()));
			END
			IF (@RemovalDate IS NULL OR @RemovalDate > DATEADD(WEEK, 2, @InseritonDate))
			BEGIN
				SET @RemovalDate = DATEADD(WEEK, 2, @InseritonDate);
			END
			IF (@InseritonDate < (SELECT DATEADD(DAY, 1, GETDATE())))
			BEGIN
				;THROW 52000, 'Menu nie moze byc wprowadzone z wyprzedzeniem mniejszym niz 1 dzien', 1;
			END
			ELSE
			BEGIN
				DECLARE @CurrentMenu int
				EXEC @CurrentMenu = dbo.GetCurrentMenu
				IF (@CurrentMenu IS NOT NULL)
				BEGIN
					EXEC dbo.RemoveMenu @CurrentMenu, @InseritonDate
				END
				INSERT INTO Menu(InsertionDate, RemovalDate)
				VALUES (@InseritonDate, @RemovalDate);
			END
		COMMIT TRAN TAddMenu
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddMenu
		DECLARE @msg nvarchar(2048) = 
		'Blad utworzenia menu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddOrder]
	@CustomerID int,
	@EmployeeID int,
	@ReceptionType nvarchar(11) = 'takeaway',
	@PaymentType nvarchar(11),
	@OrderDate datetime = NULL, --data złożenia zamówienia
	@ReceiveDate datetime , --tu ma być data z formularza, data odebrania zamówienia
	@Value decimal(20,2) = 0,
	@Received bit = NULL,
	@Settled bit = 0,
	@OrderID int OUT

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddOrder
			
			IF @OrderDate IS NULL
			BEGIN
				SET @OrderDate = GETDATE();
			END

			INSERT INTO Orders(CustomerID, EmployeeID, ReceptionType, PaymentType, OrderDate, ReceiveDate, Value, Discount, Completed, Received, Settled)
			VALUES (@CustomerID, @EmployeeID, @ReceptionType, @PaymentType, @OrderDate, @ReceiveDate, @Value, NULL, 0, @Received, @Settled)

			SET @OrderID = @@IDENTITY

		COMMIT TRAN TAddOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddOrderToReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddOrderToReceipt]
	@ReceiptID int,
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddOrderToReceipt
			DECLARE @OrderValue decimal(20,2), @ReceiptValue decimal(20,2), @NewValue decimal(20,2)
			EXEC @OrderValue = dbo.GetValueAfterDiscount @OrderID
			EXEC @ReceiptValue = dbo.GetReceiptValue @ReceiptID
			SET @NewValue = @ReceiptValue + @OrderValue
			EXEC dbo.ChangeReceiptValue @ReceiptID, @NewValue
			INSERT INTO ReceiptDetails(ReceiptID, OrderID)
			VALUES (@ReceiptID, @OrderID)
		COMMIT TRAN TAddOrderToReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddOrderToReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania zamowienia do rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddProduct]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--PRODUCTS

CREATE PROCEDURE [dbo].[AddProduct]
	@ProductName nvarchar(50),
	@CategoryID int,
	@UnitPrice decimal(20,2),
	@UnitsInStock smallint = 0

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddProduct
			INSERT INTO Products(ProductName, CategoryID, UnitPrice, UnitsInStock)
			VALUES (@ProductName, @CategoryID, @UnitPrice, @UnitsInStock);
		COMMIT TRAN TAddProduct
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddProduct
		DECLARE @msg nvarchar(2048) = 
		'Blad dodania Produktu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddProductToDish]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddProductToDish]
	@DishID int,
	@ProductID int,
	@UnitPrice decimal(20,2),
	@Quantity int = 1

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TProductToDish
			INSERT INTO DishDetails (DishID, ProductID, UnitPrice, Quantity)
			VALUES (@DishID, @ProductID, @UnitPrice, @Quantity);
			
			DECLARE @DishValue decimal(20,2) = @UnitPrice*@Quantity
			DECLARE @CurrentValue decimal(20,2)
			EXEC @CurrentValue = GetCurrentDishPrice @DishID
			DECLARE @NewValue decimal(20,2) = @DishValue + @CurrentValue
			
			EXEC dbo.UpdateDishPrice
				@DishID,
				@NewValue
				
		COMMIT TRAN TAddProduct
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TProductToDish
		DECLARE @msg nvarchar(2048) = 
		'Blad dodania Produktu do dania:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--RECEIPT

CREATE PROCEDURE [dbo].[AddReceipt]
	@InvoicedCustomer int,
	@InvoiceDate datetime,
	@AccountNumber nvarchar(26),
	@ReceiptType nvarchar(20),
	@PaymentMethod nvarchar(8),
	@Value decimal(20,2),
	@Settled bit = 0,
	@Cancelled bit = 0,
	@SaleDate datetime,
	@ReceiptID int OUTPUT

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddReceipt
			INSERT INTO Receipt(InvoicedCustomer, InvoiceDate, AccountNumber, ReceiptType, PaymentMethod, Value, Settled, Cancelled, SaleDate)
			VALUES (@InvoicedCustomer, @InvoiceDate, @AccountNumber, @ReceiptType, @PaymentMethod, @Value, @Settled, @Cancelled, @SaleDate)
			SET @ReceiptID = @@IDENTITY
			IF (@ReceiptType = 'collective invoice')
				BEGIN
					DECLARE @InvoicePeriod int, @ValidTo datetime
					SET @InvoicePeriod = (SELECT InvoicePeriod FROM Companies WHERE CompanyID = @InvoicedCustomer)
					SET @ValidTo = DATEADD(month, @InvoicePeriod, @SaleDate)
					EXEC dbo.AddCollectiveInvoice @ReceiptID, @SaleDate, @ValidTo, 1
				END
		COMMIT TRAN TAddReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddRefund]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--REFUNDS

CREATE PROCEDURE [dbo].[AddRefund]
	@ReceiptID int,
	@OrderID int,
	@Value decimal(20,2) = 0,
	@Refunded bit = 0

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TAddRefund
			INSERT INTO Refunds(ReceiptID, OrderID, Value, Refunded)
			VALUES (@ReceiptID, @OrderID, @Value, @Refunded)
		COMMIT TRAN TAddRefund
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TAddRefund
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania zwrotu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddReservation]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddReservation]
    @OrderID int,
    @CustomerID int, 
    @NumberOfPeople int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddReservation
            DECLARE @CanMakeReservation bit

            EXEC @CanMakeReservation = CheckReservationConditions @CustomerID, @OrderID, @NumberOfPeople
            IF @CanMakeReservation = 1
                INSERT INTO Reservations(OrderID, CustomerID, NumberOfPeople)
                VALUES (@OrderID, @CustomerID, @NumberOfPeople);
        COMMIT TRAN TAddReservation
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddReservation
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania rezerwacji:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddTable]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
--------------------Tables------------------------

CREATE PROCEDURE [dbo].[AddTable]
    @NumberOfSeats int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddTable
            INSERT INTO Tables(NumberOfSeats)
            VALUES (@NumberOfSeats);
        COMMIT TRAN TAddTable
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddTable
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania stolika:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[AddTableToReservation]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
----------------ReservationDetails----------------

CREATE PROCEDURE [dbo].[AddTableToReservation]
    @ReservationID int,
    @TableID int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN TAddTableToReservation
            INSERT INTO ReservationDetails(ReservationID, TableID)
            VALUES (@ReservationID, @TableID);
        COMMIT TRAN TAddTableToReservation
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TAddTableToReservation
    DECLARE @msg NVARCHAR(2048) =
    'Bład dodania stolika do rezerwacji:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[CancelOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--CANCELLING_ORDERS

CREATE PROCEDURE [dbo].[CancelOrder]
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		BEGIN TRAN TCancelOrder
			DECLARE @ReceiptID int
			EXEC @ReceiptID = dbo.GetOrderReceipt @OrderID
			IF (@ReceiptID IS NOT NULL)
			--zamowienie zostalo juz oplacone
			BEGIN
				EXEC dbo.CancelReceipt @ReceiptID, @OrderID
			END
			UPDATE Orders
			SET Received = 0
			WHERE OrderID = @OrderID
		COMMIT TRAN TCancelOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TCancelOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad anulowania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[CancelReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--CANCELLING_RECEIPT

CREATE PROCEDURE [dbo].[CancelReceipt]
	@ReceiptID int,
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TCancelReceipt
			IF (dbo.IsCollectiveInvoice (@ReceiptID) = 1)
			BEGIN
				EXEC dbo.RemoveOrderFromReceipt @ReceiptID, @OrderID
			END
			ELSE IF (SELECT Settled FROM Receipt WHERE ReceiptID = @ReceiptID) = 1
			BEGIN
				DECLARE @Value decimal(20,2)
				EXEC @Value = dbo.GetReceiptValue @ReceiptID
				EXEC dbo.AddRefund @ReceiptID, @OrderID, @Value
			END
			UPDATE Receipt
			SET Cancelled = 1
			WHERE ReceiptID = @ReceiptID
		COMMIT TRAN TCancelReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TCancelReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad anulowania rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[ChangeReceiptValue]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ChangeReceiptValue]
	@ReceiptID int,
	@NewValue decimal(20,2)

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TChangeReceiptValue
			UPDATE Receipt
			SET Value = @NewValue
			WHERE ReceiptID = @ReceiptID
		COMMIT TRAN TChangeReceiptValue
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TChangeReceiptValue
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany wartosci rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[CheckCollectiveInvoices]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--CONTROL_PROCEDURES

CREATE PROCEDURE [dbo].[CheckCollectiveInvoices]
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		BEGIN TRAN TCheckCollectiveInvoices
			DECLARE @MyCursor CURSOR
			DECLARE @ReceiptID int, @ValidTo datetime
			SET @MyCursor = CURSOR FOR 
			SELECT ReceiptID, ValidTo FROM CollectiveInvoices WHERE InProgress = 1

			OPEN @MyCursor 
			FETCH NEXT FROM @MyCursor 
			INTO @ReceiptID, @ValidTo

			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF GETDATE() > @ValidTo
				BEGIN
					DECLARE @date datetime
					SET @date = GETDATE()
					EXEC dbo.UpdateCollectiveInvoiceStatus @ReceiptID, 0
					EXEC dbo.InvoiceReceipt @ReceiptID, @date
				END
				FETCH NEXT FROM @MyCursor 
				INTO @ReceiptID, @ValidTo 
			END; 

			CLOSE @MyCursor ;
			DEALLOCATE @MyCursor;
		COMMIT TRAN TCheckCollectiveInvoices
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TCheckCollectiveInvoices
		DECLARE @msg nvarchar(2048) = 
		'Blad sprawdzania czy faktura zbiorcza powinna byc zamknieta:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[CompleteOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CompleteOrder]
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TCompleteOrder
			DECLARE @PaymentType nvarchar(11)
			SET @PaymentType = (SELECT PaymentType FROM Orders WHERE OrderID = @OrderID)
			IF @PaymentType = 'in-advance' OR dbo.IsReceived(@OrderID) = 1
			BEGIN
				UPDATE Orders
				SET Completed = 1
				WHERE OrderID = @OrderID
				EXEC dbo.InvoiceOrder @OrderID
			END
			ELSE
			BEGIN
				;THROW 52000, 'Nie mozna zatwierdzic zamowienia przy platnosci na miejscu, jesli zamowienie nie zostalo jeszcze odebrane', 1;
			END
		COMMIT TRAN TCompleteOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TCompleteOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad zamykania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[DeleteOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DeleteOrder]
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TDeleteOrder
			DELETE FROM Orders
			WHERE OrderID = @OrderID
		COMMIT TRAN TDeleteOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TDeleteOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad usuwania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[GetDiscountValue]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetDiscountValue]
    @CustomerID int,
    @result decimal(6,2) = 0 OUTPUT
AS
BEGIN  
    BEGIN TRY
    BEGIN TRAN TGetDiscountValue
        DECLARE @GrantedDiscountID int = 0
        --pętla przechodzi po wszystkich wierszach i sprawdza, czy jakiś rabat się przedawnił
        WHILE (1=1)
        BEGIN
            SELECT TOP 1 @GrantedDiscountID = GrantedDiscountID
            FROM GrantedDiscounts
            WHERE GrantedDiscountID > @GrantedDiscountID
            ORDER BY GrantedDiscountID
            IF @@ROWCOUNT = 0 BREAK;

            IF ((SELECT CustomerID FROM GrantedDiscounts WHERE GrantedDiscountID = @GrantedDiscountID)  = @CustomerID)
            BEGIN
                DECLARE @DiscountID int = (SELECT DiscountID FROM GrantedDiscounts WHERE GrantedDiscountID = @GrantedDiscountID)
                IF ( @DiscountID IN (3, 4))    
                    EXEC UpdateUsed @GrantedDiscountID
                IF ( @DiscountID IN (1, 2, 3, 4, 5))
                    SET @result = @result + (SELECT DiscountValue FROM GrantedDiscounts WHERE GrantedDiscountID = @GrantedDiscountID)
            END
        END
    COMMIT TRAN TGetDiscountValue
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TGetDiscountValue
    DECLARE @msg NVARCHAR(2048) =
    'Bład zwracania sumy rabatow:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[InvoiceOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InvoiceOrder]
@OrderID int,
	@AccountNumber nvarchar(26) = NULL

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TInvoiceOrder

			DECLARE @CustomerID int, @ReceiptID int, 
					@DiscountValue decimal(20,2), 
					@PaymentType nvarchar(11), 
					@OrderDate datetime, 
					@SaleDate datetime, 
					@ParentCompany int,
					@PaymentMethod nvarchar(8)
			SET @CustomerID = (SELECT CustomerID 
							   FROM Orders WHERE 
							   OrderID = @OrderID)
			SET @PaymentType = (SELECT PaymentType 
								FROM Orders WHERE
								OrderID = @OrderID)
			SET @SaleDate = GETDATE()
			SET @ParentCompany = (SELECT CompanyID 
								  FROM IndividualCustomers 
								  WHERE IndividualCustomerID 
								  = @CustomerID)
			
			EXEC dbo.AddDiscountToOrder @OrderId

			IF (dbo.CheckIfIndividual(@CustomerID) = 1 
				AND @ParentCompany IS NULL)
			--w pelni indywidualny klient
			BEGIN
				IF (@PaymentType = 'in-advance')
				BEGIN
					SET @PaymentMethod = 'transfer'
				END
				ELSE
				--platnosc przy odbiorze
				BEGIN
					SET @PaymentMethod = 'cash'
				END
				EXEC dbo.AddReceipt 
						@InvoicedCustomer = @CustomerID, 
						@InvoiceDate = NULL, 
						@AccountNumber = @AccountNumber, 
						@ReceiptType = 'receipt', 
						@PaymentMethod = @PaymentMethod, 
						@Value = 0, 
						@Settled = 0, 
						@Cancelled = 0, 
						@SaleDate = @SaleDate, 
						@ReceiptID = @ReceiptID OUTPUT
				EXEC dbo.AddOrderToReceipt @ReceiptID, @OrderID
				EXEC dbo.InvoiceReceipt @ReceiptID, @SaleDate
			END
			ELSE IF (dbo.CheckIfIndividual (@CustomerID) = 1 
					 AND @ParentCompany IS NOT NULL)
			--indywidualny klient firmowy
			BEGIN
			--na rachunku bedzie firma
				SET @CustomerID = @ParentCompany	
			END
			IF (dbo.CheckIfIndividual (@CustomerID) = 0)
			--klient firmowy
			BEGIN
				DECLARE @InvoicePeriod int
				SET @InvoicePeriod = (SELECT InvoicePeriod 
									  FROM Companies WHERE 
									  CompanyID = @CustomerID)
				IF (@InvoicePeriod < 0)
				--jesli nie rozliczamy go na fakture zbiorcza
				BEGIN
					IF (@PaymentType = 'in-advance')
					BEGIN
						SET @PaymentMethod = 'transfer'
					END
					ELSE 
					--platnosc przy odbiorze
					BEGIN
						SET @PaymentMethod = 'cash'
					END
					EXEC dbo.AddReceipt 
						@InvoicedCustomer = @CustomerID, 
						@InvoiceDate = NULL, 
						@AccountNumber = @AccountNumber, 
						@ReceiptType = 'one-time invoice', 
						@PaymentMethod = 'cash', 
						@Value = 0, 
						@Settled = 0, 
						@Cancelled = 0, 
						@SaleDate = @SaleDate, 
						@ReceiptID = @ReceiptID OUTPUT
					EXEC dbo.AddOrderToReceipt @ReceiptID, @OrderID
					EXEC dbo.InvoiceReceipt @ReceiptID, @SaleDate
				END
				ELSE
				--dodajemy do faktury zbiorczej
				BEGIN
					SET @ReceiptID = (SELECT TOP(1) R.InvoicedCustomer 
									  FROM CollectiveInvoices CI 
									  INNER JOIN Receipt R ON 
									  CI.ReceiptID = R.ReceiptID 
									  WHERE CI.InProgress = 1)
					IF (@ReceiptID IS NULL)
					--trzeba utworzyc nowa fakture
					BEGIN
						EXEC dbo.AddReceipt 
							@InvoicedCustomer = @CustomerID, 
							@InvoiceDate = NULL, 
							@AccountNumber = @AccountNumber, 
							@ReceiptType = 'collective invoice', 
							@PaymentMethod = 'transfer', 
							@Value = 0, 
							@Settled = 0, 
							@Cancelled = 0, 
							@SaleDate = @SaleDate, 
							@ReceiptID = @ReceiptID OUTPUT
							
					END
					EXEC dbo.AddOrderToReceipt @ReceiptID, @OrderID
				END
			END
			
		COMMIT TRAN TInvoiceOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TInvoiceOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad rozliczania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[InvoiceReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InvoiceReceipt]
	@ReceiptID int,
	@InvoiceDate datetime

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TInvoiceReceipt
			UPDATE Receipt
			SET InvoiceDate = @InvoiceDate
			WHERE ReceiptID = @ReceiptID
		COMMIT TRAN TInvoiceReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TInvoiceReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad wystawiania faktury:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[MonthlyCompanyUpdate]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--comiesięczna aktualizacja 
CREATE PROCEDURE [dbo].[MonthlyCompanyUpdate]
AS
BEGIN  
    WAITFOR TIME '00:00';
    BEGIN TRY
    IF DAY(GETDATE()) = 1
    BEGIN
        BEGIN TRAN TMonthlyCompanyUpdate
        --iteruje po wszystkich firmach
            DECLARE @CompanyID int = 0
            WHILE (1=1)
            BEGIN
                SELECT TOP 1 @CompanyID = CompanyID
                FROM Companies
                WHERE CompanyID > @CompanyID
                ORDER BY CompanyID
                IF @@ROWCOUNT = 0 BREAK;
                
                --naliczanie rabatu miesięcznego
                IF ((SELECT NumberOfOrdersInMonth FROM Companies WHERE CompanyID = @CompanyID) >= 5 AND (SELECT SumOfOrdersInMonth FROM Companies WHERE CompanyID = @CompanyID) >= 500)
                BEGIN
                    UPDATE Companies SET NumberOfMonthsInRow += 1 WHERE CompanyID = @CompanyID
					DECLARE @MonthsInRow int
					SELECT @MonthsInRow = NumberOfMonthsInRow FROM Companies WHERE CompanyID = @CompanyID
					DECLARE @NewDiscountValue decimal(6,2) = 0.01 * @MonthsInRow
					IF(@NewDiscountValue > 0.05) SET @NewDiscountValue = 0.05
                    BEGIN
                        DECLARE @NewDate datetime = DATEADD(month, 1, GETDATE())
                        EXEC AddGrantedDiscount
						    @CustomerID = @CompanyID,
						    @DiscountID  = 5,
						    @DiscountValue = @NewDiscountValue,
						    @ExpirationDate = @NewDate,
						    @Used = 0
                    END
                END
                ELSE
                    UPDATE Companies SET NumberOfMonthsInRow = 0 WHERE CompanyID = @CompanyID
                --zeruje wartosc ze starego miesiąca
                UPDATE Companies SET NumberOfOrdersInMonth = 0 WHERE CompanyID = @CompanyID
                UPDATE Companies SET SumOfOrdersInMonth = 0 WHERE CompanyID = @CompanyID

                --drugi rabat (kwartalny)
                IF(MONTH(GETDATE()) IN (1, 4, 7, 10))
                BEGIN
					DECLARE @SumOfOrdersInQuarter decimal(6,2)
					SELECT @SumOfOrdersInQuarter = SumOfOrdersInQuarter FROM Companies WHERE CompanyID = @CompanyID
                    SET @NewDiscountValue = 0.05 * @SumOfOrdersInQuarter
                    IF(@SumOfOrdersInQuarter >= 10000)
                    BEGIN
                        SET @NewDate = DATEADD(month, 3, GETDATE())
                        EXEC AddGrantedDiscount
							@CustomerID = @CompanyID,
							@DiscountID  = 6,
							@DiscountValue = @NewDiscountValue,
							@ExpirationDate = @NewDate,
							@Used = 0
                    END
                     UPDATE Companies SET SumOfOrdersInQuarter = 0 WHERE CompanyID = @CompanyID
                END

            END
        COMMIT TRAN TMonthlyCompanyUpdate
    END
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TMonthlyCompanyUpdate
    DECLARE @msg NVARCHAR(2048) =
    'Bład comiesiecznej aktualizacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[RemoveDish]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RemoveDish]
	@DishID int
	
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TRemoveDish
			UPDATE Dishes
			SET RemovalDate = GETDATE()
			WHERE DishID = @DishID;
		COMMIT TRAN TRemoveDish
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TRemoveDish
		DECLARE @msg nvarchar(2048) = 
		'Blad wycofania dania:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[RemoveMenu]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RemoveMenu]
	@MenuID int,
	@RemovalDate datetime = NULL

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TRemoveMenu
			IF (@RemovalDate IS NULL)
			BEGIN
				SET @RemovalDate = GETDATE();
			END
			IF (@RemovalDate <= (SELECT RemovalDate FROM Menu WHERE MenuID = @MenuID))
			BEGIN
				UPDATE Menu
				SET RemovalDate = @RemovalDate
				WHERE MenuID = @MenuID;
			END
			ELSE
			BEGIN
				;THROW 52000, 'Menu nie moze byc usuniete pozniej niz bylo to poczatkowo zakladane', 1;
			END
		COMMIT TRAN TRemoveMenu
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TRemoveMenu
		DECLARE @msg nvarchar(2048) = 
		'Blad usuniecia menu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[RemoveOrderFromReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RemoveOrderFromReceipt]
	@ReceiptID int,
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TRemoveOrderFromReceipt
			DECLARE @OrderValue decimal(20,2), @ReceiptValue decimal(20,2), @NewValue decimal(20,2)
			EXEC @OrderValue = dbo.GetValueAfterDiscount @OrderID
			EXEC @ReceiptValue = dbo.GetReceiptValue @ReceiptID
			SET @NewValue = @ReceiptValue - @OrderValue
			EXEC dbo.ChangeReceiptValue @ReceiptID, @NewValue
			DELETE FROM ReceiptDetails
			WHERE ReceiptID = @ReceiptID AND OrderID = @OrderID
		COMMIT TRAN TRemoveOrderFromReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TRemoveOrderFromReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania zamowienia do rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[SettleOrder]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SettleOrder]
	@OrderID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TSettleOrder
			UPDATE Orders
			SET Settled = 1
			WHERE OrderID = @OrderID
		COMMIT TRAN TSettleOrder
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TSettleOrder
		DECLARE @msg nvarchar(2048) = 
		'Blad rozliczania zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[SettleReceipt]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SettleReceipt]
	@ReceiptID int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TSettleReceipt
			DECLARE @MyCursor CURSOR
			DECLARE @OrderID int
			SET @MyCursor = CURSOR FOR 
			SELECT * FROM dbo.GetOrdersFromReceipt (@ReceiptID)

			OPEN @MyCursor 
			FETCH NEXT FROM @MyCursor 
			INTO @OrderID

			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC dbo.SettleOrder @OrderID
				FETCH NEXT FROM @MyCursor 
				INTO @OrderID 
			END; 

			CLOSE @MyCursor ;
			DEALLOCATE @MyCursor;

			UPDATE Receipt
			SET Settled = 1
			WHERE ReceiptID = @ReceiptID
		COMMIT TRAN TSettleReceipt
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TSettleReceipt
		DECLARE @msg nvarchar(2048) = 
		'Blad oplacania rachunku:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateAvailability]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateAvailability]
    @TableID int,
    @Available bit -- 0 - niedostępny / 1 - dostępny
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateAvailability
            UPDATE Tables SET Availability = @Available WHERE TableID = @TableID
        COMMIT TRAN TUpdateAvailability
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateAvailability
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji dostepnosci stolika:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCollectiveInvoiceStatus]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateCollectiveInvoiceStatus]
	@ReceiptID int,
	@InProgress bit = 0

AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		BEGIN TRAN TUpdateCollectiveInvoiceStatus
			UPDATE CollectiveInvoices
			SET InProgress = @InProgress
			WHERE ReceiptID = @ReceiptID
			DECLARE @date datetime
			SET @date = GETDATE()
			EXEC dbo.InvoiceReceipt @ReceiptID, @date;
		COMMIT TRAN TAddCollectiveInvoice
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateCollectiveInvoiceStatus
		DECLARE @msg nvarchar(2048) = 
		'Blad dodawania rachunku zbiorczego:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCompanyData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateCompanyData]
    @CustomerID int,
    @CompanyName nvarchar(30),
	@NIP nvarchar(10),
	@Country nvarchar(40),
	@ZipCode nvarchar(30),
	@Address nvarchar(40),
	@City nvarchar(40),
	@InvoicePeriod int,
    @Phone nvarchar(9),
    @Mail nvarchar(30)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateCompanyData
            IF @CompanyName IS NOT NULL 
            BEGIN
                UPDATE Companies SET CompanyName = @CompanyName WHERE CompanyID  = @CustomerID
            END
            IF @NIP IS NOT NULL
            BEGIN
                UPDATE Companies SET NIP = @NIP WHERE CompanyID  = @CustomerID
            END
            IF @Country IS NOT NULL
            BEGIN
                UPDATE Companies SET Country = @Country WHERE CompanyID  = @CustomerID
            END
            IF @ZipCode IS NOT NULL
            BEGIN
                UPDATE Companies SET ZipCode = @ZipCode WHERE CompanyID  = @CustomerID
            END
            IF @Address IS NOT NULL
            BEGIN
                UPDATE Companies SET Address = @Address WHERE CompanyID  = @CustomerID
            END
            IF @City IS NOT NULL
            BEGIN
                UPDATE Companies SET City = @City WHERE CompanyID  = @CustomerID
            END
            IF @InvoicePeriod IS NOT NULL
            BEGIN
                UPDATE Companies SET InvoicePeriod = @InvoicePeriod WHERE CompanyID  = @CustomerID
            END
            IF (@Phone IS NOT NULL OR @Mail IS NOT NULL)
                BEGIN
                EXEC UpdateCustomerData
                @CustomerID,
                @Phone,
                @Mail
                END
        COMMIT TRAN TUpdateCompanyData
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateCompanyData
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych firmy:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCompanyOrdersData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--aktualizacja statystyk z zamówień firmy
CREATE PROCEDURE [dbo].[UpdateCompanyOrdersData]
@CustomerID int,
@OrderValue decimal(20,2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdateCompanyOrdersData

                UPDATE Companies SET NumberOfOrdersInMonth += 1 WHERE CompanyID = @CustomerID
                UPDATE Companies SET SumOfOrdersInMonth += @OrderValue WHERE CompanyID = @CustomerID
                UPDATE Companies SET SumOfOrdersInQuarter += @OrderValue WHERE CompanyID = @CustomerID

        COMMIT TRAN UpdateCompanyOrdersData
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN UpdateCompanyOrdersData
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych zamówień dla firmy:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCustomerData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateCustomerData]
    @CustomerID int,
    @Phone nvarchar(9),
    @Mail nvarchar(30)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateCustomerData
            IF @Phone IS NOT NULL
            BEGIN
                UPDATE Customers SET Phone = @Phone WHERE CustomerID = @CustomerID
            END
            IF @Mail IS NOT NULL
            BEGIN
                UPDATE Customers SET Mail = @Mail WHERE CustomerID = @CustomerID
            END
        COMMIT TRAN TUpdateCustomerData
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateCustomerData
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych klienta:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateDataForDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------
-------------------Customers----------------------


--procedura odpalana triggerem po aktualizacji settled i received na 1
CREATE PROCEDURE [dbo].[UpdateDataForDiscounts]
    @CustomerID int,
    @OrderValue decimal(20,2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateDataForDiscounts
            DECLARE @IsIndividual bit
            EXEC @IsIndividual = CheckIfIndividual @CustomerID
            IF (@IsIndividual = 1)
                EXEC UpdateIndCustomerOrdersData
                    @CustomerID,
                    @OrderValue
            ELSE
                EXEC UpdateCompanyOrdersData
                    @CustomerID,
                    @OrderValue
        COMMIT TRAN TUpdateDataForDiscounts
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateDataForDiscounts
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych zamówień dla klienta:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateDishAvailability]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateDishAvailability]
	@MenuID int,
	@DishID int,
	@NewAvailability bit

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateDishAvailability
			UPDATE MenuDetails
			SET Availability = @NewAvailability
			WHERE MenuID = @MenuID AND DishID = @DishID
		COMMIT TRAN TUpdateDishAvailability
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateDishAvailability
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany dostenosci dania w menu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateDishPrice]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateDishPrice]
	@DishID int,
	@NewPrice int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateDishPrice
			UPDATE Dishes
			SET DishPrice = @NewPrice
			WHERE DishID = @DishID;
		COMMIT TRAN TUpdateDishPrice
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateDishPrice
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany ceny dania:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateDishQuantity]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateDishQuantity]
	@OrderID int,
	@DishID int,
	@NewQuantity smallint

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateDishQuantity
			DECLARE @OldQuantity smallint, 
					@DishPrice decimal(20,2), 
					@OrderValue decimal(20,2),
					@NewValue decimal(20,2)
			SET @OldQuantity = (SELECT Quantity FROM OrderDetails 
								WHERE OrderID = @OrderID AND DishID = @DishID)
			SET @DishPrice = (SELECT UnitPrice FROM OrderDetails 
								WHERE OrderID = @OrderID AND DishID = @DishID)
			SET @OrderValue = dbo.GetOrderValue(@OrderID)
			UPDATE OrderDetails
			SET Quantity = @NewQuantity
			WHERE OrderID = @OrderID AND DishID = @DishID

			SET @NewValue = @OrderValue + (@NewQuantity-@OldQuantity)*@DishPrice

			EXEC dbo.UpdateValue @OrderID, @NewValue  

		COMMIT TRAN TUpdateDishQuantity
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateDishQuantity
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany ilosci dania w zamowieniu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateEmployeeData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateEmployeeData]
    @EmployeeID int,
    @Post nvarchar(20),
    @Salary decimal(20,2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateSalary
            IF @Post IS NOT NULL
            BEGIN
                UPDATE Employees SET Post = @Post WHERE EmployeeID = @EmployeeID
            END
            IF @Salary IS NOT NULL
            BEGIN
                UPDATE Employees SET Salary = @Salary WHERE EmployeeID = @EmployeeID
            END
        COMMIT TRAN TUpdateSalary
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateSalary
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji wynagrodzenia:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateExpiredDiscounts]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateExpiredDiscounts]
AS
BEGIN  
    WAITFOR TIME '00:00';
    BEGIN TRY
    BEGIN TRAN TUpdateExpiredDiscounts
        DECLARE @GrantedDiscountID int = 0
        --pętla przechodzi po wszystkich wierszach i sprawdza, czy jakiś rabat się przedawnił
        WHILE (1=1)
        BEGIN
            SELECT TOP 1 @GrantedDiscountID = GrantedDiscountID
            FROM GrantedDiscounts
            WHERE GrantedDiscountID > @GrantedDiscountID
            ORDER BY GrantedDiscountID
            IF @@ROWCOUNT = 0 BREAK;

			DECLARE @ExpDate datetime
			SELECT @ExpDate = ExpirationDate FROM GrantedDiscounts WHERE GrantedDiscountID = @GrantedDiscountID
            IF ((@ExpDate IS NOT NULL) AND (@ExpDate < GETDATE()))
                EXEC UpdateUsed @GrantedDiscountID

        END
    COMMIT TRAN TUpdateExpiredDiscounts
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateExpiredDiscounts
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji przedawnionych rabatow:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateIndCustomerOrdersData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--aktualizacja statystyk z zamówień klienta i ewentualne naliczanie rabatu
CREATE PROCEDURE [dbo].[UpdateIndCustomerOrdersData]
@CustomerID int,
@OrderValue decimal(20, 2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateIndCustomerOrdersData

            UPDATE IndividualCustomers SET SumOfOrders += @OrderValue WHERE IndividualCustomerID = @CustomerID
            IF(@OrderValue >= 30)
            BEGIN
                UPDATE IndividualCustomers SET NumberOfOrders += 1 WHERE IndividualCustomerID = @CustomerID
                UPDATE IndividualCustomers SET OrdersInRow += 1 WHERE IndividualCustomerID = @CustomerID
            END
            ELSE
            BEGIN
                UPDATE IndividualCustomers SET OrdersInRow = 0 WHERE IndividualCustomerID = @CustomerID
            END

            IF((SELECT NumberOfOrders FROM IndividualCustomers WHERE IndividualCustomerID = @CustomerID) = 10)
                EXEC AddGrantedDiscount
                    @CustomerID,
	                @DiscountID  = 1,
	                @DiscountValue = 0.03,
                    @ExpirationDate = NULL,
	                @Used = 0
            
            IF((SELECT OrdersInRow FROM IndividualCustomers WHERE IndividualCustomerID = @CustomerID) = 10)
                EXEC AddGrantedDiscount
                    @CustomerID,
	                @DiscountID  = 2,
	                @DiscountValue = 0.03,
                    @ExpirationDate = NULL,
	                @Used = 0
            
            DECLARE @SumOfOrders int = (SELECT SumOfOrders FROM IndividualCustomers WHERE IndividualCustomerID = @CustomerID)

			DECLARE @NewDate datetime = DATEADD(DAY, 7, GETDATE())

            IF( @SumOfOrders >= 1000)
            BEGIN
                EXEC AddGrantedDiscount
                    @CustomerID,
	                @DiscountID  = 3,
	                @DiscountValue = 0.05,
                    @ExpirationDate = @NewDate,
	                @Used = 0
            END
            
            IF( @SumOfOrders >= 5000)
            BEGIN
                EXEC AddGrantedDiscount
                    @CustomerID,
	                @DiscountID  = 4,
	                @DiscountValue = 0.05,
                    @ExpirationDate = @NewDate,
	                @Used = 0
            END

        COMMIT TRAN TUpdateIndCustomerOrdersData
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateIndCustomerOrdersData
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych zamówień dla klienta indywidualnego:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateIndividualCustomerData]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateIndividualCustomerData]
    @CustomerID int,
    @CompanyID int = null,
	@FirstName nvarchar(24),
	@LastName nvarchar(30),
    @Age int = NULL,
	@PersonalDataAgreement bit,
    @Phone nvarchar(9),
    @Mail nvarchar(30)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateIndividualCustomerData
            IF @PersonalDataAgreement IS NOT NULL
            BEGIN
                UPDATE IndividualCustomers SET PersonalDataAgreement = @PersonalDataAgreement WHERE IndividualCustomerID = @CustomerID
            END
            IF @PersonalDataAgreement = 1
            BEGIN
                IF @CompanyID IS NOT NULL 
                BEGIN
                    UPDATE IndividualCustomers SET CompanyID = @CompanyID WHERE IndividualCustomerID  = @CustomerID
                END
                IF @FirstName IS NOT NULL
                BEGIN
                    UPDATE IndividualCustomers SET FirstName = @FirstName WHERE IndividualCustomerID  = @CustomerID
                END
                IF @LastName IS NOT NULL
                BEGIN
                    UPDATE IndividualCustomers SET LastName = @LastName WHERE IndividualCustomerID  = @CustomerID
                END
                IF @Age IS NOT NULL
                BEGIN
                    UPDATE IndividualCustomers SET Age = @Age WHERE IndividualCustomerID  = @CustomerID
                END
                IF (@Phone IS NOT NULL OR @Mail IS NOT NULL)
                    BEGIN
                    EXEC UpdateCustomerData
                    @CustomerID,
                    @Phone,
                    @Mail
                    END
            END
        COMMIT TRAN TUpdateIndividualCustomerData
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateIndividualCustomerData
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji danych klienta indywidualnego:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateReceived]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateReceived]
	@OrderID int,
	@Received bit

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateReceived
			UPDATE Orders
			SET Received = @Received
			WHERE OrderID = @OrderID
		COMMIT TRAN TUpdateReceived
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateReceived
		DECLARE @msg nvarchar(2048) = 
		'Blad realizacji zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateStatus]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateStatus]
	@ReceiptID int,
	@OrderID int,
	@Refunded bit = 1

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateStatus
			UPDATE Refunds
			SET Refunded = @Refunded
			WHERE ReceiptID = @ReceiptID AND OrderID = @OrderID
		COMMIT TRAN TUpdateStatus
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateStatus
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany statusu zwrotu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitPrice]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateUnitPrice]
	@ProductID int,
	@NewPrice decimal(20,2)

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateUnitPrice
			UPDATE Products
			SET UnitPrice = @NewPrice
			WHERE ProductID = @ProductID;
		COMMIT TRAN TUpdateUnitPrice
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateUnitPrice
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany ceny produktu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitsInStock]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateUnitsInStock]
	@ProductID int,
	@ChangedUnits int

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateUnitsInStock
			DECLARE @CurrentUnits int, @CurrentMenu int, @UpcomingMenu int
			UPDATE Products
			SET UnitsInStock = UnitsInStock + @ChangedUnits
			WHERE ProductID = @ProductID;

			SET @CurrentUnits = (SELECT UnitsInStock FROM Products WHERE ProductID = @ProductID)
			SET @CurrentMenu = dbo.GetCurrentMenu()
			SET @UpcomingMenu = dbo.GetUpcomingMenu()

			IF @ChangedUnits > 0
			--dostawa produktu
			BEGIN
				DECLARE @MyCursor CURSOR, @MenuID int, @DishID int
				SET @MyCursor = CURSOR FOR 
				SELECT MD.MenuID, MD.DishID FROM MenuDetails MD 
				INNER JOIN DishDetails DD 
				ON MD.DishID = DD.DishID
				WHERE(MD.MenuID = @CurrentMenu OR MD.MenuID = @UpcomingMenu) 
				AND MD.Availability = 0 AND DD.ProductID = @ProductID 
				AND DD.Quantity <= @CurrentUnits

				OPEN @MyCursor 
				FETCH NEXT FROM @MyCursor 
				INTO @MenuID, @DishID

				WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC dbo.UpdateDishAvailability @MenuID, @DishID, 1
					FETCH NEXT FROM @MyCursor 
					INTO @MenuID, @DishID
				END; 

				CLOSE @MyCursor ;
				DEALLOCATE @MyCursor;
			END;
			ELSE IF @ChangedUnits < 0
			BEGIN
				SET @MyCursor = CURSOR FOR 
				SELECT MD.MenuID, MD.DishID FROM MenuDetails MD 
				INNER JOIN DishDetails DD 
				ON MD.DishID = DD.DishID
				WHERE(MD.MenuID = @CurrentMenu OR MD.MenuID = @UpcomingMenu) 
				AND MD.Availability = 1 AND DD.ProductID = @ProductID 
				AND DD.Quantity > @CurrentUnits

				OPEN @MyCursor 
				FETCH NEXT FROM @MyCursor 
				INTO @MenuID, @DishID

				WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC dbo.UpdateDishAvailability @MenuID, @DishID, 0
					FETCH NEXT FROM @MyCursor 
					INTO @MenuID, @DishID 
				END; 

				CLOSE @MyCursor ;
				DEALLOCATE @MyCursor;
			END;
		COMMIT TRAN TUpdateUnitsInStock
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateUnitsInStock
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany dostepnej ilosci produktu:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateUsed]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateUsed]
    @GrantedDiscountID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN TUpdateUsed
            UPDATE GrantedDiscounts SET Used = 1 WHERE GrantedDiscountID = @GrantedDiscountID
        COMMIT TRAN TUpdateUsed
    END TRY
    BEGIN CATCH
    ROLLBACK TRAN TUpdateUsed
    DECLARE @msg NVARCHAR(2048) =
    'Bład aktualizacji wykorzystania rabatu:' + CHAR(13)+CHAR(10) + ERROR_MESSAGE();
    THROW 52000,@msg, 1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateValue]    Script Date: 19-01-2021 21:22:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateValue]
	@OrderID int,
	@NewValue decimal(20,2)

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN TUpdateValue
			DECLARE @Completed bit
			SET @Completed = (SELECT Completed FROM Orders WHERE OrderID = @OrderID)
			
			IF (@Completed = 0)
			--mozna zmienic wartosc zamowienia tylko gdy nie zostalo zatwierdzone i oplacone
			BEGIN
				UPDATE Orders
				SET Value = @NewValue
				WHERE OrderID = @OrderID
			END

			ELSE 
			BEGIN
				;THROW 52000, 'Nie mozna zmienic zawartosci zamowienia gdy zostalo juz zatwierdzone', 1;
			END

		COMMIT TRAN TUpdateValue
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN TUpdateValue
		DECLARE @msg nvarchar(2048) = 
		'Blad zmiany wartosci zamowienia:'+CHAR(13)+CHAR(10)+ERROR_MESSAGE();
		THROW 52000, @msg, 1;
	END CATCH
END
GO
USE [master]
GO
ALTER DATABASE [u_kroczek] SET  READ_WRITE 
GO
