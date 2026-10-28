"""Relaciones entre variables numéricas, categóricas y valores faltantes."""
import numpy as np
import pandas as pd
from scipy.stats import chi2_contingency


def tipo_variable(serie, max_categorias_numericas=10):
    """Clasifica variables; los números con pocas categorías se pueden tratar como grupos."""
    if pd.api.types.is_numeric_dtype(serie):
        if serie.nunique(dropna=True) <= max_categorias_numericas:
            return "categorica"
        return "numerica"
    return "categorica"


def v_cramer(tabla):
    """Asociación de 0 a 1 entre dos variables categóricas."""
    if tabla.shape[0] < 2 or tabla.shape[1] < 2:
        return np.nan
    total = tabla.to_numpy().sum()
    if total == 0:
        return np.nan
    chi2 = chi2_contingency(tabla, correction=False)[0]
    divisor = total * min(tabla.shape[0] - 1, tabla.shape[1] - 1)
    return np.sqrt(chi2 / divisor)


def eta_cuadrado(grupos, valores):
    """Proporción de variación numérica explicada por grupos (0 a 1)."""
    tabla = pd.DataFrame({"grupo": grupos, "valor": valores}).dropna()
    if tabla["grupo"].nunique() < 2 or tabla["valor"].nunique() < 2:
        return np.nan
    media = tabla["valor"].mean()
    total = ((tabla["valor"] - media) ** 2).sum()
    if total == 0:
        return np.nan
    entre = 0
    for nombre, parte in tabla.groupby("grupo"):
        entre += len(parte) * (parte["valor"].mean() - media) ** 2
    return entre / total


def relacion_pares(datos, max_categorias=20, max_categorias_numericas=10):
    """Analiza automáticamente todos los pares de columnas.

    Las medidas tienen interpretaciones distintas: comparar dentro de cada método.
    Las categorías menos frecuentes se agrupan en 'OTRAS'.
    """
    resultados = []
    columnas = datos.columns.tolist()
    for i in range(len(columnas)):
        for j in range(i + 1, len(columnas)):
            nombre_a = columnas[i]
            nombre_b = columnas[j]
            a = datos[nombre_a]
            b = datos[nombre_b]
            validos = a.notna() & b.notna()
            if validos.sum() < 10:
                continue
            a = a[validos]
            b = b[validos]
            tipo_a = tipo_variable(a, max_categorias_numericas)
            tipo_b = tipo_variable(b, max_categorias_numericas)
            if tipo_a == "numerica" and tipo_b == "numerica":
                metodo = "spearman"
                valor = abs(a.corr(b, method="spearman"))
            elif tipo_a == "categorica" and tipo_b == "categorica":
                metodo = "v_cramer"
                a = agrupar_categorias(a, max_categorias)
                b = agrupar_categorias(b, max_categorias)
                valor = v_cramer(pd.crosstab(a, b))
            else:
                metodo = "eta_cuadrado"
                if tipo_a == "categorica":
                    grupos = agrupar_categorias(a, max_categorias)
                    valor = eta_cuadrado(grupos, b)
                else:
                    grupos = agrupar_categorias(b, max_categorias)
                    valor = eta_cuadrado(grupos, a)
            if pd.notna(valor):
                resultados.append({
                    "variable_1": nombre_a, "variable_2": nombre_b,
                    "metodo": metodo, "asociacion": round(float(valor), 4),
                    "registros": int(validos.sum())
                })
    return pd.DataFrame(resultados, columns=[
        "variable_1", "variable_2", "metodo", "asociacion", "registros"
    ]).sort_values("asociacion", ascending=False).reset_index(drop=True)


def agrupar_categorias(serie, max_categorias=20):
    """Agrupa valores poco frecuentes para evitar tablas gigantes."""
    texto = serie.astype("string").fillna("(FALTANTE)")
    principales = texto.value_counts().head(max_categorias).index
    return texto.where(texto.isin(principales), "OTRAS")


def relacion_faltantes(datos, objetivo, max_categorias=20):
    """Relaciona la ausencia de una columna con el resto de variables.

    Para numéricas utiliza eta cuadrado de la variable contra el indicador
    binario de ausencia. Para categóricas, V de Cramér.
    """
    if objetivo not in datos.columns:
        raise ValueError("La columna objetivo no existe.")
    falta = datos[objetivo].isna()
    if falta.nunique() < 2:
        return pd.DataFrame(columns=["variable", "tipo", "metodo", "asociacion", "registros"])
    resultados = []
    for columna in datos.columns:
        if columna == objetivo:
            continue
        serie = datos[columna]
        validos = serie.notna()
        if validos.sum() < 10:
            continue
        tipo = tipo_variable(serie[validos])
        if tipo == "numerica":
            metodo = "eta_cuadrado"
            valor = eta_cuadrado(falta[validos], serie[validos])
        else:
            metodo = "v_cramer"
            grupos = agrupar_categorias(serie[validos], max_categorias)
            valor = v_cramer(pd.crosstab(grupos, falta[validos]))
        if pd.notna(valor):
            resultados.append({
                "variable": columna, "tipo": tipo, "metodo": metodo,
                "asociacion": round(float(valor), 4),
                "registros": int(validos.sum())
            })
    return pd.DataFrame(resultados, columns=[
        "variable", "tipo", "metodo", "asociacion", "registros"
    ]).sort_values("asociacion", ascending=False).reset_index(drop=True)


def faltantes_por_categoria(datos, objetivo, categoria, max_categorias=20):
    """Porcentaje de ausencia del objetivo para cada grupo de otra columna."""
    grupos = agrupar_categorias(datos[categoria], max_categorias)
    tabla = pd.DataFrame({"grupo": grupos, "falta": datos[objetivo].isna()})
    resumen = tabla.groupby("grupo", dropna=False)["falta"].agg(["size", "sum", "mean"])
    resumen.columns = ["registros", "faltantes", "proporcion"]
    resumen["porcentaje_faltante"] = (resumen["proporcion"] * 100).round(2)
    return resumen.drop(columns="proporcion").sort_values("porcentaje_faltante", ascending=False)


def matriz_coausencia(datos):
    """Correlación entre indicadores de ausencia (NaN en columnas sin variación)."""
    return datos.isna().astype(int).corr()


# ============================================================
# EJEMPLOS EN JUPYTER: elimina el signo # para ejecutar
# ============================================================
# resultado_pares = relacion_pares(datos)
# display(resultado_pares.head(30))
#
# ausencias = matriz_coausencia(datos)
# display(ausencias)
#
# Para estudiar una columna concreta, solo si lo necesitas:
# objetivo = "Ingresos"  # Cambia por una columna real
# display(relacion_faltantes(datos, objetivo).head(30))
# categoria = "Segmento"  # Cambia por una columna real
# display(faltantes_por_categoria(datos, objetivo, categoria))
