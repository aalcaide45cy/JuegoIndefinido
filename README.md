# Elixir Clandestino (nombre provisional)

Juego 3D de tono oscuro hecho con **Godot 4.7** (GDScript). En una ciudad donde
la magia está prohibida, de día llevas una herboristería normal; de noche, en
el sótano secreto, cultivas Hoja de Bruma (una hierba ficticia cuyo humo hace
soñar), preparas pociones vetadas por el Prefecto y las vendes a escondidas.

## Estado actual: prototipo 3D 0.2

Caminas en tercera persona (o primera, con **V**) por la **Plaza del
Ahorcado**, de noche, con niebla, farolas y casas hechas de cajas. En el lado
norte está tu herboristería (la de la puerta verde).

El bucle de juego:

1. **Tienda** (entra por la puerta verde con **E**): planta semillas en las
   macetas del banco. Con **Q** cambias qué hierba tienes "en la mano". Cuando
   la planta brilla, pulsa **E** para cosecharla.
2. **Sótano** (baja por la trampilla del rincón): echa 2 hierbas al caldero
   con **E** y se mezclan solas. El recetario está escrito en la pared.
3. **Mostrador** (en la tienda): de vez en cuando entra un cliente pidiendo
   una poción. Si la tienes, pulsa **E** en el mostrador antes de que se le
   acabe la paciencia.

El objetivo del prototipo es reunir 60 monedas para pagar el alquiler.

### Controles

| Tecla | Acción |
|---|---|
| WASD o flechas | Moverse |
| Ratón | Mirar |
| Shift | Correr |
| Espacio | Saltar |
| E | Usar (puertas, macetas, caldero, mostrador) |
| Q | Cambiar la hierba que tienes en la mano |
| V | Cambiar entre tercera y primera persona |
| Esc | Soltar el ratón (haz clic en la ventana para volver a jugar) |

## Cómo abrirlo y probarlo

1. Instala Godot 4.7 desde <https://godotengine.org/download>.
2. En el Gestor de Proyectos pulsa **Importar** y elige el `project.godot` de
   esta carpeta.
3. Pulsa **F5** (o el botón ▶ arriba a la derecha).

Si ya tenías el proyecto abierto cuando llegaron estos cambios, usa
**Proyecto > Recargar proyecto actual** antes de pulsar F5.

## Dónde está cada cosa

| Archivo | Qué hace |
|---|---|
| `project.godot` | Configuración (escena inicial, autoload `Juego`, renderizador Compatibilidad). |
| `scenes/mundo.tscn` | La escena principal; solo tiene un nodo con `mundo.gd`. |
| `scripts/game_data.gd` | **Datos del juego**: hierbas, pociones, recetas y precios. Cambia aquí los números para equilibrar. |
| `scripts/juego.gd` | Estado de la partida (dinero, inventario) y las teclas. Se usa desde cualquier script como `Juego`. |
| `scripts/mundo/mundo.gd` | Monta la noche (niebla, luna), los barrios, el jugador y el HUD. |
| `scripts/mundo/barrio.gd` | Base para los barrios: edificios de cajas, filas de casas y farolas. |
| `scripts/mundo/barrio_plaza.gd` | El primer barrio: la Plaza del Ahorcado y la fachada de tu herboristería. |
| `scripts/mundo/interior_herboristeria.gd` | La tienda (macetas, mostrador, trampilla) y el sótano (caldero). |
| `scripts/mundo/construir.gd` | Funciones para crear cajas, cilindros, luces y carteles con una línea. |
| `scripts/jugador/jugador.gd` | El personaje: movimiento, cámara y tecla E. |
| `scripts/objetos/interactuable.gd` | Base de todo lo que se usa con E. |
| `scripts/objetos/puerta.gd` | Puertas, trampillas y escaleras (fundido a negro y te mueve). |
| `scripts/objetos/maceta_3d.gd` | Una maceta que crece con el tiempo. |
| `scripts/objetos/caldero_3d.gd` | El caldero y las mezclas. |
| `scripts/objetos/mostrador.gd` | El mostrador y los clientes con paciencia. |
| `scripts/ui/hud.gd` | Textos en pantalla: dinero, inventario, "[E] ..." y mensajes. |

## Cómo crecer la ciudad (por barrios)

Una ciudad 3D grande es mucho trabajo, así que se construye **barrio a
barrio**. Cada barrio es un script que hereda de `Barrio`:

1. Copia `scripts/mundo/barrio_plaza.gd` con otro nombre (por ejemplo
   `barrio_mercado.gd`) y cambia `class_name` a `BarrioMercado`.
2. Escribe sus calles y casas en `construir()`.
3. Añádelo en `scripts/mundo/mundo.gd`:
   `_anadir_barrio(BarrioMercado.new(), Vector3(0, 0, -60))`
4. Abre un hueco en la plaza para que se pueda pasar de uno a otro.

## Arte y licencias

Todo el arte actual son **formas simples generadas por código** (cajas,
cilindros, esferas) y la fuente por defecto de Godot. No hay arte generado con
IA. Cuando se añadan modelos, la idea es usar packs con licencia **CC0** (por
ejemplo los de [Kenney](https://kenney.nl/assets)) y apuntar aquí de dónde sale
cada uno.
