/* =========================
   0) Кількості по таблицях
   ========================= */
SELECT 'Category'      AS [Table], COUNT(*) AS Cnt FROM dbo.Category
UNION ALL SELECT 'Product',       COUNT(*) FROM dbo.Product
UNION ALL SELECT 'Customer',      COUNT(*) FROM dbo.Customer
UNION ALL SELECT 'Supplier',      COUNT(*) FROM dbo.Supplier
UNION ALL SELECT 'OperationType', COUNT(*) FROM dbo.OperationType
UNION ALL SELECT 'Operation',     COUNT(*) FROM dbo.[Operation]
UNION ALL SELECT 'OperationLine', COUNT(*) FROM dbo.OperationLine
UNION ALL SELECT 'PaymentType',   COUNT(*) FROM dbo.PaymentType
UNION ALL SELECT 'Payment',       COUNT(*) FROM dbo.Payment;
GO

/* =========================
   1) Перевірка вимог варіанту
   - 50 000 товарів
   - 1 000 000 операцій
   - історія 5 років (2021-2025)
   ========================= */
SELECT
  ProductsCnt   = (SELECT COUNT(*) FROM dbo.Product),
  OperationsCnt = (SELECT COUNT(*) FROM dbo.[Operation]),
  OpMinDate     = (SELECT MIN(OperationDate) FROM dbo.[Operation]),
  OpMaxDate     = (SELECT MAX(OperationDate) FROM dbo.[Operation]);
GO

/* =========================
   2) Перевірка "битих" FK (має бути 0)
   ========================= */
-- Operation -> Customer
SELECT Broken_Operation_Customer = COUNT(*)
FROM dbo.[Operation] o
LEFT JOIN dbo.Customer c ON c.CustomerID = o.CustomerID
WHERE o.CustomerID IS NOT NULL AND c.CustomerID IS NULL;

-- Operation -> Supplier
SELECT Broken_Operation_Supplier = COUNT(*)
FROM dbo.[Operation] o
LEFT JOIN dbo.Supplier s ON s.SupplierID = o.SupplierID
WHERE o.SupplierID IS NOT NULL AND s.SupplierID IS NULL;

-- Operation -> OperationType
SELECT Broken_Operation_Type = COUNT(*)
FROM dbo.[Operation] o
LEFT JOIN dbo.OperationType t ON t.OperationTypeID = o.OperationTypeID
WHERE o.OperationTypeID IS NOT NULL AND t.OperationTypeID IS NULL;

-- OperationLine -> Operation
SELECT Broken_Line_Operation = COUNT(*)
FROM dbo.OperationLine l
LEFT JOIN dbo.[Operation] o ON o.OperationID = l.OperationID
WHERE o.OperationID IS NULL;

-- OperationLine -> Product
SELECT Broken_Line_Product = COUNT(*)
FROM dbo.OperationLine l
LEFT JOIN dbo.Product p ON p.ProductID = l.ProductID
WHERE p.ProductID IS NULL;

-- Payment -> Operation
SELECT Broken_Payment_Operation = COUNT(*)
FROM dbo.Payment pay
LEFT JOIN dbo.[Operation] o ON o.OperationID = pay.OperationID
WHERE o.OperationID IS NULL;

-- Payment -> PaymentType
SELECT Broken_Payment_Type = COUNT(*)
FROM dbo.Payment pay
LEFT JOIN dbo.PaymentType pt ON pt.PaymentTypeID = pay.PaymentTypeID
WHERE pt.PaymentTypeID IS NULL;
GO

/* =========================
   3) Перевірка OperationLine на overflow/некоректні значення
   (залежить від твоєї логіки, але це базово)
   ========================= */
SELECT
  BadQuantity     = SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END),
  BadUnitPrice    = SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END),
  BadDiscount     = SUM(CASE WHEN DiscountPercent IS NOT NULL AND (DiscountPercent < 0 OR DiscountPercent > 100) THEN 1 ELSE 0 END),
  BadVAT          = SUM(CASE WHEN VATPercent IS NOT NULL AND (VATPercent < 0 OR VATPercent > 100) THEN 1 ELSE 0 END),
  BadLineTotalNeg = SUM(CASE WHEN LineTotal < 0 THEN 1 ELSE 0 END)
FROM dbo.OperationLine;
GO

/* =========================
   4) Тест звітів (чернетка)
   ========================= */

-- 4.1 Список товарів категорії з наявністю (по залишку)
-- (залишок = прихід - продаж - списання + повернення_in - повернення_out)
-- Якщо в тебе OperationType.Code саме такі: PURCHASE, SALE, WRITE_OFF, RETURN_IN, RETURN_OUT
DECLARE @CategoryId INT = (SELECT TOP 1 CategoryID FROM dbo.Category ORDER BY CategoryID);

SELECT TOP 200
  p.ProductID,
  p.ProductName,
  p.CategoryID,
  StockQty =
    SUM(CASE ot.Code
      WHEN 'PURCHASE'   THEN l.Quantity
      WHEN 'RETURN_IN'  THEN l.Quantity
      WHEN 'SALE'       THEN -l.Quantity
      WHEN 'WRITE_OFF'  THEN -l.Quantity
      WHEN 'RETURN_OUT' THEN -l.Quantity
      ELSE 0
    END)
FROM dbo.Product p
LEFT JOIN dbo.OperationLine l ON l.ProductID = p.ProductID
LEFT JOIN dbo.[Operation] o ON o.OperationID = l.OperationID
LEFT JOIN dbo.OperationType ot ON ot.OperationTypeID = o.OperationTypeID
WHERE p.CategoryID = @CategoryId
GROUP BY p.ProductID, p.ProductName, p.CategoryID
ORDER BY StockQty DESC;
GO

-- 4.2 Обіг товарів за період (кількість + сума)
DECLARE @DateFrom DATE = '2025-01-01';
DECLARE @DateTo   DATE = '2025-12-31';

SELECT TOP 200
  p.ProductID,
  p.ProductName,
  QtyTurnover = SUM(l.Quantity),
  SumTurnover = SUM(l.LineTotal)
FROM dbo.OperationLine l
JOIN dbo.[Operation] o ON o.OperationID = l.OperationID
JOIN dbo.Product p ON p.ProductID = l.ProductID
WHERE o.OperationDate >= @DateFrom AND o.OperationDate <= @DateTo
GROUP BY p.ProductID, p.ProductName
ORDER BY SumTurnover DESC;
GO

-- 4.3 Список постачальників з документами (операціями)
SELECT TOP 200
  s.SupplierID,
  s.SupplierName,
  DocsCnt = COUNT(o.OperationID),
  FirstDoc = MIN(o.OperationDate),
  LastDoc  = MAX(o.OperationDate)
FROM dbo.Supplier s
JOIN dbo.[Operation] o ON o.SupplierID = s.SupplierID
GROUP BY s.SupplierID, s.SupplierName
ORDER BY DocsCnt DESC;
GO

-- 4.4 Фінансовий звіт (платежі IN/OUT по періоду)
SELECT
  TotalIN  = SUM(CASE WHEN Direction = 'IN'  THEN Amount ELSE 0 END),
  TotalOUT = SUM(CASE WHEN Direction = 'OUT' THEN Amount ELSE 0 END),
  Net      = SUM(CASE WHEN Direction = 'IN'  THEN Amount ELSE -Amount END)
FROM dbo.Payment
WHERE PaymentDate >= @DateFrom AND PaymentDate <= @DateTo;
GO
