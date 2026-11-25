# filtro local para pruebas, decide que imagenes se mandan a la ia y cuales se omiten
# ante cualquier duda o error la imagen se manda, los originales nunca se modifican
# uso: python filtro.py --entrada CARPETA --salida CARPETA
import argparse
import csv
import json
import shutil
import sys
import time
import unicodedata
from datetime import datetime
from difflib import SequenceMatcher
from pathlib import Path

import cv2
import numpy as np
import pytesseract

from entorno import buscar_tesseract, usar_idiomas_locales

BASE = Path(__file__).resolve().parent
EXTENSIONES = (".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp")

# tesseract se ubica solo, aunque no este en el PATH
if buscar_tesseract():
    pytesseract.pytesseract.tesseract_cmd = str(buscar_tesseract())
usar_idiomas_locales()


def leer_imagen(ruta):
    # se lee por bytes para que funcionen las rutas con tildes en windows
    datos = np.fromfile(str(ruta), dtype=np.uint8)
    imagen = cv2.imdecode(datos, cv2.IMREAD_GRAYSCALE)
    if imagen is None:
        raise ValueError("no se pudo leer la imagen")
    return imagen


def reducir(imagen, lado_maximo):
    # reduce las imagenes grandes para ir mas rapido
    escala = lado_maximo / max(imagen.shape)
    if escala >= 1:
        return imagen
    return cv2.resize(imagen, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)


def mascara_tinta(imagen):
    # pixeles bastante mas oscuros que su fondo, tolera sombras suaves
    fondo = cv2.medianBlur(cv2.dilate(imagen, np.ones((15, 15), np.uint8)), 21)
    tinta = (cv2.subtract(fondo, imagen) > 25).astype(np.uint8) * 255
    # se ignora el borde, suele tener sombras del scanner
    alto, ancho = tinta.shape
    my, mx = int(alto * 0.02), int(ancho * 0.02)
    tinta[:my], tinta[-my:], tinta[:, :mx], tinta[:, -mx:] = 0, 0, 0, 0
    return tinta


def girar_orientacion(imagen):
    # corrige 90, 180 y 270 grados, si tesseract no esta seguro la deja igual
    try:
        datos = pytesseract.image_to_osd(imagen, output_type=pytesseract.Output.DICT)
    except pytesseract.TesseractError:
        return imagen
    if datos["orientation_conf"] < 2:
        return imagen
    giros = {90: cv2.ROTATE_90_CLOCKWISE, 180: cv2.ROTATE_180, 270: cv2.ROTATE_90_COUNTERCLOCKWISE}
    if datos["rotate"] in giros:
        return cv2.rotate(imagen, giros[datos["rotate"]])
    return imagen


def rotar(imagen, angulo, fondo):
    # rota sin recortar las esquinas
    alto, ancho = imagen.shape
    matriz = cv2.getRotationMatrix2D((ancho / 2, alto / 2), angulo, 1)
    coseno, seno = abs(matriz[0, 0]), abs(matriz[0, 1])
    nuevo_ancho = int(alto * seno + ancho * coseno)
    nuevo_alto = int(alto * coseno + ancho * seno)
    matriz[0, 2] += (nuevo_ancho - ancho) / 2
    matriz[1, 2] += (nuevo_alto - alto) / 2
    return cv2.warpAffine(imagen, matriz, (nuevo_ancho, nuevo_alto), borderValue=fondo)


def enderezar(imagen):
    # busca el angulo en que las lineas de texto quedan mas marcadas
    chica = mascara_tinta(reducir(imagen, 800))

    def puntaje(angulo):
        filas = rotar(chica, angulo, 0).sum(axis=1, dtype=np.float64)
        return np.sum(np.diff(filas) ** 2)

    mejor = max(np.arange(-10, 10.1, 0.5), key=puntaje)
    if abs(mejor) < 0.5 or puntaje(mejor) < puntaje(0) * 1.05:
        return imagen
    return rotar(imagen, float(mejor), 255)


def normalizar(texto):
    # minusculas, sin tildes y con un solo espacio
    texto = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return " ".join(texto.lower().split())


