/*
  ANALISIS EXPLORATORIO DE DATOS - CARTERA / MORA
  Basado en consulta2.sql

  Cambia @FechaInicio y @FechaFin; ejecuta todo en una misma ventana de SSMS.
  Cada SELECT devuelve un resultado independiente.
  Solo SELECT, JOIN, GROUP BY, CASE, COUNT, SUM, AVG.

  Se conservan los filtros originales, incluido NumeroCuotaActual IS NULL.
  Se analizan cierres mensuales y no se incluye fn_DominioMensual(@fecha),
  pues recibe una sola fecha. Tampoco se unen EventosRelevantes, porque
  pueden duplicar creditos cuando coinciden varios eventos.
  La tasa de mora usa como denominador registros con dato de mora.
*/

SET NOCOUNT ON;
DECLARE @FechaInicio DATE = '2026-07-01';
DECLARE @FechaFin DATE = '2026-08-31';

IF OBJECT_ID('tempdb..#Datos') IS NOT NULL DROP TABLE #Datos;

-- BASE DEL ANALISIS
SELECT
     car.FechaCorte AS FechaCorte
    ,car.CarteraKey AS CarteraKey
    ,car.ClienteKey AS ClienteKey
    ,cli.Edad AS EdadCliente
    ,cli.Genero AS GeneroCliente
    ,cli.EstadoCivil AS EstadoCivilCliente
    ,cli.Ciudad AS CiudadCliente
    ,cli.Departamento AS DepartamentoCliente
    ,cli.Segmento AS SegmentoCliente
    ,cli.NivelIngreso AS NivelIngresoCliente
    ,cli.GradoInstruccion AS GradoInstruccionCliente
    ,cli.EsClienteActivoDigital AS EsClienteDigital
    ,car.TipoCredito AS TipoCredito
    ,car.SectorEconomicoCliente AS SectorEconomicoCliente
    ,car.CalificacionFIE AS CalificacionFIE
    ,car.CalificacionASFI AS CalificacionASFI
    ,car.SaldoBs AS SaldoCreditoBs
    ,car.MontoDesembolsadoBs AS MontoDesembolsadoBs
    ,car.TasaEfectiva AS TasaEfectivaCredito
    ,car.MaxDiasMoraMes AS MaxDiasMoraMes
    ,car.MaxDiasMora3M AS MaxDiasMora3M
    ,car.MaxDiasMora6M AS MaxDiasMora6M
    ,car.MaxDiasMora12M AS MaxDiasMora12M
    ,car.MesesConMora6M AS MesesConMora6M
    ,car.TasaCumplimiento AS TasaCumplimiento
    ,car.AntiguedadCreditoMeses AS AntiguedadCreditoMeses
    ,car.CantidadReprogramaciones AS CantidadReprogramaciones
    ,tra.CantidadTrx AS CantidadTrx
    ,tra.CantidadQR AS CantidadQR
    ,tra.FlujoNetoBs AS FlujoNetoBs
    ,inf.MontoDeudaTotalBs AS InfocredMontoDeudaTotalBs
INTO #Datos
FROM Resultados.dcar.DominioCartera car
LEFT JOIN Resultados.dcli.DominioClientes cli
    ON car.ClienteKey = cli.ClienteKey
   AND car.FechaCorte = cli.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
    ON car.ClienteKey = tra.ClienteKey
   AND car.FechaCorte = tra.Fecha
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred inf
    ON car.ClienteKey = inf.ClienteKey
   AND car.FechaCorte = CONVERT(DATE, CONVERT(VARCHAR(8), inf.FechaKey, 112))
WHERE car.FechaCorte >= @FechaInicio
  AND car.FechaCorte <= @FechaFin
  AND car.FechaCorte = EOMONTH(car.FechaCorte)
  AND car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL';

-- 01. TAMANO POR MES
SELECT FechaCorte, COUNT(*) AS Registros,
       COUNT(DISTINCT ClienteKey) AS ClientesDistintos,
       COUNT(DISTINCT CarteraKey) AS CreditosDistintos
FROM #Datos
GROUP BY FechaCorte ORDER BY FechaCorte;

-- 02. TAMANO TOTAL DEL PERIODO (CREDITOS-MES)
SELECT COUNT(*) AS RegistrosTotal,
       COUNT(DISTINCT ClienteKey) AS ClientesUnicos,
       COUNT(DISTINCT CarteraKey) AS CreditosUnicos,
       COUNT(DISTINCT FechaCorte) AS MesesConDatos
FROM #Datos;

-- 03. MORA POR MES: ACTUAL Y 3M, 6M, 12M
-- Excluye NULL del denominador de cada indicador.
SELECT FechaCorte, COUNT(MaxDiasMoraMes) AS ConDatoMoraActual,
       SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMoraActual,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMoraActual,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMora3M > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMora3M), 0) AS DECIMAL(6,2)) AS PctMora3M,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMora6M > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMora6M), 0) AS DECIMAL(6,2)) AS PctMora6M,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMora12M > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMora12M), 0) AS DECIMAL(6,2)) AS PctMora12M
