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

## Estado de la fase 1 (importante para quien siga)

La rama `claude/project-thread-s1xxaq` tiene la versión **jugable** (0.3). El
trabajo a medias de la fase 1 está en la rama **`wip/fase1-inventario`**
y **todavía no arranca**. Lo que hay allí:

- Hecho: datos de objetos (`scripts/datos/objetos.gd`, `habilidades.gd`),
  inventario por casillas con montones, dividir, ordenar y mover
  (`scripts/juego.gd`), casilla con arrastrar y soltar (`ui/casilla_ui.gd`),
  base de ventanas (`ui/ventana.gd`) y las ventanas Inventario, Tienda (con
  pestañas y tu inventario al lado), Estantería y Admin (`ui/ventanas.gd`).
- Error al arrancar: `juego.gd` da "Parse error" (probablemente por una
  llamada mal escrita en `_nueva_casilla`/`_anadir_en`; las clases
  `DatosObjetos` y `DatosHabilidades` salen como no declaradas por esa
  cascada: abrir el proyecto en el editor para refrescar `class_name`).
- Falta adaptar al inventario nuevo (siguen usando `Juego.objetos`,
  `Juego.hierbas`, `Juego.pociones`, `GameData.CARGAS_JARRA`): `maceta_3d.gd`,
  `caldero_3d.gd`, `mostrador.gd`, `muebles.gd`, `tendero.gd`, `hud.gd` (que
  abra las ventanas nuevas y borre `menus.gd`/`menu_base.gd`) y
  `minijuego_plantar.gd`.
- Falta: barra rápida dibujada en el HUD con teclas 1-9 y rueda del ratón,
  objeto en la mano, barra de vida, ciclo de día y noche con el sol, F1 para
  el panel de administrador.
- Además, Alfonso pidió: **más tiendas con interior visible** (ferretería y
  armería, además de la herboristería) y que al comprar se vean a la vez su
  inventario y el del vendedor, con pestañas. Eso ya está planteado en
  `Ventanas.Tienda`.

## Fase 1: el núcleo (inventario, barra rápida, tiempo, admin)

- Datos de todos los objetos en `scripts/datos/objetos.gd`: nombre, tipo,
  precio, cuántos caben por casilla (1 o hasta 20) y qué nivel o habilidad
  hacen falta para comprarlos.
- Inventario por casillas con montones (stacks): herramientas y armas de 1 en
  1; semillas, tierra, munición, hierbas y pociones hasta 20 por casilla.
- Barra rápida abajo con 9 casillas: teclas 1 a 9 o rueda del ratón. Lo que
  eliges se ve en la mano (jarra, regadera, palo, bate, pistola...).
- Inventario con TAB y estantería de casa por casillas (clic para mover).
- Vida del jugador con su barra.
- Ciclo de día y noche: sol que se mueve, cielo que cambia de color, farolas
  que se encienden al anochecer y mejor iluminación general.
- Panel de administrador (F1): cambiar la hora y la velocidad del tiempo,
  botón de +100 $, cambiar la vida y darse cualquier objeto para probar.

## Fase 2: la ciudad

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

## Más adelante

- Guardar y cargar partida.
- Modelos de verdad con licencia CC0 (por ejemplo, Kenney) en lugar de cajas.
- Sonido y música.
