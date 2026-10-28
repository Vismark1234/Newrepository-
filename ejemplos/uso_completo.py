"""Ejemplo de relaciones entre variables con el DataFrame datos."""
import sys
sys.path.insert(0, "01_perfilado")
sys.path.insert(0, "02_relaciones")

from perfilado import normalizar_vacios, resumen_calidad
from relaciones import relacion_pares, relacion_faltantes, faltantes_por_categoria

datos_limpios = normalizar_vacios(datos)
calidad = resumen_calidad(datos_limpios)
print(calidad.head(30))

relaciones = relacion_pares(datos_limpios)
print(relaciones.head(30))

columnas = calidad[calidad["faltantes"] > 0].index
if len(columnas) > 0:
    objetivo = columnas[0]
    ranking = relacion_faltantes(datos_limpios, objetivo)
    print(ranking.head(20))
    categoricas = ranking[ranking["tipo"] == "categorica"]
    if len(categoricas) > 0:
        columna = categoricas.iloc[0]["variable"]
        print(faltantes_por_categoria(datos_limpios, objetivo, columna))