FROM #Datos GROUP BY FechaCorte ORDER BY FechaCorte;

-- 04. MORA TOTAL EN TODOS LOS REGISTROS CREDITO-MES
SELECT COUNT(MaxDiasMoraMes) AS RegistrosConDatoMora,
       SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS RegistrosConMora,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora,
       AVG(CAST(MaxDiasMoraMes AS FLOAT)) AS PromedioDiasMora
FROM #Datos;

-- 05. GENERO POR MES
SELECT FechaCorte, GeneroCliente, COUNT(*) AS Cantidad,
       COUNT(DISTINCT ClienteKey) AS ClientesDistintos
FROM #Datos GROUP BY FechaCorte, GeneroCliente
ORDER BY FechaCorte, Cantidad DESC;

-- 06. ESTADO CIVIL EN TODO EL PERIODO
SELECT EstadoCivilCliente, COUNT(*) AS Cantidad,
       CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM #Datos), 0)
            AS DECIMAL(6,2)) AS Porcentaje
FROM #Datos GROUP BY EstadoCivilCliente ORDER BY Cantidad DESC;

-- 07. SEGMENTO Y MORA POR MES
SELECT FechaCorte, SegmentoCliente, COUNT(*) AS Registros,
       SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END) AS ConMora,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora,
       AVG(CAST(SaldoCreditoBs AS FLOAT)) AS SaldoPromedioBs
FROM #Datos GROUP BY FechaCorte, SegmentoCliente
ORDER BY FechaCorte, Registros DESC;

-- 08. SECTOR ECONOMICO Y MORA TOTAL
SELECT SectorEconomicoCliente, COUNT(*) AS Registros,
       COUNT(DISTINCT ClienteKey) AS ClientesUnicos,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora
FROM #Datos GROUP BY SectorEconomicoCliente
ORDER BY Registros DESC;

-- 09. CALIFICACION CREDITICIA POR MES
SELECT FechaCorte, CalificacionFIE, COUNT(*) AS Registros,
       AVG(CAST(MaxDiasMoraMes AS FLOAT)) AS PromedioDiasMora
FROM #Datos GROUP BY FechaCorte, CalificacionFIE
ORDER BY FechaCorte, Registros DESC;

