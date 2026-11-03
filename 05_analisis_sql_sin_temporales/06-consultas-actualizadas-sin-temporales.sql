/* CONSULTAS ACTUALIZADAS SIN TABLAS TEMPORALES
   Orden: fechas de eventos, funcion general y analisis. */


/* ==================== 03. FECHAS DE EVENTOS ==================== */
/* Ejecutar una sola vez. Las fechas originales deben estar en formato dd/mm/aaaa. */

SET DATEFORMAT DMY;

SELECT *
INTO Inteligencia_Comercial.dbo.EventosRelevantes_FechasCorrectas
FROM Inteligencia_Comercial.dbo.EventosRelevantes;

ALTER TABLE Inteligencia_Comercial.dbo.EventosRelevantes_FechasCorrectas
ALTER COLUMN FechaInicio DATE NULL;

ALTER TABLE Inteligencia_Comercial.dbo.EventosRelevantes_FechasCorrectas
ALTER COLUMN FechaFin DATE NULL;



/* ==================== 01. FUNCION GENERAL ==================== */
/*
    CONSULTA GENERAL DEL DATASET DE CARTERA

    Crea una funcion reutilizable; no crea tablas temporales.
    Uso:
        SELECT *
        FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis
             ('2026-08-01', '2026-08-31');
*/

USE Inteligencia_Comercial;
GO

