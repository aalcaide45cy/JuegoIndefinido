# Modo servidor y multijugador

Documento de diseño (2026-11-18). Está escrito en español sencillo a propósito.
Nada de esto está programado todavía: es el plan para hacerlo bien y sin rehacer el juego.

## 1. La idea en dos frases

- **Un solo juego, tres formas de jugar**: *un jugador* (el mundo se para cuando sales),
  *servidor* (el mundo sigue vivo aunque no haya nadie) y *amigos* (varios jugadores en el mismo mundo).
- Para que eso funcione, **el mundo tiene que vivir en un "servidor"** y el jugador solo es un "cliente" que mira
  y manda órdenes. Incluso en un jugador, el juego lleva dentro un servidor pequeño que solo funciona mientras juegas.

## 2. Los modos, explicados con ejemplos

| Modo | Qué pasa al salir | Quién puede entrar | Ejemplo |
|---|---|---|---|
| **Un jugador** | El mundo se guarda y se **para** | Nadie más | Juegas solo en el sofá |
| **Anfitrión** (tú juegas y los amigos entran) | Al salir tú, se cierra la partida para todos (se guarda) | Amigos por código o IP | Tus amigos entran a tu mundo mientras juegas |
| **Servidor dedicado** | **Sigue corriendo**: día y noche, cultivos, animales, economía | Cualquiera con la dirección; entran y salen cuando quieren | Un PC o un servidor alquilado encendido 24 h, y tú entras cuando te apetece |

Lo importante: **el servidor dedicado es el mismo juego sin pantalla** (Godot lo llama *headless*).
Tú "entras" como si fueras un cliente, aunque estés en tu propio PC.

Tu petición "entro en single player y el servidor sigue activo" se resuelve así: no hay un "single player" aparte.
Hay **un cliente** que se conecta a un servidor. Si el servidor está en tu PC y lo cierras, se para. Si está aparte y sigue encendido, sigue el mundo.

## 3. Cómo se hace: arquitectura propuesta

### 3.1 Servidor autoritativo (la regla de oro)

El **servidor manda**. Los clientes dicen "quiero comprar esto", "voy hacia aquí", "disparo".
El servidor comprueba si es posible, lo hace y avisa a todos. Así nadie puede decir "tengo 1.000.000 $".

Usaremos el **multijugador de alto nivel de Godot** (`MultiplayerAPI` + `ENetMultiplayerPeer`):

- Está incluido en Godot, sin librerías extra, y funciona con GDScript.
- `@rpc` marca las funciones que se llaman por red.
- `MultiplayerSpawner` y `MultiplayerSynchronizer` crean y sincronizan objetos (jugadores, vehículos).
- Para Steam más adelante se cambia el "peer" por GodotSteam (ver sección 6) sin tocar la lógica del juego.

### 3.2 Tres capas

```
 CLIENTE (cada jugador)         SERVIDOR (autoritativo)          DATOS
 ─────────────────────         ───────────────────────          ─────
 Pantalla, HUD, menús           Reloj y día/noche                Mundo (partida)
 Cámara y sonido                Cultivos, granjas, macetas       Jugadores (uno por cuenta)
 Lee teclado y ratón            Economía, negocios, personal
 Predice su movimiento    ⇄     Policía, guardias, tráfico
 Muestra lo que le dice         Vehículos, encargos
 el servidor                    Valida cada orden
```

- **Capa de mundo** (`scripts/mundo_logica/`, nueva): reglas sin nada visual. Funciona en el servidor.
- **Capa de cliente** (`scripts/ui`, cámara, partículas, música): solo existe en quien tiene pantalla.
- **Capa de red** (`scripts/red/`, nueva): `GestorRed` (autoload) con crear/unirse, lista de jugadores y los `@rpc`.

### 3.3 Qué simula el servidor aunque no haya nadie

