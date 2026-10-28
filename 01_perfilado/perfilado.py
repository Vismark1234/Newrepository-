"""Perfilado automático de columnas y valores ausentes."""
import pandas as pd

def normalizar_vacios(datos: pd.DataFrame) -> pd.DataFrame:
    """Convierte cadenas vacías o con espacios a valores ausentes."""
    copia = datos.copy()
    columnas = copia.select_dtypes(include=["object", "string"]).columns
    for col in columnas:
        copia[col] = copia[col].replace(r"^\s*$", pd.NA, regex=True)
    return copia

def resumen_calidad(datos: pd.DataFrame) -> pd.DataFrame:
    """Resumen de tipos, nulos, porcentaje faltante y cardinalidad."""
    df = normalizar_vacios(datos)
    n = len(df)
    resultado = pd.DataFrame({
        "tipo": df.dtypes.astype(str),
        "faltantes": df.isna().sum(),
        "porcentaje_faltante": df.isna().mean().mul(100).round(2) if n else 0,
        "valores_unicos": df.nunique(dropna=True),
    })
    resultado["completos"] = n - resultado["faltantes"]
    return resultado.sort_values("porcentaje_faltante", ascending=False)
