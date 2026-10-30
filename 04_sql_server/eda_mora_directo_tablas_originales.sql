/*
ANALISIS EXPLORATORIO DE DATOS (EDA) - SQL SERVER
VERSION PARA MILLONES DE REGISTROS | TABLAS ORIGINALES

FUENTES VALIDAS SEGUN consulta2.sql:
 Resultados.dcar.DominioCartera (car)
 Resultados.dcli.DominioClientes (cli)
 Inteligencia_Comercial.dbo.TransaccionesMensuales (tra)
 INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred (inf)
 Inteligencia_Comercial.dbo.EventosRelevantes (eve)

QUE CAMBIA:
 1) NO se carga #Datos con millones de filas.
 2) Cada SELECT accede a las tablas que necesita, con filtros del periodo.
 3) Las fechas mensuales estan en una tabla-variable PEQUENA de cierres.
    Solo contiene fechas (no creditos ni clientes).
 4) Se evita EOMONTH(car.FechaCorte) y convertir inf.FechaKey
    en la condicion de union: se comparan columnas directamente.
 5) Puedes ejecutar UNA CONSULTA a la vez; no es necesario ejecutar
    todas las consultas del archivo juntas.
 6) Sin CROSS APPLY, SQL dinamico ni procedimientos.

POBLACION: mismas condiciones de consulta2.sql: CARTERA, BANCA
MICROEMPRESA, VIGENTE, MENSUAL, NumeroCuotaActual IS NULL y
PERSONA NATURAL. El filtro NumeroCuotaActual IS NULL puede reducir
mucho el numero de registros; revisalo antes de generalizar.

INTERPRETACION: en tablas de cartera, las cantidades representan
CREDITOS-MES, no clientes unicos. Un cliente con varios creditos
aparece varias veces. En los totales, cada mes cuenta de nuevo.
Los nulos NO se consideran 0 en indicadores de mora.
*/

-- CONFIGURACION (cambia solamente estas dos fechas)
DECLARE @FechaInicio DATE = '2026-07-01';
DECLARE @FechaFin    DATE = '2026-08-31';

-- Calendario pequeno de cierres mensuales: permite buscar por igualdad.
DECLARE @Cortes TABLE (
    FechaCorte DATE PRIMARY KEY,
    FechaKey INT
);
DECLARE @Mes DATE = EOMONTH(@FechaInicio);
WHILE @Mes <= EOMONTH(@FechaFin)
BEGIN
    INSERT INTO @Cortes (FechaCorte, FechaKey)
    VALUES (@Mes, CONVERT(INT, CONVERT(CHAR(8), @Mes, 112)));
    SET @Mes = EOMONTH(@Mes, 1);
END;

-- Verifica los cortes seleccionados.
SELECT FechaCorte, FechaKey FROM @Cortes ORDER BY FechaCorte;

-- ===== SECCION A: VOLUMEN, COBERTURA Y UNICIDAD =====

-- A01. Registros, creditos y clientes por mes.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS RegistrosCreditoMes,
       COUNT(DISTINCT car.CarteraKey) AS CreditosDistintos,
       COUNT(DISTINCT car.ClienteKey) AS ClientesDistintos
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte
ORDER BY m.FechaCorte;

-- A02. Totales del periodo; NO son "clientes-mes" ni creditos nuevos.
SELECT COUNT_BIG(*) AS RegistrosCreditoMes,
       COUNT(DISTINCT car.CarteraKey) AS CreditosUnicos,
       COUNT(DISTINCT car.ClienteKey) AS ClientesUnicos
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
);

-- A03. Cartera duplicada en el mismo corte, sin uniones.
SELECT TOP (100) car.FechaCorte, car.CarteraKey, COUNT_BIG(*) AS Veces
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
GROUP BY car.FechaCorte, car.CarteraKey
HAVING COUNT_BIG(*) > 1
ORDER BY Veces DESC;

-- A04. Filas duplicadas en DominioClientes (romperian un JOIN 1 a 1).
SELECT TOP (100) cli.FechaCorte, cli.ClienteKey, COUNT_BIG(*) AS Veces
FROM @Cortes m
JOIN Resultados.dcli.DominioClientes cli
    ON cli.FechaCorte = m.FechaCorte
GROUP BY cli.FechaCorte, cli.ClienteKey
HAVING COUNT_BIG(*) > 1
ORDER BY Veces DESC;

-- A05. Filas duplicadas en TransaccionesMensuales (deberia ser una por cliente-mes).
SELECT TOP (100) tra.Fecha, tra.ClienteKey, COUNT_BIG(*) AS Veces
FROM @Cortes m
JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON tra.Fecha = m.FechaCorte
GROUP BY tra.Fecha, tra.ClienteKey
HAVING COUNT_BIG(*) > 1
ORDER BY Veces DESC;

-- A06. Filas duplicadas en ClienteInfocred por fecha y cliente.
SELECT TOP (100) inf.FechaKey, inf.ClienteKey, COUNT_BIG(*) AS Veces
FROM @Cortes m
JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.FechaKey = m.FechaKey
GROUP BY inf.FechaKey, inf.ClienteKey
HAVING COUNT_BIG(*) > 1
ORDER BY Veces DESC;