def leer_texto(imagen, idioma):
    # devuelve el texto de toda la pagina y el del tercio superior
    datos = pytesseract.image_to_data(imagen, lang=idioma, config="--psm 3", output_type=pytesseract.Output.DICT)
    todo, arriba = [], []
    for palabra, y in zip(datos["text"], datos["top"]):
        if palabra.strip():
            todo.append(palabra)
            if y < imagen.shape[0] * 0.35:
                arriba.append(palabra)
    return normalizar(" ".join(todo)), normalizar(" ".join(arriba))


def contiene(texto, frase, minimo):
    # busca una frase aunque el ocr falle en algunas letras
    frase = normalizar(frase)
    palabras = texto.split()
    cantidad = len(frase.split())
    for i in range(len(palabras) - cantidad + 1):
        trozo = " ".join(palabras[i:i + cantidad])
        if SequenceMatcher(None, frase, trozo, autojunk=False).ratio() >= minimo:
            return True
    return False


def esta_en_blanco(imagen, texto):
    # solo es blanca si no hay texto y casi no hay marcas
    marcas = np.count_nonzero(mascara_tinta(reducir(imagen, 1600))) / reducir(imagen, 1600).size
    return texto == "" and marcas < 0.0003 and imagen.std() < 12


def comparar_plantilla(imagen, plantilla, zonas_variables):
    # alinea la pagina con la plantilla
    # devuelve coincidencias coherentes, proporcion de puntos coherentes y contenido sin explicar
    pagina = reducir(imagen, 1600)
    plantilla = reducir(plantilla, 1600)
    orb = cv2.ORB_create(4000)
    puntos_p, desc_p = orb.detectAndCompute(plantilla, None)
    puntos_i, desc_i = orb.detectAndCompute(pagina, None)
    if desc_p is None or desc_i is None:
        return 0, 0.0, 1.0

    pares = cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(desc_i, desc_p, k=2)
    buenos = [par[0] for par in pares if len(par) == 2 and par[0].distance < 0.75 * par[1].distance]
    if len(buenos) < 10:
        return 0, 0.0, 1.0

    origen = np.float32([puntos_i[m.queryIdx].pt for m in buenos])
    destino = np.float32([puntos_p[m.trainIdx].pt for m in buenos])
    matriz, validos = cv2.findHomography(origen, destino, cv2.RANSAC, 5.0)
    if matriz is None:
        return 0, 0.0, 1.0

    coherentes = int(validos.sum())
    alto, ancho = plantilla.shape
    alineada = cv2.warpPerspective(pagina, matriz, (ancho, alto), borderValue=255)

    # tinta de la pagina que no esta en la plantilla ni en las zonas de datos
    # una captura de invoice insertada aparece aqui
    base = cv2.dilate(mascara_tinta(plantilla), np.ones((11, 11), np.uint8))
    sobrante = cv2.bitwise_and(mascara_tinta(alineada), cv2.bitwise_not(base))
    for x1, y1, x2, y2 in zonas_variables:
        sobrante[int(y1 * alto):int(y2 * alto), int(x1 * ancho):int(x2 * ancho)] = 0

    # tambien se mide lo que queda fuera de la plantilla despues de alinear
    afuera = mascara_tinta(pagina)
    cubierto = cv2.warpPerspective(np.full((alto, ancho), 255, np.uint8), np.linalg.inv(matriz),
                                   (pagina.shape[1], pagina.shape[0]))
    fuera = np.count_nonzero(afuera[cubierto == 0]) / max(np.count_nonzero(afuera), 1)

    # se revisa por cuadros, un recuadro agregado se concentra en una parte de la hoja
    peor = 0.0
    for fila in np.array_split(sobrante, 8, axis=0):
        for cuadro in np.array_split(fila, 6, axis=1):
            peor = max(peor, np.count_nonzero(cuadro) / cuadro.size)

    return coherentes, coherentes / len(buenos), max(peor, fuera)


