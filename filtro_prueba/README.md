# Filtro de prueba

Separa imagenes en `enviar` y `omitidas`. Solo copia, no modifica ni borra originales. No llama a ninguna IA.

## Instalar (una sola vez, con internet)

1. Instalar Python 3.11 o superior.
2. En la carpeta del script ejecutar:

       python instalar.py

Instala las librerias de `requirements.txt` (opencv-python, numpy, pytesseract y Pillow).
En Windows instala Tesseract con winget si falta; puede pedir permiso o aceptar condiciones.
Si faltan los idiomas `spa`, `eng` u `osd`, los descarga en la carpeta `tessdata` del proyecto.
Sin winget, instalar Tesseract desde https://github.com/UB-Mannheim/tesseract/wiki y repetir el paso 2.

## Usar

    python filtro.py --entrada "D:\imagenes" --salida "D:\resultados"

Cada ejecucion crea una carpeta con `enviar/`, `omitidas/` y `reporte.csv` (decision, motivo y segundos).
Admite png, jpg, jpeg, tif, tiff y bmp. No lee PDF.

## Activar un formato (reglas.json)

Al inicio todos estan apagados: solo se omiten las hojas en blanco.

1. Guardar en `plantillas/` un escaneo limpio y derecho, recortado a la hoja, con los datos variables tapados en blanco.
2. `titulos_encabezado`: frases fijas del tercio superior. Deben aparecer todas.
3. `zonas_variables`: rectangulos donde van los datos, como [x1, y1, x2, y2] de 0 a 1.
   Ejemplo: [0.40, 0.20, 0.90, 0.25]. Deben ser pequenos: lo que se agregue dentro de ellos no se detecta.
4. `"activo": true`

El logo se compara como parte de la plantilla; por si solo nunca omite una hoja. El color no se usa.

Umbrales (`minimo_puntos`, `minima_proporcion`, `maximo_sobrante`, `similitud_texto`) son valores iniciales:
ajustarlos con las medidas de `reporte.csv`.

## Limites

- No corrige la perspectiva ni el fondo antes del OCR en fotos.
- Una pagina que continua un Invoice no se reconoce como tal.
- Un agregado pequeno, o dentro de una zona variable, puede pasar sin detectarse.

`pruebas.py` genera imagenes inventadas y ejecuta el filtro (usa Pillow y la fuente DejaVu).
