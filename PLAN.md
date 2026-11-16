# Plan de Elixir Clandestino

Este es el plan para ir de la plaza actual a una ciudad jugable. Cada fase se
puede probar por separado y se sube a GitHub al terminar. Primero va lo que
sostiene todo lo demás: el inventario, el tiempo y el panel de administrador.

Sobre el alcance: una ciudad grande con decenas de armas y tiendas es mucho
trabajo. Por eso cada fase deja algo que ya se puede jugar, y los datos
(objetos, precios, niveles) están en archivos aparte para añadir cosas sin
tocar el resto del código.

## Hecho

- **0.1 Prototipo 2D** (guardado en `prototipo_2d/`).
- **0.2 Paso a 3D**: plaza nocturna, personaje en primera/tercera persona (V).
- **0.3 Escondite**: herboristería con interior, casa en alquiler, minijuego de
  plantar, caldero y ventanilla de venta.

## Estado de la fase 1 (rama `claude/project-thread-bxnc21`)

Escrita en la nube **sin poder ejecutar Godot**: hay que probarla en el PC.
Incluye:

- Datos de objetos y habilidades en `scripts/datos/` (se cargan con `preload`,
  sin depender de `class_name`, para evitar errores de "clase no declarada").
- Inventario de 63 casillas (9 de barra + 54 de mochila) con montones de 1 o
  hasta 20, arrastrar y soltar, dividir (clic derecho), ordenar y Mayús+clic.
- Barra rápida dibujada en el HUD (teclas 1-9 y rueda del ratón) y objeto en
  la mano en 3D (`scripts/jugador/modelo_mano.gd`).
- Tienda con pestañas por categoría, tu inventario al lado y zona para vender
  arrastrando. Estantería de casa por casillas.
- Dinero (200 $ al empezar), vida con barra, hora y día en el HUD.
- Panel de administrador (F1): hora, velocidad del tiempo, dinero, vida,
  nivel, habilidades y darse objetos.
- Ciclo de día y noche (`scripts/mundo/ciclo_dia.gd`): sol, luna, cielo,
  niebla y farolas que se encienden solas.
- Guardar y cargar (`scripts/guardado.gd`, archivo `user://partida.json`):
  inventario, dinero, nivel, habilidades, hora, casa alquilada, macetas y
  posición. Esc abre el menú de pausa (Reanudar, Guardar, Cargar, Salir) y al
  arrancar hay menú de Continuar / Nueva partida.
- Plantar, caldero, ventanilla y muebles adaptados al inventario nuevo. El
  caldero usa la hierba que llevas en la mano.

Ajustes tras la primera prueba: un día dura 60 minutos reales por defecto (se
cambia en F1) y se quitaron los parpadeos de las fachadas (cajas que
compartían plano con las paredes).

Fases 3 a 6 (misma rama, sin probar): nivel con experiencia (plantar, cosechar,
preparar y vender dan XP), academia en la Zona Industrial para aprender
habilidades, armas cuerpo a cuerpo y de fuego (clic izquierdo, R recarga, clic
derecho = zoom del francotirador), munición por tipo, marcas de bala, granadas,
C4 con detonador, lanzagranadas, galería de tiro con dianas y guardias que
patrullan de noche y te persiguen si llevas algo ilegal. Si la vida llega a
cero reapareces en la plaza y pierdes el 20 % del dinero.

Primer paso de calidad visual (fase 7, solo con código): cielo con degradado,
sol visible y atardeceres naranjas; grano de textura en paredes y suelos;
ajuste de contraste y color. Quedan los modelos y texturas reales (ver
`assets/LEEME.md`), partículas, sonido y el tema de interfaz.

Pendiente de la fase 1: probar en Godot y corregir lo que falle.

