USE InventoryDB;
GO

/* STEP 1: Category */
CREATE TABLE dbo.Category (
    CategoryID       INT IDENTITY(1,1) CONSTRAINT PK_Category PRIMARY KEY,
    CategoryName     NVARCHAR(100) NOT NULL,
    ParentCategoryID INT NULL,
    Description      NVARCHAR(255) NULL
);
GO

ALTER TABLE dbo.Category
ADD CONSTRAINT FK_Category_Parent
    FOREIGN KEY (ParentCategoryID) REFERENCES dbo.Category(CategoryID);
GO

/* STEP 2: Product */
CREATE TABLE dbo.Product (
    ProductID     INT IDENTITY(1,1) CONSTRAINT PK_Product PRIMARY KEY,
    CategoryID    INT NOT NULL,
    ProductCode   NVARCHAR(50) NOT NULL,
    ProductName   NVARCHAR(150) NOT NULL,
    Unit          NVARCHAR(20)  NULL,
    PurchasePrice DECIMAL(18,2) NULL,
    SalePrice     DECIMAL(18,2) NULL,
    MinStockQty   INT           NULL,
    CreatedDate   DATE          NOT NULL CONSTRAINT DF_Product_CreatedDate DEFAULT (GETDATE()),
    IsActive      BIT           NOT NULL CONSTRAINT DF_Product_IsActive DEFAULT (1)
);
GO

ALTER TABLE dbo.Product
ADD CONSTRAINT FK_Product_Category
    FOREIGN KEY (CategoryID) REFERENCES dbo.Category(CategoryID);

ALTER TABLE dbo.Product
ADD CONSTRAINT UQ_Product_ProductCode UNIQUE (ProductCode);
GO

/* STEP 3: Supplier */
CREATE TABLE dbo.Supplier (
    SupplierID    INT IDENTITY(1,1) CONSTRAINT PK_Supplier PRIMARY KEY,
    SupplierName  NVARCHAR(150) NOT NULL,
    TaxID         NVARCHAR(20)  NULL,
    Phone         NVARCHAR(30)  NULL,
    Email         NVARCHAR(100) NULL,
    Address       NVARCHAR(200) NULL,
    ContactPerson NVARCHAR(100) NULL,
    IsActive      BIT           NOT NULL CONSTRAINT DF_Supplier_IsActive DEFAULT (1)
);
GO

ALTER TABLE dbo.Supplier
ADD CONSTRAINT UQ_Supplier_TaxID UNIQUE (TaxID);
GO

/* STEP 4: Customer */
CREATE TABLE dbo.Customer (
    CustomerID   INT IDENTITY(1,1) CONSTRAINT PK_Customer PRIMARY KEY,
    CustomerName NVARCHAR(150) NOT NULL,
    CustomerType NVARCHAR(50)  NULL,
    Phone        NVARCHAR(30)  NULL,
    Email        NVARCHAR(100) NULL,
    Address      NVARCHAR(200) NULL,
    IsActive     BIT           NOT NULL CONSTRAINT DF_Customer_IsActive DEFAULT (1)
);
GO

/* STEP 5: OperationType */
CREATE TABLE dbo.OperationType (
    OperationTypeID INT IDENTITY(1,1) CONSTRAINT PK_OperationType PRIMARY KEY,
    Code            NVARCHAR(50)  NOT NULL,
    Name            NVARCHAR(100) NOT NULL,
    IsInflow        BIT           NOT NULL
);
GO

ALTER TABLE dbo.OperationType
ADD CONSTRAINT UQ_OperationType_Code UNIQUE (Code);
GO

/* STEP 6: Operation (document header) */
CREATE TABLE dbo.[Operation] (
    OperationID     INT IDENTITY(1,1) CONSTRAINT PK_Operation PRIMARY KEY,
    OperationTypeID INT NOT NULL,
    SupplierID      INT NULL,
    CustomerID      INT NULL,
    OperationDate   DATE NOT NULL,
    DocNumber       NVARCHAR(50) NULL,
    TotalAmount     DECIMAL(18,2) NULL CONSTRAINT DF_Operation_TotalAmount DEFAULT (0),
    Status          NVARCHAR(50) NOT NULL CONSTRAINT DF_Operation_Status DEFAULT ('Draft'),
    Comment         NVARCHAR(255) NULL
);
GO

