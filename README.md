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

## Diagnóstico automático de TODAS las variables

No necesitas seleccionar una columna objetivo.

```python
import sys
sys.path.insert(0, "02_relaciones")

from analisis_global import analizar_todo, exportar_excel
from perfilado import normalizar_vacios

# Si importas perfilado, añade también "01_perfilado" a sys.path.
resultado = analizar_todo(datos)
display(resultado["relaciones"].head(30))
display(resultado["faltantes"].head(30))
display(resultado["categorias"].head(30))
display(resultado["coausencia"])

exportar_excel(resultado)
```

Para usar `normalizar_vacios`, añade primero `sys.path.insert(0, "01_perfilado")`. El análisis de pares con 103 columnas puede requerir tiempo; las medidas son exploratorias y no prueban causalidad. Para exportar a Excel, instala `openpyxl`.