CREATE OR ALTER FUNCTION dbo.fn_DatasetCarteraAnalisis
(
    @FechaInicio DATE,
    @FechaFin DATE
)
RETURNS TABLE
AS
RETURN
(
WITH CarteraBase AS
(
    SELECT car.*
    FROM Resultados.dcar.dominiocartera car
    WHERE car.FechaCorte BETWEEN EOMONTH(@FechaInicio) AND EOMONTH(@FechaFin)
      AND car.Producto = 'CARTERA'
      AND car.TipoBanca = 'BANCA MICROEMPRESA'
      AND car.EstadoCredito = 'VIGENTE'
      AND car.FrecuenciaPago = 'MENSUAL'
),
Meses AS
(
    SELECT DISTINCT FechaCorte
    FROM CarteraBase
),
ClienteOrdenado AS
(
    SELECT
        c.ClienteKey,
        c.FechaCorte,
        c.Edad,
        c.Genero,
        c.EstadoCivil,
        c.NumeroHijos,
        c.Ciudad,
        c.Departamento,
        c.Barrio,
        c.edadComoClienteMeses,
        c.Segmento,
        c.Nacionalidad,
        c.JefaHogar,
        c.NivelIngreso,
        c.NivelEgreso,
        c.TipoFuenteIngreso,
        c.Profesion,
        c.GradoInstruccion,
        c.EsDeudorcartera,
        c.EsCodeudorcartera,
        c.EsGarantecartera,
        c.EsClienteActivoDigital,
        c.EsclienteTinka,
        ROW_NUMBER() OVER
        (
            PARTITION BY c.ClienteKey, c.FechaCorte
            -- No se prioriza CARTERA ni CAPTACION; se conserva una asignacion.
            ORDER BY c.Asignacion_Motivo
        ) AS rn
    FROM Resultados.dcli.dominioclientes c
    INNER JOIN Meses m
            ON m.FechaCorte = c.FechaCorte
    WHERE c.TipoPersona = 'PERSONA NATURAL'
),
ClienteUnico AS
(
SELECT
    ClienteKey,
    FechaCorte,
    Edad,
    Genero,
    EstadoCivil,
    NumeroHijos,
    Ciudad,
    Departamento,
    Barrio,
    edadComoClienteMeses,
    Segmento,
    Nacionalidad,
    JefaHogar,
    NivelIngreso,
    NivelEgreso,
    TipoFuenteIngreso,
    Profesion,
    GradoInstruccion,
    EsDeudorcartera,
    EsCodeudorcartera,
    EsGarantecartera,
    EsClienteActivoDigital,
    EsclienteTinka
FROM ClienteOrdenado
WHERE rn = 1
),
HistoricoTransaccional AS
(
SELECT
    m.FechaCorte,
    h.ClienteKey,
    h.CantidadTrx_3M,
    h.MontoTotalBs_3M,
    h.CantidadDepositos_3M,
    h.CantidadRetiros_3M,
    h.MontoDepositosBs_3M,
    h.MontoRetirosBs_3M,
    h.CantidadTrx_6M,
    h.MontoTotalBs_6M,
    h.CantidadDepositos_6M,
    h.CantidadRetiros_6M,
    h.MontoDepositosBs_6M,
    h.MontoRetirosBs_6M,
    h.CantidadTrx_12M,
    h.MontoTotalBs_12M,
    h.CantidadDepositos_12M,
    h.CantidadRetiros_12M,
    h.MontoDepositosBs_12M,
    h.MontoRetirosBs_12M,
    h.MesesConHistoria
FROM Meses m
CROSS APPLY test.dbo.fn_DominioMensual(m.FechaCorte) AS h
),
EventoMesOrdenado AS
(
    SELECT
        m.FechaCorte,
        e.CodigoRegional,
        e.CodigoDepartamento,
        e.Evento,
        e.DuracionDias,
        e.Descripcion,
        e.FechaInicio,
        e.FechaFin,
        COUNT_BIG(*) OVER
        (
            PARTITION BY m.FechaCorte, e.CodigoRegional
        ) AS CantidadEventos,
        ROW_NUMBER() OVER
        (
            PARTITION BY m.FechaCorte, e.CodigoRegional
            ORDER BY
                e.DuracionDias DESC,
                e.FechaInicio,
                e.FechaFin,
                e.Evento
        ) AS rn
    FROM Meses m
    INNER JOIN dbo.EventosRelevantes_FechasCorrectas e
            ON e.FechaInicio <= m.FechaCorte
           AND e.FechaFin >= m.FechaCorte
),
EventosMes AS
(
SELECT
    FechaCorte,
    CodigoRegional,
    CodigoDepartamento,
    Evento,
    DuracionDias,
    Descripcion,
    FechaInicio,
    FechaFin,
    CantidadEventos
FROM EventoMesOrdenado
WHERE rn = 1
)
SELECT
    car.FechaCorte                              AS FechaCorte,
    car.CarteraKey                              AS CarteraKey,
    car.ClienteKey                              AS ClienteKey,

    -- Perfil del cliente
    cli.Edad                                    AS EdadCliente,
    cli.Genero                                  AS GeneroCliente,
    cli.EstadoCivil                             AS EstadoCivilCliente,
    cli.NumeroHijos                             AS NumeroHijosCliente,
    cli.Ciudad                                  AS CiudadCliente,
    cli.Departamento                            AS DepartamentoCliente,
    cli.Barrio                                  AS BarrioCliente,
    cli.edadComoClienteMeses                    AS AntiguedadClienteMeses,
    cli.Segmento                                AS SegmentoCliente,
    cli.Nacionalidad                            AS NacionalidadCliente,
    cli.JefaHogar                               AS EsJefaHogar,

    -- Situacion economica
    cli.NivelIngreso                            AS NivelIngresoCliente,
    cli.NivelEgreso                             AS NivelEgresoCliente,
    cli.TipoFuenteIngreso                       AS FuenteIngresoCliente,
    cli.Profesion                               AS ProfesionCliente,
    cli.GradoInstruccion                        AS GradoInstruccionCliente,
    car.Patrimonio                              AS PatrimonioClienteBs,
    car.Activos                                 AS ActivosClienteBs,
    car.VentasAnuales                           AS VentasAnualesClienteBs,

    -- Endeudamiento externo
    inf.PeorCalificacionASFIKey                 AS InfocredPeorCalificacionASFIKey,
    inf.SaldoVigenteBs                          AS InfocredSaldoVigenteBs,
    inf.SaldoVencidoBs                          AS InfocredSaldoVencidoBs,
    inf.SaldoEjecucionBs                        AS InfocredSaldoEjecucionBs,
    inf.SaldoCantigadoBs                        AS InfocredSaldoCastigadoBs,
    inf.SaldoContingenteBs                      AS InfocredSaldoContingenteBs,
    DATEDIFF(MONTH, car.FechaCorte, inf.MaximaFechaVencimiento)
                                                  AS InfocredMesesHastaMaxVencimiento,
    inf.MontoDeudaTotalBs                       AS InfocredMontoDeudaTotalBs,
    inf.CuotaBs                                 AS InfocredCuotaBs,
    inf.CantidadDeudasOtrasEntidades            AS InfocredCantDeudasOtrasEntidades,
    inf.CantidadDeudasDeudor                    AS InfocredCantDeudasDeudor,
    inf.CantidadDeudasCodeudor                  AS InfocredCantDeudasCodeudor,
    inf.EsCreditoVivienda                       AS InfocredEsCreditoVivienda,

    -- Productos y canales
    car.Productocartera                         AS ProductoCartera,
    cli.EsDeudorcartera                         AS EsDeudorCartera,
    cli.EsCodeudorcartera                       AS EsCodeudorCartera,
    cli.EsGarantecartera                        AS EsGaranteCartera,
    cli.EsClienteActivoDigital                  AS EsClienteDigital,
    cli.EsclienteTinka                          AS EsClienteTinka,

    -- Caracteristicas del credito
    car.CodigoOficialCredito                    AS CodigoOficialCredito,
    car.NombreOficialCredito                    AS NombreOficialCredito,
    car.TipoCredito                             AS TipoCredito,
    car.TipoBanca                               AS TipoBanca,
    car.TasaEfectiva                            AS TasaEfectivaCredito,
    car.TasaBase                                AS TasaBaseCredito,
    car.TasaTRE                                 AS TasaTRECredito,
    car.PlazoDias                               AS PlazoCreditoDias,
    car.PlazoMeses                              AS PlazoCreditoMeses,
    car.FrecuenciaPago                          AS FrecuenciaPagoCredito,
    car.TipoAmortizacion                        AS TipoAmortizacion,
    car.CantidadReprogramaciones                AS CantidadReprogramaciones,
    car.MontoReprogramadoBs                     AS MontoReprogramadoBs,
    car.EstadoCredito                           AS EstadoCredito,
    car.LineaCredito                            AS LineaCredito,
    car.MontoLineaCreditoBs                     AS MontoLineaCreditoBs,

    -- Actividad economica
    car.SectorEconomicoCliente                  AS SectorEconomicoCliente,
    car.SectorEconomicoCredito                  AS SectorEconomicoCredito,
    car.ActividadEconomicaCliente               AS ActividadEconomicaCliente,
    car.ActividadEconomicaCredito               AS ActividadEconomicaCredito,
    car.ActividadEconomicaClienteCAEDEC         AS ActividadEconomicaClienteCAEDEC,
    car.ActividadEconomicaCreditoCAEDEC         AS ActividadEconomicaCreditoCAEDEC,
    car.Nrotrabajadores                         AS NumeroTrabajadores,
    car.IndiceActividad                         AS IndiceActividadEconomica,
    car.TamanioEmpresa                          AS TamanioEmpresa,

    -- Endeudamiento y garantias
    car.SaldoBs                                 AS SaldoCreditoBs,
    car.SaldoCapitalBs                          AS SaldoCapitalBs,
    car.SaldoDiferidoBs                         AS SaldoDiferidoBs,
    car.InteresBs                               AS InteresBs,
    car.OtrosRubrosBs                           AS OtrosRubrosBs,
    car.MontoDesembolsadoBs                     AS MontoDesembolsadoBs,
    car.GarantiaHipotecaria                     AS GarantiaHipotecariaBs,
    car.GarantiaPersonal                        AS GarantiaPersonalBs,
    car.GarantiaPrendaria                       AS GarantiaPrendariaBs,
    car.GarantiaCaptacion                       AS GarantiaCaptacionBs,
    car.GarantiaOtros                           AS GarantiaOtrosBs,
    car.GarantiaDocumentosCustodia              AS GarantiaDocumentosCustodiaBs,
    car.MontoGarantiaBs                         AS MontoGarantiaTotalBs,
    car.PrevisionRequeridaBs                    AS PrevisionRequeridaBs,
    car.PrevisionCiclicaBs                      AS PrevisionCiclicaBs,

    -- Fechas del credito
    DATEDIFF(MONTH, car.FechaCorte, car.FechaVencimiento)
                                                  AS MesesHastaVencimientoCredito,
    car.FechaVencimiento                        AS FechaVencimiento,
    DATEDIFF(MONTH, car.FechaCorte, car.FechaVencimientoReprogramada)
                                                  AS MesesHastaVencimientoReprogramado,
    car.FechaVencimientoReprogramada            AS FechaVencimientoReprogramada,
    DATEDIFF(MONTH, car.FechaCorte, car.FechaRefinanciamiento)
                                                  AS MesesDiferenciaRefinanciamiento,
    car.FechaRefinanciamiento                   AS FechaRefinanciamiento,
    DATEDIFF(DAY, car.FechaCorte, car.FechaProximoPago)
                                                  AS DiasHastaProximoPago,
    car.FechaProximoPago                        AS FechaProximoPago,

    -- Eventos
    eve.Evento                                  AS Evento,
    eve.DuracionDias                            AS EventoDuracionDias,
    eve.CodigoRegional                          AS EventoCodigoRegional,
    eve.CodigoDepartamento                      AS EventoCodigoDepartamento,
    eve.Descripcion                             AS EventoDescripcion,
    ISNULL(eve.CantidadEventos, 0)               AS CantidadEventos,

    -- Comportamiento de pago
    car.MaxDiasMoraMes                          AS MaxDiasMoraMes,
    car.MaxDiasMora3M                           AS MaxDiasMora3M,
    car.PromedioMora3M                          AS PromedioMora3M,
    car.MesesConMora3M                          AS MesesConMora3M,
    car.MaxDiasMora6M                           AS MaxDiasMora6M,
    car.PromedioMora6M                          AS PromedioMora6M,
    car.MesesConMora6M                          AS MesesConMora6M,
    car.MaxDiasMora12M                          AS MaxDiasMora12M,
    car.PromedioMora12M                         AS PromedioMora12M,
    car.MesesConMora12M                         AS MesesConMora12M,
    car.TasaCumplimiento                        AS TasaCumplimiento,
    car.AntiguedadCreditoMeses                  AS AntiguedadCreditoMeses,
    car.CalificacionFIE                         AS CalificacionFIE,
    car.CalificacionASFI                        AS CalificacionASFI,

    -- Comportamiento transaccional del mes
    tra.CantidadTrx                             AS CantidadTrx,
    tra.MontoTotalBs                            AS MontoTotalTrxBs,
    tra.CantidadDepositos                       AS CantidadDepositos,
    tra.CantidadRetiros                         AS CantidadRetiros,
    tra.MontoDepositosBs                        AS MontoDepositosBs,
    tra.MontoRetirosBs                          AS MontoRetirosBs,
    tra.FlujoNetoBs                             AS FlujoNetoBs,
    tra.CantidadQR                              AS CantidadQR,
    tra.CantidadDigital                         AS CantidadDigital,
    tra.CantidadPresencial                      AS CantidadPresencial,
    tra.CantidadAutoservicio                    AS CantidadAutoservicio,
    tra.CantidadProcesamiento                   AS CantidadProcesamiento,
    tra.MontoQR                                 AS MontoQRBs,
    tra.MontoDigital                            AS MontoDigitalBs,
    tra.MontoPresencial                         AS MontoPresencialBs,
    tra.MontoAutoservicio                       AS MontoAutoservicioBs,
    tra.MontoProcesamiento                      AS MontoProcesamientoBs,

    -- Historico transaccional de 3 meses
    trh.CantidadTrx_3M                          AS CantidadTrx3M,
    trh.MontoTotalBs_3M                         AS MontoTotalBs3M,
    trh.CantidadDepositos_3M                    AS CantidadDepositos3M,
    trh.CantidadRetiros_3M                      AS CantidadRetiros3M,
    trh.MontoDepositosBs_3M                     AS MontoDepositosBs3M,
    trh.MontoRetirosBs_3M                       AS MontoRetirosBs3M,

    -- Historico transaccional de 6 meses
    trh.CantidadTrx_6M                          AS CantidadTrx6M,
    trh.MontoTotalBs_6M                         AS MontoTotalBs6M,
    trh.CantidadDepositos_6M                    AS CantidadDepositos6M,
    trh.CantidadRetiros_6M                      AS CantidadRetiros6M,
    trh.MontoDepositosBs_6M                     AS MontoDepositosBs6M,
    trh.MontoRetirosBs_6M                       AS MontoRetirosBs6M,

    -- Historico transaccional de 12 meses
    trh.CantidadTrx_12M                         AS CantidadTrx12M,
    trh.MontoTotalBs_12M                        AS MontoTotalBs12M,
    trh.CantidadDepositos_12M                   AS CantidadDepositos12M,
    trh.CantidadRetiros_12M                     AS CantidadRetiros12M,
    trh.MontoDepositosBs_12M                    AS MontoDepositosBs12M,
    trh.MontoRetirosBs_12M                      AS MontoRetirosBs12M,
    trh.MesesConHistoria                        AS MesesConHistoria,

    -- Indicadores de cobertura de los JOIN
    CONVERT(BIT, CASE WHEN tra.ClienteKey IS NULL THEN 0 ELSE 1 END)
                                                  AS TieneTransaccionesMes,
    CONVERT(BIT, CASE WHEN trh.ClienteKey IS NULL THEN 0 ELSE 1 END)
                                                  AS TieneHistoricoTransaccional,
    CONVERT(BIT, CASE WHEN inf.ClienteKey IS NULL THEN 0 ELSE 1 END)
                                                  AS TieneInfocred,
    CONVERT(BIT, CASE WHEN eve.FechaCorte IS NULL THEN 0 ELSE 1 END)
                                                  AS TieneEvento
FROM CarteraBase car
INNER JOIN ClienteUnico cli
        ON cli.ClienteKey = car.ClienteKey
       AND cli.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.TransaccionesMensuales tra
       ON tra.ClienteKey = car.ClienteKey
      AND tra.Fecha = car.FechaCorte
LEFT JOIN HistoricoTransaccional trh
       ON trh.ClienteKey = car.ClienteKey
      AND trh.FechaCorte = car.FechaCorte
LEFT JOIN Inteligencia_Comercial.dbo.clienteinfocred inf
       ON inf.ClienteKey = car.ClienteKey
      AND inf.FechaKey = CONVERT(INT, CONVERT(CHAR(8), car.FechaCorte, 112))
LEFT JOIN EventosMes eve
       ON eve.FechaCorte = car.FechaCorte
      AND eve.CodigoRegional = car.CodigoRegional
);
GO