-- A07. Clientes con varios creditos en cada cierre.
SELECT m.FechaCorte, car.ClienteKey,
       COUNT(DISTINCT car.CarteraKey) AS NumeroCreditos
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.ClienteKey
HAVING COUNT(DISTINCT car.CarteraKey) > 1
ORDER BY m.FechaCorte, NumeroCreditos DESC;

-- A08. Clientes de cartera sin fila correspondiente en DominioClientes.
-- Este control NO aplica el filtro TipoPersona para detectar faltantes.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS CreditosBase,
       SUM(CASE WHEN cli.ClienteKey IS NULL THEN 1 ELSE 0 END) AS SinCliente
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
LEFT JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
GROUP BY m.FechaCorte
ORDER BY m.FechaCorte;

-- A09. Cobertura de transacciones por credito-mes.
-- Si la fuente tra tiene duplicados, corregirlos antes de interpretar.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS CreditosMes,
       SUM(CASE WHEN tra.ClienteKey IS NULL THEN 1 ELSE 0 END) AS SinFilaTransaccion,
       SUM(CASE WHEN tra.CantidadTrx = 0 THEN 1 ELSE 0 END) AS CeroTransacciones,
       SUM(CASE WHEN tra.CantidadTrx > 0 THEN 1 ELSE 0 END) AS ConTransacciones
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON tra.ClienteKey = car.ClienteKey
   AND tra.Fecha = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- A10. Cobertura de Infocred por credito-mes.
SELECT m.FechaCorte, COUNT_BIG(*) AS Registros,
       SUM(CASE WHEN inf.ClienteKey IS NULL THEN 1 ELSE 0 END) AS SinRegistroInfocred,
       SUM(CASE WHEN inf.ClienteKey IS NOT NULL AND inf.MontoDeudaTotalBs IS NULL
                THEN 1 ELSE 0 END) AS ConRegistroSinDeudaInformada
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- ===== SECCION B: VARIABLES NUMERICAS Y MORA =====

-- B01. Indicadores generales de mora por cierre mensual.
SELECT m.FechaCorte,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMoraActual,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMoraActual,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0) AS DECIMAL(7,2)) AS PctConMoraActual,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes >= 30 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0) AS DECIMAL(7,2)) AS PctConMora30Dias,
       AVG(CAST(car.MaxDiasMoraMes AS FLOAT)) AS PromedioDiasMora,
       MAX(car.MaxDiasMoraMes) AS MaximoDiasMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B02. Indicadores de mora en 3, 6 y 12 meses por corte.
SELECT m.FechaCorte,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMora3M > 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT_BIG(car.MaxDiasMora3M), 0) AS DECIMAL(7,2)) AS PctMora3M,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMora6M > 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT_BIG(car.MaxDiasMora6M), 0) AS DECIMAL(7,2)) AS PctMora6M,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMora12M > 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT_BIG(car.MaxDiasMora12M), 0) AS DECIMAL(7,2)) AS PctMora12M,
       AVG(CAST(car.PromedioMora6M AS FLOAT)) AS PromedioMora6M,
       AVG(CAST(car.MesesConMora12M AS FLOAT)) AS PromedioMesesConMora12M
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B03. Saldo y desembolso por mes. NO sumar saldos de diferentes cortes
-- para interpretar un saldo total historico: son fotografias mensuales.
SELECT m.FechaCorte,
       COUNT_BIG(car.SaldoBs) AS ConDatoSaldo,
       SUM(car.SaldoBs) AS SaldoTotalBs,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs,
       MIN(car.SaldoBs) AS SaldoMinimoBs,
       MAX(car.SaldoBs) AS SaldoMaximoBs,
       AVG(CAST(car.MontoDesembolsadoBs AS FLOAT)) AS DesembolsoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B04. Estadisticas globales: promedios de todas las filas credito-mes.
SELECT COUNT_BIG(*) AS Registros,
       AVG(CAST(car.MaxDiasMoraMes AS FLOAT)) AS PromedioDiasMora,
       MIN(car.MaxDiasMoraMes) AS MinimoDiasMora,
       MAX(car.MaxDiasMoraMes) AS MaximoDiasMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs,
       MIN(car.SaldoBs) AS SaldoMinimoBs,
       MAX(car.SaldoBs) AS SaldoMaximoBs,
       AVG(CAST(car.TasaEfectiva AS FLOAT)) AS TasaEfectivaPromedio,
       AVG(CAST(car.AntiguedadCreditoMeses AS FLOAT)) AS AntiguedadPromedioMeses
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
);

