/*
CONSULTA SIMPLE DE CALIDAD MENSUAL - SQL SERVER
Sin cursor, sin SQL dinámico, sin procedimientos.
AGREGA TUS COLUMNAS EN LOS DOS LUGARES MARCADOS.
*/

DECLARE @Mes DATE = '2026-09-01';

WITH DatosMes AS (
    SELECT
        -- >>> LUGAR 1: AGREGA AQUÍ TODAS TUS COLUMNAS <<<
        ClienteKey,
        Ingresos,
        Ocupacion
    FROM dbo.MiTabla
    WHERE FechaRegistro >= @Mes
      AND FechaRegistro < DATEADD(MONTH, 1, @Mes)
),
Resumen AS (
    SELECT
        COUNT_BIG(*) AS Total,
        -- >>> LUGAR 2: AGREGA UNA EXPRESIÓN POR CADA COLUMNA <<<
        SUM(CASE WHEN ClienteKey IS NULL THEN 1 ELSE 0 END) AS Nulos_ClienteKey,
        SUM(CASE WHEN Ingresos IS NULL THEN 1 ELSE 0 END) AS Nulos_Ingresos,
        SUM(CASE WHEN Ocupacion IS NULL THEN 1 ELSE 0 END) AS Nulos_Ocupacion,
        SUM(CASE WHEN Ocupacion IS NOT NULL AND LTRIM(RTRIM(Ocupacion)) = '' THEN 1 ELSE 0 END) AS Vacios_Ocupacion
    FROM DatosMes
)
SELECT
    v.Columna,
    r.Total,
    v.Nulos,
    v.Vacios,
    v.Nulos + v.Vacios AS Faltantes,
    CAST(100.0 * (v.Nulos + v.Vacios) / NULLIF(r.Total, 0) AS DECIMAL(6,2)) AS Porcentaje
FROM Resumen AS r
CROSS APPLY (VALUES
    -- >>> LUGAR 3: AGREGA AQUÍ UNA FILA POR CADA COLUMNA <<<
    ('ClienteKey', r.Nulos_ClienteKey, 0),
    ('Ingresos', r.Nulos_Ingresos, 0),
    ('Ocupacion', r.Nulos_Ocupacion, r.Vacios_Ocupacion)
) AS v(Columna, Nulos, Vacios)
ORDER BY Porcentaje DESC, Columna;

/*
EJEMPLO PARA AGREGAR OTRA COLUMNA:
1) En DatosMes:       Saldo,
2) En Resumen:        SUM(CASE WHEN Saldo IS NULL THEN 1 ELSE 0 END) AS Nulos_Saldo,
3) En CROSS APPLY:    ('Saldo', r.Nulos_Saldo, 0),

Si es texto, agrega además su conteo de vacíos:
SUM(CASE WHEN MiTexto IS NOT NULL AND LTRIM(RTRIM(MiTexto)) = ''
         THEN 1 ELSE 0 END) AS Vacios_MiTexto
Y en CROSS APPLY: ('MiTexto', r.Nulos_MiTexto, r.Vacios_MiTexto)

Sustituye los nombres de ejemplo y el FROM por tu consulta real.
El mes se filtra antes de calcular los porcentajes.
*/