# Estilo low poly e interfaces

Todo el juego usa un aspecto **low poly**: caras planas, pocos polígonos, colores lisos y sin texturas pesadas. Así se ve coherente y pide pocos recursos.

## Mundo
- `scripts/estilo.gd` (clase `Estilo`): paleta común, `aplanar()` (cambia las texturas de los modelos de Quaternius por su color medio), `facetar()` (normales por cara).
- `Construir`: sin textura de grano en paredes y suelos; cilindros de 8 lados y esferas de 10x5, con caras planas.
- Texturas de piedra/ladrillo de la plaza → color liso. Kenney (vehículos, paleta plana) y los personajes se dejan igual.

## Interfaces
- Un solo tema (`Hud.crear_tema()`): botones, pestañas, listas desplegables, deslizadores, barras, campos de texto, menús y avisos.
- Esquinas **cortadas** (`corner_detail = 1`), borde grueso abajo en los botones, franja superior en las ventanas.
- Tipografía: `SystemFont` (Bahnschrift/Segoe UI si existen; si no, la de Godot). No se distribuye ningún archivo de letra.
- Animaciones suaves: las ventanas aparecen con fundido y escala; los botones crecen al pasar el ratón y se hunden al pulsar (`Estilo.animar_boton`).
- Paleta en `Estilo`: `FONDO`, `BORDE`, `ACENTO`, `ORO`, `TEXTO`, `PELIGRO`, `AVISO`, `INFO`, `MAGIA`.

## Cómo medirlo
```
godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_estilo.tscn -- <carpeta> todo
```
Saca capturas del mundo (8 sitios + noche) y de todas las ventanas, e imprime FPS, llamadas de dibujo y triángulos.