-- B05. Reprogramaciones, antiguedad y cumplimiento por mes.
SELECT m.FechaCorte,
       AVG(CAST(car.CantidadReprogramaciones AS FLOAT)) AS ReprogramacionesPromedio,
       SUM(CASE WHEN car.CantidadReprogramaciones > 0 THEN 1 ELSE 0 END) AS ConReprogramacion,
       AVG(CAST(car.AntiguedadCreditoMeses AS FLOAT)) AS AntiguedadPromedioMeses,
       AVG(CAST(car.TasaCumplimiento AS FLOAT)) AS TasaCumplimientoPromedio
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B06. Faltantes numericos y valores 0 (son cosas distintas).
SELECT m.FechaCorte,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(*) - COUNT_BIG(car.SaldoBs) AS NulosSaldo,
       SUM(CASE WHEN car.SaldoBs = 0 THEN 1 ELSE 0 END) AS SaldoCero,
       COUNT_BIG(*) - COUNT_BIG(car.MaxDiasMoraMes) AS NulosMoraActual,
       SUM(CASE WHEN car.MaxDiasMoraMes = 0 THEN 1 ELSE 0 END) AS MoraCero,
       COUNT_BIG(*) - COUNT_BIG(car.MaxDiasMora6M) AS NulosMora6M,
       COUNT_BIG(*) - COUNT_BIG(car.TasaCumplimiento) AS NulosCumplimiento
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B07. Valores a revisar en cartera, por mes (no implica error).
SELECT m.FechaCorte,
       SUM(CASE WHEN car.SaldoBs < 0 THEN 1 ELSE 0 END) AS SaldoNegativo,
       SUM(CASE WHEN car.MontoDesembolsadoBs < 0 THEN 1 ELSE 0 END) AS DesembolsoNegativo,
       SUM(CASE WHEN car.MaxDiasMoraMes < 0 THEN 1 ELSE 0 END) AS MoraNegativa,
       SUM(CASE WHEN car.MesesConMora6M > 6 THEN 1 ELSE 0 END) AS MesesConMora6MFueraRango,
       SUM(CASE WHEN car.MesesConMora12M > 12 THEN 1 ELSE 0 END) AS MesesConMora12MFueraRango
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B08. Edad y calidad del perfil del cliente por mes.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(*) - COUNT_BIG(cli.Edad) AS NulosEdad,
       AVG(CAST(cli.Edad AS FLOAT)) AS EdadPromedio,
       MIN(cli.Edad) AS EdadMinima,
       MAX(cli.Edad) AS EdadMaxima,
       SUM(CASE WHEN cli.Edad < 18 OR cli.Edad > 100 THEN 1 ELSE 0 END) AS EdadesARevisar,
       SUM(CASE WHEN cli.Genero IS NULL OR LTRIM(RTRIM(cli.Genero)) = ''
                THEN 1 ELSE 0 END) AS GeneroNuloOVacio,
       SUM(CASE WHEN cli.Segmento IS NULL OR LTRIM(RTRIM(cli.Segmento)) = ''
                THEN 1 ELSE 0 END) AS SegmentoNuloOVacio
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B09. Transacciones por mes: nulo != cero.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS CreditosMes,
       COUNT_BIG(*) - COUNT_BIG(tra.CantidadTrx) AS SinDatoTrx,
       SUM(CASE WHEN tra.CantidadTrx = 0 THEN 1 ELSE 0 END) AS TrxCero,
       AVG(CAST(tra.CantidadTrx AS FLOAT)) AS CantTrxPromedio,
       AVG(CAST(tra.CantidadQR AS FLOAT)) AS CantQRPromedio,
       AVG(CAST(tra.FlujoNetoBs AS FLOAT)) AS FlujoNetoPromedio,
       MAX(tra.CantidadTrx) AS MayorNumeroTrx
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON tra.ClienteKey = car.ClienteKey
   AND tra.Fecha = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- B10. Deuda Infocred por mes: distingue ausencia de fila y monto nulo.
SELECT m.FechaCorte,
       COUNT_BIG(inf.ClienteKey) AS ConRegistroInfocred,
       COUNT_BIG(inf.MontoDeudaTotalBs) AS ConMontoDeuda,
       AVG(CAST(inf.MontoDeudaTotalBs AS FLOAT)) AS DeudaExternaPromedio,
       MIN(inf.MontoDeudaTotalBs) AS DeudaExternaMinima,
       MAX(inf.MontoDeudaTotalBs) AS DeudaExternaMaxima
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- ===== SECCION C: VARIABLES CATEGORICAS =====
-- Las consultas siguientes son INDEPENDIENTES. Ejecuta solo las que necesites.
-- Mensual y total usan el MISMO filtro de poblacion.
-- Porcentaje = porcentaje de CREDITOS-MES de ese corte o periodo.
-- Se incluyen NULL como categoria para detectar faltantes.
-- SUM(COUNT_BIG(*)) OVER evita recalcular el total con otra consulta.

-- C01A. GENERO: POR MES
SELECT m.FechaCorte, cli.Genero AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Genero
ORDER BY m.FechaCorte, Cantidad DESC;

-- C01B. GENERO: TODO EL PERIODO
SELECT cli.Genero AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Genero
ORDER BY Cantidad DESC;

-- C02A. ESTADO CIVIL: POR MES
SELECT m.FechaCorte, cli.EstadoCivil AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EstadoCivil
ORDER BY m.FechaCorte, Cantidad DESC;