ALTER TABLE dbo.[Operation]
ADD CONSTRAINT FK_Operation_OperationType
    FOREIGN KEY (OperationTypeID) REFERENCES dbo.OperationType(OperationTypeID);

ALTER TABLE dbo.[Operation]
ADD CONSTRAINT FK_Operation_Supplier
    FOREIGN KEY (SupplierID) REFERENCES dbo.Supplier(SupplierID);

ALTER TABLE dbo.[Operation]
ADD CONSTRAINT FK_Operation_Customer
    FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID);

CREATE INDEX IX_Operation_OperationDate ON dbo.[Operation](OperationDate);
CREATE INDEX IX_Operation_OperationType ON dbo.[Operation](OperationTypeID);
GO

/* STEP 7: OperationLine (document lines) */
CREATE TABLE dbo.OperationLine (
    OperationLineID  INT IDENTITY(1,1) CONSTRAINT PK_OperationLine PRIMARY KEY,
    OperationID      INT NOT NULL,
    ProductID        INT NOT NULL,
    Quantity         DECIMAL(18,3) NOT NULL,
    UnitPrice        DECIMAL(18,2) NOT NULL,
    DiscountPercent  DECIMAL(5,2)  NULL CONSTRAINT DF_OperationLine_Discount DEFAULT (0),
    VATPercent       DECIMAL(5,2)  NULL CONSTRAINT DF_OperationLine_VAT DEFAULT (20),
    LineTotal        DECIMAL(18,2) NULL
);
GO

ALTER TABLE dbo.OperationLine
ADD CONSTRAINT FK_OperationLine_Operation
    FOREIGN KEY (OperationID) REFERENCES dbo.[Operation](OperationID);

ALTER TABLE dbo.OperationLine
ADD CONSTRAINT FK_OperationLine_Product
    FOREIGN KEY (ProductID) REFERENCES dbo.Product(ProductID);

ALTER TABLE dbo.OperationLine
ADD CONSTRAINT CH_OperationLine_Quantity_Positive
    CHECK (Quantity > 0);

CREATE INDEX IX_OperationLine_Operation ON dbo.OperationLine(OperationID);
CREATE INDEX IX_OperationLine_Product   ON dbo.OperationLine(ProductID);
GO

/* STEP 8: PaymentType */
CREATE TABLE dbo.PaymentType (
    PaymentTypeID INT IDENTITY(1,1) CONSTRAINT PK_PaymentType PRIMARY KEY,
    Name          NVARCHAR(100) NOT NULL,
    Description   NVARCHAR(200) NULL
);
GO

/* STEP 9: Payment */
CREATE TABLE dbo.Payment (
    PaymentID     INT IDENTITY(1,1) CONSTRAINT PK_Payment PRIMARY KEY,
    OperationID   INT NOT NULL,
    PaymentTypeID INT NOT NULL,
    PaymentDate   DATE NOT NULL,
    Amount        DECIMAL(18,2) NOT NULL,
    Direction     NVARCHAR(10)  NOT NULL,  -- IN / OUT
    Comment       NVARCHAR(255) NULL
);
GO

ALTER TABLE dbo.Payment
ADD CONSTRAINT FK_Payment_Operation
    FOREIGN KEY (OperationID) REFERENCES dbo.[Operation](OperationID);

ALTER TABLE dbo.Payment
ADD CONSTRAINT FK_Payment_PaymentType
    FOREIGN KEY (PaymentTypeID) REFERENCES dbo.PaymentType(PaymentTypeID);

ALTER TABLE dbo.Payment
ADD CONSTRAINT CH_Payment_Amount_Positive
    CHECK (Amount > 0);

ALTER TABLE dbo.Payment
ADD CONSTRAINT CH_Payment_Direction
    CHECK (Direction IN ('IN','OUT'));

CREATE INDEX IX_Payment_Operation ON dbo.Payment(OperationID);
CREATE INDEX IX_Payment_Date      ON dbo.Payment(PaymentDate);
GO
