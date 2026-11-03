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
    COUN…8901 tokens truncated…)),
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