def decidir(imagen, reglas, plantillas):
    # devuelve la decision, el motivo y la imagen enderezada
    imagen = enderezar(girar_orientacion(imagen))
    texto, encabezado = leer_texto(imagen, reglas["idioma_ocr"])

    if esta_en_blanco(imagen, texto):
        return "omitir", "pagina en blanco", imagen

    if any(contiene(texto, p, reglas["similitud_texto"]) for p in reglas["palabras_que_siempre_se_envian"]):
        return "enviar", "posible invoice", imagen

    detalles = []
    for formato in reglas["formatos"]:
        if not formato["activo"]:
            continue
        nombre = formato["nombre"]
        titulos = formato["titulos_encabezado"]
        # sin titulos la regla esta incompleta y no puede omitir nada
        if not titulos or not all(contiene(encabezado, t, reglas["similitud_texto"]) for t in titulos):
            detalles.append(f"{nombre}: no coincide el encabezado")
            continue

        for plantilla in plantillas[nombre]:
            coherentes, proporcion, sobrante = comparar_plantilla(imagen, plantilla, formato["zonas_variables"])
            medida = f"{nombre}: puntos={coherentes} proporcion={proporcion:.2f} sobrante={sobrante:.3f}"
            detalles.append(medida)
            if (coherentes >= reglas["minimo_puntos"] and proporcion >= reglas["minima_proporcion"]
                    and sobrante <= reglas["maximo_sobrante"]):
                return "omitir", medida, imagen

    return "enviar", "duda o sin formato a omitir. " + "; ".join(detalles), imagen


def cargar_reglas(ruta):
    # lee las reglas y las plantillas de los formatos activos
    reglas = json.loads(ruta.read_text(encoding="utf-8-sig"))
    plantillas = {}
    for formato in reglas["formatos"]:
        if formato["activo"]:
            if not formato["plantillas"]:
                raise ValueError(f"{formato['nombre']} esta activo y no tiene plantillas")
            plantillas[formato["nombre"]] = [leer_imagen(ruta.parent / p) for p in formato["plantillas"]]
    return reglas, plantillas


def principal():
    lector = argparse.ArgumentParser(description="Separa las imagenes que se mandan y las que se omiten.")
    lector.add_argument("--entrada", type=Path, required=True, help="carpeta de imagenes")
    lector.add_argument("--salida", type=Path, required=True, help="carpeta de resultados")
    lector.add_argument("--reglas", type=Path, default=BASE / "reglas.json")
    argumentos = lector.parse_args()

    try:
        if not argumentos.entrada.is_dir():
            raise ValueError(f"no existe la carpeta {argumentos.entrada}")
        reglas, plantillas = cargar_reglas(argumentos.reglas.resolve())
        pytesseract.get_tesseract_version()
        faltan = set(reglas["idioma_ocr"].split("+") + ["osd"]) - set(pytesseract.get_languages())
        if faltan:
            raise ValueError(f"faltan idiomas de tesseract: {', '.join(sorted(faltan))}")
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    # cada ejecucion usa su propia carpeta, asi no se mezclan resultados
    corrida = argumentos.salida / f"{datetime.now():%Y%m%d_%H%M%S_%f}"
    entrada = argumentos.entrada.resolve()
    salida = argumentos.salida.resolve()
    rutas = sorted(
        r for r in entrada.rglob("*")
        if r.is_file() and r.suffix.lower() in EXTENSIONES and salida not in r.parents
    )
    for carpeta in ("enviar", "omitidas"):
        (corrida / carpeta).mkdir(parents=True, exist_ok=True)

    totales = {"enviar": 0, "omitir": 0}
    with (corrida / "reporte.csv").open("w", newline="", encoding="utf-8-sig") as archivo:
        reporte = csv.writer(archivo, delimiter=";")
        reporte.writerow(["imagen", "decision", "motivo", "segundos"])

        for ruta in rutas:
            inicio = time.perf_counter()
            try:
                # un tiff de varias paginas no se analiza, se manda completo
                if ruta.suffix.lower() in (".tif", ".tiff") and cv2.imcount(str(ruta)) > 1:
                    raise ValueError("tiff con varias paginas")
                decision, motivo, _ = decidir(leer_imagen(ruta), reglas, plantillas)
            except Exception as error:
                decision, motivo = "enviar", f"error del filtro: {error}"

            carpeta = "omitidas" if decision == "omitir" else "enviar"
            destino = corrida / carpeta / ruta.relative_to(entrada)
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ruta, destino)

            segundos = time.perf_counter() - inicio
            totales[decision] += 1
            nombre = str(ruta.relative_to(entrada))
            reporte.writerow([nombre, decision, motivo, f"{segundos:.2f}"])
            print(f"{nombre}: {decision.upper()} ({segundos:.1f} s) - {motivo}")

    print(f"\nImagenes: {len(rutas)} | enviar: {totales['enviar']} | omitidas: {totales['omitir']}")
    print(f"Resultados en: {corrida}")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
