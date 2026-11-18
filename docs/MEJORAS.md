# Lista priorizada de mejoras

Sale de la revisión de [`DISENO.md`](DISENO.md) (2026-11-18). Cada punto dice **qué**, **por qué** y
**dónde**. Marca con [x] lo que se haga. Los hilos que ya están programando (vehículos, mapa,
recetas, negocios) pueden tomar de aquí lo que les toque.

Escala: **P0** = hacer antes que nada (arregla datos o evita rehacer trabajo), **P1** = siguiente,
**P2** = cuando el núcleo esté firme, **P3** = pulido y largo plazo. Esfuerzo: S (horas), M (un día), L (varios días).

## P0: antes de seguir ampliando

- [ ] **Relojes absolutos en producción** (S/M). Cultivos de huerto, granja, manzanos y macetas guardan
  cuándo empezaron en vez de descontar tiempo en `_process`. Sin esto, con chunks los campos lejos no
  producen. `parcela.gd`, `corral.gd`, `arbol_frutal.gd`, `maceta_3d.gd`, `guardado.gd`.
- [ ] **Quitar el objetivo de 1.000 $** (S). `GameData.OBJETIVO_DINERO` y el aviso "Prototipo superado"
  en `juego.gd` salen a los 10 minutos. Sustituir por metas del móvil (ver P1).
- [ ] **Una sola fuente para precios** (S). Borrar `precio_semilla` y `PRECIO_ALQUILER` de `game_data.gd`;
  que `barrio_residencial.gd` y `barrio_campo.gd` lean `propiedades.gd`.
- [ ] **Datos de cultivos, granja y vehículos a `scripts/datos/`** (S). `Parcela.CULTIVOS`, `Corral.ESPECIES`,
  `Vehiculo.TIPOS` fuera de sus scripts (el hilo de vehículos debe hacerlo, para no chocar).
- [ ] **Archivo `scripts/datos/economia.gd` con los multiplicadores** (S): % de venta a tienda, factor de
  compra, factor de cosecha, multas. Cambiar el equilibrio será tocar un archivo.

## P1: equilibrar y dar rumbo

- [ ] **Subir los tiempos de las hierbas** (S): Bruma 15 s → 60 s, Sepulcral 25 s → 120 s. `game_data.gd`.
  Efecto: bajar el dinero/hora del nivel 1 de 5.000-8.000 a 1.500-3.000.
- [ ] **Alquiler que se repite** (M): cobrar cada día de juego (propuesta 4 % del precio de compra por día)
  y avisar en el móvil; si no pagas, pierdes la propiedad a los 3 días. Compra a 40 veces el alquiler
  (no 25). `propiedades.gd`, `juego.gd`, `inmobiliaria.gd`.
- [ ] **Arreglar la escala de los huertos** (S): quitar el tope de 60 unidades o subir el tope según tamaño;
  que el beneficio por m² baje con el tamaño no, sino que suba un poco. `parcela.gd`, `propiedades.gd`.
- [ ] **Equilibrar la legal frente a la ilegal** (S): venta de cosechas al 33 % (hoy 50 %) o tiempos x2.
  Objetivo: huerto grande ≈ 2.000 $/h; pociones 3.000 $/h con riesgo. `juego.gd` (`vender`), `parcela.gd`.
- [ ] **Equilibrar la granja** (S): vaca 90 s por leche (o leche a 24 $) y manzanos 2 en vez de 3 o fruta
  cada 5 min. `corral.gd`, `arbol_frutal.gd`.
- [ ] **Más recetas e ingredientes** (M): 3 hierbas nuevas (nivel 3, 6, 9) y 8 pociones con recetas de
  2 a 4 ingredientes; precios de 40 a 600 $. `game_data.gd`, `objetos.gd`. (El hilo de recetas.)
- [ ] **Desbloqueo por nivel de lo que no son armas** (S): según la tabla de 6.3 de `DISENO.md`
  (hierba Sepulcral nivel 2, empaquetadora nivel 2, vacas nivel 6, huertos grandes nivel 7-10…).
  Solo hace falta usar el campo `nivel` que ya existe.
