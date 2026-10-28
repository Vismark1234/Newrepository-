"""Ejemplo: ejecutar cuando el DataFrame 'datos' ya esté cargado."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "01_perfilado"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "02_relaciones"))

from perfilado import normalizar_vacios, resumen_calidad
from relaciones import relacion_faltantes, matriz_coausencia

# En Jupyter, tras cargar 'datos':
# datos = pd.read_csv("archivo.csv")
df = normalizar_vacios(datos)
perfil = resumen_calidad(df)
print(perfil.head(30))
print(matriz_coausencia(df).round(2))
columnas_incompletas = perfil.index[perfil["faltantes"] > 0]
if len(columnas_incompletas):
    objetivo = columnas_incompletas[0]
    print("Análisis de ausencia:", objetivo)
    print(relacion_faltantes(df, objetivo).head(20))