/* ==================== 02. CONSULTAS DE ANALISIS ==================== */
/*
    ANALISIS COMPLETO DEL DATASET POR RANGO DE FECHAS

    Requisito:
      - Ejecutar primero 01-consulta-dataset-inner-join.sql para crear
        dbo.fn_DatasetCarteraAnalisis.

    Como elegir el rango:
      - Un mes: FechaInicio y FechaFin deben pertenecer al mismo mes.
      - Tres meses: por ejemplo, FechaInicio = 2026-06-01 y
        FechaFin = 2026-08-01.
      - N meses: colocar el primer y el ultimo mes que se desea revisar.

    Las fechas se convierten automaticamente al ultimo dia del mes.
    Cada seccion devuelve un resultado separado para facilitar su lectura.
*/

SET NOCOUNT ON;


/*==============================================================
  1. RANGO QUE SE DESEA ANALIZAR
==============================================================*/

DECLARE @FechaInicio DATE = DATEFROMPARTS(2026, 8, 1);
DECLARE @FechaFin    DATE = DATEFROMPARTS(2026, 8, 1);

SET @FechaInicio = EOMONTH(@FechaInicio);
SET @FechaFin = EOMONTH(@FechaFin);

IF @FechaInicio > @FechaFin
    THROW 50001, 'FechaInicio no puede ser mayor que FechaFin.', 1;

IF OBJECT_ID
   (
       'Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis',
       'IF'
   ) IS NULL
    THROW 50002, 'No existe dbo.fn_DatasetCarteraAnalisis. Ejecute primero el archivo 01.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
    THROW 50003, 'No existen registros dentro del rango seleccionado.', 1;


/*==============================================================
  2. ESTRUCTURA DEL DATASET

  Muestra las columnas y sus tipos. Sirve para confirmar que una
  variable es numerica, texto o fecha antes de transformarla.
==============================================================*/

SELECT
    c.column_id AS OrdenColumna,
    c.name AS Columna,
    t.name AS TipoDato,
    c.max_length AS LongitudMaxima,
    c.precision AS PrecisionNumerica,
    c.scale AS Decimales,
    c.is_nullable AS PermiteNulos
FROM Inteligencia_Comercial.sys.columns c
INNER JOIN Inteligencia_Comercial.sys.types t
        ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID
      (
          'Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis',
          'IF'
      )
ORDER BY c.column_id;


/*==============================================================
  3. COBERTURA DEL RANGO

  Confirma cuantos meses se solicitaron y cuantos realmente existen.
  Si MesesConDatos es menor que MesesSolicitados, falta algun corte.
==============================================================*/

SELECT
    @FechaInicio AS FechaInicioSolicitada,
    @FechaFin AS FechaFinSolicitada,
    DATEDIFF(MONTH, @FechaInicio, @FechaFin) + 1 AS MesesSolicitados,
    COUNT_BIG(DISTINCT FechaCorte) AS MesesConDatos,
    MIN(FechaCorte) AS PrimerMesDisponible,
    MAX(FechaCorte) AS UltimoMesDisponible,
    COUNT_BIG(*) AS TotalFilas,
    COUNT_BIG(DISTINCT CarteraKey) AS CarterasDiferentes,
    COUNT_BIG(DISTINCT ClienteKey) AS ClientesDiferentes
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin;

-- Detalla que meses tienen datos y cuales faltan dentro del rango.
;WITH MesesEsperados AS
(
    SELECT @FechaInicio AS FechaCorte

    UNION ALL

    SELECT EOMONTH(DATEADD(MONTH, 1, FechaCorte))
    FROM MesesEsperados
    WHERE FechaCorte < @FechaFin
)
SELECT
    m.FechaCorte,
    COUNT_BIG(d.FechaCorte) AS FilasEncontradas,
    CASE WHEN COUNT_BIG(d.FechaCorte) = 0 THEN 'FALTA EL MES' ELSE 'OK' END AS Estado
FROM MesesEsperados m
LEFT JOIN Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
       ON d.FechaCorte = m.FechaCorte
GROUP BY m.FechaCorte
ORDER BY m.FechaCorte
OPTION (MAXRECURSION 0);


/*==============================================================
  4. VOLUMEN POR MES

  Permite detectar aumentos o disminuciones inesperadas de registros.
  FilasAdicionales debe ser cero si se espera una fila por cartera y mes.
==============================================================*/

SELECT
    FechaCorte,
    COUNT_BIG(*) AS TotalFilas,
    COUNT_BIG(DISTINCT CarteraKey) AS CarterasDiferentes,
    COUNT_BIG(DISTINCT ClienteKey) AS ClientesDiferentes,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT CarteraKey) AS FilasAdicionales
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  5. REGISTROS DUPLICADOS

  Muestra las carteras que aparecen mas de una vez en el mismo mes.
  Antes de eliminar duplicados se debe identificar que JOIN los produjo.
==============================================================*/

SELECT TOP (200)
    FechaCorte,
    CarteraKey,
    COUNT_BIG(*) AS CantidadFilas
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, CarteraKey
HAVING COUNT_BIG(*) > 1
ORDER BY CantidadFilas DESC, FechaCorte, CarteraKey;


/*==============================================================
  6. VALORES NULOS DE TODAS LAS COLUMNAS

  Devuelve cantidad y porcentaje de nulos para cada variable durante
  todo el rango. El bloque se genera automaticamente porque el dataset
  contiene muchas columnas. No es necesario modificar esta seccion.
==============================================================*/

DECLARE @SumaNulos NVARCHAR(MAX) = N'';
DECLARE @ListaNulos NVARCHAR(MAX) = N'';
DECLARE @SqlNulos NVARCHAR(MAX);

SELECT
    @SumaNulos = @SumaNulos
        + N', SUM(CASE WHEN ' + QUOTENAME(c.name)
        + N' IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS '
        + QUOTENAME(c.name),
    @ListaNulos = @ListaNulos
        + CASE WHEN @ListaNulos = N'' THEN N'' ELSE N',' END
        + N'(N''' + REPLACE(c.name, '''', '''''') + N''', a.' + QUOTENAME(c.name) + N')'
FROM Inteligencia_Comercial.sys.columns c
WHERE c.object_id = OBJECT_ID
      (
          'Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis',
          'IF'
      )
ORDER BY c.column_id;

SET @SqlNulos = N'
    SELECT
        v.Columna,
        a.TotalFilas,
        v.ValoresNulos,
        CONVERT
        (
            DECIMAL(6,2),
            100.0 * v.ValoresNulos / NULLIF(a.TotalFilas, 0)
        ) AS PorcentajeNulos
    FROM
    (
        SELECT COUNT_BIG(*) AS TotalFilas' + @SumaNulos + N'
        FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@pFechaInicio, @pFechaFin)
        WHERE FechaCorte BETWEEN @pFechaInicio AND @pFechaFin
    ) a
    CROSS APPLY (VALUES ' + @ListaNulos + N') v(Columna, ValoresNulos)
    ORDER BY PorcentajeNulos DESC, v.Columna;';

EXEC sys.sp_executesql
    @SqlNulos,
    N'@pFechaInicio DATE, @pFechaFin DATE',
    @pFechaInicio = @FechaInicio,
    @pFechaFin = @FechaFin;


/*==============================================================
  7. NULOS IMPORTANTES POR MES

  Ayuda a descubrir si la calidad de datos empeoro en un mes concreto.
  El resultado muestra porcentajes; 100 significa totalmente nulo.
==============================================================*/

SELECT
    FechaCorte,
    COUNT_BIG(*) AS TotalFilas,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN EdadCliente IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloEdad,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN GeneroCliente IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloGenero,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN NivelIngresoCliente IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloNivelIngreso,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN SaldoCreditoBs IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloSaldo,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN MaxDiasMora12M IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloMora12M,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN CantidadTrx IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloTransacciones,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN InfocredMontoDeudaTotalBs IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloInfocred,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CASE WHEN Evento IS NULL THEN 1.0 ELSE 0.0 END))
        AS PorcentajeNuloEvento
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  8. COBERTURA DE LAS FUENTES

  Indica que porcentaje del dataset encontro informacion en cada JOIN.
  No tener evento puede ser normal; no significa necesariamente error.
==============================================================*/

SELECT
    FechaCorte,
    COUNT_BIG(*) AS TotalFilas,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CONVERT(FLOAT, TieneTransaccionesMes)))
        AS PorcentajeConTransacciones,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CONVERT(FLOAT, TieneHistoricoTransaccional)))
        AS PorcentajeConHistorico,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CONVERT(FLOAT, TieneInfocred)))
        AS PorcentajeConInfocred,
    CONVERT(DECIMAL(6,2), 100.0 * AVG(CONVERT(FLOAT, TieneEvento)))
        AS PorcentajeConEvento
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  9. RESUMEN NUMERICO POR MES

  Compara minimo, promedio y maximo de las principales variables.
  Cambios fuertes entre meses pueden indicar datos atipicos o cambios
  en la poblacion analizada.
