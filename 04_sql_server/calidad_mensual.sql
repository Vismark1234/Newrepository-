-- PERFILADO MENSUAL: ejecuta este script una sola vez en SSMS.
-- SQL Server 2017+. Cambia el mes, la tabla y la columna de fecha.
DECLARE @Mes DATE = '2026-09-01';

SELECT *
INTO #Datos
FROM dbo.MiTabla
WHERE FechaRegistro >= @Mes
  AND FechaRegistro < DATEADD(MONTH, 1, @Mes);

DECLARE @SQL NVARCHAR(MAX);

-- Genera un resumen por columna; no necesitas escribir sus nombres.
SELECT @SQL = STRING_AGG(CAST(
    'SELECT ' + QUOTENAME(name, '''') + ' AS Columna, ' +
    'COUNT_BIG(*) AS Total, ' +
    'COUNT_BIG(*) - COUNT(' + QUOTENAME(name) + ') AS Nulos, ' +
    CASE
        WHEN system_type_id IN (35, 99, 167, 175, 231, 239)
        THEN 'SUM(CASE WHEN ' + QUOTENAME(name) +
             ' IS NOT NULL AND LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), ' +
             QUOTENAME(name) + '))) = '''' THEN 1 ELSE 0 END)'
        ELSE 'COUNT_BIG(*) * 0'
    END + ' AS Vacios FROM #Datos'
    AS NVARCHAR(MAX)), ' UNION ALL ')
FROM tempdb.sys.columns
WHERE object_id = OBJECT_ID('tempdb..#Datos');

SET @SQL = '
SELECT Columna, Total, Nulos, Vacios,
       Nulos + Vacios AS Faltantes,
       CAST(100.0 * (Nulos + Vacios) / NULLIF(Total, 0)
            AS DECIMAL(6,2)) AS Porcentaje
FROM (' + @SQL + ') AS R
ORDER BY Porcentaje DESC, Columna;';

EXEC sys.sp_executesql @SQL;

DROP TABLE #Datos;

-- EJEMPLO: reemplaza dbo.MiTabla y FechaRegistro con tus nombres reales.
-- También puedes usar tu SELECT con JOIN, siempre con INTO #Datos.
-- Para columnas numéricas o fechas, solo NULL cuenta como faltante.
