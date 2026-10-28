"""Comparar automáticamente TODAS las columnas numéricas de un DataFrame.

Ejemplo:
    resultado = analizar_numericas(datos)
    print(resultado["correlaciones"].head(30))
"""
import pandas as pd


def analizar_numericas(datos, minimo_registros=10):
    """Calcula correlaciones y diferencias entre todos los pares numéricos.

    No selecciona una variable objetivo. Usa solo filas donde ambos valores existen.
    No modifica el DataFrame original.
    """
    numericas = datos.select_dtypes(include="number")
    columnas = numericas.columns.tolist()
    comparaciones = []

    for i in range(len(columnas)):
        for j in range(i + 1, len(columnas)):
            nombre_a = columnas[i]
            nombre_b = columnas[j]
            pares = numericas[[nombre_a, nombre_b]].dropna()
            cantidad = len(pares)
            if cantidad < minimo_registros:
                continue
            if pares[nombre_a].nunique() < 2 or pares[nombre_b].nunique() < 2:
                continue

            pearson = pares[nombre_a].corr(pares[nombre_b], method="pearson")
            spearman = pares[nombre_a].corr(pares[nombre_b], method="spearman")
            comparaciones.append({
                "variable_1": nombre_a,
                "variable_2": nombre_b,
                "registros_comparados": cantidad,
                "pearson": round(float(pearson), 4),
                "spearman": round(float(spearman), 4),
                "fuerza_spearman": round(abs(float(spearman)), 4)
            })

    columnas_resultado = [
        "variable_1", "variable_2", "registros_comparados",
        "pearson", "spearman", "fuerza_spearman"
    ]
    tabla = pd.DataFrame(comparaciones, columns=columnas_resultado)
    tabla = tabla.sort_values("fuerza_spearman", ascending=False)

    resumen = pd.DataFrame({
        "variable": columnas,
        "tipo": [str(numericas[col].dtype) for col in columnas],
        "faltantes": [int(numericas[col].isna().sum()) for col in columnas],
        "media": [numericas[col].mean() for col in columnas],
        "mediana": [numericas[col].median() for col in columnas],
        "minimo": [numericas[col].min() for col in columnas],
        "maximo": [numericas[col].max() for col in columnas]
    })
    return {
        "correlaciones": tabla.reset_index(drop=True),
        "matriz_pearson": numericas.corr(method="pearson"),
        "matriz_spearman": numericas.corr(method="spearman"),
        "resumen": resumen
    }


def correlaciones_de_variable(resultado, columna):
    """Filtra las relaciones donde aparece una columna específica."""
    tabla = resultado["correlaciones"]
    filtro = (tabla["variable_1"] == columna) | (tabla["variable_2"] == columna)
    return tabla[filtro].copy()


def comparar_por_diferencias(datos, columna_a, columna_b):
    """Compara fila a fila dos columnas numéricas con la misma unidad de medida."""
    tabla = datos[[columna_a, columna_b]].dropna().copy()
    tabla["diferencia"] = tabla[columna_a] - tabla[columna_b]
    tabla["diferencia_absoluta"] = tabla["diferencia"].abs()
    return tabla
