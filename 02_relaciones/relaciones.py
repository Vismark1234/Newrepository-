"""Asociación exploratoria entre ausencia de una variable y otras columnas."""
import numpy as np
import pandas as pd
from scipy.stats import chi2_contingency, mannwhitneyu

def relacion_faltantes(datos: pd.DataFrame, objetivo: str, max_categorias: int = 20) -> pd.DataFrame:
    """Compara presencia/ausencia de objetivo con predictores categóricos y numéricos.

    Categóricos: V de Cramér; numéricos: diferencia estandarizada de medianas.
    Son medidas distintas: no comparar directamente sus magnitudes.
    """
    if objetivo not in datos.columns:
        raise KeyError(f"No existe la columna: {objetivo}")
    y = datos[objetivo].isna()
    if y.nunique() < 2:
        return pd.DataFrame(columns=["variable", "tipo", "medida", "valor", "n_validos"])
    resultados = []
    for col in datos.columns:
        if col == objetivo:
            continue
        s = datos[col]
        validos = s.notna()
        if validos.sum() < 10:
            continue
        if pd.api.types.is_numeric_dtype(s) and not pd.api.types.is_bool_dtype(s):
            a = s[validos & y]
            b = s[validos & ~y]
            if len(a) < 3 or len(b) < 3:
                continue
            escala = s[validos].std()
            efecto = abs(a.median() - b.median()) / escala if pd.notna(escala) and escala > 0 else 0.0
            resultados.append((col, "numerica", "diferencia_medianas_estandarizada", float(efecto), int(validos.sum())))
        else:
            categorias = s.astype("string").fillna("(faltante)")
            frecuentes = categorias.value_counts().head(max_categorias).index
            agrupadas = categorias.where(categorias.isin(frecuentes), "(otras)")
            tabla = pd.crosstab(agrupadas, y)
            if min(tabla.shape) < 2:
                continue
            chi2 = chi2_contingency(tabla, correction=False)[0]
            n = tabla.to_numpy().sum()
            v = np.sqrt(chi2 / (n * min(tabla.shape[0]-1, tabla.shape[1]-1))) if n else 0
            resultados.append((col, "categorica", "v_cramer", float(v), int(validos.sum())))
    return pd.DataFrame(resultados, columns=["variable", "tipo", "medida", "valor", "n_validos"]).sort_values(["tipo", "valor"], ascending=[True, False]).reset_index(drop=True)

def matriz_coausencia(datos: pd.DataFrame) -> pd.DataFrame:
    """Correlación phi entre indicadores binarios de ausencia; NaN si son constantes."""
    return datos.isna().astype(int).corr()
