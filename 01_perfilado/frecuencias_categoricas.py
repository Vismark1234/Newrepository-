"""Tabla de frecuencias y gráfico para una columna categórica.

Cada porcentaje usa como denominador el total de filas del DataFrame.
Los valores nulos, vacíos o con solo espacios cuentan como '(Sin dato)'.
"""

import pandas as pd
import matplotlib.pyplot as plt


def frecuencia_categorica(datos: pd.DataFrame, columna: str,
                          graficar: bool = True, max_categorias: int = 15) -> pd.DataFrame:
    """Agrupa una columna y devuelve cantidad, porcentaje y acumulado.

    El resultado incluye una fila TOTAL. El gráfico usa cantidades y
    muestra los porcentajes de cada grupo. Si hay demasiadas categorías,
    el gráfico agrupa las restantes como 'OTRAS CATEGORÍAS', sin excluirlas
    del total ni de la tabla de frecuencias.
    """
    if columna not in datos.columns:
        raise KeyError(f"La columna '{columna}' no existe en el DataFrame.")
    if max_categorias < 1:
        raise ValueError("max_categorias debe ser mayor o igual a 1.")

    total = len(datos)
    if total == 0:
        return pd.DataFrame([{
            "Categoria": "TOTAL", "Cantidad": 0,
            "Porcentaje": 0.0, "Porcentaje acumulado": 0.0
        }])

    valores = datos[columna].astype("string").str.strip()
    valores = valores.replace("", pd.NA).fillna("(Sin dato)")

    resumen = valores.value_counts().rename_axis("Categoria").reset_index(name="Cantidad")
    resumen["Categoria"] = resumen["Categoria"].astype(str)
    resumen["Porcentaje"] = (resumen["Cantidad"] / total * 100).round(2)
    resumen["Porcentaje acumulado"] = (resumen["Cantidad"].cumsum() / total * 100).round(2)

    fila_total = pd.DataFrame([{
        "Categoria": "TOTAL", "Cantidad": total,
        "Porcentaje": 100.0, "Porcentaje acumulado": 100.0
    }])
    tabla = pd.concat([resumen, fila_total], ignore_index=True)

    if graficar:
        grafico = resumen.head(max_categorias).copy()
        if len(resumen) > max_categorias:
            otras = int(resumen.iloc[max_categorias:]["Cantidad"].sum())
            fila_otras = pd.DataFrame([{
                "Categoria": "OTRAS CATEGORÍAS", "Cantidad": otras,
                "Porcentaje": round(otras / total * 100, 2)
            }])
            grafico = pd.concat([grafico, fila_otras], ignore_index=True)

        fig, ax = plt.subplots(figsize=(10, max(4, 0.5 * len(grafico) + 1)))
        barras = ax.barh(grafico["Categoria"], grafico["Cantidad"])
        ax.invert_yaxis()
        limite = max(1, float(grafico["Cantidad"].max()) * 1.5)
        for barra, cantidad, porcentaje in zip(
            barras, grafico["Cantidad"], grafico["Porcentaje"]
        ):
            ax.text(
                barra.get_width() + limite * 0.01,
                barra.get_y() + barra.get_height() / 2,
                f"{cantidad:,} ({porcentaje:.2f}%)", va="center"
            )
        ax.set_xlim(0, limite)
        ax.set_xlabel("Cantidad de registros")
        ax.set_title(f"Distribución de {columna} | Total: {total:,} registros")
        ax.grid(axis="x", alpha=0.25)
        plt.tight_layout()
        plt.show()

    return tabla


# ============================================================
# EJEMPLO DE USO EN JUPYTER NOTEBOOK
# ============================================================
# datos es tu DataFrame ya cargado.
# Si estás en la raíz del repositorio, ejecuta en tu notebook:
#
# import sys
# sys.path.insert(0, "01_perfilado")
# from frecuencias_categoricas import frecuencia_categorica
#
# tabla = frecuencia_categorica(datos, "Segmento")
# display(tabla)
#
# # Otra columna, sin gráfico:
# tabla2 = frecuencia_categorica(datos, "EstadoCivil", graficar=False)
# display(tabla2)
#
# # Si hay muchas categorías, muestra las 10 mayores y agrupa las otras
# # SOLO en el gráfico (la tabla sigue incluyendo todas):
# tabla3 = frecuencia_categorica(datos, "Ciudad", max_categorias=10)
# display(tabla3)