Todo lo que "debe pasar solo". En cuanto no hay jugadores, el servidor **no dibuja ni carga trozos de mapa**: solo avanza datos. Esto es barato.

| Sistema | Hoy (donde está) | En el servidor sin jugadores |
|---|---|---|
| Reloj, día y noche | `Juego.hora`, `Juego.dia`, `Juego.reloj` | Sí, siempre |
| Cultivos | `Juego.parcelas` (`t`, `total`) | Sí, por reloj absoluto (sin cargar el huerto) |
| Corrales y manzanos | `Juego.granja` con `u` = reloj | Sí, ya usa reloj absoluto |
| Macetas | `Maceta3D` (`_ultimo_reloj`) | Sí, pero hay que moverlas a datos (hoy viven en nodos) |
| Economía, precios, mercado | `Juego.negocio`, `Negocios.ponerse_al_dia` | Sí, una vez por día |
| Alquileres e impagos | `DatosPropiedades.cobrar_dia` | Sí, una vez por día (sobre **cada** jugador) |
| Personal y almacén | `GestorPersonal` | Sí |
| Clima | `Clima` | Sí, con semilla común: todos ven la misma tormenta |
| Guardias y policía | `GestorPolicia`, `Guardia` | Solo cerca de jugadores (ver 3.5) |
| Tráfico y peatones | `GestorVehiculos`, `RedCalles` | Solo cerca de jugadores (ver 3.5) |
| Encargos del móvil | `Encargos` | Sí, por jugador |

Buena noticia: **el reloj absoluto (`Juego.reloj`) ya existe** y corrales, árboles y macetas ya lo usan.
Es el truco clave: nadie "avanza" las plantas cada segundo, se calcula "cuánto tiempo pasó" cuando alguien mira.
Así el servidor puede dormir y despertar sin perder nada.

### 3.4 Qué se sincroniza y cómo

Regla: **datos pequeños y poco frecuentes**. Nunca mandar el mundo entero.

1. **Al entrar** un jugador recibe una "foto" completa de lo suyo: dinero, inventario, nivel, casas, vehículos.
2. **Cada ~10 veces por segundo**: posición y giro de jugadores y vehículos cercanos (`MultiplayerSynchronizer`), solo los que están en su zona de interés.
3. **Por evento**: "se compró algo", "se plantó", "empezó el día". Son `@rpc` puntuales.
4. **Hora**: el servidor manda la hora cada 1-2 segundos; el cliente la avanza solo entre mensajes.
5. **Mundo generado**: no se envía. El mapa sale de una **semilla** (`GestorTrozos.SEMILLA`); cada cliente lo genera igual. Solo se envían las diferencias (casas compradas, huertos plantados).

**Zona de interés**: cada jugador solo recibe lo que hay a su alrededor (por ejemplo, los trozos de 128 m vecinos). Con un mapa de 10 km es imprescindible.

### 3.5 Tráfico, peatones, guardias

Hoy cada uno sigue al único jugador. Propuesta:

- Se simulan en el servidor **solo dentro de un radio** (≈200-300 m) de cualquier jugador.
- Lejos de todos los jugadores desaparecen (o se congelan) y, al volver alguien, reaparecen con una posición plausible según la hora.
- Los clientes **no** simulan IA: solo reciben posición y animación. Es lo más barato y evita que cada uno vea cosas distintas.
- La policía: `estrellas`, `alerta` y `sospecha` pasan a ser **por jugador**, no globales.

### 3.6 Guardado

**Dos tipos de archivo**, porque ahora hay mundo y hay jugadores:

- `mundo.json`: semilla, `hora`, `dia`, `reloj`, parcelas, granja, propiedades vendidas/compradas por dueño, plazas de coches tomadas, mercado, clima. Lo guarda **el servidor** cada 1-2 minutos y al apagarse.
- `jugadores/<id>.json`: dinero, banco, vida, nivel, xp, habilidades, inventario, estantería, aspecto, vehículos propios, encargos, reputación, recetario, efectos, posición. Se guarda al salir y cada pocos minutos.

