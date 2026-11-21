# Vehículos 3D hechos con IA

Los vehículos del juego ya no son los modelos de Kenney sin más: ahora cada
carrocería es un modelo 3D con volumen (ventanas, faros, interior, retrovisores)
generado con Higgsfield, y **las ruedas son nodos aparte** que ruedan y viran.

## Cómo se hicieron
1. Imagen de referencia por vehículo (`gpt_image_2_6`), estilo low poly, **sin
   ruedas** (el hueco de la rueda vacío) y fondo blanco.
2. Imagen a 3D con `meshy_v7_image_to_3d` (texturizado, ~10 000–12 000 triángulos).
3. `tools/optimizar_glb.py` reduce la textura a 1024 px JPEG: de ~3 MB a ~0,7 MB por modelo.
4. Las ruedas (Kenney, CC0) se colocan por código (`scripts/vehiculos/modelo_vehiculo.gd`,
   tabla `DATOS`). Esas posiciones se calibraron con vistas laterales medidas.

Coste en créditos de Higgsfield: unos 38 por modelo 3D + 0,25 por imagen
(15 vehículos ≈ 600 créditos con las pruebas).

## Archivos
- `assets/vehiculos/<tipo>.glb`: sedan, hatchback, taxi, suv, furgoneta, camion, tractor,
  excavadora, trailer, remolque_carga, remolque_grande, portacoches, deportivo,
  helicoptero, avion. Los nombres coinciden con las claves de `Vehiculo.TIPOS`.
- Frente del modelo en **-X** (el código lo gira a -Z).
- `ModeloVehiculo.crear(tipo, largo, con_direccion)` monta el vehículo y devuelve ruedas y hélices.

## Comportamiento
- Conduciendo: las ruedas giran según la velocidad y las delanteras viran (hasta ~29°).
- Remolques: ruedan al ser arrastrados.
- Tráfico de la ciudad: los coches de `vida_urbana.gd` usan los mismos modelos con las ruedas girando.
- Helicóptero y avioneta: carrocería nueva y hélices como nodos que giran.
- Si falta un GLB, el juego usa los modelos de Kenney o cajas como antes.

## Probado en Godot (2026-11-21)
Se probó en el PC con `tests/captura_vehiculos.tscn` (ventana fuera de pantalla) y con
`tests/captura_trafico.tscn`:
- Orientación: los 15 vehículos miran a -Z (frente) y ningún modelo sale girado.
- Altura: la parte baja de las ruedas queda en y = 0 (no flotan) en todos los vehículos con ruedas.
- Largo: la carrocería mide justo lo pedido en `Vehiculo.TIPOS` (helicóptero y avioneta son más
  largos por las hélices).
- Ruedas: giran con `rotation.x -= v*dt/radio`, el signo correcto para avanzar hacia -Z; al virar
  a la izquierda (`direccion > 0`) las delanteras giran con `rotation.y > 0`, también correcto.
- Hélices: se mueven con `rotate(eje, ...)` en `vehiculo.gd` (aire); se ven en su sitio.
- Tráfico: los coches de la ciudad usan los modelos nuevos.
No hizo falta cambiar `modelo_vehiculo.gd`.
Detalle menor: la excavadora hunde 14 cm la carrocería bajo el suelo (`suelo` 0.057).