==============================================================*/

SELECT
    FechaCorte,
    MIN(EdadCliente) AS EdadMinima,
    AVG(CONVERT(FLOAT, EdadCliente)) AS EdadPromedio,
    MAX(EdadCliente) AS EdadMaxima,
    MIN(SaldoCreditoBs) AS SaldoMinimo,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedio,
    MAX(SaldoCreditoBs) AS SaldoMaximo,
    MIN(MontoDesembolsadoBs) AS DesembolsoMinimo,
    AVG(CONVERT(FLOAT, MontoDesembolsadoBs)) AS DesembolsoPromedio,
    MAX(MontoDesembolsadoBs) AS DesembolsoMaximo,
    MIN(MaxDiasMora12M) AS Mora12MMinima,
    AVG(CONVERT(FLOAT, MaxDiasMora12M)) AS Mora12MPromedio,
    MAX(MaxDiasMora12M) AS Mora12MMaxima,
    MIN(CantidadTrx) AS TransaccionesMinimas,
    AVG(CONVERT(FLOAT, CantidadTrx)) AS TransaccionesPromedio,
    MAX(CantidadTrx) AS TransaccionesMaximas
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  10. MEDIANA Y VALORES ALTOS

  P50 es la mediana. P95 y P99 ayudan a detectar montos extremos sin
  dejar que un valor muy grande distorsione el promedio.
  Esta consulta puede tardar mas porque debe ordenar los valores.
==============================================================*/

SELECT DISTINCT
    FechaCorte,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, SaldoCreditoBs))
        OVER (PARTITION BY FechaCorte) AS SaldoP50,
    PERCENTILE_CONT(0.95) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, SaldoCreditoBs))
        OVER (PARTITION BY FechaCorte) AS SaldoP95,
    PERCENTILE_CONT(0.99) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, SaldoCreditoBs))
        OVER (PARTITION BY FechaCorte) AS SaldoP99,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, MontoDesembolsadoBs))
        OVER (PARTITION BY FechaCorte) AS DesembolsoP50,
    PERCENTILE_CONT(0.95) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, MontoDesembolsadoBs))
        OVER (PARTITION BY FechaCorte) AS DesembolsoP95,
    PERCENTILE_CONT(0.99) WITHIN GROUP
        (ORDER BY CONVERT(FLOAT, MontoDesembolsadoBs))
        OVER (PARTITION BY FechaCorte) AS DesembolsoP99
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
ORDER BY FechaCorte;


/*==============================================================
  11. DISTRIBUCION DE GENERO

  Revisa cantidad y porcentaje por categoria para cada mes.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), GeneroCliente), N'<NULO>') AS Genero,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), GeneroCliente), N'<NULO>')
ORDER BY FechaCorte, Cantidad DESC;


/*==============================================================
  12. DISTRIBUCION GEOGRAFICA

  Permite detectar concentracion y cambios por departamento.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), DepartamentoCliente), N'<NULO>') AS Departamento,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), DepartamentoCliente), N'<NULO>')
ORDER BY FechaCorte, Cantidad DESC;


/*==============================================================
  13. DISTRIBUCION DE SEGMENTOS

  Revisa si la composicion comercial cambia entre meses.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), SegmentoCliente), N'<NULO>') AS Segmento,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), SegmentoCliente), N'<NULO>')
ORDER BY FechaCorte, Cantidad DESC;


/*==============================================================
  14. DISTRIBUCION DE TIPOS DE CREDITO

  Ayuda a comprobar que el conjunto conserve una mezcla similar de
  productos durante el periodo estudiado.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), TipoCredito), N'<NULO>') AS TipoCredito,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), TipoCredito), N'<NULO>')
ORDER BY FechaCorte, Cantidad DESC;


/*==============================================================
  15. DISTRIBUCION DE CALIFICACIONES

  Sirve para observar el perfil de riesgo y su cambio mensual.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(100), CalificacionFIE), N'<NULO>') AS CalificacionFIE,
    COALESCE(CONVERT(NVARCHAR(100), CalificacionASFI), N'<NULO>') AS CalificacionASFI,
    COUNT_BIG(*) AS Cantidad
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(100), CalificacionFIE), N'<NULO>'),
    COALESCE(CONVERT(NVARCHAR(100), CalificacionASFI), N'<NULO>')
ORDER BY FechaCorte, Cantidad DESC;


/*==============================================================
  16. CANTIDAD DE VALORES DIFERENTES

  Una variable con un solo valor no aporta separacion al analisis.
  Una variable con demasiados valores puede necesitar agrupacion.
==============================================================*/

SELECT
    COUNT_BIG(DISTINCT GeneroCliente) AS ValoresGenero,
    COUNT_BIG(DISTINCT EstadoCivilCliente) AS ValoresEstadoCivil,
    COUNT_BIG(DISTINCT DepartamentoCliente) AS ValoresDepartamento,
    COUNT_BIG(DISTINCT CiudadCliente) AS ValoresCiudad,
    COUNT_BIG(DISTINCT BarrioCliente) AS ValoresBarrio,
    COUNT_BIG(DISTINCT SegmentoCliente) AS ValoresSegmento,
    COUNT_BIG(DISTINCT ProfesionCliente) AS ValoresProfesion,
    COUNT_BIG(DISTINCT TipoCredito) AS ValoresTipoCredito,
    COUNT_BIG(DISTINCT ActividadEconomicaClienteCAEDEC) AS ValoresActividadCliente,
    COUNT_BIG(DISTINCT ActividadEconomicaCreditoCAEDEC) AS ValoresActividadCredito,
    COUNT_BIG(DISTINCT CodigoOficialCredito) AS ValoresOficialCredito
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin;


/*==============================================================
  17. POSIBLES VALORES FUERA DE RANGO

  No elimina registros. Cuenta casos que deben ser revisados con las
  reglas del negocio antes de corregirlos.
==============================================================*/