Hoy `Guardado.guardar()` mezcla todo en `user://partida_N.json` y lee de nodos del mundo (macetas). Hay que **separar** esos dos bloques.
En un jugador seguirán existiendo 5 ranuras: cada ranura es un mundo con un jugador (se guarda igual y es compatible con las partidas antiguas: una migración sencilla las parte en mundo + jugador).

**Identidad del jugador**: al principio un ID aleatorio guardado en su PC (`user://id_jugador.txt`) y un nombre. Con Steam se usa el SteamID. Así, al volver, el servidor reconoce tu personaje.

**Logros**: son de la cuenta (ya van aparte en `logros.gd`), se quedan en el cliente.

### 3.7 Cómo invitar a amigos (de lo fácil a lo ideal)

1. **IP y puerto** (primer hito): el anfitrión abre el puerto (por defecto 24565, UDP) y pasa su IP. Funciona en LAN y por internet si abre el router. Es lo más simple, pero lo más incómodo para un principiante.
2. **Código de sala**: un servidorcito de "encuentro" (puede ser un Cloudflare Worker, ya conectado al proyecto) guarda `código → IP:puerto`. El amigo escribe `ABCD-12`. Más cómodo, y se puede usar UPnP/hole punching para evitar abrir el router.
3. **Steam** (para publicar): con **GodotSteam** y *Steam Networking Sockets* (`SteamMultiplayerPeer`): el amigo pulsa "Unirse" desde la lista de amigos de Steam. Sin IP ni puertos, y con relé de Steam (si falla la conexión directa, pasa por sus servidores). Hay que tener el juego en Steam (o usar el AppID de prueba 480 mientras se desarrolla).
4. **Servidor dedicado**: se ejecuta con `--headless --servidor`. Para un servidor de verdad: un VPS barato o el PC de casa siempre encendido. Los jugadores entran por IP, código o lista de servidores.

Recomendación: IP+puerto primero, luego código de sala, y Steam al final (con la misma interfaz `GestorRed` para no rehacer nada).

## 4. Qué hay que refactorizar del código actual

Esta es la parte más grande. Resumen de lo que he visto en el código:

### 4.1 `Juego` (autoload, 881 líneas) mezcla tres cosas

- `scripts/juego.gd` guarda **estado del jugador** (dinero, vida, inventario, nivel…), **estado del mundo** (hora, día, reloj, parcelas, granja) y **cosas de pantalla** (`menu_abierto`, controles de teclado, avisos).
- Hay unas **1.000 referencias a `Juego.`** en el código (jugador.gd 54, guardado 82, ventanas 98…).

Propuesta: dividirlo en tres sin romper nada de golpe:

- `EstadoMundo` (servidor): hora, día, reloj, duración del día, parcelas, granja, propiedades, mercado.
- `EstadoJugador` (una instancia **por jugador**): todo lo personal.
- `Juego` se queda como **fachada**: `Juego.dinero` sigue funcionando en el cliente y apunta al `EstadoJugador` local, así los ~1.000 usos no se tocan al principio.

### 4.2 Pausa global

`ventanas.gd` hace `get_tree().paused = true` al abrir tiendas e inventario. En multijugador **no se puede pausar el mundo**: los demás siguen jugando.
Hay que cambiarlo por "jugador ocupado" (no se mueve, no puede interactuar), y solo en un jugador se mantiene la pausa de verdad.

### 4.3 Lógica metida en nodos de escena

- `Maceta3D`, `Parcela`, `Corral`, `ArbolFrutal`, `Mostrador`, `Colocable`, `Interactuable`: guardan estado dentro del nodo o lo mezclan con la malla. Hay que moverlo a datos (diccionarios por id) y que el nodo solo **dibuje**.
- Patrón objetivo: el cliente pulsa E → manda `@rpc` "interactuar(id)" → el servidor valida → cambia datos → avisa → el nodo se redibuja.
- `Guardado.guardar()` recorre `get_nodes_in_group("macetas")`: en un servidor sin trozos cargados no hay nodos. Debe leer **datos**.

