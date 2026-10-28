/*
ANÁLISIS MENSUAL DE NULOS Y VACÍOS - SQL SERVER 2017+
Sin cursor, sin procedimiento almacenado y sin WHILE.
Cambia únicamente el mes, la tabla y la columna de fecha.
*/

DECLARE @Mes DATE = '2026-09-01';

SELECT *
INTO #Datos
FROM dbo.MiTabla
WHERE FechaRegistro >= @Mes
  AND FechaRegistro < DATEADD(MONTH, 1, @Mes);

DECLARE @SQL NVARCHAR(MAX);

SELECT @SQL = STRING_AGG(
    CAST(
        'SELECT ' + QUOTENAME(name, '''') + ' AS Columna, ' +
        'COUNT_BIG(*) AS TotalFilas, ' +
        'SUM(CASE WHEN ' + QUOTENAME(name) + ' IS NULL THEN 1 ELSE 0 END) AS Nulos, ' +
        CASE
            WHEN system_type_id IN (35, 99, 167, 175, 231, 239)
            THEN 'SUM(CASE WHEN ' + QUOTENAME(name) + ' IS NOT NULL AND ' +
                 'LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), ' + QUOTENAME(name) +
                 '))) = '''' THEN 1 ELSE 0 END)'
            ELSE 'CAST(0 AS INT)'
        END + ' AS Vacios ' +
        'FROM #Datos'
    AS NVARCHAR(MAX)),
    ' UNION ALL '
)
FROM tempdb.sys.columns
WHERE object_id = OBJECT_ID('tempdb..#Datos');

SET @SQL = '
SELECT Columna, TotalFilas, Nulos, Vacios,
       Nulos + Vacios AS TotalFaltantes,
       CAST(100.0 * (Nulos + Vacios) / NULLIF(TotalFilas, 0) AS DECIMAL(6,2))
           AS PorcentajeFaltante
FROM (' + @SQL + ') AS Resultado
ORDER BY PorcentajeFaltante DESC, Columna;';

EXEC sp_executesql @SQL;

DROP TABLE #Datos;

/*
EJEMPLO EN SSMS:
1. Cambia @Mes.
2. Reemplaza dbo.MiTabla y FechaRegistro por tus nombres.
3. Ejecuta todo el bloque.
4. El resultado tiene una fila por cada columna del SELECT.

Para varias tablas, reemplaza el SELECT INTO #Datos por tu SELECT con JOIN.
Las columnas numéricas y fechas solo se consideran faltantes si son NULL.
*/