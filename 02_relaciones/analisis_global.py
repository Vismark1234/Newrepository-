"""Diagnóstico de TODAS las variables: asociaciones y patrones de ausencia.

No es necesario elegir una variable objetivo. Uso:
    resultado = analizar_todo(datos)
    print(resultado["relaciones"].head(30))
    print(resultado["faltantes"].head(30))
"""
import pandas as pd
from relaciones import relacion_pares, relacion_faltantes, faltantes_por_categoria, matriz_coausencia


def analizar_todo(datos, max_categorias=20, max_categorias_numericas=10):
    """Analiza todos los pares y todas las columnas con valores ausentes."""
    relaciones = relacion_pares(datos, max_categorias, max_categorias_numericas)
    resumen_faltantes = []
    detalles = []

    for objetivo in datos.columns:
        cantidad = int(datos[objetivo].isna().sum())
        if cantidad == 0:
            continue

        porcentaje = round(100 * cantidad / len(datos), 2) if len(datos) > 0 else 0
        ranking = relacion_faltantes(datos, objetivo, max_categorias)

        for fila in ranking.itertuples(index=False):
            resumen_faltantes.append({
                "variable_faltante": objetivo,
                "faltantes": cantidad,
                "porcentaje_faltante": porcentaje,
                "variable_asociada": fila.variable,
                "tipo": fila.tipo,
                "metodo": fila.metodo,
                "asociacion": fila.asociacion,
                "registros": fila.registros
            })

        # Detalle por categorías: permite detectar grupos con alta ausencia.
        for fila in ranking.itertuples(index=False):
            if fila.tipo != "categorica":
                continue
            tabla = faltantes_por_categoria(datos, objetivo, fila.variable, max_categorias)
            for grupo, valores in tabla.iterrows():
                detalles.append({
                    "variable_faltante": objetivo,
                    "variable_asociada": fila.variable,
                    "categoria": grupo,
                    "registros": int(valores["registros"]),
                    "faltantes": int(valores["faltantes"]),
                    "porcentaje_faltante": float(valores["porcentaje_faltante"])
                })

    columnas_resumen = [
        "variable_faltante", "faltantes", "porcentaje_faltante",
        "variable_asociada", "tipo", "metodo", "asociacion", "registros"
    ]
    columnas_detalle = [
        "variable_faltante", "variable_asociada", "categoria",
        "registros", "faltantes", "porcentaje_faltante"
    ]
    faltantes = pd.DataFrame(resumen_faltantes, columns=columnas_resumen)
    categorias = pd.DataFrame(detalles, columns=columnas_detalle)

    if len(faltantes) > 0:
        faltantes = faltantes.sort_values(
            ["variable_faltante", "asociacion"], ascending=[True, False]
        )
    if len(categorias) > 0:
        categorias = categorias.sort_values(
            "porcentaje_faltante", ascending=False
        )

    return {
        "relaciones": relaciones,
        "faltantes": faltantes,
        "categorias": categorias,
        "coausencia": matriz_coausencia(datos)
    }


def exportar_excel(resultado, archivo="diagnostico_variables.xlsx"):
    """Guarda cada tabla en una hoja para revisar fácilmente los resultados."""
    with pd.ExcelWriter(archivo) as escritor:
        resultado["relaciones"].to_excel(escritor, sheet_name="Relaciones", index=False)
        resultado["faltantes"].to_excel(escritor, sheet_name="Faltantes", index=False)
        resultado["categorias"].to_excel(escritor, sheet_name="Categorias", index=False)
        resultado["coausencia"].to_excel(escritor, sheet_name="Coausencia")


# ============================================================
# EJEMPLO EN JUPYTER: todas las variables incluidas
# ============================================================
# resultado = analizar_todo(datos)
# display(resultado["relaciones"].head(30))
# display(resultado["faltantes"].head(30))
# display(resultado["categorias"].head(30))
# display(resultado["coausencia"])
#
# Opcional: exportar a Excel (requiere openpyxl)
# exportar_excel(resultado, "diagnostico_variables.xlsx")