### 4.4 Cosas que asumen "un único jugador"

- `Guardia`, `GestorPolicia`, `CochePatrulla`, tráfico y cámara buscan "el jugador" (un solo nodo). Deben recibir una lista y elegir el más cercano.
- `Juego.estrellas`, `alerta`, `sospecha`, `distrito_actual`, `interiores` pasan a `EstadoJugador`.
- `Ciclo_dia`, `Clima`, `Musica`, `HUD`, partículas: solo en clientes (no se crean en el servidor dedicado).
- `Juego._process` usa `Input` (correr con ilegal): eso lo mide el cliente y lo informa.

### 4.5 Aleatoriedad

Hay ~94 usos de `randi`/`randf`. En el servidor cada decisión importante (cacheo, ofertas, clientes, qué sale en un corral) debe decidirla **el servidor**. Lo puramente visual (polvo, sonido) puede seguir con aleatorio local.

### 4.6 Mundo y trozos

`GestorTrozos` y `GeneradorMundo` ya están bien pensados: puro, por semilla, sin depender de la pantalla. Se reutilizan igual. El servidor solo necesita **la física/colisiones cercanas a jugadores** si valida movimiento; para empezar el servidor confía en la posición del cliente con límites razonables (ver trampas).

## 5. Riesgos y cómo mitigarlos

| Riesgo | Por qué | Qué hacer |
|---|---|---|
| **Mundo de 10 km por trozos** | Cada jugador está en un sitio distinto; el servidor no puede cargar todo | Zona de interés por jugador; el servidor solo carga trozos con jugadores; los cultivos y granjas lejanos se calculan con reloj absoluto (ya existe) |
| **Vehículos** | Mucha física; vehículos de varios jugadores y remolques enganchados | El conductor tiene la autoridad física de su vehículo y el servidor la comprueba (velocidad máxima); sincronizar a 10-20 Hz con interpolación; enganche de remolques validado en servidor. Los helicópteros y aviones, en fase tardía |
| **Policía** | Hoy mira a un solo jugador y usa cálculos por fotograma | Estrellas por jugador; IA solo cerca de jugadores; qué ve la policía lo decide el servidor |
| **Panel admin (F1)** | Cambia hora, dinero, vida: sería un cheat de todos | Solo funciona en un jugador o para el **anfitrión/administradores** autorizados en el servidor (lista en un archivo); cada acción pasa por `@rpc` con comprobación |
| **Trampas** | El cliente es de quien juega | Servidor autoritativo en todo lo que importa (dinero, inventario, compra/venta, daño). Límites de velocidad y distancia en movimiento. Registro de acciones raras |
| **Dinero y comercio entre jugadores** | Duplicar objetos con cierres de partida | Transacciones atómicas en servidor y guardado antes/después |
| **Latencia** | El juego es de primera persona | Predicción local del movimiento del propio jugador y reconciliación; el resto con interpolación |
| **Rendimiento del servidor** | Las IA y la física consumen | Simulación por radio, 20 ticks/s para IA y 60 para física solo cerca; servidor sin render |
| **Partidas antiguas** | Cambia el formato | Migración automática de `partida_N.json` a mundo + jugador |
| **Tiempo y bucles de espera** | Hoy un menú pausa el juego; con otros jugadores no | Ver 4.2 |
| **Sin probar en Godot** | Todo el código actual es "sin probar" en el motor | Cada fase debe terminar con prueba real en el PC (hilo tester) antes de seguir |
| **Abrir puertos** | Un principiante no sabe | Código de sala y Steam al final; documentar bien IP/puerto |