Fase 2 (misma rama): la ciudad ya tiene **cuatro barrios** unidos por calles de
8 m, cada uno en su script de `scripts/mundo/`:
- Plaza del Ahorcado (centro): herboristería, ferretería, armería y tu primera casa.
- Mercado (norte): botica, herbolario, ferretería, armería, panadería y otra botica.
- Barrio Residencial (este): cuatro casas en alquiler (160 a 700 $), panadería y botica.
- Zona Industrial (sur): ferretería, armería, almacenes y contenedores.
Hay 11 tiendas y 5 casas en alquiler; cada casa tiene su propio caldero,
cama, estantería y macetas. Lo que vende cada tienda sale de
`scripts/datos/objetos.gd` (campo `tienda`). Comida y medicinas curan al usarlas
(clic izquierdo con ellas en la mano). Para añadir un barrio: copia uno de los
tres y añádelo en `mundo.gd`. Falta el barrio oeste y los edificios de relleno
con detalle.

## Peticiones nuevas de Alfonso (2026-11-16)

- Guardado y carga de partida, con menú de Esc y menú inicial (hecho, fase 1).
- Ciudad más grande y con más tiendas (fase 2).
- Llevar a cabo todo el plan y que el juego sea **bonito**: ahora se ve básico
  (fase de calidad visual, abajo).

## Regla de diseño: cada estación de trabajo tiene su menú

Alfonso prefiere ventanas visuales a pulsar E muchas veces. El caldero ya
tiene la suya (`Ventanas.Caldero`: elegir receta, arrastrar hierbas, preparar).
Toda estación nueva (mesa de crafteo, banco de armas, instructor...) seguirá
el mismo patrón: ventana con recetas a un lado, casillas donde se sueltan los
ingredientes y tu inventario al otro. Al arrastrar, el icono se ve grande.

## Fase 2: la ciudad

- Ciudad grande, construida barrio a barrio (cada uno en su script de
  `scripts/mundo/`), con muchas más tiendas: herboristería, ferretería,
  armería, mercado, taberna, instructores...
- Varios barrios unidos por calles: plaza, mercado, barrio residencial y
  zona industrial (de momento con edificios de cajas).
- Varias viviendas con cartel "Disponible para alquilar" y precio distinto.
- Tiendas de todo tipo con interior: herboristería (semillas y abono),
  ferretería (herramientas y regaderas), armería (armas y munición).

## Fase 3: nivel y habilidades

- El jugador gana experiencia al plantar, cosechar, preparar y vender.
- Niveles que desbloquean objetos en las tiendas.
- Habilidades que se aprenden pagando a un instructor (por ejemplo, "Manejo
  de armas" en la galería de tiro). Sin la habilidad no te venden el arma.

## Fase 4: armas cuerpo a cuerpo y de fuego

- Palo, bate, barra de hierro, cuchillo y katana: golpe con clic izquierdo.
- Pistola, escopeta, rifle y francotirador (con zoom): disparo, retroceso,
  recarga (R) y munición por tipo.
- Marcas de bala que se quedan en paredes y suelo.
- Dianas en la galería de tiro para practicar.

## Fase 5: explosivos

- Granadas que se lanzan con física, C4 que se pega y se detona a distancia,
  y lanzagranadas.
- Explosiones con daño en un radio, empuje y marca en el suelo.

## Fase 6: peligro en la ciudad

- La guardia del Prefecto patrulla de noche. Si te ve con algo ilegal, te
  persigue.
- Daño, muerte y reaparición en casa (perdiendo algo de dinero).

## Fase 7: calidad visual (que se vea bonito)

Se hace por partes, en paralelo a las fases anteriores, cuidando el
rendimiento (el renderizador es Compatibilidad):

- Iluminación y sombras: sol y luna con sombras suaves, luces cálidas en
  interiores, brillo (glow) y niebla de ambiente; amanecer y atardecer con
  color.
- Materiales con detalle: texturas CC0 para suelo, paredes, madera y metal en
  lugar de colores planos.
- Modelos de verdad con licencia libre (CC0, por ejemplo Kenney o Quaternius)
  en vez de cajas: edificios, mobiliario, farolas, armas. Se apunta la
  licencia y el autor de cada paquete en `CREDITOS.md`.
- Efectos: partículas (humo del caldero, polvo, chispas, agua), huellas y
  marcas de bala, destellos de disparo.
- Sonido ambiente (ciudad de noche, pasos, tienda) y música suave.
- Interfaz con estilo coherente (tema de Godot propio: tipografía, colores,
  bordes y botones iguales en todas las ventanas).

## Más adelante

- Varias partidas guardadas (ahora hay una sola).
