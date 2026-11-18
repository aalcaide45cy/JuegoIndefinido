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

### 3.8 Servidores fáciles de montar (para la nube y para cualquiera)

Objetivo: que cualquiera monte su servidor **copiando un comando** o pulsando un botón en un servicio de nube.

**a) Un ejecutable sin pantalla.** Godot exporta el juego para **Linux** y **Windows**, y se arranca con
`./juego --headless -- --servidor`. No necesita tarjeta gráfica ni ventana. Recomendado: un *preset* de exportación "Servidor" que quite imágenes, música y shaders para que pese poco.

**b) Un archivo de configuración sencillo** (`servidor.cfg`, texto plano, se crea solo la primera vez):

```ini
nombre = "Mi servidor"
contrasena = ""            ; vacío = abierto
puerto = 24565
semilla = 12345            ; 0 = aleatoria al crear el mundo
max_jugadores = 8          ; 1 a 64
modo = "propio"            ; "propio" = cada jugador su dinero y negocios | "cooperativo" = dinero y negocios compartidos
pvp = false                ; true = los jugadores pueden hacerse daño
robos = false              ; true = se puede robar a otros jugadores
guardado_minutos = 2
transporte = ["enet"]      ; "enet" (UDP), "websocket" (TCP), "steam"
lista_steam = false        ; true = aparece en la lista de servidores de Steam
admins = ["ID_DEL_ADMIN"]  ; quién administra (por ID o SteamID)
```

Todo se puede sobrescribir con variables de entorno (`JI_PUERTO`, `JI_CONTRASENA`…), que es lo que usan los servicios de nube.

**c) Imagen Docker con un solo comando.** Imagen pequeña (Debian "slim" + el ejecutable exportado), con un **volumen** `/datos` donde se guarda `mundo.json`, `jugadores/` y `servidor.cfg`. Así actualizar el servidor no borra el mundo:

```bash
docker run -d --name juego -p 24565:24565/udp -v juego-datos:/datos \
  -e JI_NOMBRE="Mi servidor" -e JI_CONTRASENA="secreta" ghcr.io/aalcaide45cy/juegoindefinido-servidor:latest
```

Y un `docker-compose.yml` de ejemplo (copiar, pegar, `docker compose up -d`). La imagen se construye y publica sola con **GitHub Actions** en cada versión.

**d) Guía paso a paso (a escribir en `docs/SERVIDOR.md`).**

| Dónde | Dificultad | Notas importantes |
|---|---|---|
| **VPS** (Hetzner, DigitalOcean, OVH…) | Fácil | Instalar Docker, ejecutar el comando de arriba y abrir el puerto UDP 24565 en el cortafuegos. Es la opción recomendada: ~4-6 €/mes |
| **Fly.io** | Media | Admite UDP con IP dedicada; volumen persistente para `/datos`; un `fly.toml` de ejemplo en el repo |
| **Railway / Render** | Cuidado | Suelen exponer solo TCP/HTTP, no UDP. Con ENet no funcionarían. Solución: ofrecer **WebSocket** (`WebSocketMultiplayerPeer`, TCP) como transporte alternativo del servidor |
| **Casa (PC o Raspberry)** | Media | Abrir el puerto en el router o usar el código de sala/UPnP |
| **Steam** | Fácil para jugadores | El anfitrión o servidor se anuncia por Steam sin abrir puertos |

(Hay que **comprobar** cada proveedor al escribir la guía: sus reglas de UDP y de volúmenes cambian.)

**e) Transporte doble.** El servidor escucha **ENet (UDP)**, mejor para juego rápido, y opcionalmente **WebSocket**, que pasa por casi cualquier nube. El resto del juego no cambia, porque todo va por `GestorRed`.

**f) Administración remota básica.**
- **Consola de texto** por la entrada estándar del contenedor (`docker attach`): `jugadores`, `expulsar <id>`, `prohibir <id>`, `guardar`, `apagar`, `decir <mensaje>`, `hora <h>`.
- **Chat de administración en el juego**: los `admins` del `.cfg` usan `/comandos` (reutilizando el panel admin F1, pero validado en el servidor).
- **Más adelante**: pequeña página web de estado con contraseña (jugadores conectados, hora del mundo, botón de guardar) y **copias de seguridad** automáticas del volumen (cada X horas, conservando las últimas N).
- **Comprobación de salud**: el servidor responde a un "ping" para que Docker o la nube lo reinicien si se cuelga. Se guarda siempre antes de apagar (señal `SIGTERM`).

