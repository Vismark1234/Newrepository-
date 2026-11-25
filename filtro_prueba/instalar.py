# instala las librerias con pip y comprueba el ocr, uso: python instalar.py
# si existe la carpeta paquetes, instala desde ahi sin usar internet
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent


def principal():
    comando = [sys.executable, "-m", "pip", "install", "-r", str(BASE / "requirements.txt")]
    paquetes = BASE / "paquetes"
    if paquetes.is_dir():
        comando += ["--no-index", "--find-links", str(paquetes)]
    try:
        subprocess.run(comando, check=True)
        # se prueba en otro proceso para que vea lo recien instalado
        subprocess.run([sys.executable, "-c", "import cv2; from rapidocr import RapidOCR; RapidOCR()"], check=True)
    except subprocess.CalledProcessError:
        print("\nERROR: no se completo la instalacion, revise el mensaje anterior.", file=sys.stderr)
        return 1
    print("\nInstalacion lista.")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
