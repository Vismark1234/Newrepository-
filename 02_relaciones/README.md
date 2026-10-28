# Relaciones entre variables

## 1. Analizar todos los pares
```python
from relaciones import relacion_pares
resultado = relacion_pares(datos)
print(resultado.head(30))
```

- **Spearman:** relación monotónica entre dos variables numéricas. Se muestra su magnitud absoluta; no su dirección.
- **V de Cramér:** asociación entre dos variables categóricas (0 a 1).
- **Eta cuadrado:** diferencia de una variable numérica entre categorías (0 a 1).

**Importante:** son métricas distintas, no deben interpretarse como equivalentes. Una asociación alta no demuestra causalidad. Una variable numérica con 10 o menos valores distintos se trata como categórica por defecto; cambia el parámetro si tus códigos numéricos no representan categorías.

## 2. Entender los faltantes
```python
from relaciones import relacion_faltantes, faltantes_por_categoria

ranking = relacion_faltantes(datos, "Ingreso")
print(ranking.head(20))

detalle = faltantes_por_categoria(datos, "Ingreso", "Segmento")
print(detalle)
```

El ranking compara la ausencia de `Ingreso` con otras columnas. La tabla de detalle muestra el porcentaje de registros sin ingreso por segmento.

## 3. Ausencias simultáneas
```python
from relaciones import matriz_coausencia
print(matriz_coausencia(datos))
```

Antes del análisis, convierte códigos especiales de ausencia a NaN y verifica la calidad de tus columnas. Las asociaciones con categorías poco frecuentes pueden ser inestables; revisa siempre el número de registros.
