/*
CALIDAD DE DATOS POR MES - SQL SERVER 2017+
Solo edita @Mes, @Columnas y el SELECT de origen.
No crea procedimientos, no usa cursores ni ciclos.
*/
DECLARE @Mes DATE = '2026-09-01';
DECLARE @Columnas NVARCHAR(MAX) = 'Ingresos, Ocupacion, Saldo, EstadoCivil';

-- Reemplaza este SELECT por tu consulta real del mes (puede tener JOIN).
SELECT *
INTO #Datos
FROM dbo.MiTabla
WHERE FechaRegistro >= @Mes
  AND FechaRegistro < DATEADD(MONTH, 1, @Mes);

DECLARE @SQL NVARCHAR(MAX);

-- Usa únicamente las columnas escritas en @Columnas.
-- QUOTENAME evita problemas con espacios o caracteres especiales en nombres.
SELECT @SQL = STRING_AGG(CAST(
    'SELECT ' + QUOTENAME(c.name, '''') + ' AS Columna, ' +
    'COUNT_BIG(*) AS Total, ' +
    'COUNT_BIG(*) - COUNT(' + QUOTENAME(c.name) + ') AS Nulos, ' +
    CASE WHEN c.system_type_id IN (35, 99, 167, 175, 231, 239)
         THEN 'SUM(CASE WHEN ' + QUOTENAME(c.name) +
              ' IS NOT NULL AND LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), ' +
              QUOTENAME(c.name) + '))) = '''' THEN 1 ELSE 0 END)'
         ELSE 'COUNT_BIG(*) * 0'
    END + ' AS Vacios FROM #Datos'
AS NVARCHAR(MAX)), ' UNION ALL ')
FROM tempdb.sys.columns AS c
JOIN (
    SELECT DISTINCT LTRIM(RTRIM(value)) AS Nombre
    FROM STRING_SPLIT(@Columnas, ',')
) AS elegidas ON elegidas.Nombre = c.name
WHERE c.object_id = OBJECT_ID('tempdb..#Datos');

IF @SQL IS NULL
BEGIN
    DROP TABLE #Datos;
    THROW 50000, 'Ninguna columna de @Columnas coincide con #Datos.', 1;
END;

SET @SQL = '
SELECT Columna, Total, Nulos, Vacios,
       Nulos + Vacios AS Faltantes,
       CAST(100.0 * (Nulos + Vacios) / NULLIF(Total, 0)
            AS DECIMAL(6,2)) AS Porcentaje
FROM (' + @SQL + ') AS R
ORDER BY Porcentaje DESC, Columna;';

EXEC sys.sp_executesql @SQL;
DROP TABLE #Datos;

/*
EJEMPLO:
DECLARE @Columnas NVARCHAR(MAX) = 'Ingresos, Ocupacion, Saldo';

RESULTADO:
Columna     Total   Nulos   Vacios   Faltantes   Porcentaje
Ingresos    10000   1500    0        1500        15.00
Ocupacion   10000    200    300       500         5.00
Saldo       10000      0      0         0         0.00

Nota: los nombres deben coincidir con las columnas del SELECT de origen.
Las columnas de texto cuentan NULL, cadenas vacías y espacios.
Las numéricas/fechas cuentan NULL.
*/