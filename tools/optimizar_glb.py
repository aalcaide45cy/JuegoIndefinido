#!/usr/bin/env python3
"""Reduce las texturas de un GLB (por defecto a 1024 px, JPEG) y reescribe el archivo.
Uso: python3 -I tools/optimizar_glb.py entrada.glb salida.glb [lado_maximo]
Solo necesita Pillow."""
import io, json, struct, sys
from PIL import Image


def leer(ruta):
    d = open(ruta, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    p = 20 + n
    n2 = struct.unpack("<I", d[p:p + 4])[0]
    return j, d[p + 8:p + 8 + n2]


def escribir(ruta, j, binario):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binario += b"\0" * (-len(binario) % 4)
    total = 12 + 8 + len(js) + 8 + len(binario)
    with open(ruta, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binario), 0x004E4942) + binario)


def main(entrada, salida, lado=1024):
    j, b = leer(entrada)
    trozos = []
    imagenes = {im["bufferView"]: im for im in j.get("images", []) if "bufferView" in im}
    for i, bv in enumerate(j["bufferViews"]):
        datos = b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        if i in imagenes:
            img = Image.open(io.BytesIO(datos)).convert("RGB")
            img.thumbnail((lado, lado), Image.LANCZOS)
            out = io.BytesIO()
            img.save(out, "JPEG", quality=85, optimize=True)
            datos = out.getvalue()
            imagenes[i]["mimeType"] = "image/jpeg"
        trozos.append(datos)
    nuevo = b""
    for bv, datos in zip(j["bufferViews"], trozos):
        nuevo += b"\0" * (-len(nuevo) % 4)
        bv["byteOffset"] = len(nuevo)
        bv["byteLength"] = len(datos)
        nuevo += datos
    j["buffers"] = [{"byteLength": len(nuevo)}]
    escribir(salida, j, nuevo)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1024)