-- C02B. ESTADO CIVIL: TODO EL PERIODO
SELECT cli.EstadoCivil AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EstadoCivil
ORDER BY Cantidad DESC;

-- C03A. CIUDAD: POR MES
SELECT m.FechaCorte, cli.Ciudad AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Ciudad
ORDER BY m.FechaCorte, Cantidad DESC;

-- C03B. CIUDAD: TODO EL PERIODO
SELECT cli.Ciudad AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Ciudad
ORDER BY Cantidad DESC;

-- C04A. DEPARTAMENTO: POR MES
SELECT m.FechaCorte, cli.Departamento AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Departamento
ORDER BY m.FechaCorte, Cantidad DESC;

-- C04B. DEPARTAMENTO: TODO EL PERIODO
SELECT cli.Departamento AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Departamento
ORDER BY Cantidad DESC;

-- C05A. BARRIO (ALTA CARDINALIDAD): POR MES
SELECT m.FechaCorte, cli.Barrio AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Barrio
ORDER BY m.FechaCorte, Cantidad DESC;

-- C05B. BARRIO (ALTA CARDINALIDAD): TODO EL PERIODO
SELECT cli.Barrio AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Barrio
ORDER BY Cantidad DESC;

-- C06A. SEGMENTO: POR MES
SELECT m.FechaCorte, cli.Segmento AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Segmento
ORDER BY m.FechaCorte, Cantidad DESC;

-- C06B. SEGMENTO: TODO EL PERIODO
SELECT cli.Segmento AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Segmento
ORDER BY Cantidad DESC;

-- C07A. NACIONALIDAD: POR MES
SELECT m.FechaCorte, cli.Nacionalidad AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Nacionalidad
ORDER BY m.FechaCorte, Cantidad DESC;

-- C07B. NACIONALIDAD: TODO EL PERIODO
SELECT cli.Nacionalidad AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Nacionalidad
ORDER BY Cantidad DESC;

-- C08A. JEFA DE HOGAR: POR MES
SELECT m.FechaCorte, cli.JefaHogar AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.JefaHogar
ORDER BY m.FechaCorte, Cantidad DESC;

-- C08B. JEFA DE HOGAR: TODO EL PERIODO
SELECT cli.JefaHogar AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.JefaHogar
ORDER BY Cantidad DESC;

-- C09A. NIVEL DE INGRESO: POR MES
SELECT m.FechaCorte, cli.NivelIngreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.NivelIngreso
ORDER BY m.FechaCorte, Cantidad DESC;

-- C09B. NIVEL DE INGRESO: TODO EL PERIODO
SELECT cli.NivelIngreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.NivelIngreso
ORDER BY Cantidad DESC;

-- C10A. NIVEL DE EGRESO: POR MES
SELECT m.FechaCorte, cli.NivelEgreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.NivelEgreso
ORDER BY m.FechaCorte, Cantidad DESC;

-- C10B. NIVEL DE EGRESO: TODO EL PERIODO
SELECT cli.NivelEgreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.NivelEgreso
ORDER BY Cantidad DESC;

-- C11A. FUENTE DE INGRESO: POR MES
SELECT m.FechaCorte, cli.TipoFuenteIngreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.TipoFuenteIngreso
ORDER BY m.FechaCorte, Cantidad DESC;

-- C11B. FUENTE DE INGRESO: TODO EL PERIODO
SELECT cli.TipoFuenteIngreso AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.TipoFuenteIngreso
ORDER BY Cantidad DESC;

-- C12A. PROFESION (ALTA CARDINALIDAD): POR MES
SELECT m.FechaCorte, cli.Profesion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Profesion
ORDER BY m.FechaCorte, Cantidad DESC;

-- C12B. PROFESION (ALTA CARDINALIDAD): TODO EL PERIODO
SELECT cli.Profesion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Profesion
ORDER BY Cantidad DESC;

-- C13A. GRADO DE INSTRUCCION: POR MES
SELECT m.FechaCorte, cli.GradoInstruccion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.GradoInstruccion
ORDER BY m.FechaCorte, Cantidad DESC;

-- C13B. GRADO DE INSTRUCCION: TODO EL PERIODO
SELECT cli.GradoInstruccion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.GradoInstruccion
ORDER BY Cantidad DESC;

-- C14A. ES DEUDOR CARTERA: POR MES
SELECT m.FechaCorte, cli.EsDeudorcartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsDeudorcartera
ORDER BY m.FechaCorte, Cantidad DESC;

-- C14B. ES DEUDOR CARTERA: TODO EL PERIODO
SELECT cli.EsDeudorcartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EsDeudorcartera
ORDER BY Cantidad DESC;

-- C15A. ES CODEUDOR CARTERA: POR MES
SELECT m.FechaCorte, cli.EsCodeudorcartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsCodeudorcartera
ORDER BY m.FechaCorte, Cantidad DESC;

-- C15B. ES CODEUDOR CARTERA: TODO EL PERIODO
SELECT cli.EsCodeudorcartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EsCodeudorcartera
ORDER BY Cantidad DESC;

