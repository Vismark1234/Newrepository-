/*
PERFILADO MENSUAL DE TODAS LAS COLUMNAS - SQL SERVER
Indica el mes y reemplaza el SELECT que llena #DatosMes.
El resultado tiene una fila por columna: nulos, vacíos y porcentaje.
No requiere procedimientos ni otros archivos.
*/

DECLARE @Mes DATE = '2026-09-01';  -- Cambia el mes

-- 1) Preparar los datos de UN MES. Puedes usar JOIN y varias tablas.
--    Reemplaza dbo.MiTabla y FechaRegistro con tus nombres reales.
SELECT *
INTO #DatosMes
FROM dbo.MiTabla
WHERE FechaRegistro >= DATEFROMPARTS(YEAR(@Mes), MONTH(@Mes), 1)
  AND FechaRegistro < DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@Mes), MONTH(@Mes), 1));

-- 2) Crear la tabla donde se guardará el resultado.
CREATE TABLE #Resultado (
    Columna SYSNAME,
    TotalFilas BIGINT,
    Nulos BIGINT,
    Vacios BIGINT,
    TotalFaltantes BIGINT,
    PorcentajeFaltante DECIMAL(6,2)
);

-- 3) Recorrer automáticamente todas las columnas.
DECLARE @Columna SYSNAME;
DECLARE @Tipo SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE columnas CURSOR LOCAL FAST_FORWARD FOR
SELECT c.name, t.name
FROM tempdb.sys.columns AS c
JOIN tempdb.sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('tempdb..#DatosMes')
ORDER BY c.column_id;

OPEN columnas;
FETCH NEXT FROM columnas INTO @Columna, @Tipo;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- En columnas de texto, vacío significa '' o solamente espacios.
    -- En números/fechas únicamente se contabilizan los NULL.
    DECLARE @CondicionVacio NVARCHAR(MAX) = '0 = 1';

    IF @Tipo IN ('varchar', 'nvarchar', 'char', 'nchar', 'text', 'ntext')
    BEGIN
        SET @CondicionVacio =
            'NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), ' +
            QUOTENAME(@Columna) + ')), '''') IS NULL AND ' +
            QUOTENAME(@Columna) + ' IS NOT NULL';
    END;

    SET @SQL = N'
    INSERT INTO #Resultado
    SELECT
        @NombreColumna,
        COUNT_BIG(*),
        COALESCE(SUM(CASE WHEN ' + QUOTENAME(@Columna) + N' IS NULL THEN CAST(1 AS BIGINT) ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN ' + @CondicionVacio + N' THEN CAST(1 AS BIGINT) ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN ' + QUOTENAME(@Columna) + N' IS NULL OR (' + @CondicionVacio + N')
                          THEN CAST(1 AS BIGINT) ELSE 0 END), 0),
        CAST(
            100.0 * COALESCE(SUM(CASE WHEN ' + QUOTENAME(@Columna) + N' IS NULL OR (' + @CondicionVacio + N')
                                         THEN CAST(1 AS BIGINT) ELSE 0 END), 0)
            / NULLIF(COUNT_BIG(*), 0)
            AS DECIMAL(6,2)
        )
    FROM #DatosMes;';

    EXEC sp_executesql @SQL, N'@NombreColumna SYSNAME', @NombreColumna = @Columna;

    FETCH NEXT FROM columnas INTO @Columna, @Tipo;
END;

CLOSE columnas;
DEALLOCATE columnas;

-- 4) Mostrar el resultado: primero las columnas con más faltantes.
SELECT Columna, TotalFilas, Nulos, Vacios, TotalFaltantes, PorcentajeFaltante
FROM #Resultado
ORDER BY PorcentajeFaltante DESC, TotalFaltantes DESC, Columna;

DROP TABLE #Resultado;
DROP TABLE #DatosMes;

/*
EJEMPLO DE SALIDA (valores ilustrativos):
Columna       TotalFilas  Nulos  Vacios  TotalFaltantes  PorcentajeFaltante
Ocupacion     1000        150    50      200             20.00
Ingresos      1000        120     0      120             12.00
Saldo         1000          0     0        0              0.00

NOTAS:
- El porcentaje se calcula respecto a las filas del mes.
- NULL y vacío se cuentan por separado, sin duplicar faltantes.
- Para buen rendimiento, filtra por fecha ANTES de recorrer columnas.
- La fecha del filtro debe ser DATE/DATETIME; si es INT YYYYMMDD,
  adapta el WHERE para comparar enteros.
*/