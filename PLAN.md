# Plan de Elixir Clandestino

Este es el plan para ir de la plaza actual a una ciudad jugable. Cada fase se
puede probar por separado y se sube a GitHub al terminar. Primero va lo que
sostiene todo lo demás: el inventario, el tiempo y el panel de administrador.

Sobre el alcance: una ciudad grande con decenas de armas y tiendas es mucho
trabajo. Por eso cada fase deja algo que ya se puede jugar, y los datos
(objetos, precios, niveles) están en archivos aparte para añadir cosas sin
tocar el resto del código.

## Hecho

- **0.1 Prototipo 2D** (eliminado: ya no se usaba).
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

Assets reales: los paquetes CC0 de Quaternius ya están en `assets/quaternius/`
(Fantasy Props, Medieval Village, Toon Shooter y Universal Base Characters; el
Downtown City MegaKit no se copió por tamaño, 88 MB). Ya se ven en las armas de
la mano y en la decoración de tiendas, casas y mercado. Quedan: cambiar las cajas
de los edificios por Medieval Village, personajes para tenderos, clientes y
guardias, y texturas de Poly Haven. Las licencias están en `CREDITS.md`.

Guardias (de noche): solo te persiguen si llevas algo ilegal (pociones, hierbas,
armas de fuego o explosivos). Arriba sale "¡DETECTADO!" con el motivo y una barra
de búsqueda que baja sola (6 por segundo; 30 dentro de un edificio). Para
esconderte: salir de su vista, entrar en un edificio, agacharte (C o Ctrl, ven
menos y vas más despacio), estar lejos de las farolas (sombra) o guardar lo
ilegal en la estantería de tu casa. Ajustes en `guardia.gd` y `jugador.gd`.

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

## Estado extra (sin probar en Godot: el hilo del PC debe revisarlo)
- Ventanas de las casas se iluminan de noche (material compartido `Barrio.material_ventana_luz`, lo controla `CicloDia`).
- Personajes Quaternius: guardias (Soldier, anima Idle/Walk/Run), clientes (Hazmat) y tenderos (Superhero + pelo). Si algo sale gigante, torcido o con armas de más, ajustar `Assets.personaje()`. Si no carga el modelo, se usa el muñeco de cajas.
- Armas en mano con modelos Quaternius (escala de cuchillo/granada ajustada).
- Sonido: `Sonido.tocar()` genera disparo/explosión por código; si se ponen archivos CC0 en `assets/sonidos/NOMBRE.ogg|wav` se usan solos. Pendiente: sonido ambiente y pasos.
- Pendiente: más partículas, sustituir cajas de edificios por piezas Medieval Village, revisión de huecos.
- Mapa grande a pantalla completa (tecla N, `scripts/ui/mapa_grande.gd`); icono del juego nuevo (poción) en `icon.svg`. SIN PROBAR en Godot.
- Pendiente: iconos de interfaz de un pack gratuito (Kenney no es accesible desde la nube; hace falta que Alfonso descargue un pack CC0 como "Game Icons" a assets/ui/).
- Finales de calle: muro de ladrillo con almenas, portón de madera con herrajes y antorchas de noche; marcos y carteles de tienda en madera lisa (sin rayas); sol de día algo más suave. SIN PROBAR en Godot.

## Cola grande (pedida el 2026-11-16) — orden y diseño
Orden de fases (cada una se sube al PR y el PC la prueba):
1. Estilo moderno (materiales, texturas, interfaz) + minijuegos de sembrar/cocinar con calidad que afecta al precio.
2. Vehículos y conducción (`scripts/vehiculos/vehiculo.gd`, VehicleBody3D con Jolt; entrar/salir con E, cámara propia, gasolina, daño).
3. Concesionarios, tiendas de alquiler de coches, coches aparcados que se pueden robar (la policía te busca) y comprar.
4. Ciudad grande por zonas: la ciudad actual pasa a ser la "zona 0"; el resto se divide en chunks de ~160 m que se construyen al acercarte (hilo/por trozos) y se liberan al alejarte. Mallas fusionadas por chunk, sombras solo cerca, tráfico y peatones simplificados a lo lejos (solo se simulan los cercanos). Mapa grande por zonas con carreteras.
5. Campo, casas grandes o en el campo, tractores.
6. Macetas mejorables (niveles), riego automático, abono y abono mejorado, máquinas de empaquetar, varios locales en alquiler.
Nota de rendimiento: "100 veces más grande" en superficie NO cabe en una sola escena; se hará con chunks cargados según distancia. Hoy rinde 220-430 FPS, hay margen pero no para 100x sin streaming.

**Reordenado (consejo del hilo del PC):** tras estilo moderno y minijuegos: mejoras baratas (macetas por niveles, riego, abonos, locales en alquiler, empaquetadora) -> ciudad por chunks con mapa desde datos y red de calles como datos -> vehículos y tráfico -> concesionarios, alquiler y robo -> campo y tractores. Hecho ya: móvil con encargos, mejora de maceta (niveles 1-3), kit de riego y abono mejorado (se usan con E sobre la maceta con el objeto en la mano).

## Diseño de la ciudad por chunks (para la rama claude/ciudad-grande)
- `scripts/mundo/red_calles.gd`: red de calles como datos (ya existe, con las calles actuales). Se amplía con el resto de zonas.
- Cada barrio/zona nuevo es un `Barrio` que se construye bajo demanda: un gestor (`GestorChunks`) mira la posición del jugador cada 0,5 s, construye los chunks a menos de ~200 m (de uno en uno por fotograma para no dar tirones, con `Construir.fusionar_estaticos` al terminar) y libera los de más de ~300 m.
- Las posiciones, nombres y tipos de cada chunk son datos (lista) para poder dibujar el mapa grande desde datos.
- Tráfico: coches simples que siguen tramos de `RedCalles`, solo simulados dentro de ~120 m.