## 6. Fases, esfuerzo y primer hito

Esfuerzo orientativo en **sesiones de trabajo** (una sesión ≈ un hilo grande). Dependen de lo que salga al probar en Godot.

| Fase | Qué se hace | Esfuerzo | Resultado visible |
|---|---|---|---|
| **0. Preparación** | Cerrar los pendientes de `MEJORAS.md` (P0) y pruebas del mundo grande | 1-2 | Base estable |
| **1. Separar mundo y jugador** | Dividir `Juego` en `EstadoMundo` + `EstadoJugador` con fachada; la pausa pasa a "jugador ocupado"; guardado en dos bloques (con migración) | 3-4 | **El juego se ve igual**, pero por dentro está listo |
| **2. Servidor local en un jugador** | Cliente y servidor en el mismo proceso: las acciones pasan por funciones de "servidor"; macetas, huertos y granjas en datos | 3-4 | Igual que hoy, sin pausa por menús |
| **3. Servidor dedicado sin pantalla** | `--headless --servidor`, reloj y economía corriendo, guardado automático de mundo, sin nodos de escena | 2-3 | **El mundo sigue vivo** con nadie dentro |
| **4. ENet: un cliente remoto (HITO MÍNIMO)** | `GestorRed`, conectar por IP, un jugador remoto que se mueve, ver la hora y plantar/cosechar | 3-4 | Tú y un amigo en el mismo mundo |
| **5. Varios jugadores** | Inventario/dinero por jugador, tienda, casas, encargos, policía por jugador, ver a otros con su aspecto, chat | 4-6 | 2-8 jugadores jugando |
| **6. Vehículos y tráfico en red** | Conductor con autoridad, remolques, IA solo cerca de jugadores | 4-5 | Coches compartidos |
| **7. Invitar fácil** | Código de sala (Worker) y UPnP; lista de servidores | 2-3 | "Dime el código" |
| **8. Steam** | GodotSteam, lista de amigos, relé, logros de Steam | 3-4 | Unirse desde Steam |
| **9. Blindaje** | Anti-trampas, admin autorizado, reconexión, pruebas de carga | 3-4 | Servidor robusto |

Total aproximado: **28-39 sesiones**. Con un hito jugable ya en la fase 4 (**≈ 12-17 sesiones**).

### Primer hito mínimo viable (fases 0 a 4)

> Dos ordenadores: uno ejecuta el servidor, el otro se conecta por IP, entra al mundo, ve la hora del servidor, se mueve, siembra y cosecha en un huerto.
> Si el cliente sale y vuelve, **las plantas han crecido**.

Esto demuestra la idea completa (mundo que sigue vivo + invitar) con muy poco riesgo, y el resto son capas encima.

### Qué haría yo ahora mismo (sin riesgo)

1. Terminar de unir y probar en Godot lo que está en las ramas (mundo grande, guardado).
2. Empezar por la **fase 1** en una rama propia y con pruebas en el PC al acabar cada paso. Es el cambio más delicado porque toca ~1.000 líneas que usan `Juego`.

> En este PR solo va el documento. La fase 1 toca casi todos los archivos y el código actual no se ha probado en Godot, así que cambiarlo ahora sin poder ejecutarlo sería arriesgado.

## 7. Decisiones que tendrá que tomar Alfonso

1. ¿**Máximo de jugadores**? (propuesta: 2-8 al inicio.)
2. ¿**Cooperativo** (todos en el mismo negocio) o cada jugador con su propio dinero y negocios? (propuesta: **cada uno lo suyo**, con la ciudad compartida.)
3. ¿Puede haber **PvP** (hacerse daño entre jugadores) y robarse? (propuesta: desactivable por servidor.)
4. ¿El servidor dedicado lo quieres para **casa** (tu PC) o alquilado (VPS)? Afecta a Steam y a la documentación.
5. ¿Quién es **administrador** del servidor?