**Fases extra** (se suman a la sección 6): preset de exportación + arranque `--servidor` + `servidor.cfg` = **1-2 sesiones** (con la fase 3). Docker + GitHub Actions + guía de VPS = **1-2**. Transporte WebSocket + guías Fly.io/otros = **1-2**. Consola y copias de seguridad = **1-2**.

### 3.9 ¿Docker? ¿Y cómo lo hace ARK?

**Docker es una opción, no la única.** ARK (y Valheim, Rust, etc.) funciona así:

1. **Servidor dedicado aparte**: es un programa distinto del juego (en ARK, `ShooterGameServer`), sin gráficos, que se descarga gratis con **SteamCMD** (la herramienta de línea de comandos de Steam) usando un *AppID de servidor* propio (ARK: 376030).
2. **Se configura con archivos de texto** (`GameUserSettings.ini`, `Game.ini`) y parámetros de arranque (mapa, puerto, contraseña, máx. jugadores).
3. **Los hosts de juegos** (Nitrado, G-Portal, etc.) lo ofrecen con **un clic**: tienen una plantilla que ejecuta SteamCMD, crea los archivos y arranca el servidor. El cliente solo elige nombre y contraseña.
4. **Los jugadores lo encuentran** en la lista de servidores de Steam, o por IP:puerto.
5. Mucha gente también lo corre en **Docker** (imágenes de la comunidad) o en su PC con SteamCMD.

**Cómo lo replicaríamos** (de menos a más trabajo):

| Paso | Qué es | Para quién |
|---|---|---|
| **A. Descargable** | `servidor-windows.zip` y `servidor-linux.tar.gz` en GitHub Releases, con `servidor.cfg` y un `iniciar.bat`/`iniciar.sh`. Descomprimir y ejecutar | Cualquiera, en su PC o VPS |
| **B. Imagen Docker** | La misma cosa en un contenedor (sección 3.8). Es **lo que piden la mayoría de nubes y paneles** modernos | VPS, Fly.io, paneles tipo Pterodactyl |
| **C. Servidor dedicado en Steam** | Un segundo "app" en Steamworks, gratis para quien tenga el juego, con su AppID de servidor. Se baja con `steamcmd +login anonymous +app_update <AppID> +quit`. Se registra en la lista de servidores de Steam con `GodotSteam` | Quien use SteamCMD o hosts de juegos |
| **D. Plantilla para hosts** | Un *egg* de **Pterodactyl** (panel de código abierto que usan muchos hosts pequeños), más instrucciones para que hosts comerciales la añadan | Hosts de juegos |

Recomendación: **A y B primero** (baratos y valen para todo). **C y D cuando el juego esté en Steam**: necesita tener la ficha del juego creada y el AppID de servidor. Mientras tanto se pueden probar con el AppID de pruebas 480.

**Pasos para un host de juegos (cuando exista C/D):** 1) crear el servidor y elegir la plantilla del juego; 2) el host ejecuta SteamCMD y descarga el servidor; 3) el cliente rellena nombre, contraseña, puerto y máx. jugadores (genera `servidor.cfg`); 4) abrir el puerto UDP indicado; 5) arrancar; 6) el servidor aparece en la lista de Steam y los amigos entran por IP o código. Los detalles exactos (nombres de variables, puertos, AppID) se confirman con cada host al escribir `docs/SERVIDOR.md`.

### 3.10 ¿Qué es la "plantilla" (Pterodactyl)?

Muchas empresas que alquilan servidores de juegos usan un **panel web** para sus clientes. El más común y gratuito se llama **Pterodactyl**.
Ese panel no sabe nada de nuestro juego. Una **plantilla** (en Pterodactyl se llama *egg*, "huevo") es un archivo pequeño que le explica:

- qué imagen Docker o qué descarga usar,
- con qué comando arrancar el servidor,
- qué casillas enseñar al cliente (nombre, contraseña, máximo de jugadores…).

Con ella, el cliente pulsa "Crear servidor de Elixir Clandestino", rellena cuatro casillas y listo, sin escribir comandos.
Para nosotros es solo **un archivo de texto** que se hace al final, una vez que el servidor y Docker funcionan.

### 3.11 Máximo de jugadores: estimación y cómo medirlo

**Aviso honesto (ver también 3.12, que las corrige para el modo ligero):** estas cifras son **estimaciones razonadas, no medidas**. El juego no está probado todavía en Godot y no hay servidor. Sirven para decidir cuánto diseñar, no para prometer nada.

**Qué gasta el servidor por cada jugador:**

1. **Red**: unos 10 mensajes por segundo de posición. Poco: unos 3-10 KB/s por jugador.
2. **Zona del jugador**: peatones, tráfico, guardias y el trozo de mapa a su alrededor (colisiones). Es **lo más caro**, y se suma por jugador.
3. **Vehículos**: un jugador conduciendo gasta más que uno andando, y más si va rápido, porque carga trozos nuevos sin parar.
4. **Mundo común**: reloj, cultivos, economía. Casi gratis y no crece con los jugadores.

Dos jugadores **juntos** comparten zona (se reparten el coste). Jugadores **dispersos** por el mapa de 10 km cuestan el máximo cada uno. Por eso el límite depende más de **cómo se reparten** que de cuántos son.

**Estimación orientativa** (con la simulación por radio de 3.5, sin pantalla, y con peatones y tráfico moderados):

| Servidor | Jugadores cómodos | Jugadores en el límite | Qué falla primero |
|---|---|---|---|
| **PC casero** (4-6 núcleos, buena CPU, fibra) | 4-8 | 12-16 | Subida de internet y la CPU de un solo núcleo |
| **VPS pequeño** (2 núcleos, 4 GB, ~5 €/mes) | 3-6 | 8-10 | CPU compartida |
| **VPS potente** (4-8 núcleos, 8-16 GB, ~20-40 €/mes) | 10-20 | 24-32 | Una hebra: Godot reparte mal la IA |
| **Máximo teórico del diseño** (`max_jugadores`) | | 64 | Habría que poner varios servidores o simplificar la IA |

Estas cifras salen de suponer que cada jugador "activo" cuesta algo parecido a **medio núcleo** (mundo local, IA cercana, físicas) y que el servidor acepta bien una carga de 4-6 núcleos con Godot. Puede salir mejor o bastante peor.

**Lo que más sube el límite** (de más a menos efecto): bajar el radio de IA y de tráfico; menos peatones lejos del jugador; vehículos de IA simples; hilos para generar trozos; pasar los cálculos de zona del servidor a datos simples; actualizar la IA a 10 veces por segundo en vez de 60.

**Cómo mediríamos el límite real** (en una fase propia, justo después del hito mínimo):

1. **Clientes simulados** (*bots*): un modo `--bot` del propio juego, sin pantalla, que se conecta, camina por la ciudad, entra a tiendas, conduce y planta. Se ponen 10, 20, 40... en una sola máquina.
2. **Tres recorridos**: todos agrupados en la plaza, todos dispersos por los 10 km, y la mitad conduciendo rápido (el peor caso).
3. **Qué se mide**: tiempo por fotograma del servidor (objetivo: menos de 16 ms de media y nunca más de 50 ms), uso de CPU y memoria, ancho de banda por jugador y el **retardo** que ve un cliente.
4. **Resultado**: una tabla "jugadores cómodos / máximo" por tipo de máquina, que se guarda en `docs/RENDIMIENTO.md`, y un valor recomendado de `max_jugadores` para cada tipo.
5. **Servidor que se avisa solo**: cuando pasa de 30 ms de media, escribe un aviso en el registro; opcionalmente no deja entrar a más jugadores.

Estimación de esfuerzo: **2-3 sesiones** (bots + pruebas de carga + una pasada de mejoras). Se hace después de la fase 4, y se repite al acabar las fases 5 y 6, porque cada sistema nuevo cambia el límite.