-- C16A. ES GARANTE CARTERA: POR MES
SELECT m.FechaCorte, cli.EsGarantecartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsGarantecartera
ORDER BY m.FechaCorte, Cantidad DESC;

-- C16B. ES GARANTE CARTERA: TODO EL PERIODO
SELECT cli.EsGarantecartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EsGarantecartera
ORDER BY Cantidad DESC;

-- C17A. CLIENTE DIGITAL: POR MES
SELECT m.FechaCorte, cli.EsClienteActivoDigital AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsClienteActivoDigital
ORDER BY m.FechaCorte, Cantidad DESC;

-- C17B. CLIENTE DIGITAL: TODO EL PERIODO
SELECT cli.EsClienteActivoDigital AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EsClienteActivoDigital
ORDER BY Cantidad DESC;

-- C18A. CLIENTE TINKA: POR MES
SELECT m.FechaCorte, cli.EsclienteTinka AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsclienteTinka
ORDER BY m.FechaCorte, Cantidad DESC;

-- C18B. CLIENTE TINKA: TODO EL PERIODO
SELECT cli.EsclienteTinka AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.EsclienteTinka
ORDER BY Cantidad DESC;

-- C19A. PRODUCTO CARTERA: POR MES
SELECT m.FechaCorte, car.Productocartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.Productocartera
ORDER BY m.FechaCorte, Cantidad DESC;

-- C19B. PRODUCTO CARTERA: TODO EL PERIODO
SELECT car.Productocartera AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.Productocartera
ORDER BY Cantidad DESC;

-- C20A. TIPO DE CREDITO: POR MES
SELECT m.FechaCorte, car.TipoCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TipoCredito
ORDER BY m.FechaCorte, Cantidad DESC;

-- C20B. TIPO DE CREDITO: TODO EL PERIODO
SELECT car.TipoCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.TipoCredito
ORDER BY Cantidad DESC;

-- C21A. TIPO DE AMORTIZACION: POR MES
SELECT m.FechaCorte, car.TipoAmortizacion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TipoAmortizacion
ORDER BY m.FechaCorte, Cantidad DESC;

-- C21B. TIPO DE AMORTIZACION: TODO EL PERIODO
SELECT car.TipoAmortizacion AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.TipoAmortizacion
ORDER BY Cantidad DESC;

-- C22A. LINEA DE CREDITO: POR MES
SELECT m.FechaCorte, car.LineaCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.LineaCredito
ORDER BY m.FechaCorte, Cantidad DESC;

-- C22B. LINEA DE CREDITO: TODO EL PERIODO
SELECT car.LineaCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.LineaCredito
ORDER BY Cantidad DESC;

-- C23A. SECTOR ECONOMICO CLIENTE: POR MES
SELECT m.FechaCorte, car.SectorEconomicoCliente AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.SectorEconomicoCliente
ORDER BY m.FechaCorte, Cantidad DESC;

-- C23B. SECTOR ECONOMICO CLIENTE: TODO EL PERIODO
SELECT car.SectorEconomicoCliente AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.SectorEconomicoCliente
ORDER BY Cantidad DESC;

-- C24A. SECTOR ECONOMICO CREDITO: POR MES
SELECT m.FechaCorte, car.SectorEconomicoCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.SectorEconomicoCredito
ORDER BY m.FechaCorte, Cantidad DESC;

-- C24B. SECTOR ECONOMICO CREDITO: TODO EL PERIODO
SELECT car.SectorEconomicoCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.SectorEconomicoCredito
ORDER BY Cantidad DESC;

-- C25A. ACTIVIDAD ECONOMICA CLIENTE (ALTA CARDINALIDAD): POR MES
SELECT m.FechaCorte, car.ActividadEconomicaCliente AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.ActividadEconomicaCliente
ORDER BY m.FechaCorte, Cantidad DESC;

-- C25B. ACTIVIDAD ECONOMICA CLIENTE (ALTA CARDINALIDAD): TODO EL PERIODO
SELECT car.ActividadEconomicaCliente AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.ActividadEconomicaCliente
ORDER BY Cantidad DESC;

-- C26A. ACTIVIDAD ECONOMICA CREDITO (ALTA CARDINALIDAD): POR MES
SELECT m.FechaCorte, car.ActividadEconomicaCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.ActividadEconomicaCredito
ORDER BY m.FechaCorte, Cantidad DESC;

-- C26B. ACTIVIDAD ECONOMICA CREDITO (ALTA CARDINALIDAD): TODO EL PERIODO
SELECT car.ActividadEconomicaCredito AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.ActividadEconomicaCredito
ORDER BY Cantidad DESC;

-- C27A. CAEDEC CLIENTE: POR MES
SELECT m.FechaCorte, car.ActividadEconomicaClienteCAEDEC AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.ActividadEconomicaClienteCAEDEC
ORDER BY m.FechaCorte, Cantidad DESC;

-- C27B. CAEDEC CLIENTE: TODO EL PERIODO
SELECT car.ActividadEconomicaClienteCAEDEC AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.ActividadEconomicaClienteCAEDEC
ORDER BY Cantidad DESC;

