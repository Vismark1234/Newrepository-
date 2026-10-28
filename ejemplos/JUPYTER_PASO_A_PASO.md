# Uso directo en un solo Jupyter Notebook

No necesitas escribir `from analisis_configurable import analizar`. Copia las funciones de `02_relaciones/relaciones.py` y `02_relaciones/analisis_configurable.py` en las celdas indicadas; elimina la línea `from relaciones import ...` de la segunda porque las funciones ya están definidas arriba.

## Celda 1: bibliotecas
```python
import pandas as pd
import numpy as np
from scipy.stats import chi2_contingency
```

## Celda 2: cargar datos
Si ya tienes un DataFrame llamado `datos`, omite la lectura.
```python
# datos = pd.read_csv("mis_datos.csv")
print(datos.shape)
display(datos.head())
display(datos.dtypes.to_frame("tipo"))
```

## Celda 3: funciones
Pega aquí **todo el código** de `02_relaciones/relaciones.py`, sin repetir los imports.

## Celda 4: función configurable
Pega aquí el código de `02_relaciones/analisis_configurable.py`, **sin la línea**:
`from relaciones import relacion_pares, relacion_faltantes, faltantes_por_categoria`

## Celda 5: indicar categorías y exclusiones
```python
categoricas = ["Segmento", "TipoCredito"]  # Edita con tus columnas reales
excluir = ["ClienteKey", "CarteraKey"]    # Opcional
```

## Celda 6: ejecutar TODO el análisis
```python
resultado = analizar(datos, categoricas=categoricas, excluir=excluir)
```

## Celda 7: revisar relaciones entre todas las variables
```python
display(resultado["relaciones"].head(30))
```

## Celda 8: revisar qué columnas se relacionan con las ausencias
```python
display(resultado["faltantes"].head(30))
```

## Celda 9: revisar todas las relaciones de una variable (opcional)
```python
nombre = "Saldo"  # Cambia por el nombre de una columna real
tabla = resultado["relaciones"]
filtro = (tabla["variable_1"] == nombre) | (tabla["variable_2"] == nombre)
display(tabla[filtro])
```

## Celda 10: guardar tablas (opcional)
```python
resultado["relaciones"].to_csv("relaciones.csv", index=False)
resultado["faltantes"].to_csv("faltantes.csv", index=False)
```

**Nota:** las columnas numéricas se seleccionan automáticamente. Si una columna tiene números guardados como texto, conviértela con `pd.to_numeric(datos["columna"], errors="coerce")` solo después de verificar su significado. Los nombres de ejemplo deben existir en tus datos. Las funciones no modifican el DataFrame original.