### 3.12 ¿Debería necesitar poca potencia? Sí, con un "modo ligero"

Alfonso tiene razón en lo principal: **un servidor que no dibuja nada y solo guarda datos es muy ligero.**
Posiciones, vida, dinero, inventario, hora, cultivos y economía son números y textos. Eso lo aguanta hasta un VPS pequeño con muchos jugadores.

Lo que lo **encarece** no son los jugadores, es **el mundo vivo alrededor**:

| Cosa | Coste | Por qué |
|---|---|---|
| Datos de jugadores, hora, cultivos, economía | Muy bajo | Son cuentas, no dibujos |
| Peatones y tráfico con IA | Medio-alto | Cada uno decide, camina y choca varias veces por segundo |
| Guardias y policía persiguiendo | Medio | Buscan caminos y ven al jugador |
| Físicas y colisiones del mapa (trozos) | Alto | El servidor tendría que tener el terreno y los edificios "puestos" para comprobar choques |
| Vehículos con física completa | Alto | Es física de verdad para cada coche |

**Corrección a mis estimaciones (3.11):** las cifras de antes suponían un servidor "completo" (IA y física en el servidor). Con el **modo ligero** de abajo, calculo que sube, siempre con la misma salvedad de que son estimaciones sin medir:

| Servidor | Cómodos (modo completo) | Cómodos (modo ligero) |
|---|---|---|
| PC casero | 4-8 | 10-20 |
| VPS pequeño | 3-6 | 8-16 |
| VPS potente | 10-20 | 30-64 |

**Modo ligero** (se elige en `servidor.cfg`: `simulacion = "completa"` o `"ligera"`):

1. **Mundo dormido por zonas**: un trozo de mapa solo "despierta" (con IA y físicas) si hay un jugador cerca. Lejos de jugadores solo existen los **datos** (cultivos, propiedades, reloj). Es el truco de siempre y ya encaja con el reloj absoluto.
2. **Peatones y tráfico simplificados**: lejos del jugador no hay IA; se **generan** al acercarse según la hora (más gente de día, menos de noche) y se "esfuman" al alejarse. Pocos y con rutas fijas sobre `RedCalles`, sin física.
3. **Físicas solo cerca**: colisión de verdad solo en un radio pequeño de cada jugador. Fuera de él, el servidor solo comprueba límites de velocidad y de distancia.
4. **IA a menos frecuencia**: guardias y peatones deciden 5-10 veces por segundo, no 60. La posición se interpola.
5. **Vehículos**: el conductor manda su física y el servidor comprueba que sea razonable (sin chocar con cada piedra).
6. **Sin jugadores**: el servidor entra en **reposo**: solo reloj, cultivos y economía por reloj absoluto. Consume casi nada, así que se puede dejar encendido 24 h.

Coste: el mundo es **menos denso** de vida y la policía cerca de jugadores lejanos se simplifica. Se puede ofrecer el modo completo a quien tenga un servidor potente.

### 3.13 Seguridad y anti-trampas

**La regla de oro: el cliente nunca decide nada importante.** El cliente solo dice lo que *quiere hacer*; el servidor decide si se puede.

**Qué decide siempre el servidor** (el cliente no puede cambiarlo aunque modifique el juego):

| Cosa | Cómo se protege |
|---|---|
| Dinero, banco, nivel, xp | Solo cambia dentro del servidor. El cliente recibe el resultado |
| Vida y daño | El servidor calcula el daño y la muerte; ningún cliente se "cura" solo |
| Inventario | Comprar, vender, mover y usar pasan por el servidor. El cliente pide "mover casilla 3 a 5" y el servidor comprueba que el objeto existe |
| Posición | El cliente propone dónde está; el servidor comprueba **velocidad máxima**, distancia por salto, no atravesar muros importantes y no salir del mapa. Si no cuadra, lo devuelve al sitio válido |
| Vehículos | Velocidad y aceleración máximas por tipo; no se manejan vehículos ajenos ni a más de unos metros |
| Cultivos, granjas, tiempos | Con el reloj del servidor, nunca el del cliente |
| Compras y alquileres | Se cobra y se registra en el servidor, de forma atómica (todo o nada) |
| Aleatorio (cacheos, ofertas, qué cae) | Lo tira el servidor |
| Panel admin (F1) | Solo para los `admins` del `.cfg`, comprobado en el servidor. Un cliente normal no puede ni pedirlo |