-- C28A. CAEDEC CREDITO: POR MES
SELECT m.FechaCorte, car.ActividadEconomicaCreditoCAEDEC AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.ActividadEconomicaCreditoCAEDEC
ORDER BY m.FechaCorte, Cantidad DESC;

-- C28B. CAEDEC CREDITO: TODO EL PERIODO
SELECT car.ActividadEconomicaCreditoCAEDEC AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.ActividadEconomicaCreditoCAEDEC
ORDER BY Cantidad DESC;

-- C29A. TAMANO DE EMPRESA: POR MES
SELECT m.FechaCorte, car.TamanioEmpresa AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TamanioEmpresa
ORDER BY m.FechaCorte, Cantidad DESC;

-- C29B. TAMANO DE EMPRESA: TODO EL PERIODO
SELECT car.TamanioEmpresa AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.TamanioEmpresa
ORDER BY Cantidad DESC;

-- C30A. CALIFICACION FIE: POR MES
SELECT m.FechaCorte, car.CalificacionFIE AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.CalificacionFIE
ORDER BY m.FechaCorte, Cantidad DESC;

-- C30B. CALIFICACION FIE: TODO EL PERIODO
SELECT car.CalificacionFIE AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.CalificacionFIE
ORDER BY Cantidad DESC;

-- C31A. CALIFICACION ASFI: POR MES
SELECT m.FechaCorte, car.CalificacionASFI AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.CalificacionASFI
ORDER BY m.FechaCorte, Cantidad DESC;

-- C31B. CALIFICACION ASFI: TODO EL PERIODO
SELECT car.CalificacionASFI AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.CalificacionASFI
ORDER BY Cantidad DESC;

-- C32A. PEOR CALIFICACION ASFI INFOCRED: POR MES
SELECT m.FechaCorte, inf.PeorCalificacionASFIKey AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, inf.PeorCalificacionASFIKey
ORDER BY m.FechaCorte, Cantidad DESC;

-- C32B. PEOR CALIFICACION ASFI INFOCRED: TODO EL PERIODO
SELECT inf.PeorCalificacionASFIKey AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY inf.PeorCalificacionASFIKey
ORDER BY Cantidad DESC;

-- C33A. INFOCRED CREDITO VIVIENDA: POR MES
SELECT m.FechaCorte, inf.EsCreditoVivienda AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (PARTITION BY m.FechaCorte), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, inf.EsCreditoVivienda
ORDER BY m.FechaCorte, Cantidad DESC;

-- C33B. INFOCRED CREDITO VIVIENDA: TODO EL PERIODO
SELECT inf.EsCreditoVivienda AS Categoria,
       COUNT_BIG(*) AS Cantidad,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
            AS DECIMAL(7,2)) AS Porcentaje
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY inf.EsCreditoVivienda
ORDER BY Cantidad DESC;

-- ===== SECCION D: CRUCES CATEGORICOS Y RELACION CON LA MORA =====
-- "Con mora" significa MaxDiasMoraMes > 0, no causa ni predice por si solo.
-- El porcentaje divide sobre los registros que tienen dato de mora.

-- D01. GENERO Y MORA (POR MES)
SELECT m.FechaCorte, cli.Genero AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Genero
ORDER BY m.FechaCorte, Registros DESC;

-- D02. SEGMENTO Y MORA (POR MES)
SELECT m.FechaCorte, cli.Segmento AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Segmento
ORDER BY m.FechaCorte, Registros DESC;

-- D03. NIVEL DE INGRESO Y MORA (POR MES)
SELECT m.FechaCorte, cli.NivelIngreso AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.NivelIngreso
ORDER BY m.FechaCorte, Registros DESC;

-- D04. GRADO DE INSTRUCCION Y MORA (POR MES)
SELECT m.FechaCorte, cli.GradoInstruccion AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.GradoInstruccion
ORDER BY m.FechaCorte, Registros DESC;

-- D05. CLIENTE DIGITAL Y MORA (POR MES)
SELECT m.FechaCorte, cli.EsClienteActivoDigital AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.EsClienteActivoDigital
ORDER BY m.FechaCorte, Registros DESC;

-- D06. CIUDAD Y MORA (POR MES)
SELECT m.FechaCorte, cli.Ciudad AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, cli.Ciudad
ORDER BY m.FechaCorte, Registros DESC;

-- D07. TIPO DE CREDITO Y MORA (POR MES)
SELECT m.FechaCorte, car.TipoCredito AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TipoCredito
ORDER BY m.FechaCorte, Registros DESC;

-- D08. SECTOR ECONOMICO Y MORA (POR MES)
SELECT m.FechaCorte, car.SectorEconomicoCliente AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.SectorEconomicoCliente
ORDER BY m.FechaCorte, Registros DESC;

-- D09. CALIFICACION FIE Y MORA (POR MES)
SELECT m.FechaCorte, car.CalificacionFIE AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.CalificacionFIE
ORDER BY m.FechaCorte, Registros DESC;

