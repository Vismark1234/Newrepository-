/*
 CONSULTAS BASICAS PARA ANALIZAR VARIABLES (SQL SERVER)
 Archivo basado en tu consulta2.sql.

 Cambia las fechas de inicio y fin.
 Ejecuta todo en una sola ventana de SSMS.
 Despues cambia GENEROCLIENTE por otra columna para perfilarla.
 Sin APPLY, procedimientos, UNION, tablas de metadatos ni SQL dinamico.

 Estas consultas siguen tus filtros, incluido NumeroCuotaActual IS NULL.
 No incluye fn_DominioMensual(@fecha), porque esa funcion necesita
 calcularse por cada fecha y no puede reutilizarse para todo el periodo.
 Las variables de mora 3M/6M/12M de DominioCartera si se incluyen.
*/
SET NOCOUNT ON;
DECLARE @FechaInicio DATE = '2026-07-01';
DECLARE @FechaFin DATE = '2026-08-31';

IF OBJECT_ID('tempdb..#Datos') IS NOT NULL DROP TABLE #Datos;

-- 1. CREAR BASE DE DATOS CON TUS UNIONES Y FILTROS (una sola vez)
SELECT
    car.FechaCorte AS FechaCorte,
    car.CarteraKey AS CarteraKey,
-- 1. Perfil del cliente
    car.ClienteKey                              AS ClienteKey
   ,cli.Edad                                    AS EdadCliente
   ,cli.Genero                                  AS GeneroCliente
   ,cli.EstadoCivil                             AS EstadoCivilCliente
   ,cli.NumeroHijos                             AS NumeroHijosCliente
   ,cli.Ciudad                                  AS CiudadCliente
   ,cli.Departamento                            AS DepartamentoCliente
   ,cli.Barrio                                  AS BarrioCliente
   ,cli.edadComoClienteMeses                    AS AntiguedadClienteMeses
   ,cli.Segmento                                AS SegmentoCliente
   ,cli.Nacionalidad                            AS NacionalidadCliente
   ,cli.JefaHogar                               AS EsJefaHogar

-- 2. Situación económica
   -- ,cli.MontoIngreso                            AS IngresoClienteBs
   ,cli.NivelIngreso                            AS NivelIngresoCliente
   ,cli.NivelEgreso                             AS NivelEgresoCliente
   ,cli.TipoFuenteIngreso                       AS FuenteIngresoCliente
   ,cli.Profesion                               AS ProfesionCliente
   ,cli.GradoInstruccion                        AS GradoInstruccionCliente
   ,car.Patrimonio                              AS PatrimonioClienteBs
   ,car.Activos                                 AS ActivosClienteBs
   ,car.VentasAnuales                           AS VentasAnualesClienteBs

-- 3. Endeudamiento externo (Infocred)
   ,inf.PeorCalificacionASFIKey                 AS InfocredPeorCalificacionASFIKey
   ,inf.SaldoVigenteBs                          AS InfocredSaldoVigenteBs
   ,inf.SaldoVencidoBs                          AS InfocredSaldoVencidoBs
   ,inf.SaldoEjecucionBs                        AS InfocredSaldoEjecucionBs
   ,inf.SaldoCantigadoBs                        AS InfocredSaldoCastigadoBs
   ,inf.SaldoContingenteBs                      AS InfocredSaldoContingenteBs
   --,inf.MaximaFechaVencimiento                  AS InfocredMaxFechaVencimiento
   ,DATEDIFF(month,car.FechaCorte,inf.MaximaFechaVencimiento) AS InfocredMesesHastaMaxVencimiento
   ,inf.MontoDeudaTotalBs                       AS InfocredMontoDeudaTotalBs
   ,inf.CuotaBs                                 AS InfocredCuotaBs
   ,inf.CantidadDeudasOtrasEntidades            AS InfocredCantDeudasOtrasEntidades
   ,inf.CantidadDeudasDeudor                    AS InfocredCantDeudasDeudor
   ,inf.CantidadDeudasCodeudor                  AS InfocredCantDeudasCodeudor
   ,inf.EsCreditoVivienda                       AS InfocredEsCreditoVivienda

