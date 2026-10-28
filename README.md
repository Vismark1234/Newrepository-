# Relaciones entre variables y calidad de datos

Código Python sencillo y editable para explorar conjuntos de datos con muchas columnas.

## Estructura
- `01_perfilado/`: tipos de datos, valores únicos y datos faltantes.
- `02_relaciones/`: relaciones entre numéricas, categóricas y ausencia de datos.
- `03_imputacion/`: imputación básica.
- `ejemplos/`: ejecución con el DataFrame `datos`.

## Instalación
```bash
pip install -r requirements.txt
```

## En Jupyter Notebook
```python
import sys
sys.path.insert(0, "01_perfilado")
sys.path.insert(0, "02_relaciones")

from perfilado import normalizar_vacios, resumen_calidad
from relaciones import relacion_pares, relacion_faltantes, faltantes_por_categoria

datos = normalizar_vacios(datos)
print(resumen_calidad(datos).head(20))

# Relaciones entre todas las columnas
relaciones = relacion_pares(datos)
print(relaciones.head(30))

# ¿Con qué variables se relaciona la ausencia de una columna?
ranking = relacion_faltantes(datos, "Ingreso")
print(ranking.head(20))

# ¿Qué porcentaje falta en cada categoría?
print(faltantes_por_categoria(datos, "Ingreso", "Segmento"))
```

Sustituye `Ingreso` y `Segmento` por nombres de columnas reales. Se utiliza código explícito, sin lambdas. Las métricas son exploratorias, no prueban causalidad. Las medidas de asociación no son idénticas entre tipos de variables; revisa siempre el tamaño de cada grupo.