SELECT
    FechaCorte,
    SUM(CASE WHEN CarteraKey IS NULL THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS CarteraKeyNulo,
    SUM(CASE WHEN ClienteKey IS NULL THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS ClienteKeyNulo,
    SUM(CASE WHEN EdadCliente < 0 OR EdadCliente > 110 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS EdadFueraDeRango,
    SUM(CASE WHEN NumeroHijosCliente < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS NumeroHijosNegativo,
    SUM(CASE WHEN PlazoCreditoDias < 0 OR PlazoCreditoMeses < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS PlazoNegativo,
    SUM(CASE WHEN TasaEfectivaCredito < 0 OR TasaBaseCredito < 0 OR TasaTRECredito < 0
             THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS TasaNegativa,
    SUM(CASE WHEN SaldoCreditoBs < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS SaldoNegativo,
    SUM(CASE WHEN MontoDesembolsadoBs < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS DesembolsoNegativo,
    SUM(CASE WHEN MontoGarantiaTotalBs < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS GarantiaNegativa,
    SUM(CASE WHEN CantidadTrx < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS CantidadTransaccionesNegativa,
    SUM(CASE WHEN MaxDiasMora12M < 0 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS MoraNegativa
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  18. CONSISTENCIA DE FECHAS

  Busca fechas que pueden contradecir el estado vigente del credito.
  Una fecha de proximo pago anterior al corte puede representar mora;
  por eso se marca para revision y no como error definitivo.
==============================================================*/

SELECT
    FechaCorte,
    SUM
    (
        CASE
            WHEN FechaVencimiento IS NOT NULL
             AND FechaVencimiento < FechaCorte
             AND EstadoCredito = 'VIGENTE'
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS VigenteConFechaVencida,
    SUM
    (
        CASE
            WHEN FechaProximoPago IS NOT NULL
             AND FechaProximoPago < FechaCorte
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS ProximoPagoAnteriorAlCorte,
    SUM
    (
        CASE
            WHEN FechaVencimientoReprogramada IS NOT NULL
             AND FechaVencimientoReprogramada < FechaCorte
             AND EstadoCredito = 'VIGENTE'
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS ReprogramadoConFechaVencida
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  19. COHERENCIA TRANSACCIONAL

  Compara el total de transacciones con la suma de canales. Solo revisa
  filas donde todos los conteos necesarios tienen informacion.
==============================================================*/

SELECT
    FechaCorte,
    SUM
    (
        CASE
            WHEN CantidadTrx IS NOT NULL
             AND CantidadDigital IS NOT NULL
             AND CantidadPresencial IS NOT NULL
             AND CantidadAutoservicio IS NOT NULL
             AND CantidadProcesamiento IS NOT NULL
             AND CantidadTrx <
                 CantidadDigital + CantidadPresencial
                 + CantidadAutoservicio + CantidadProcesamiento
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS CanalesMayoresAlTotal,
    SUM
    (
        CASE
            WHEN CantidadTrx IS NOT NULL
             AND CantidadDepositos IS NOT NULL
             AND CantidadRetiros IS NOT NULL
             AND CantidadDepositos + CantidadRetiros > CantidadTrx
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS DepositosYRetirosMayoresAlTotal
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  20. PERMANENCIA DE CLIENTES EN EL RANGO

  Muestra cuantos clientes aparecen en uno, dos, tres o mas meses.
  Es util para conocer si el dataset es una foto mensual o un panel.
==============================================================*/

;WITH MesesPorCliente AS
(
    SELECT
        ClienteKey,
        COUNT_BIG(DISTINCT FechaCorte) AS MesesConDatos
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY ClienteKey
)
SELECT
    MesesConDatos,
    COUNT_BIG(*) AS CantidadClientes
FROM MesesPorCliente
GROUP BY MesesConDatos
ORDER BY MesesConDatos;


/*==============================================================
  21. PLANTILLA PARA LA VARIABLE OBJETIVO

  Cuando se defina la variable que el modelo debe predecir, reemplazar
  VariableObjetivo por su nombre y ejecutar la consulta por separado.
  Se deja comentada para que el archivo funcione sin conocer el objetivo.
==============================================================*/

/*
SELECT
    FechaCorte,
    VariableObjetivo,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, VariableObjetivo
ORDER BY FechaCorte, VariableObjetivo;
*/


/*==============================================================
  22. RESUMEN MENSUAL PARA EXCEL

  Una fila por mes con los principales indicadores. Se puede usar
  directamente para graficos de lineas y tarjetas de seguimiento.
==============================================================*/

SELECT
    FechaCorte,
    COUNT_BIG(DISTINCT CarteraKey) AS TotalCarteras,
    COUNT_BIG(DISTINCT ClienteKey) AS TotalClientes,
    SUM(CONVERT(DECIMAL(38,2), SaldoCreditoBs)) AS SaldoTotalBs,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    SUM(CONVERT(DECIMAL(38,2), MontoDesembolsadoBs)) AS DesembolsoTotalBs,
    AVG(CONVERT(FLOAT, MontoDesembolsadoBs)) AS DesembolsoPromedioBs,
    AVG(CONVERT(FLOAT, MaxDiasMora12M)) AS Mora12MPromedio,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 0 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeConMora,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN CantidadTrx > 0 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN CantidadTrx IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeConTransacciones,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN EsClienteDigital = 1 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN EsClienteDigital IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeClientesDigitales,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN CantidadReprogramaciones > 0 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN CantidadReprogramaciones IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeReprogramados
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  23. TENDENCIA DE NULOS PARA EXCEL

  Formato vertical: fecha, variable y porcentaje. Es apropiado para
  un grafico de lineas con una linea por variable.
==============================================================*/

SELECT
    d.FechaCorte,
    n.Variable,
    COUNT_BIG(*) AS TotalFilas,
    SUM(CONVERT(BIGINT, n.EsNulo)) AS ValoresNulos,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CONVERT(BIGINT, n.EsNulo)) / NULLIF(COUNT_BIG(*), 0)
    ) AS PorcentajeNulos
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
CROSS APPLY
(
    VALUES
        (N'EdadCliente', CASE WHEN d.EdadCliente IS NULL THEN 1 ELSE 0 END),
        (N'GeneroCliente', CASE WHEN d.GeneroCliente IS NULL THEN 1 ELSE 0 END),
        (N'NivelIngresoCliente', CASE WHEN d.NivelIngresoCliente IS NULL THEN 1 ELSE 0 END),
        (N'PatrimonioClienteBs', CASE WHEN d.PatrimonioClienteBs IS NULL THEN 1 ELSE 0 END),
        (N'SaldoCreditoBs', CASE WHEN d.SaldoCreditoBs IS NULL THEN 1 ELSE 0 END),
        (N'MaxDiasMora12M', CASE WHEN d.MaxDiasMora12M IS NULL THEN 1 ELSE 0 END),
        (N'CantidadTrx', CASE WHEN d.CantidadTrx IS NULL THEN 1 ELSE 0 END),
        (N'InfocredMontoDeudaTotalBs', CASE WHEN d.InfocredMontoDeudaTotalBs IS NULL THEN 1 ELSE 0 END),
        (N'CalificacionFIE', CASE WHEN d.CalificacionFIE IS NULL THEN 1 ELSE 0 END),
        (N'CalificacionASFI', CASE WHEN d.CalificacionASFI IS NULL THEN 1 ELSE 0 END)
) n(Variable, EsNulo)
WHERE d.FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY d.FechaCorte, n.Variable
ORDER BY n.Variable, d.FechaCorte;


/*==============================================================
  24. BANDAS DE MORA

  Permite crear un grafico de columnas apiladas y observar si aumenta
  o disminuye la proporcion de clientes con mayor mora.
==============================================================*/

;WITH BaseMora AS
(
    SELECT
        FechaCorte,
        CASE
            WHEN MaxDiasMora12M IS NULL THEN N'SIN DATO'
            WHEN MaxDiasMora12M = 0 THEN N'0 DIAS'
            WHEN MaxDiasMora12M <= 30 THEN N'1 A 30 DIAS'
            WHEN MaxDiasMora12M <= 60 THEN N'31 A 60 DIAS'
            WHEN MaxDiasMora12M <= 90 THEN N'61 A 90 DIAS'
            ELSE N'MAS DE 90 DIAS'
        END AS BandaMora,
        CASE
            WHEN MaxDiasMora12M IS NULL THEN 6
            WHEN MaxDiasMora12M = 0 THEN 1
            WHEN MaxDiasMora12M <= 30 THEN 2
            WHEN MaxDiasMora12M <= 60 THEN 3
            WHEN MaxDiasMora12M <= 90 THEN 4
            ELSE 5
        END AS OrdenBanda
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
SELECT
    FechaCorte,
    BandaMora,
    COUNT_BIG(*) AS Cantidad,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS Porcentaje
FROM BaseMora
GROUP BY FechaCorte, BandaMora, OrdenBanda
ORDER BY FechaCorte, OrdenBanda;


/*==============================================================
  25. MORA MAYOR A 30 DIAS POR SEGMENTO

  La mora se usa como indicador descriptivo. Para el modelo, la
  variable objetivo debe calcularse en un periodo futuro.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), SegmentoCliente), N'<NULO>') AS Segmento,
    COUNT_BIG(*) AS CantidadCarteras,
    SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS CarterasConDatoMora,
    SUM(CASE WHEN MaxDiasMora12M > 30 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS CarterasMoraMayor30,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), SegmentoCliente), N'<NULO>')
ORDER BY FechaCorte, PorcentajeMoraMayor30 DESC;


/*==============================================================
  26. MORA MAYOR A 30 DIAS POR DEPARTAMENTO

  Sirve para comparar zonas en un grafico de barras o mapa.
==============================================================*/

SELECT
    FechaCorte,
    COALESCE(CONVERT(NVARCHAR(200), DepartamentoCliente), N'<NULO>') AS Departamento,
    COUNT_BIG(*) AS CantidadCarteras,
    SUM(CASE WHEN MaxDiasMora12M > 30 THEN CONVERT(BIGINT, 1) ELSE 0 END)
        AS CarterasMoraMayor30,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY FechaCorte, COALESCE(CONVERT(NVARCHAR(200), DepartamentoCliente), N'<NULO>')
ORDER BY FechaCorte, PorcentajeMoraMayor30 DESC;


/*==============================================================
  27. MORA POR RANGO DE EDAD

  Agrupa edades para evitar graficos con demasiadas categorias.
==============================================================*/

;WITH EdadAgrupada AS
(
    SELECT
        FechaCorte,
        SaldoCreditoBs,
        MaxDiasMora12M,
        CASE
            WHEN EdadCliente IS NULL THEN N'SIN DATO'
            WHEN EdadCliente < 25 THEN N'MENOR A 25'
            WHEN EdadCliente <= 34 THEN N'25 A 34'
            WHEN EdadCliente <= 44 THEN N'35 A 44'
            WHEN EdadCliente <= 54 THEN N'45 A 54'
            WHEN EdadCliente <= 64 THEN N'55 A 64'
            ELSE N'65 O MAS'
        END AS RangoEdad,
        CASE
            WHEN EdadCliente IS NULL THEN 7
            WHEN EdadCliente < 25 THEN 1
            WHEN EdadCliente <= 34 THEN 2
            WHEN EdadCliente <= 44 THEN 3
            WHEN EdadCliente <= 54 THEN 4
            WHEN EdadCliente <= 64 THEN 5
            ELSE 6
        END AS OrdenEdad
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
SELECT
    FechaCorte,
    RangoEdad,
    COUNT_BIG(*) AS CantidadCarteras,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM EdadAgrupada
GROUP BY FechaCorte, RangoEdad, OrdenEdad
ORDER BY FechaCorte, OrdenEdad;


/*==============================================================
  28. DISTRIBUCION POR RANGO DE SALDO

  Se puede usar como histograma. Los limites estan expresados en Bs
  y pueden ajustarse a los rangos utilizados por el negocio.
==============================================================*/

;WITH SaldoAgrupado AS
(
    SELECT
        FechaCorte,
        MaxDiasMora12M,
        CASE
            WHEN SaldoCreditoBs IS NULL THEN N'SIN DATO'
            WHEN SaldoCreditoBs <= 0 THEN N'0 O MENOR'
            WHEN SaldoCreditoBs <= 1000 THEN N'1 A 1.000'
            WHEN SaldoCreditoBs <= 5000 THEN N'1.001 A 5.000'
            WHEN SaldoCreditoBs <= 10000 THEN N'5.001 A 10.000'
            WHEN SaldoCreditoBs <= 50000 THEN N'10.001 A 50.000'
            ELSE N'MAS DE 50.000'
        END AS RangoSaldo,
        CASE
            WHEN SaldoCreditoBs IS NULL THEN 7
            WHEN SaldoCreditoBs <= 0 THEN 1
            WHEN SaldoCreditoBs <= 1000 THEN 2
            WHEN SaldoCreditoBs <= 5000 THEN 3
            WHEN SaldoCreditoBs <= 10000 THEN 4
            WHEN SaldoCreditoBs <= 50000 THEN 5
            ELSE 6
        END AS OrdenSaldo
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
SELECT
    FechaCorte,
    RangoSaldo,
    COUNT_BIG(*) AS CantidadCarteras,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS PorcentajeCarteras,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM SaldoAgrupado
GROUP BY FechaCorte, RangoSaldo, OrdenSaldo
ORDER BY FechaCorte, OrdenSaldo;


/*==============================================================
  29. USO DE CANALES

  Formato vertical para graficar cantidad y monto por canal. QR puede
  formar parte de Digital, por lo que no debe sumarse dos veces.
==============================================================*/

SELECT
    d.FechaCorte,
    c.Canal,
    SUM(CONVERT(DECIMAL(38,2), c.Cantidad)) AS CantidadTransacciones,
    SUM(CONVERT(DECIMAL(38,2), c.Monto)) AS MontoTotalBs
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
CROSS APPLY
(
    VALUES
        (N'QR', d.CantidadQR, d.MontoQRBs),
        (N'DIGITAL', d.CantidadDigital, d.MontoDigitalBs),
        (N'PRESENCIAL', d.CantidadPresencial, d.MontoPresencialBs),
        (N'AUTOSERVICIO', d.CantidadAutoservicio, d.MontoAutoservicioBs),
        (N'PROCESAMIENTO', d.CantidadProcesamiento, d.MontoProcesamientoBs)
) c(Canal, Cantidad, Monto)
WHERE d.FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY d.FechaCorte, c.Canal
ORDER BY d.FechaCorte, c.Canal;


/*==============================================================
  30. DECILES DE SALDO

  Divide cada mes en diez grupos de igual cantidad. Ayuda a comparar
  concentracion, montos y mora sin elegir limites manuales.
==============================================================*/

;WITH BaseDeciles AS
(
    SELECT
        FechaCorte,
        SaldoCreditoBs,
        MaxDiasMora12M,
        NTILE(10) OVER
        (
            PARTITION BY FechaCorte
            ORDER BY SaldoCreditoBs
        ) AS DecilSaldo
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
      AND SaldoCreditoBs IS NOT NULL
)
SELECT
    FechaCorte,
    DecilSaldo,
    COUNT_BIG(*) AS CantidadCarteras,
    MIN(SaldoCreditoBs) AS SaldoMinimoBs,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    MAX(SaldoCreditoBs) AS SaldoMaximoBs,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM BaseDeciles
GROUP BY FechaCorte, DecilSaldo
ORDER BY FechaCorte, DecilSaldo;


/*==============================================================
  31. REPROGRAMACIONES Y MORA

  Compara clientes con y sin reprogramaciones para revisar si presentan
  diferencias de saldo o comportamiento de pago.
==============================================================*/

SELECT
    FechaCorte,
    CASE
        WHEN CantidadReprogramaciones IS NULL THEN N'SIN DATO'
        WHEN CantidadReprogramaciones = 0 THEN N'SIN REPROGRAMACION'
        ELSE N'CON REPROGRAMACION'
    END AS GrupoReprogramacion,
    COUNT_BIG(*) AS CantidadCarteras,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    AVG(CONVERT(FLOAT, MaxDiasMora12M)) AS Mora12MPromedio,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY
    FechaCorte,
    CASE
        WHEN CantidadReprogramaciones IS NULL THEN N'SIN DATO'
        WHEN CantidadReprogramaciones = 0 THEN N'SIN REPROGRAMACION'
        ELSE N'CON REPROGRAMACION'
    END
ORDER BY FechaCorte, GrupoReprogramacion;


/*==============================================================
  32. ESTABILIDAD DE VARIABLES NUMERICAS

  Formato vertical para graficar promedio y desviacion por mes. Cambios
  fuertes pueden indicar deriva de datos o cambios de poblacion.
==============================================================*/

SELECT
    d.FechaCorte,
    v.Variable,
    COUNT_BIG(v.Valor) AS CantidadConDato,
    AVG(v.Valor) AS Promedio,
    STDEV(v.Valor) AS DesviacionEstandar,
    MIN(v.Valor) AS Minimo,
    MAX(v.Valor) AS Maximo
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
CROSS APPLY
(
    VALUES
        (N'EdadCliente', CONVERT(FLOAT, d.EdadCliente)),
        (N'AntiguedadClienteMeses', CONVERT(FLOAT, d.AntiguedadClienteMeses)),
        (N'PatrimonioClienteBs', CONVERT(FLOAT, d.PatrimonioClienteBs)),
        (N'SaldoCreditoBs', CONVERT(FLOAT, d.SaldoCreditoBs)),
        (N'MontoDesembolsadoBs', CONVERT(FLOAT, d.MontoDesembolsadoBs)),
        (N'MaxDiasMora12M', CONVERT(FLOAT, d.MaxDiasMora12M)),
        (N'TasaCumplimiento', CONVERT(FLOAT, d.TasaCumplimiento)),
        (N'CantidadTrx', CONVERT(FLOAT, d.CantidadTrx)),
        (N'MontoTotalTrxBs', CONVERT(FLOAT, d.MontoTotalTrxBs)),
        (N'InfocredMontoDeudaTotalBs', CONVERT(FLOAT, d.InfocredMontoDeudaTotalBs))
) v(Variable, Valor)
WHERE d.FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY d.FechaCorte, v.Variable
ORDER BY v.Variable, d.FechaCorte;


/*==============================================================
  33. ENTRENAMIENTO Y VALIDACION TEMPORAL

  Usa el ultimo mes como validacion y los meses anteriores como
  entrenamiento. Es preferible a dividir aleatoriamente datos temporales.
==============================================================*/

SELECT
    CASE
        WHEN FechaCorte = @FechaFin THEN N'VALIDACION_TEMPORAL'
        ELSE N'ENTRENAMIENTO'
    END AS GrupoModelo,
    MIN(FechaCorte) AS PrimeraFecha,
    MAX(FechaCorte) AS UltimaFecha,
    COUNT_BIG(*) AS CantidadFilas,
    COUNT_BIG(DISTINCT ClienteKey) AS CantidadClientes,
    COUNT_BIG(DISTINCT CarteraKey) AS CantidadCarteras
FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
GROUP BY
    CASE
        WHEN FechaCorte = @FechaFin THEN N'VALIDACION_TEMPORAL'
        ELSE N'ENTRENAMIENTO'
    END
ORDER BY PrimeraFecha;


/*==============================================================
  34. CLIENTES REPETIDOS ENTRE ENTRENAMIENTO Y VALIDACION

  Indica cuantos clientes del ultimo mes tambien aparecen en meses
  anteriores. Sirve para documentar el posible solapamiento temporal.
==============================================================*/

;WITH ClientesEntrenamiento AS
(
    SELECT DISTINCT ClienteKey
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte >= @FechaInicio
      AND FechaCorte < @FechaFin
),
ClientesValidacion AS
(
    SELECT DISTINCT ClienteKey
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte = @FechaFin
)
SELECT
    (SELECT COUNT_BIG(*) FROM ClientesEntrenamiento) AS ClientesEntrenamiento,
    (SELECT COUNT_BIG(*) FROM ClientesValidacion) AS ClientesValidacion,
    COUNT_BIG(*) AS ClientesEnAmbosGrupos,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*)
        / NULLIF((SELECT COUNT_BIG(*) FROM ClientesValidacion), 0)
    ) AS PorcentajeValidacionVistoEnEntrenamiento
FROM ClientesEntrenamiento e
INNER JOIN ClientesValidacion v
        ON v.ClienteKey = e.ClienteKey;


/*==============================================================
  35. OBJETIVO FUTURO DE MORA

  Calcula, a nivel cliente, si en el mes siguiente supera 30 dias de
  mora. Este objetivo futuro evita utilizar informacion del mismo mes
  que se quiere predecir.
==============================================================*/

;WITH ClienteMes AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        MAX(MaxDiasMoraMes) AS MoraDelMes
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY FechaCorte, ClienteKey
),
ClienteConFuturo AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        MoraDelMes,
        LEAD(FechaCorte) OVER
            (PARTITION BY ClienteKey ORDER BY FechaCorte) AS FechaSiguiente,
        LEAD(MoraDelMes) OVER
            (PARTITION BY ClienteKey ORDER BY FechaCorte) AS MoraMesSiguiente
    FROM ClienteMes
)
SELECT
    FechaCorte AS FechaDeLasVariables,
    EOMONTH(DATEADD(MONTH, 1, FechaCorte)) AS FechaDelObjetivo,
    COUNT_BIG(*) AS TotalClientes,
    SUM
    (
        CASE
            WHEN FechaSiguiente = EOMONTH(DATEADD(MONTH, 1, FechaCorte))
             AND MoraMesSiguiente IS NOT NULL
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS ClientesConObjetivoConocido,
    SUM
    (
        CASE
            WHEN FechaSiguiente = EOMONTH(DATEADD(MONTH, 1, FechaCorte))
             AND MoraMesSiguiente > 30
            THEN CONVERT(BIGINT, 1)
            ELSE 0
        END
    ) AS ClientesConMoraMayor30SiguienteMes,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM
        (
            CASE
                WHEN FechaSiguiente = EOMONTH(DATEADD(MONTH, 1, FechaCorte))
                 AND MoraMesSiguiente > 30
                THEN 1.0
                ELSE 0.0
            END
        )
        / NULLIF
        (
            SUM
            (
                CASE
                    WHEN FechaSiguiente = EOMONTH(DATEADD(MONTH, 1, FechaCorte))
                     AND MoraMesSiguiente IS NOT NULL
                    THEN 1.0
                    ELSE 0.0
                END
            ),
            0
        )
    ) AS PorcentajeObjetivoMora30
FROM ClienteConFuturo
WHERE FechaCorte < @FechaFin
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  36. CRECIMIENTO MENSUAL

  Muestra la variacion porcentual de clientes, carteras y saldo frente
  al mes anterior. En Excel funciona bien como grafico de lineas.
==============================================================*/

;WITH ResumenMes AS
(
    SELECT
        FechaCorte,
        COUNT_BIG(DISTINCT ClienteKey) AS Clientes,
        COUNT_BIG(DISTINCT CarteraKey) AS Carteras,
        SUM(CONVERT(DECIMAL(38,2), SaldoCreditoBs)) AS SaldoTotalBs
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY FechaCorte
),
ResumenConAnterior AS
(
    SELECT
        *,
        LAG(Clientes) OVER (ORDER BY FechaCorte) AS ClientesMesAnterior,
        LAG(Carteras) OVER (ORDER BY FechaCorte) AS CarterasMesAnterior,
        LAG(SaldoTotalBs) OVER (ORDER BY FechaCorte) AS SaldoMesAnterior
    FROM ResumenMes
)
SELECT
    FechaCorte,
    Clientes,
    Carteras,
    SaldoTotalBs,
    CONVERT
    (
        DECIMAL(10,2),
        100.0 * (Clientes - ClientesMesAnterior)
        / NULLIF(ClientesMesAnterior, 0)
    ) AS CrecimientoClientesPorcentaje,
    CONVERT
    (
        DECIMAL(10,2),
        100.0 * (Carteras - CarterasMesAnterior)
        / NULLIF(CarterasMesAnterior, 0)
    ) AS CrecimientoCarterasPorcentaje,
    CONVERT
    (
        DECIMAL(10,2),
        100.0 * (SaldoTotalBs - SaldoMesAnterior)
        / NULLIF(SaldoMesAnterior, 0)
    ) AS CrecimientoSaldoPorcentaje
FROM ResumenConAnterior
ORDER BY FechaCorte;


/*==============================================================
  37. ENTRADA, CONTINUIDAD Y REINGRESO DE CLIENTES

  Permite entender si el cambio mensual proviene de clientes nuevos en
  el rango, clientes continuos o clientes que reaparecen.
==============================================================*/

;WITH ClienteFecha AS
(
    SELECT DISTINCT FechaCorte, ClienteKey
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
),
ClienteConAnterior AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        LAG(FechaCorte) OVER
            (PARTITION BY ClienteKey ORDER BY FechaCorte) AS FechaAnterior
    FROM ClienteFecha
),
ClienteClasificado AS
(
    SELECT
        FechaCorte,
        CASE
            WHEN FechaAnterior IS NULL THEN N'PRIMERA APARICION EN EL RANGO'
            WHEN FechaAnterior = EOMONTH(DATEADD(MONTH, -1, FechaCorte))
                THEN N'CLIENTE CONTINUO'
            ELSE N'CLIENTE QUE REAPARECE'
        END AS TipoPermanencia
    FROM ClienteConAnterior
)
SELECT
    FechaCorte,
    TipoPermanencia,
    COUNT_BIG(*) AS CantidadClientes,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte)
    ) AS PorcentajeClientes
FROM ClienteClasificado
GROUP BY FechaCorte, TipoPermanencia
ORDER BY FechaCorte, TipoPermanencia;


/*==============================================================
  38. TRANSICION DE MORA ENTRE MESES

  Muestra desde que banda de mora viene cada cliente y a cual pasa.
  Se puede visualizar como matriz de calor o diagrama de flujo.
==============================================================*/

;WITH MoraClienteMes AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        MAX(MaxDiasMoraMes) AS MaxMoraDelMes
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY FechaCorte, ClienteKey
),
BandaClienteMes AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        CASE
            WHEN MaxMoraDelMes IS NULL THEN N'SIN DATO'
            WHEN MaxMoraDelMes = 0 THEN N'0 DIAS'
            WHEN MaxMoraDelMes <= 30 THEN N'1 A 30 DIAS'
            WHEN MaxMoraDelMes <= 60 THEN N'31 A 60 DIAS'
            WHEN MaxMoraDelMes <= 90 THEN N'61 A 90 DIAS'
            ELSE N'MAS DE 90 DIAS'
        END AS BandaActual
    FROM MoraClienteMes
),
Transicion AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        BandaActual,
        LAG(FechaCorte) OVER
            (PARTITION BY ClienteKey ORDER BY FechaCorte) AS FechaAnterior,
        LAG(BandaActual) OVER
            (PARTITION BY ClienteKey ORDER BY FechaCorte) AS BandaAnterior
    FROM BandaClienteMes
)
SELECT
    FechaCorte,
    BandaAnterior,
    BandaActual,
    COUNT_BIG(*) AS CantidadClientes,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * COUNT_BIG(*)
        / SUM(COUNT_BIG(*)) OVER (PARTITION BY FechaCorte, BandaAnterior)
    ) AS PorcentajeDesdeBandaAnterior
FROM Transicion
WHERE FechaAnterior = EOMONTH(DATEADD(MONTH, -1, FechaCorte))
GROUP BY FechaCorte, BandaAnterior, BandaActual
ORDER BY FechaCorte, BandaAnterior, BandaActual;


/*==============================================================
  39. EXPOSICION MONETARIA POR BANDA DE MORA

  Complementa la cantidad de casos con el dinero expuesto en cada nivel
  de riesgo. Es apropiado para columnas apiladas en Excel.
==============================================================*/

;WITH ExposicionMora AS
(
    SELECT
        FechaCorte,
        SaldoCreditoBs,
        CASE
            WHEN MaxDiasMora12M IS NULL THEN N'SIN DATO'
            WHEN MaxDiasMora12M = 0 THEN N'0 DIAS'
            WHEN MaxDiasMora12M <= 30 THEN N'1 A 30 DIAS'
            WHEN MaxDiasMora12M <= 60 THEN N'31 A 60 DIAS'
            WHEN MaxDiasMora12M <= 90 THEN N'61 A 90 DIAS'
            ELSE N'MAS DE 90 DIAS'
        END AS BandaMora
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
SELECT
    FechaCorte,
    BandaMora,
    COUNT_BIG(*) AS CantidadCarteras,
    SUM(CONVERT(DECIMAL(38,2), SaldoCreditoBs)) AS SaldoExpuestoBs,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CONVERT(DECIMAL(38,4), SaldoCreditoBs))
        / NULLIF
        (
            SUM(SUM(CONVERT(DECIMAL(38,4), SaldoCreditoBs)))
                OVER (PARTITION BY FechaCorte),
            0
        )
    ) AS PorcentajeDelSaldo
FROM ExposicionMora
GROUP BY FechaCorte, BandaMora
ORDER BY FechaCorte, BandaMora;


/*==============================================================
  40. CONCENTRACION DEL SALDO POR CLIENTE

  Indica cuanto del saldo total esta concentrado en el 1, 5 y 10 por
  ciento de clientes con mayor saldo.
==============================================================*/

;WITH SaldoCliente AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        SUM(CONVERT(DECIMAL(38,2), SaldoCreditoBs)) AS SaldoClienteBs
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY FechaCorte, ClienteKey
),
ClienteOrdenado AS
(
    SELECT
        FechaCorte,
        ClienteKey,
        SaldoClienteBs,
        ROW_NUMBER() OVER
            (PARTITION BY FechaCorte ORDER BY SaldoClienteBs DESC) AS Posicion,
        COUNT_BIG(*) OVER (PARTITION BY FechaCorte) AS TotalClientes,
        SUM(SaldoClienteBs) OVER (PARTITION BY FechaCorte) AS SaldoTotalBs
    FROM SaldoCliente
)
SELECT
    FechaCorte,
    MAX(TotalClientes) AS TotalClientes,
    MAX(SaldoTotalBs) AS SaldoTotalBs,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM
        (
            CASE WHEN Posicion <= CEILING(TotalClientes * 0.01)
                 THEN SaldoClienteBs ELSE 0 END
        ) / NULLIF(MAX(SaldoTotalBs), 0)
    ) AS PorcentajeSaldoTop1,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM
        (
            CASE WHEN Posicion <= CEILING(TotalClientes * 0.05)
                 THEN SaldoClienteBs ELSE 0 END
        ) / NULLIF(MAX(SaldoTotalBs), 0)
    ) AS PorcentajeSaldoTop5,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM
        (
            CASE WHEN Posicion <= CEILING(TotalClientes * 0.10)
                 THEN SaldoClienteBs ELSE 0 END
        ) / NULLIF(MAX(SaldoTotalBs), 0)
    ) AS PorcentajeSaldoTop10
FROM ClienteOrdenado
GROUP BY FechaCorte
ORDER BY FechaCorte;


/*==============================================================
  41. ACTIVIDAD TRANSACCIONAL Y MORA

  Permite revisar si clientes con poca o mucha actividad presentan
  comportamientos de pago diferentes.
==============================================================*/

;WITH ActividadAgrupada AS
(
    SELECT
        FechaCorte,
        SaldoCreditoBs,
        MaxDiasMora12M,
        CASE
            WHEN CantidadTrx IS NULL THEN N'SIN DATO'
            WHEN CantidadTrx = 0 THEN N'SIN TRANSACCIONES'
            WHEN CantidadTrx <= 5 THEN N'1 A 5'
            WHEN CantidadTrx <= 20 THEN N'6 A 20'
            WHEN CantidadTrx <= 50 THEN N'21 A 50'
            ELSE N'MAS DE 50'
        END AS BandaActividad
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin)
    WHERE FechaCorte BETWEEN @FechaInicio AND @FechaFin
)
SELECT
    FechaCorte,
    BandaActividad,
    COUNT_BIG(*) AS CantidadCarteras,
    AVG(CONVERT(FLOAT, SaldoCreditoBs)) AS SaldoPromedioBs,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM ActividadAgrupada