-- 10. GRUPOS DE EDAD Y MORA EN EL PERIODO
SELECT CASE WHEN EdadCliente IS NULL THEN 'Sin dato'
            WHEN EdadCliente < 18 THEN 'Menor de 18'
            WHEN EdadCliente <= 29 THEN '18 a 29'
            WHEN EdadCliente <= 44 THEN '30 a 44'
            WHEN EdadCliente <= 59 THEN '45 a 59'
            ELSE '60 o mas' END AS GrupoEdad,
       COUNT(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora
FROM #Datos
GROUP BY CASE WHEN EdadCliente IS NULL THEN 'Sin dato'
              WHEN EdadCliente < 18 THEN 'Menor de 18'
              WHEN EdadCliente <= 29 THEN '18 a 29'
              WHEN EdadCliente <= 44 THEN '30 a 44'
              WHEN EdadCliente <= 59 THEN '45 a 59'
              ELSE '60 o mas' END
ORDER BY GrupoEdad;

-- 11. NIVEL DE INGRESO Y MORA POR MES
SELECT FechaCorte, NivelIngresoCliente, COUNT(*) AS Registros,
       AVG(CAST(SaldoCreditoBs AS FLOAT)) AS SaldoPromedioBs,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora
FROM #Datos GROUP BY FechaCorte, NivelIngresoCliente
ORDER BY FechaCorte, Registros DESC;

-- 12. SALDOS MENSUALES
-- Saldo total: fotografia mensual, NO flujo de ingresos.
SELECT FechaCorte, COUNT(SaldoCreditoBs) AS CreditosConSaldo,
       SUM(SaldoCreditoBs) AS SaldoTotalBs,
       AVG(CAST(SaldoCreditoBs AS FLOAT)) AS SaldoPromedioBs,
       MIN(SaldoCreditoBs) AS SaldoMinimoBs,
       MAX(SaldoCreditoBs) AS SaldoMaximoBs,
       AVG(CAST(MontoDesembolsadoBs AS FLOAT)) AS DesembolsoPromedioBs
FROM #Datos GROUP BY FechaCorte ORDER BY FechaCorte;

-- 13. FALTANTES POR MES (NULL DIFERENTE DE 0)
SELECT FechaCorte, COUNT(*) AS Registros,
       COUNT(*) - COUNT(EdadCliente) AS NulosEdad,
       COUNT(*) - COUNT(SegmentoCliente) AS NulosSegmento,
       COUNT(*) - COUNT(MaxDiasMoraMes) AS NulosMora,
       COUNT(*) - COUNT(CantidadTrx) AS SinDatoTransacciones,
       SUM(CASE WHEN CantidadTrx = 0 THEN 1 ELSE 0 END) AS CeroTransacciones,
       COUNT(*) - COUNT(InfocredMontoDeudaTotalBs) AS SinDatoInfocred,
       CAST(100.0 * (COUNT(*) - COUNT(CantidadTrx))
            / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS PctSinDatoTransacciones
FROM #Datos GROUP BY FechaCorte ORDER BY FechaCorte;

-- 14. FALTANTES POR SEGMENTO Y MES
SELECT FechaCorte, SegmentoCliente, COUNT(*) AS Registros,
       CAST(100.0 * (COUNT(*) - COUNT(CantidadTrx))
            / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS PctSinTransacciones,
       CAST(100.0 * (COUNT(*) - COUNT(InfocredMontoDeudaTotalBs))
            / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS PctSinInfocred
FROM #Datos GROUP BY FechaCorte, SegmentoCliente
ORDER BY FechaCorte, Registros DESC;

-- 15. POSIBLES ATIPICOS (UMBRAL DE REVISION, NO ERROR CONFIRMADO)
SELECT FechaCorte,
       SUM(CASE WHEN EdadCliente < 18 OR EdadCliente > 100 THEN 1 ELSE 0 END) AS EdadesFueraRango,
       SUM(CASE WHEN SaldoCreditoBs < 0 THEN 1 ELSE 0 END) AS SaldosNegativos,
       SUM(CASE WHEN MontoDesembolsadoBs < 0 THEN 1 ELSE 0 END) AS DesembolsosNegativos,
       SUM(CASE WHEN MaxDiasMoraMes < 0 THEN 1 ELSE 0 END) AS MoraNegativa,
       SUM(CASE WHEN CantidadTrx < 0 THEN 1 ELSE 0 END) AS TransaccionesNegativas
FROM #Datos GROUP BY FechaCorte ORDER BY FechaCorte;

-- 16. LOS 20 SALDOS MAS ALTOS
SELECT TOP (20) FechaCorte, ClienteKey, CarteraKey,
       SaldoCreditoBs, MontoDesembolsadoBs, MaxDiasMoraMes
FROM #Datos WHERE SaldoCreditoBs IS NOT NULL
ORDER BY SaldoCreditoBs DESC;

-- 17. RELACION EXPLORATORIA: USO DE QR Y MORA
SELECT FechaCorte,
       CASE WHEN CantidadQR IS NULL THEN 'Sin dato'
            WHEN CantidadQR = 0 THEN 'Sin QR'
            ELSE 'Con QR' END AS GrupoQR,
       COUNT(*) AS Registros,
       CAST(100.0 * SUM(CASE WHEN MaxDiasMoraMes > 0 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(MaxDiasMoraMes), 0) AS DECIMAL(6,2)) AS PctConMora
FROM #Datos
GROUP BY FechaCorte,
         CASE WHEN CantidadQR IS NULL THEN 'Sin dato'
              WHEN CantidadQR = 0 THEN 'Sin QR'
              ELSE 'Con QR' END
ORDER BY FechaCorte, GrupoQR;

-- 18. COBERTURA HISTORICA POR CLIENTE
SELECT ClienteKey,
       COUNT(DISTINCT FechaCorte) AS MesesConInformacion,
       COUNT(DISTINCT CarteraKey) AS CreditosDistintos
FROM #Datos GROUP BY ClienteKey
ORDER BY MesesConInformacion DESC, CreditosDistintos DESC;

-- 19. CUMPLIMIENTO, REPROGRAMACIONES Y ANTIGUEDAD POR MES
-- Comprobar la escala de TasaCumplimiento (0-1 o 0-100) antes de interpretarla.
SELECT FechaCorte,
       AVG(CAST(TasaCumplimiento AS FLOAT)) AS CumplimientoPromedio,
       AVG(CAST(CantidadReprogramaciones AS FLOAT)) AS ReprogramacionesPromedio,
       SUM(CASE WHEN CantidadReprogramaciones > 0 THEN 1 ELSE 0 END) AS ConReprogramacion,
       AVG(CAST(AntiguedadCreditoMeses AS FLOAT)) AS AntiguedadPromedioMeses
FROM #Datos GROUP BY FechaCorte ORDER BY FechaCorte;

-- 20. DUPLICADOS POR CREDITO / CORTE (REVISAR JOIN)
SELECT FechaCorte, CarteraKey, COUNT(*) AS Veces
FROM #Datos
GROUP BY FechaCorte, CarteraKey
HAVING COUNT(*) > 1
ORDER BY Veces DESC;

/*
 ATENCION AL INTERPRETAR:
 - Las tasas de mora excluyen NULL en la variable de mora.
 - La suma de saldos entre distintos meses no es flujo acumulado.
 - La correlacion o comparacion entre grupos no demuestra causalidad.
 - Si hay duplicados en consulta 20, revisar JOIN antes de interpretar.
 - Solo se describen creditos VIGENTES, en BANCA MICROEMPRESA,
   de PERSONAS NATURALES y los que cumplen NumeroCuotaActual IS NULL.
*/