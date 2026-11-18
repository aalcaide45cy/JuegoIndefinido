# Mundo grande de 10 km x 10 km

Estado: escrito en la nube, **sin probar en Godot**. Si algo falla, mira primero la consola y las
constantes de `scripts/mundo/gestor_trozos.gd`.

## Cómo funciona
- `generador_mundo.gd`: funciones puras que, a partir de una **semilla** (`GestorTrozos.SEMILLA`), dan
  siempre el mismo mundo: terreno (llanuras, colinas, montañas de hasta ~150 m), aldeas / pueblos /
  ciudades con calles, casas y huertos, carreteras entre ellos y bosques de pinos.
- `gestor_trozos.gd`: carga y descarga trozos según dónde esté el jugador.
  - Cerca: trozos de 128 m (radio ~580 m) con choques, carreteras, casas, huertos y árboles.
  - Lejos: trozos de 512 m (radio ~2,3 km) solo para verse (terreno, carreteras, casas en cajas).
  - Generación en hilos (`USAR_HILOS`) y como mucho 2 trozos montados por fotograma.
  - Muros invisibles en el borde del mundo y rescate si el jugador cae bajo el terreno.
- `constructor_malla.gd`: arma mallas con color por vértice sin crear nodos (apto para hilos).
- La ciudad original es el **núcleo**: el terreno se aplana a su alrededor, no se genera nada encima y
  tres carreteras salen de los finales de sus calles (norte, sur y campo al este).
- Ya no hay muro alrededor de la ciudad (`mundo.gd`).

## Propiedades
- Casas con cartel verde y huertos con valla: ids `w_c_<celda>_...` y `w_h_<celda>_...`
  (se guardan en `viviendas` / `huertos` / `en_propiedad`, no hace falta guardar el mapa).
- E alquila, Mayús+E compra (`PropiedadMundo`, `Parcela`). La inmobiliaria de la plaza permite
  vender las que tengas (`Propiedades.del_mundo_propias`).
- Los cultivos crecen aunque estés lejos: `GestorTrozos` descuenta el tiempo de todas las parcelas.
  Pendiente (P0 de MEJORAS.md): lo mismo para corrales, manzanos y macetas (hoy solo están en la ciudad).

## Mapa
- Minimapa: la cámara sigue la altura del jugador (sirve en montañas).
- Mapa grande (N): tecla **Z** cambia entre la ciudad y el mundo entero (imagen generada de los datos).

## Pendiente / ideas
- Probar en Godot: orden de caras (ahora sin culling), rendimiento, tirones al montar trozos.
- Interiores para las casas del mundo (ahora solo descansar), colisión de los árboles, farolas.
- Gente, guardias y tráfico solo cerca del jugador; encargos hacia casas/pueblos lejanos.
- Viaje rápido (taxi / tren) para no cruzar 10 km a pie.
- Montañas, lago y costa con carácter propio (hoy el relieve es solo ruido).