GROUP BY FechaCorte, BandaActividad
ORDER BY FechaCorte, BandaActividad;


/*==============================================================
  42. DECILES DE VARIABLES NUMERICAS

  Evalua la relacion entre cada variable y la mora. Una tendencia clara
  entre deciles indica posible capacidad predictiva.
==============================================================*/

;WITH VariablesNumericas AS
(
    SELECT
        d.FechaCorte,
        d.MaxDiasMora12M,
        v.Variable,
        v.Valor
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
    CROSS APPLY
    (
        VALUES
            (N'EdadCliente', CONVERT(FLOAT, d.EdadCliente)),
            (N'AntiguedadClienteMeses', CONVERT(FLOAT, d.AntiguedadClienteMeses)),
            (N'PatrimonioClienteBs', CONVERT(FLOAT, d.PatrimonioClienteBs)),
            (N'SaldoCreditoBs', CONVERT(FLOAT, d.SaldoCreditoBs)),
            (N'MontoDesembolsadoBs', CONVERT(FLOAT, d.MontoDesembolsadoBs)),
            (N'TasaEfectivaCredito', CONVERT(FLOAT, d.TasaEfectivaCredito)),
            (N'AntiguedadCreditoMeses', CONVERT(FLOAT, d.AntiguedadCreditoMeses)),
            (N'CantidadTrx', CONVERT(FLOAT, d.CantidadTrx)),
            (N'InfocredMontoDeudaTotalBs', CONVERT(FLOAT, d.InfocredMontoDeudaTotalBs))
    ) v(Variable, Valor)
    WHERE d.FechaCorte BETWEEN @FechaInicio AND @FechaFin
      AND v.Valor IS NOT NULL
),
VariableConDecil AS
(
    SELECT
        *,
        NTILE(10) OVER
        (
            PARTITION BY FechaCorte, Variable
            ORDER BY Valor
        ) AS Decil
    FROM VariablesNumericas
)
SELECT
    FechaCorte,
    Variable,
    Decil,
    COUNT_BIG(*) AS CantidadFilas,
    MIN(Valor) AS ValorMinimo,
    AVG(Valor) AS ValorPromedio,
    MAX(Valor) AS ValorMaximo,
    CONVERT
    (
        DECIMAL(6,2),
        100.0 * SUM(CASE WHEN MaxDiasMora12M > 30 THEN 1.0 ELSE 0.0 END)
        / NULLIF(SUM(CASE WHEN MaxDiasMora12M IS NOT NULL THEN 1.0 ELSE 0.0 END), 0)
    ) AS PorcentajeMoraMayor30
