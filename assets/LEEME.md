# Cómo poner assets gratuitos en el juego

1. Descarga un paquete **CC0** (sin crédito obligatorio, apto para Steam):
   - Kenney: https://kenney.nl/assets  (ciudad, edificios, mobiliario, armas)
   - Quaternius: https://quaternius.com  (personajes, props, edificios)
   - Poly Haven: https://polyhaven.com  (texturas y cielos)
   Evita las licencias con "NC" (no comercial). CC-BY vale si das crédito.
2. Copia los archivos `.glb` a `assets/modelos/` y las imágenes a
   `assets/texturas/`, **con el nombre de la tabla de abajo**.
3. Abre el proyecto en Godot (importa solo) y dale a jugar.
4. Apunta el paquete, el autor, la web y la licencia en `CREDITS.md`.

## Nombres que el juego reconoce

| Archivo en `assets/modelos/` | Dónde se usa |
|---|---|
| `farola.glb` | farolas de la calle (en lugar de poste y caja) |

(Se irá ampliando: cada vez que el código acepte un modelo nuevo se añade
una fila aquí. Si un archivo no existe, se dibuja la caja de siempre.)

| Archivo en `assets/texturas/` | Dónde se usa |
|---|---|
| `suelo.png` | suelo de las calles |

El tamaño de los modelos se ajusta en `scripts/assets.gd` (parámetro `escala`).
