# Análisis de calidad de datos con Python

Herramientas para explorar conjuntos de datos con numerosas variables, detectar valores faltantes y estudiar sus posibles causas.

## Carpetas
- **01_perfilado/**: resumen automático de tipos, cardinalidad, nulos, vacíos y espacios.
- **02_relaciones/**: relación entre la ausencia y otras variables; matriz de coausencia.
- **03_imputacion/**: imputación numérica y categórica sin fuga de información.
- **ejemplos/**: uso con un DataFrame llamado `datos`.

## Instalación
```bash
pip install -r requirements.txt
```

## Uso en Jupyter
```python
import sys
sys.path.insert(0, "01_perfilado")
sys.path.insert(0, "02_relaciones")
from perfilado import normalizar_vacios, resumen_calidad
from relaciones import relacion_faltantes, matriz_coausencia

df = normalizar_vacios(datos)
print(resumen_calidad(df).head(30))
print(matriz_coausencia(df))
print(relacion_faltantes(df, objetivo="NOMBRE_DE_COLUMNA").head(20))
```

Las asociaciones son exploratorias y no demuestran causalidad. Revisa los códigos especiales de ausencia según tu fuente de datos. Ajusta imputadores únicamente sobre el conjunto de entrenamiento.