**Validación de cada acción:** distancia (¿estás cerca de la tienda?), estado (¿tienes ese dinero?, ¿ese objeto?), tiempo (¿ya pasó el tiempo de espera?) y permiso (¿es tuyo?). Cualquier mensaje raro se ignora y se anota.

**Protección del servidor:**
- **Contraseña** y **lista blanca** (`whitelist.txt` con IDs permitidos) opcionales, más **lista de expulsados** (`bans.txt`).
- **Cifrado**: ENet de Godot permite cifrado (DTLS); se activa con una clave del servidor. El WebSocket usa `wss://` (TLS). Con Steam, la conexión ya va cifrada.
- **Límites de tasa**: máximo de mensajes por segundo por jugador. Si se pasa, se le avisa y luego se le expulsa. Evita inundar el servidor.
- **Límites de tamaño**: nunca se acepta un mensaje o texto enorme. Los nombres y chats se limpian.
- **Registro** (`registro.log`): quién entra y sale, compras grandes, expulsiones, acciones rechazadas y desconexiones raras.
- **Copias automáticas** del mundo y de los jugadores (cada X horas, guardando las últimas N), y guardado atómico (se escribe a archivo temporal y luego se renombra) para que un corte no corrompa nada.
- **Panel admin protegido**: consola solo por el contenedor o por una clave larga; la página web de estado solo con contraseña y HTTPS.
- **Versión del juego**: si un cliente tiene otra versión o archivos alterados, se rechaza con un mensaje claro.

**Qué se puede evitar y qué no (la verdad):**

| Trampa | ¿Se evita? |
|---|---|
| Dinero, objetos o nivel falsos | **Sí**, con servidor autoritativo |
| Volar o teletransportarse | **Sí** en gran parte (límites de velocidad y distancia) |
| Duplicar objetos | **Sí**, con transacciones del servidor y pruebas |
| Inundar el servidor | **Sí**, con límites de tasa |
| Mirar datos que el servidor ya te manda (ver a lo lejos, mapa) | **No del todo**: solo se manda lo cercano, pero lo que llega al cliente se puede leer |
| "Aimbot" o ayudas de apuntado (si hay PvP) | **Difícil**: se pueden detectar patrones raros, pero no se puede evitar al 100 % |
| Acelerar un poco dentro de los límites | **Se limita**, pero un margen pequeño es imposible de quitar |
| Programas externos que juegan solos (bots) | **No del todo**; se pueden limitar los patrones sospechosos |
| Admin malintencionado | Depende de a quién des el rol |

Un anti-trampas de tipo *Easy Anti-Cheat* para Steam se podría estudiar más tarde, pero no es necesario para un juego cooperativo con amigos. Con servidor autoritativo ya se evita lo grave. Las pruebas de seguridad son parte de la fase 9.

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
| **3. Servidor dedicado sin pantalla** | `--headless --servidor`, `servidor.cfg`, reloj y economía corriendo, guardado automático de mundo, sin nodos de escena (más Docker y guía VPS, ver 3.8) | 3-5 | **El mundo sigue vivo** con nadie dentro |
| **4. ENet: un cliente remoto (HITO MÍNIMO)** | `GestorRed`, conectar por IP, un jugador remoto que se mueve, ver la hora y plantar/cosechar | 3-4 | Tú y un amigo en el mismo mundo |
| **5. Varios jugadores** | Inventario/dinero por jugador, tienda, casas, encargos, policía por jugador, ver a otros con su aspecto, chat | 4-6 | 2-8 jugadores jugando |
| **6. Vehículos y tráfico en red** | Conductor con autoridad, remolques, IA solo cerca de jugadores | 4-5 | Coches compartidos |
| **7. Invitar y alojar fácil** | Código de sala (Worker) y UPnP; lista de servidores; WebSocket, guías de nube, consola y copias (ver 3.8) | 4-6 | "Dime el código" |
| **8. Steam** | GodotSteam, lista de amigos, relé, logros de Steam; **servidor dedicado en Steam** (AppID de servidor, SteamCMD, lista de servidores) = opción C | 4-5 | Unirse desde Steam y servidores en la lista |
| **8b. Plantilla Pterodactyl** | *Egg* para paneles de hosts de juegos, apoyado en C (opción D) | 1 | Hosts de juegos con un clic |
| **8c. Pruebas de carga** | Bots, tres recorridos de prueba, `docs/RENDIMIENTO.md` y `max_jugadores` recomendado (3.11) | 2-3 | Tabla real de jugadores por máquina |
| **9. Blindaje** | Anti-trampas y seguridad (3.13), admin autorizado, cifrado, límites de tasa, reconexión, **modo de simulación ligera** (3.12) | 4-5 | Servidor robusto |

