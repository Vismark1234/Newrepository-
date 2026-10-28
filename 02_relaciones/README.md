# Relaciones y ausencia

`relacion_faltantes(datos, objetivo)` identifica variables asociadas a que una columna esté ausente. Usa V de Cramér para categóricas y diferencia estandarizada de medianas para numéricas. Estas medidas **no son directamente comparables**. `matriz_coausencia(datos)` muestra si dos columnas suelen faltar simultáneamente. Una asociación no demuestra por qué faltan los datos.