FROM VariableConDecil
GROUP BY FechaCorte, Variable, Decil
ORDER BY Variable, FechaCorte, Decil;


/*==============================================================
  43. ESTABILIDAD POBLACIONAL PSI

  Compara la distribucion de cada mes contra el primer mes. Un PSI menor
  a 0.10 suele ser estable; entre 0.10 y 0.25 requiere revision; mayor
  a 0.25 indica un cambio importante de poblacion.
==============================================================*/

;WITH Categorias AS
(
    SELECT
        d.FechaCorte,
        c.Variable,
        c.Valor,
        COUNT_BIG(*) AS Cantidad
    FROM Inteligencia_Comercial.dbo.fn_DatasetCarteraAnalisis(@FechaInicio, @FechaFin) d
    CROSS APPLY
    (
        VALUES
            (N'GeneroCliente',
                COALESCE(CONVERT(NVARCHAR(200), d.GeneroCliente), N'<NULO>')),
            (N'DepartamentoCliente',
                COALESCE(CONVERT(NVARCHAR(200), d.DepartamentoCliente), N'<NULO>')),
            (N'SegmentoCliente',
                COALESCE(CONVERT(NVARCHAR(200), d.SegmentoCliente), N'<NULO>')),
            (N'NivelIngresoCliente',
                COALESCE(CONVERT(NVARCHAR(200), d.NivelIngresoCliente), N'<NULO>')),
            (N'TipoCredito',
                COALESCE(CONVERT(NVARCHAR(200), d.TipoCredito), N'<NULO>'))
    ) c(Variable, Valor)
    WHERE d.FechaCorte BETWEEN @FechaInicio AND @FechaFin
    GROUP BY d.FechaCorte, c.Variable, c.Valor
),
Distribucion AS
(
    SELECT
        FechaCorte,
        Variable,
        Valor,
        CONVERT
        (
            FLOAT,
            Cantidad * 1.0 / SUM(Cantidad) OVER (PARTITION BY FechaCorte, Variable)
        ) AS Proporcion
    FROM Categorias
),
ValoresPosibles AS
(
    SELECT DISTINCT Variable, Valor
    FROM Distribucion
),
Meses AS
(
    SELECT DISTINCT FechaCorte
    FROM Distribucion
),
FechaBase AS
(
    SELECT MIN(FechaCorte) AS FechaBase
    FROM Distribucion
),
Malla AS
(
    SELECT m.FechaCorte, v.Variable, v.Valor
    FROM Meses m
    CROSS JOIN ValoresPosibles v
),
Comparacion AS
(
    SELECT
        g.FechaCorte,
        fb.FechaBase,
        g.Variable,
        g.Valor,
        CASE
            WHEN ISNULL(actual.Proporcion, 0) < 0.000001 THEN 0.000001
            ELSE actual.Proporcion
        END AS ProporcionActual,
        CASE
            WHEN ISNULL(base.Proporcion, 0) < 0.000001 THEN 0.000001
            ELSE base.Proporcion
        END AS ProporcionBase
    FROM Malla g
    CROSS JOIN FechaBase fb
    LEFT JOIN Distribucion actual
           ON actual.FechaCorte = g.FechaCorte
          AND actual.Variable = g.Variable
          AND actual.Valor = g.Valor
    LEFT JOIN Distribucion base
           ON base.FechaCorte = fb.FechaBase
          AND base.Variable = g.Variable
          AND base.Valor = g.Valor
)
SELECT
    FechaCorte,
    MAX(FechaBase) AS FechaBase,
    Variable,
    CONVERT
    (
        DECIMAL(12,6),
        SUM
        (
            (ProporcionActual - ProporcionBase)
            * LOG(ProporcionActual / ProporcionBase)
        )
    ) AS PSI,
    CASE
        WHEN SUM
        (
            (ProporcionActual - ProporcionBase)
            * LOG(ProporcionActual / ProporcionBase)
        ) < 0.10 THEN N'ESTABLE'
        WHEN SUM
        (
            (ProporcionActual - ProporcionBase)
            * LOG(ProporcionActual / ProporcionBase)
        ) < 0.25 THEN N'REVISAR'
        ELSE N'CAMBIO IMPORTANTE'
    END AS EstadoPSI
FROM Comparacion
GROUP BY FechaCorte, Variable
ORDER BY Variable, FechaCorte;