-- 4. Productos y canales
   ,car.Productocartera                         AS ProductoCartera
   ,cli.EsDeudorcartera                         AS EsDeudorCartera
   ,cli.EsCodeudorcartera                       AS EsCodeudorCartera
   ,cli.EsGarantecartera                        AS EsGaranteCartera
   ,cli.EsClienteActivoDigital                  AS EsClienteDigital
   ,cli.EsclienteTinka                          AS EsClienteTinka

-- 5. Características del crédito
   ,car.CodigoOficialCredito                    AS CodigoOficialCredito
   ,car.NombreOficialCredito                    AS NombreOficialCredito
   ,car.TipoCredito                             AS TipoCredito
   ,car.TipoBanca                               AS TipoBanca
   ,car.TasaEfectiva                            AS TasaEfectivaCredito
   ,car.TasaBase                                AS TasaBaseCredito
   ,car.TasaTRE                                 AS TasaTRECredito
   ,car.PlazoDias                               AS PlazoCreditoDias
   ,car.PlazoMeses                              AS PlazoCreditoMeses
   ,car.FrecuenciaPago                          AS FrecuenciaPagoCredito
   ,car.TipoAmortizacion                        AS TipoAmortizacion
   ,car.CantidadReprogramaciones                AS CantidadReprogramaciones
   ,car.MontoReprogramadoBs                     AS MontoReprogramadoBs
   ,car.EstadoCredito                           AS EstadoCredito
   ,car.LineaCredito                            AS LineaCredito
   ,car.MontoLineaCreditoBs                     AS MontoLineaCreditoBs

-- 6. Actividad económica
   ,car.SectorEconomicoCliente                  AS SectorEconomicoCliente
   ,car.SectorEconomicoCredito                  AS SectorEconomicoCredito
   ,car.ActividadEconomicaCliente               AS ActividadEconomicaCliente
   ,car.ActividadEconomicaCredito               AS ActividadEconomicaCredito
   ,car.ActividadEconomicaClienteCAEDEC         AS ActividadEconomicaClienteCAEDEC
   ,car.ActividadEconomicaCreditoCAEDEC         AS ActividadEconomicaCreditoCAEDEC
   ,car.Nrotrabajadores                         AS NumeroTrabajadores
   ,car.IndiceActividad                         AS IndiceActividadEconomica
   ,car.TamanioEmpresa                          AS TamanioEmpresa

-- 7. Endeudamiento y garantías
   ,car.SaldoBs                                 AS SaldoCreditoBs
   ,car.SaldoCapitalBs                          AS SaldoCapitalBs
   ,car.SaldoDiferidoBs                         AS SaldoDiferidoBs
   ,car.InteresBs                               AS InteresBs
   ,car.OtrosRubrosBs                           AS OtrosRubrosBs
   ,car.MontoDesembolsadoBs                     AS MontoDesembolsadoBs
   ,car.GarantiaHipotecaria                     AS GarantiaHipotecariaBs
   ,car.GarantiaPersonal                        AS GarantiaPersonalBs
   ,car.GarantiaPrendaria                       AS GarantiaPrendariaBs
   ,car.GarantiaCaptacion                       AS GarantiaCaptacionBs
   ,car.GarantiaOtros                           AS GarantiaOtrosBs
   ,car.GarantiaDocumentosCustodia              AS GarantiaDocumentosCustodiaBs
   ,car.MontoGarantiaBs                         AS MontoGarantiaTotalBs
   ,car.PrevisionRequeridaBs                    AS PrevisionRequeridaBs
   ,car.PrevisionCiclicaBs                      AS PrevisionCiclicaBs