-- D10. TAMANO DE EMPRESA Y MORA (POR MES)
SELECT m.FechaCorte, car.TamanioEmpresa AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TamanioEmpresa
ORDER BY m.FechaCorte, Registros DESC;

-- D11. TIPO DE AMORTIZACION Y MORA (POR MES)
SELECT m.FechaCorte, car.TipoAmortizacion AS Categoria,
       COUNT_BIG(*) AS Registros,
       COUNT_BIG(car.MaxDiasMoraMes) AS ConDatoMora,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora,
       AVG(CAST(car.SaldoBs AS FLOAT)) AS SaldoPromedioAproximadoBs
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY m.FechaCorte, car.TipoAmortizacion
ORDER BY m.FechaCorte, Registros DESC;

-- D12. GRUPOS DE EDAD Y MORA (TOTAL DEL PERIODO).
-- Las edades menores a 18 y mayores a 100 se separan para validacion.
SELECT CASE
           WHEN cli.Edad IS NULL THEN 'SIN DATO'
           WHEN cli.Edad < 18 THEN 'MENOR DE 18'
           WHEN cli.Edad <= 29 THEN '18-29'
           WHEN cli.Edad <= 44 THEN '30-44'
           WHEN cli.Edad <= 59 THEN '45-59'
           WHEN cli.Edad <= 100 THEN '60-100'
           ELSE 'MAYOR DE 100'
       END AS GrupoEdad,
       COUNT_BIG(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY CASE
           WHEN cli.Edad IS NULL THEN 'SIN DATO'
           WHEN cli.Edad < 18 THEN 'MENOR DE 18'
           WHEN cli.Edad <= 29 THEN '18-29'
           WHEN cli.Edad <= 44 THEN '30-44'
           WHEN cli.Edad <= 59 THEN '45-59'
           WHEN cli.Edad <= 100 THEN '60-100'
           ELSE 'MAYOR DE 100'
         END
ORDER BY Registros DESC;

-- D13. TRANSACCIONES QR Y MORA (POR MES).
SELECT m.FechaCorte,
       CASE
           WHEN tra.CantidadQR IS NULL THEN 'SIN DATO'
           WHEN tra.CantidadQR = 0 THEN 'SIN QR'
           ELSE 'CON QR'
       END AS GrupoQR,
       COUNT_BIG(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0) AS DECIMAL(7,2))
            AS PorcentajeConMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON tra.ClienteKey = car.ClienteKey
   AND tra.Fecha = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte,
         CASE WHEN tra.CantidadQR IS NULL THEN 'SIN DATO'
              WHEN tra.CantidadQR = 0 THEN 'SIN QR'
              ELSE 'CON QR' END
ORDER BY m.FechaCorte, GrupoQR;

-- D14. NUMERO DE TRANSACCIONES POR GRUPOS Y MORA (POR MES).
SELECT m.FechaCorte,
       CASE WHEN tra.CantidadTrx IS NULL THEN 'SIN DATO'
            WHEN tra.CantidadTrx = 0 THEN 'CERO'
            WHEN tra.CantidadTrx <= 5 THEN '1 A 5'
            WHEN tra.CantidadTrx <= 20 THEN '6 A 20'
            ELSE 'MAS DE 20' END AS GrupoTrx,
       COUNT_BIG(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON tra.ClienteKey = car.ClienteKey
   AND tra.Fecha = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte,
         CASE WHEN tra.CantidadTrx IS NULL THEN 'SIN DATO'
              WHEN tra.CantidadTrx = 0 THEN 'CERO'
              WHEN tra.CantidadTrx <= 5 THEN '1 A 5'
              WHEN tra.CantidadTrx <= 20 THEN '6 A 20'
              ELSE 'MAS DE 20' END
ORDER BY m.FechaCorte, GrupoTrx;

-- D15. CALIFICACION EXTERNA Y MORA (POR MES).
SELECT m.FechaCorte, inf.PeorCalificacionASFIKey AS Categoria,
       COUNT_BIG(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON inf.ClienteKey = car.ClienteKey
   AND inf.FechaKey = m.FechaKey
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte, inf.PeorCalificacionASFIKey
ORDER BY m.FechaCorte, Registros DESC;

-- D16. PORCENTAJE CON MORA POR SECTOR (TOTAL DEL PERIODO)
SELECT car.SectorEconomicoCliente AS Sector,
       COUNT_BIG(*) AS CreditosMes,
       SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN car.MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(car.MaxDiasMoraMes), 0)
            AS DECIMAL(7,2)) AS PorcentajeConMora
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
AND EXISTS (
    SELECT 1 FROM Resultados.dcli.DominioClientes cli
    WHERE cli.ClienteKey = car.ClienteKey
      AND cli.FechaCorte = car.FechaCorte
      AND cli.TipoPersona = 'PERSONA NATURAL'
)
GROUP BY car.SectorEconomicoCliente
HAVING COUNT_BIG(car.MaxDiasMoraMes) >= 30
ORDER BY PorcentajeConMora DESC;