- [ ] **Metas encadenadas en el móvil** (M): 6 misiones con recompensa. `ui/telefono.gd`, `juego.gd`.
- [ ] **Subir los sueldos del personal** (S): hoy 35-60 $/día frente a 6.000+ $/h que rinde un huerto grande.
  Sueldo ≈ 25-40 % de lo que rinde el puesto, o día de 20-24 min. `datos/personal.gd`, `juego.gd`.
- [ ] **Multas proporcionales** (S): cacheo = 5 % del dinero + valor de lo confiscado; registro de casa
  igual; morir = 10 a 20 % con mínimo. `ui/cacheo.gd`, `juego.gd`, `jugador.gd`.

## P2: sistemas que faltan o están a medias

- [ ] **Chunks y mapa de 10 x 10 km** (L, por hitos M0 a M7 de `DISENO.md` sección 7.5). Empezar por
  `GestorChunks` + límite fijo + red de carreteras en datos.
- [ ] **Negocio legal** (L): tienda propia (alquilar un local) con ingresos pasivos y empleados que vendan
  o empaqueten (el personal básico ya existe en `gestor_personal.gd`).
- [ ] **Habilidades con efecto** (M): Cultivo, Cocina, Persuasión, Sigilo, Conducción, Mecánica
  (3 niveles). `habilidades.gd`, y donde se use cada efecto.
- [ ] **Policía que crece con tu riqueza** (M): estrellas 1 a 3, más guardias y retenes en barrios ricos,
  persecución en coche, cárcel corta con pérdida de tiempo y multa. `guardia.gd`, `jugador.gd`.
- [ ] **Encargos con lugares generados** (M): elegidos entre puntos de interés cercanos al jugador, con
  más pago por distancia y por riesgo. `encargos.gd`.
- [ ] **Gasolineras y taxi / viaje rápido** (M): gasolina a precio de surtidor (la mitad que el bidón),
  taxi con tarifa por distancia, estaciones. Sirven de gasto y de transporte.
- [ ] **Distritos de ciudad** (L): ampliar los 4 barrios actuales a una ciudad de 2 x 2 km con tiendas
  nuevas (banco, taberna, taller, hospital) y propiedades con precio por prestigio.
- [ ] **Dormir y esperar** (S): que dormir en la cama pase el tiempo con aviso de lo que pasa (cosechas
  listas, cobros, encargos que caducan).

## P3: pulido y largo plazo

- [ ] **Equilibrio de armas y combate**: tabla de daño, vida de guardias, precio de munición. Hoy el daño
  más alto (lanzagranadas 100) no tiene enemigos que lo justifiquen.
- [ ] **Sonido y música** por zona y por hora. `sonido.gd` ya genera efectos básicos.
- [ ] **Iconos de interfaz** CC0 (Game Icons) y tema de interfaz unificado.
- [ ] **Estaciones y clima** (lluvia que riega, niebla que aumenta el sigilo).
- [ ] **Varias partidas guardadas** y versión del guardado (`VERSION` ya existe, falta migrar).
- [ ] **Logros de Steam** a partir de las metas.
- [ ] **Cambiar el icono** (hoy usa el de Godot, CC BY) antes de publicar en Steam. Anotado en `CREDITS.md`.
- [ ] **Revisión de nombres**: "Elixir Clandestino" es provisional.

## Riesgos que conviene vigilar

- **Rendimiento**: 20.000 llamadas de dibujo antes de fusionar. Con el mapa grande, todo lo nuevo debe usar
  MultiMesh, fusión por chunk y luces con `luces_lod`.
- **Sin probar en Godot**: casi todo lo reciente lo escribió la nube. Cada hito debe pasar por el hilo del PC.
- **Choques entre hilos**: `PLAN.md`, `juego.gd` y `objetos.gd` los tocan todos. Hacer commits pequeños y
  actualizar la rama antes de empezar.