-- 8. Fechas del crédito
   
   --,car.FechaCorte                              AS FechaCorte
   ,DATEDIFF(month,car.FechaCorte,car.FechaVencimiento) AS MesesHastaVencimientoCredito
   ,car.FechaVencimiento                        AS FechaVencimiento
   ,DATEDIFF(month,car.FechaCorte,car.FechaVencimientoReprogramada) AS MesesHastaVencimientoReprogramado
   ,car.FechaVencimientoReprogramada            AS FechaVencimientoReprogramada
   ,DATEDIFF(month,car.FechaCorte,car.FechaRefinanciamiento) AS MesesDiferenciaRefinanciamiento
   ,car.FechaRefinanciamiento                   AS FechaRefinanciamiento
   ,DATEDIFF(day,car.FechaCorte,car.FechaProximoPago) AS DiasHastaProximoPago
   ,car.FechaProximoPago                        AS FechaProximoPago

-- 9. Eventos
   ,eve.Evento                                  AS Evento
   --no se usara se tiene el intervalo en duraciondias
   
   --,eve.FechaInicio                             AS EventoFechaInicio
   --,eve.FechaFin                                AS EventoFechaFin
   ,eve.DuracionDias                            AS EventoDuracionDias
   ,eve.CodigoRegional                          AS EventoCodigoRegional
   ,eve.CodigoDepartamento                      AS EventoCodigoDepartamento
   --,eve.Departamento                            AS EventoDepartamento
   ,eve.Descripcion                             AS EventoDescripcion

-- 10. Comportamiento de pago
   ,car.MaxDiasMoraMes                          AS MaxDiasMoraMes
   ,car.MaxDiasMora3M                           AS MaxDiasMora3M
   ,car.PromedioMora3M                          AS PromedioMora3M
   ,car.MesesConMora3M                          AS MesesConMora3M
   ,car.MaxDiasMora6M                           AS MaxDiasMora6M
   ,car.PromedioMora6M                          AS PromedioMora6M
   ,car.MesesConMora6M                          AS MesesConMora6M
   ,car.MaxDiasMora12M                          AS MaxDiasMora12M
   ,car.PromedioMora12M                         AS PromedioMora12M
   ,car.MesesConMora12M                         AS MesesConMora12M
   ,car.TasaCumplimiento                        AS TasaCumplimiento
   ,car.AntiguedadCreditoMeses                  AS AntiguedadCreditoMeses
   ,car.CalificacionFIE                         AS CalificacionFIE
   ,car.CalificacionASFI                        AS CalificacionASFI

-- 11. Comportamiento transaccional
   ,tra.CantidadTrx                             AS CantidadTrx
   ,tra.MontoTotalBs                            AS MontoTotalTrxBs
   ,tra.CantidadDepositos                       AS CantidadDepositos
   ,tra.CantidadRetiros                         AS CantidadRetiros
   ,tra.MontoDepositosBs                        AS MontoDepositosBs
   ,tra.MontoRetirosBs                          AS MontoRetirosBs
   ,tra.FlujoNetoBs                             AS FlujoNetoBs
   ,tra.CantidadQR                              AS CantidadQR
   ,tra.CantidadDigital                         AS CantidadDigital
   ,tra.CantidadPresencial                      AS CantidadPresencial
   ,tra.CantidadAutoservicio                    AS CantidadAutoservicio
   ,tra.CantidadProcesamiento                   AS CantidadProcesamiento
   ,tra.MontoQR                                 AS MontoQRBs
   ,tra.MontoDigital                            AS MontoDigitalBs
   ,tra.MontoPresencial                         AS MontoPresencialBs
   ,tra.MontoAutoservicio                       AS MontoAutoservicioBs
   ,tra.MontoProcesamiento                      AS MontoProcesamientoBs

-- 12. Histórico transaccional 3M

-- 13. Histórico transaccional 6M

