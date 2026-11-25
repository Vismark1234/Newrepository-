# prueba con imagenes inventadas
import copy, json, random, shutil, subprocess, sys
from pathlib import Path
import cv2, numpy as np
from PIL import Image, ImageDraw, ImageFont
import filtro

random.seed(1)
def letra(t):
    return ImageFont.truetype("DejaVuSans.ttf", t)

def formulario(semilla, extra=None):
    r = random.Random(semilla)
    im = Image.new("L", (1240, 1754), 255); d = ImageDraw.Draw(im)
    d.ellipse((80, 70, 220, 210), outline=0, width=10); d.polygon([(150, 90), (195, 180), (105, 180)], fill=40)
    d.text((300, 110), "ORDEN DE TRANSFERENCIAS AL EXTERIOR", font=letra(34), fill=0)
    for i, e in enumerate(["Nombre del solicitante", "Direccion principal", "Numero de cuenta", "Importe solicitado", "Moneda de pago", "Motivo de la operacion", "Firma autorizada"]):
        y = 320 + i * 110
        d.rectangle((80, y, 1160, y + 90), outline=0, width=3); d.line((520, y, 520, y + 90), fill=0, width=3)
        d.text((100, y + 30), e, font=letra(28), fill=0)
        d.text((550, y + 30), str(r.randint(10**6, 10**9)), font=letra(28), fill=0)
    if extra == "captura":
        d.rectangle((150, 1180, 1100, 1650), outline=0, width=3)
        for i in range(9):
            d.text((180, 1210 + i * 48), f"Detalle {r.randint(1000,99999)} producto cantidad total {r.randint(100,9999)}", font=letra(26), fill=0)
    if extra == "invoice":
        d.text((200, 1300), "COMMERCIAL INVOICE No. 4471", font=letra(40), fill=0)
    return np.array(im)

base = Path("tmp_prueba"); shutil.rmtree(base, ignore_errors=True)
(base / "entrada").mkdir(parents=True); (base / "plantillas").mkdir()
cv2.imwrite(str(base / "plantillas/formulario.png"), formulario(0))
reglas = json.loads(Path("reglas.json").read_text())
reglas["formatos"] = [reglas["formatos"][0]]
reglas["formatos"][0].update(activo=True, titulos_encabezado=["ORDEN DE TRANSFERENCIAS AL EXTERIOR"], zonas_variables=[[0.43, 0.18, 0.93, 0.62]])
(base / "reglas.json").write_text(json.dumps(reglas))
normal = formulario(5)
casos = {"blanca": np.full((1754, 1240), 255, np.uint8), "formulario": normal,
 "inclinado": filtro.rotar(formulario(6), 3, 255), "girado90": cv2.rotate(formulario(7), cv2.ROTATE_90_CLOCKWISE),
 "al_reves": cv2.rotate(formulario(8), cv2.ROTATE_180),
 "con_captura": formulario(9, "captura"), "con_invoice": formulario(10, "invoice")}
for n, im in casos.items():
    cv2.imwrite(str(base / "entrada" / f"{n}.png"), im)
(base / "entrada/danada.jpg").write_bytes(b"x")
sys.exit(subprocess.run([sys.executable, "filtro.py", "--entrada", str(base / "entrada"), "--salida", str(base / "salida"), "--reglas", str(base / "reglas.json")]).returncode)
