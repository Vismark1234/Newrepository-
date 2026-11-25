# ubica tesseract y sus idiomas, solo usa librerias incluidas en python
import os
import shutil
from pathlib import Path

BASE = Path(__file__).resolve().parent
CARPETA_IDIOMAS = BASE / "tessdata"


def buscar_tesseract():
    # primero el PATH, despues las carpetas habituales de windows
    ruta = shutil.which("tesseract")
    if ruta:
        return Path(ruta)
    for variable, resto in (
        ("ProgramFiles", "Tesseract-OCR"),
        ("ProgramFiles(x86)", "Tesseract-OCR"),
        ("LOCALAPPDATA", r"Programs\Tesseract-OCR"),
    ):
        if os.getenv(variable):
            candidato = Path(os.getenv(variable)) / resto / "tesseract.exe"
            if candidato.is_file():
                return candidato
    return None


def usar_idiomas_locales():
    # si el instalador creo la carpeta tessdata del proyecto, se usa esa
    if CARPETA_IDIOMAS.is_dir():
        os.environ["TESSDATA_PREFIX"] = str(CARPETA_IDIOMAS)