-- ===== SECCION E: CALIDAD DE CATEGORICAS Y EVENTOS =====

-- E01. Categorias y valores vacios mas comunes por mes.
SELECT m.FechaCorte,
       COUNT_BIG(*) AS Registros,
       SUM(CASE WHEN cli.Genero IS NULL OR LTRIM(RTRIM(cli.Genero)) = ''
                THEN 1 ELSE 0 END) AS FaltantesGenero,
       SUM(CASE WHEN cli.EstadoCivil IS NULL OR LTRIM(RTRIM(cli.EstadoCivil)) = ''
                THEN 1 ELSE 0 END) AS FaltantesEstadoCivil,
       SUM(CASE WHEN cli.Segmento IS NULL OR LTRIM(RTRIM(cli.Segmento)) = ''
                THEN 1 ELSE 0 END) AS FaltantesSegmento,
       SUM(CASE WHEN cli.Ciudad IS NULL OR LTRIM(RTRIM(cli.Ciudad)) = ''
                THEN 1 ELSE 0 END) AS FaltantesCiudad,
       SUM(CASE WHEN cli.NivelIngreso IS NULL OR LTRIM(RTRIM(CONVERT(VARCHAR(100), cli.NivelIngreso))) = ''
                THEN 1 ELSE 0 END) AS FaltantesNivelIngreso
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte
ORDER BY m.FechaCorte;

-- E02. Cardinalidad (cuantas categorias diferentes hay por mes).
SELECT m.FechaCorte,
       COUNT(DISTINCT cli.Genero) AS Generos,
       COUNT(DISTINCT cli.EstadoCivil) AS EstadosCiviles,
       COUNT(DISTINCT cli.Segmento) AS Segmentos,
       COUNT(DISTINCT cli.Ciudad) AS Ciudades,
       COUNT(DISTINCT cli.Profesion) AS Profesiones,
       COUNT(DISTINCT cli.NivelIngreso) AS NivelesIngreso
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY m.FechaCorte ORDER BY m.FechaCorte;

-- E03. Categorias raras de segmento: menos de 30 registros en el periodo.
SELECT cli.Segmento AS Categoria, COUNT_BIG(*) AS Registros
FROM @Cortes m
JOIN Resultados.dcar.DominioCartera car
    ON car.FechaCorte = m.FechaCorte
JOIN Resultados.dcli.DominioClientes cli
    ON cli.ClienteKey = car.ClienteKey
   AND cli.FechaCorte = car.FechaCorte
WHERE car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL'
GROUP BY cli.Segmento
HAVING COUNT_BIG(*) < 30
ORDER BY Registros, Categoria;

-- E04. Eventos vigentes en los cierres mensuales: SOLO tabla de eventos.
-- No unir a creditos si hay varios eventos por regional y fecha.
SELECT m.FechaCorte,
       eve.CodigoDepartamento,
       COUNT_BIG(*) AS EventosActivos
FROM @Cortes m
JOIN Inteligencia_Comercial.dbo.EventosRelevantes eve
    ON m.FechaCorte BETWEEN CONVERT(DATE, eve.FechaInicio, 103)
                        AND CONVERT(DATE, eve.FechaFin, 103)
GROUP BY m.FechaCorte, eve.CodigoDepartamento
ORDER BY m.FechaCorte, EventosActivos DESC;

-- E05. Tipos/nombres de eventos en el periodo, sin multiplicar creditos.
SELECT eve.Evento, eve.CodigoRegional, eve.CodigoDepartamento,
       COUNT_BIG(*) AS NumeroRegistrosEventos
FROM Inteligencia_Comercial.dbo.EventosRelevantes eve
WHERE CONVERT(DATE, eve.FechaInicio, 103) <= EOMONTH(@FechaFin)
  AND CONVERT(DATE, eve.FechaFin, 103) >= @FechaInicio
GROUP BY eve.Evento, eve.CodigoRegional, eve.CodigoDepartamento
ORDER BY NumeroRegistrosEventos DESC;

/*
RECOMENDACIONES DE RENDIMIENTO:
- Ejecuta solamente los SELECT que estes explorando, NO todo a la vez
  sobre un historico de millones de filas.
- Analiza primero un mes (por ejemplo 2026-08-01 a 2026-08-31);
  luego extiende el periodo si los resultados son utiles.
- Si los cortes se guardaron con una hora distinta de 00:00,
  revisa la igualdad contra las fechas del calendario @Cortes.
- Revisar indices existentes, con el DBA, para:
  car.FechaCorte (filtrado), car.ClienteKey,
  cli.(FechaCorte, ClienteKey),
  tra.(Fecha, ClienteKey),
  inf.(FechaKey, ClienteKey).
  No se crean ni modifican indices en este archivo.
- A03-A06 deben revisarse ANTES de cruces: si hay duplicados en
  tablas de detalle, los JOIN pueden inflar conteos y porcentajes.
- No se usa fn_DominioMensual(@fecha) en varias fechas; la funcion
  de historial debe consultarse por corte separado si se necesita.
- Los grupos son descriptivos: NO muestran causalidad.
*/

