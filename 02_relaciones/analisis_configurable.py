"""Analiza todas las columnas numéricas y las categóricas indicadas por el usuario.

Las columnas categóricas se especifican con una lista. El resto de columnas
numéricas se detectan automáticamente. Los object no declarados se ignoran.
"""
import pandas as pd
from relaciones import relacion_pares, relacion_faltantes, faltantes_por_categoria


def preparar_columnas(datos, categoricas=None, excluir=None):
    """Devuelve copia con variables válidas para análisis, sin alterar datos."""
    if categoricas is None:
        categoricas = []
    if excluir is None:
        excluir = []

    for columna in categoricas + excluir:
        if columna not in datos.columns:
            raise ValueError("No existe la columna: " + columna)

    numericas = datos.select_dtypes(include="number").columns.tolist()
    seleccionadas = []
    for columna in datos.columns:
        if columna in excluir:
            continue
        if columna in categoricas or columna in numericas:
            seleccionadas.append(columna)

    tabla = datos[seleccionadas].copy()
    for columna in categoricas:
        if columna in tabla.columns:
            tabla[columna] = tabla[columna].astype("string")
    return tabla


def analizar(datos, categoricas=None, excluir=None, max_categorias=20):
    """Compara todas las columnas numéricas y las categóricas especificadas."""
    tabla = preparar_columnas(datos, categoricas, excluir)
    relaciones = relacion_pares(
        tabla, max_categorias=max_categorias, max_categorias_numericas=0
    )
    resultados_faltantes = []
    for objetivo in tabla.columns:
        if tabla[objetivo].isna().sum() == 0:
            continue
        ranking = relacion_faltantes(tabla, objetivo, max_categorias)
        for fila in ranking.itertuples(index=False):
            resultados_faltantes.append({
                "variable_faltante": objetivo,
                "variable_asociada": fila.variable,
                "metodo": fila.metodo,
                "asociacion": fila.asociacion,
                "registros": fila.registros
            })

    columnas = [
        "variable_faltante", "variable_asociada", "metodo",
        "asociacion", "registros"
    ]
    faltantes = pd.DataFrame(resultados_faltantes, columns=columnas)
    if len(faltantes) > 0:
        faltantes = faltantes.sort_values("asociacion", ascending=False)

    return {
        "columnas": tabla.columns.tolist(),
        "relaciones": relaciones,
        "faltantes": faltantes.reset_index(drop=True)
    }


# ============================================================
# EJEMPLO EN JUPYTER: todas las numéricas + categorías elegidas
# ============================================================
# categoricas = ["Segmento", "TipoCredito"]  # Nombres reales
# excluir = ["ClienteKey", "CarteraKey"]     # Opcional
# resultado = analizar(datos, categoricas=categoricas, excluir=excluir)
# display(resultado["relaciones"].head(30))
# display(resultado["faltantes"].head(30))
#
# Si no tienes categorías:
# resultado = analizar(datos)
# display(resultado["relaciones"].head(30))