-- 14. Histórico transaccional 12M
INTO #Datos
FROM Resultados.dcar.DominioCartera AS car
LEFT JOIN Resultados.dcli.DominioClientes AS cli
       ON car.ClienteKey = cli.ClienteKey AND car.FechaCorte = cli.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales AS tra
       ON car.ClienteKey = tra.ClienteKey AND car.FechaCorte = tra.Fecha
LEFT JOIN INTELIGENCIA_COMERCIAL.dbo.ClienteInfocred AS inf
       ON car.ClienteKey = inf.ClienteKey
      AND inf.FechaKey = CONVERT(INT, CONVERT(CHAR(8), car.FechaCorte, 112))
LEFT JOIN Inteligencia_Comercial.dbo.EventosRelevantes AS eve
       ON car.CodigoRegional = eve.CodigoRegional
      AND car.FechaCorte BETWEEN CONVERT(DATE, eve.FechaInicio, 103)
                             AND CONVERT(DATE, eve.FechaFin, 103)
WHERE car.FechaCorte >= @FechaInicio
  AND car.FechaCorte <= @FechaFin
  AND car.FechaCorte = EOMONTH(car.FechaCorte)
  AND car.NumeroCuotaActual IS NULL
  AND car.Producto = 'CARTERA'
  AND car.TipoBanca = 'BANCA MICROEMPRESA'
  AND car.EstadoCredito = 'VIGENTE'
  AND car.FrecuenciaPago = 'MENSUAL'
  AND cli.TipoPersona = 'PERSONA NATURAL';

-- 2. NUMERO DE REGISTROS POR MES
SELECT FechaCorte, COUNT(*) AS Registros,
       COUNT(DISTINCT ClienteKey) AS ClientesDistintos
FROM #Datos
GROUP BY FechaCorte
ORDER BY FechaCorte;

-- 3. NUMERO DE REGISTROS EN EL PERIODO COMPLETO
SELECT COUNT(*) AS RegistrosTotal,
       COUNT(DISTINCT ClienteKey) AS ClientesDistintos
FROM #Datos;

-- 4. EJEMPLO DE VARIABLE CATEGORICA POR MES
-- Cambia GeneroCliente por EstadoCivilCliente, NivelIngresoCliente,
-- EsClienteDigital, TipoCredito, CalificacionFIE, etc.
SELECT d.FechaCorte,
       d.GeneroCliente AS Categoria,
       COUNT(*) AS Cantidad,
       CAST(100.0 * COUNT(*) / NULLIF((
           SELECT COUNT(*) FROM #Datos x
           WHERE x.FechaCorte = d.FechaCorte
       ), 0) AS DECIMAL(6,2)) AS Porcentaje
FROM #Datos d
GROUP BY d.FechaCorte, d.GeneroCliente
ORDER BY d.FechaCorte, Cantidad DESC;

-- 5. LA MISMA VARIABLE EN TODO EL PERIODO
SELECT GeneroCliente AS Categoria,
       COUNT(*) AS Cantidad,
       CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM #Datos), 0)
            AS DECIMAL(6,2)) AS Porcentaje
FROM #Datos
GROUP BY GeneroCliente
ORDER BY Cantidad DESC;

-- 6. CANTIDAD DE CATEGORIAS DISTINTAS POR MES
SELECT FechaCorte,
       COUNT(DISTINCT GeneroCliente) AS CategoriasDistintas
FROM #Datos
GROUP BY FechaCorte
ORDER BY FechaCorte;

