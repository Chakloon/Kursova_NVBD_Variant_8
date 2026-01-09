USE InventoryDB;
GO

/* Trigger: рахує LineTotal у рядку */
CREATE TRIGGER TR_OperationLine_SetLineTotal
ON dbo.OperationLine
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ol
    SET LineTotal = ROUND(
            ol.Quantity * ol.UnitPrice * (100 - ISNULL(ol.DiscountPercent,0)) / 100.0,
            2
        )
    FROM dbo.OperationLine ol
    INNER JOIN inserted i ON ol.OperationLineID = i.OperationLineID;
END;
GO

/* Trigger: оновлює TotalAmount у Operation */
CREATE TRIGGER TR_Operation_UpdateTotalAmount
ON dbo.OperationLine
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedOperations AS (
        SELECT DISTINCT OperationID FROM inserted
        UNION
        SELECT DISTINCT OperationID FROM deleted
    )
    UPDATE o
    SET TotalAmount = ISNULL(s.SumTotal,0)
    FROM dbo.[Operation] o
    INNER JOIN ChangedOperations co ON o.OperationID = co.OperationID
    OUTER APPLY (
        SELECT SUM(LineTotal) AS SumTotal
        FROM dbo.OperationLine ol
        WHERE ol.OperationID = o.OperationID
    ) s;
END;
GO