Total aproximado: **37-52 sesiones**. Con un hito jugable ya en la fase 4 (**≈ 13-19 sesiones**).

### Primer hito mínimo viable (fases 0 a 4)

> Dos ordenadores: uno ejecuta el servidor, el otro se conecta por IP, entra al mundo, ve la hora del servidor, se mueve, siembra y cosecha en un huerto.
> Si el cliente sale y vuelve, **las plantas han crecido**.

Esto demuestra la idea completa (mundo que sigue vivo + invitar) con muy poco riesgo, y el resto son capas encima.

### Qué haría yo ahora mismo (sin riesgo)

1. Terminar de unir y probar en Godot lo que está en las ramas (mundo grande, guardado).
2. Empezar por la **fase 1** en una rama propia y con pruebas en el PC al acabar cada paso. Es el cambio más delicado porque toca ~1.000 líneas que usan `Juego`.

> En este PR solo va el documento. La fase 1 toca casi todos los archivos y el código actual no se ha probado en Godot, así que cambiarlo ahora sin poder ejecutarlo sería arriesgado.

## 7. Todas las opciones, sin decidir: se configuran

Alfonso quiere **tener todas las opciones**. El diseño no excluye ninguna: cada decisión es un ajuste de `servidor.cfg` (o de la pantalla "Crear partida"), y el código lee el ajuste en vez de dar nada por hecho.

| Decisión | Cómo queda configurable | Qué implica en el diseño |
|---|---|---|
| Número de jugadores | `max_jugadores` (1-64) | El servidor carga datos solo por jugador y zona de interés (3.4), así que escala sin cambios |
| Cooperativo o cada uno lo suyo | `modo = "propio"` o `"cooperativo"` | `EstadoJugador` guarda lo personal; en cooperativo, dinero, negocios y propiedades apuntan a un `EstadoEquipo` compartido en vez de al jugador. Hay que **diseñar los datos así desde la fase 1** |
| PvP y robos | `pvp`, `robos` | Cada daño y robo pasa por el servidor, que mira el ajuste antes de aplicarlo |
| Dónde alojar | A (descargable), B (Docker), C (servidor en Steam), D (Pterodactyl), anfitrión o un jugador | Un solo servidor, **cuatro envoltorios**: no hay código distinto para cada uno |
| Administración | `admins` y consola/comandos (3.8) | Rangos posibles: administrador, moderador, jugador |
| Transporte de red | `transporte` (`enet`, `websocket`, `steam`) | Todo va por `GestorRed`, así que se pueden activar varios a la vez |

Las cuatro opciones de alojamiento tienen su fase:

| Opción | Fase del plan |
|---|---|
| **A. Descargable** Windows/Linux | Fase 3 |
| **B. Imagen Docker** | Fase 3 (con guía VPS) y fase 7 (nubes) |
| **C. Servidor dedicado en Steam** | Fase 8 |
| **D. Plantilla Pterodactyl** | Fase 8b (después de C) |

Lo que sí hay que decidir (pero más adelante, no ahora): los **valores por defecto** de cada ajuste. Propuesta: 8 jugadores, `modo = "propio"`, PvP y robos desactivados, `transporte = ["enet"]`.
