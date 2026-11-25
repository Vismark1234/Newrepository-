# instala lo necesario y comprueba que funcione, se ejecuta una vez: python instalar.py
import shutil
import subprocess
import sys
import urllib.request

from entorno import BASE, CARPETA_IDIOMAS, buscar_tesseract, usar_idiomas_locales

IDIOMAS = ("spa", "eng", "osd")
URL_IDIOMAS = "https://github.com/tesseract-ocr/tessdata_fast/raw/main/{}.traineddata"


def instalar_librerias():
    print("1. Instalando librerias de Python...")
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", str(BASE / "requirements.txt")], check=True)


def instalar_tesseract():
    # devuelve la ruta de tesseract, en windows lo instala con winget si falta
    print("2. Buscando Tesseract...")
    ruta = buscar_tesseract()
    if ruta:
        return ruta

    if sys.platform != "win32" or shutil.which("winget") is None:
        raise RuntimeError(
            "No se encontro Tesseract. Instalelo y vuelva a ejecutar este archivo. "
            "Windows: https://github.com/UB-Mannheim/tesseract/wiki"
        )

    subprocess.run(["winget", "install", "-e", "--id", "UB-Mannheim.TesseractOCR"], check=True)
    ruta = buscar_tesseract()
    if ruta is None:
        raise RuntimeError("Tesseract se instalo pero no se encontro. Cierre la terminal y vuelva a ejecutar.")
    return ruta


def listar_idiomas(ruta):
    resultado = subprocess.run([str(ruta), "--list-langs"], capture_output=True, text=True, check=True)
    return set((resultado.stdout + resultado.stderr).split())


def preparar_idiomas(ruta):
    # si falta algun idioma se crea tessdata en el proyecto, asi no se necesitan permisos de administrador
    print("3. Comprobando idiomas...")
    usar_idiomas_locales()
    if set(IDIOMAS) <= listar_idiomas(ruta):
        return

    CARPETA_IDIOMAS.mkdir(exist_ok=True)
    for idioma in IDIOMAS:
        destino = CARPETA_IDIOMAS / f"{idioma}.traineddata"
        if destino.is_file():
            continue
        print(f"   Descargando {idioma}...")
        temporal = destino.with_suffix(".parte")
        with urllib.request.urlopen(URL_IDIOMAS.format(idioma), timeout=120) as respuesta:
            temporal.write_bytes(respuesta.read())
        temporal.replace(destino)

    usar_idiomas_locales()
    faltan = set(IDIOMAS) - listar_idiomas(ruta)
    if faltan:
        raise RuntimeError(f"Faltan idiomas: {', '.join(sorted(faltan))}")


def comprobar_librerias():
    # se prueba en otro proceso para que vea lo recien instalado
    print("4. Comprobando librerias...")
    subprocess.run([sys.executable, "-c", "import cv2, numpy, pytesseract, PIL"], check=True)


def principal():
    try:
        if sys.version_info < (3, 11):
            raise RuntimeError("Se necesita Python 3.11 o superior.")
        instalar_librerias()
        ruta = instalar_tesseract()
        preparar_idiomas(ruta)
        comprobar_librerias()
    except Exception as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        return 1
    print("\nInstalacion lista.")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