-- 7. DATOS FALTANTES POR MES
-- COUNT(*) - COUNT(columna) cuenta los NULL.
-- Para texto, se revisan ademas los espacios o textos vacios.
SELECT FechaCorte,
       COUNT(*) AS Registros,
       COUNT(*) - COUNT(EdadCliente) AS NulosEdad,
       SUM(CASE WHEN GeneroCliente IS NULL OR LTRIM(RTRIM(GeneroCliente)) = ''
                THEN 1 ELSE 0 END) AS FaltantesGenero,
       CAST(100.0 * SUM(CASE WHEN GeneroCliente IS NULL OR LTRIM(RTRIM(GeneroCliente)) = ''
                             THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
            AS DECIMAL(6,2)) AS PorcentajeFaltanteGenero,
       COUNT(*) - COUNT(SaldoCreditoBs) AS NulosSaldo,
       COUNT(*) - COUNT(MaxDiasMora6M) AS NulosMora6M,
       COUNT(*) - COUNT(CantidadTrx) AS NulosTransacciones,
       COUNT(*) - COUNT(InfocredSaldoVigenteBs) AS NulosInfocred
FROM #Datos
GROUP BY FechaCorte
ORDER BY FechaCorte;

-- 8. DATOS FALTANTES EN TODO EL PERIODO
SELECT COUNT(*) AS Registros,
       COUNT(*) - COUNT(EdadCliente) AS NulosEdad,
       SUM(CASE WHEN GeneroCliente IS NULL OR LTRIM(RTRIM(GeneroCliente)) = ''
                THEN 1 ELSE 0 END) AS FaltantesGenero,
       CAST(100.0 * SUM(CASE WHEN GeneroCliente IS NULL OR LTRIM(RTRIM(GeneroCliente)) = ''
                             THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
            AS DECIMAL(6,2)) AS PorcentajeFaltanteGenero,
       COUNT(*) - COUNT(SaldoCreditoBs) AS NulosSaldo,
       COUNT(*) - COUNT(MaxDiasMora6M) AS NulosMora6M,
       COUNT(*) - COUNT(CantidadTrx) AS NulosTransacciones,
       COUNT(*) - COUNT(InfocredSaldoVigenteBs) AS NulosInfocred
FROM #Datos;

-- 9. RESUMEN NUMERICO POR MES
SELECT FechaCorte,
       COUNT(*) AS Registros,
       MIN(EdadCliente) AS EdadMinima,
       MAX(EdadCliente) AS EdadMaxima,
       AVG(CAST(EdadCliente AS FLOAT)) AS EdadPromedio,
       MIN(SaldoCreditoBs) AS SaldoMinimo,
       MAX(SaldoCreditoBs) AS SaldoMaximo,
       AVG(SaldoCreditoBs) AS SaldoPromedio,
       AVG(MaxDiasMora6M * 1.0) AS Mora6MPromedio
FROM #Datos
GROUP BY FechaCorte
ORDER BY FechaCorte;

-- 10. RESUMEN NUMERICO DEL TOTAL
SELECT COUNT(*) AS Registros,
       MIN(EdadCliente) AS EdadMinima,
       MAX(EdadCliente) AS EdadMaxima,
       AVG(CAST(EdadCliente AS FLOAT)) AS EdadPromedio,
       MIN(SaldoCreditoBs) AS SaldoMinimo,
       MAX(SaldoCreditoBs) AS SaldoMaximo,
       AVG(SaldoCreditoBs) AS SaldoPromedio,
       AVG(MaxDiasMora6M * 1.0) AS Mora6MPromedio
FROM #Datos;

-- 11. REVISAR POSIBLES REGISTROS DUPLICADOS
-- Un credito puede duplicarse si coincide con mas de un evento.
SELECT FechaCorte, CarteraKey, COUNT(*) AS Veces
FROM #Datos
GROUP BY FechaCorte, CarteraKey
HAVING COUNT(*) > 1
ORDER BY Veces DESC;

/*
 Observaciones:
 - El analisis se hace sobre registros de credito, no clientes unicos.
 - FechaCorte solo incluye cierres de mes por el filtro original.
 - Las variables TipoBanca, EstadoCredito y FrecuenciaPagoCredito
   tendran una sola categoria debido a los filtros.
 - Evento NULL puede indicar ausencia de un evento asociado y no un error.
*/