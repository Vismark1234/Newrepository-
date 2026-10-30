# Acta de alcance del proyecto

## Identificación

**Proyecto:** Análisis de brechas de cobertura de vacunación contra la COVID-19 en Francia.  
**Estudiante:** Vismark Abner Choque Cachi.  
**Asignatura:** Visualización de Datos.  
**Ruta:** 05 — Cobertura de vacunación.  
**Fecha:** 30 de octubre de 2026.  
**Estado:** Propuesta de alcance. Pendiente de revisión académica; no representa aprobación docente.

## Propósito y problema

Los archivos de vacunación presentan distintos niveles de detalle. Consultarlos por separado dificulta comparar territorios y grupos de edad y seguir su evolución. El proyecto integrará y analizará esa información para identificar brechas históricas y comunicarlas mediante indicadores, mapas y un tablero interactivo.

## Objetivo general

Analizar y visualizar la cobertura histórica de vacunación contra la COVID-19 en Francia por departamento y grupo de edad, mediante integración y transformación en SQL Server, análisis en Python y visualizaciones en Power BI y QGIS, para apoyar una priorización territorial académica simulada.

## Usuario y decisión

El usuario de referencia será una persona responsable de planificación sanitaria territorial en un escenario simulado. La decisión consiste en seleccionar departamentos y grupos de edad que merecen revisión posterior por cobertura relativamente baja o evolución limitada. Los resultados no demostrarán las causas de esas diferencias.

## Alcance de los datos

Se utilizarán datos VAC-SI publicados por Santé publique France en data.gouv.fr, catálogos y geometrías de departamentos. Se propone estudiar del 27 de diciembre de 2020 al 10 de julio de 2023; fechas, filas y disponibilidad de indicadores se confirmarán durante el perfilamiento. Junio de 2023 será el primer corte mensual completo propuesto para mapas.

La unidad principal será departamento, grupo de edad y fecha. Se conservarán separados los hechos con diferentes niveles de detalle. Sexo y tipo de vacuna serán análisis complementarios compatibles. Profesionales y residentes, si se incorporan, se tratarán como cohortes independientes.

## Trabajo incluido

- Conservar originales y documentar procedencia, licencia, estructura y calidad.
- Implementar ELT: SSIS extrae y carga; procedimientos T-SQL limpian y transforman dentro de SQL Server.
- Crear dimensiones y tablas de hechos en la misma base, con esquemas raw, stg, dwh y analitica.
- Analizar faltantes, distribuciones, diferencias territoriales y tendencias con Python.
- Evaluar segmentación exploratoria con K-means y guardar resultados interpretables en SQL Server.
- Construir al menos seis vistas, incluidos mapa coroplético, tendencias mensuales y tablero con tres KPI.
- Evaluar comprensión y accesibilidad, guardar versiones inicial y mejorada y documentar cambios.
- Gestionar versiones de paquetes, scripts, notebooks y documentación en GitHub.

## Indicadores principales

| Indicador | Cálculo | Unidad |
|---|---|---|
| Cobertura de esquema completo | Último valor mensual válido de couv_complet | Porcentaje |
| Brecha de cobertura | 100 − cobertura de esquema completo | Puntos porcentuales |
| Variación mensual | Cobertura del mes actual − cobertura del mes calendario anterior | Puntos porcentuales |

Se comparará la misma población y territorio. La brecha respecto al 100 % es descriptiva y no una meta sanitaria oficial. No se sumarán coberturas ni acumulados entre fechas. Los datos faltantes se mostrarán como tales y los totales no se sumarán con sus desgloses. La cobertura nacional no se obtendrá con un promedio simple de departamentos.

## Priorización y segmentación

Se comenzará ordenando departamentos comparables e identificando el cuartil inferior de cobertura, junto con su evolución y calidad. Es un criterio académico exploratorio. K-means complementará el análisis si la selección de variables, estandarización, silueta, estabilidad e interpretación respaldan su utilidad. Si no aporta grupos claros, se documentará la limitación y se conservará la priorización descriptiva.

## Fuera del alcance

No se recogerán datos personales ni historias clínicas. No se estimará cobertura actual de 2026, se harán diagnósticos, se demostrarán relaciones causales ni se implementará un sistema sanitario de producción.

## Entregables y aceptación

Se entregarán datos o enlaces reproducibles, diccionario, modelo dimensional, paquetes SSIS, scripts SQL, notebooks, tablero Power BI, mapas y proyecto QGIS, informe, evidencias de evaluación y README. El flujo deberá ejecutarse nuevamente, dejar controles de calidad y mantener relaciones y granularidades correctas. Los KPI deberán coincidir con consultas de verificación.

Se documentará una prueba con dos personas o una evaluación heurística estructurada si no es viable. El proceso seguirá CRISP-DM, Munzner y PDCA y aplicará los autores y fichas normativas exigidos por la guía. Extensión del informe, duración del video y fechas de entrega quedan sujetos a aclaración de la docente; no se fija un cronograma sin esa confirmación.

## Riesgos y cambios de alcance

Se controlarán archivos incompletos, uniones que dupliquen datos, incompatibilidad de categorías y falta de cortes comparables. Cada cambio de fuente, periodo, indicador o unidad de análisis se documentará con motivo e impacto en el repositorio. Los hallazgos se incorporarán después del análisis; esta acta no presenta resultados calculados.
