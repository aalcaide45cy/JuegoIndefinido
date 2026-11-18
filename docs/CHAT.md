# Chat del juego

Chat dentro del juego con canales, avisos del sistema y una capa de mensajes lista para el modo servidor (ver `docs/MULTIJUGADOR.md`).

## Canales
| Canal | Atajo | Quién lo oye |
|---|---|---|
| Cercano | `/c` | jugadores a menos de **25 m** |
| Gritar | `/gr` | a menos de **120 m** (sale en MAYÚSCULAS, espera de 8 s) |
| Grupo | `/g` | tu grupo, estés donde estés |
| Privado | `/p NOMBRE texto` (`/w`, `/r` responde) | solo esa persona |
| Facción | `/f` | tu facción |
| Sistema | — | avisos del juego (cobros, encargos, policía, cosechas…); nadie escribe ahí |

Teclas: **Enter** (o `/`) escribe · **Tab** cambia de canal · **↑ ↓** recupera lo escrito · **Esc** cierra · ⚙ filtros, silenciados, grupo y facción.
Otros comandos: `/ayuda`, `/limpiar`, `/silenciar NOMBRE`, `/desilenciar NOMBRE`, `/grupo unir X|salir`, `/faccion unir X|salir`, `/jugadores`.

## Cómo está hecho
```
PanelChat (pantalla)  ->  Chat (autoload, cliente)  ->  ServidorChat (reglas, sin nodos)
                              |  @rpc (solo en red)
                              v
                          servidor: reparte a cada cliente
```
- `scripts/chat/canales.gd`: datos (nombres, colores, alcances, límites).
- `scripts/chat/servidor_chat.gd`: **todas las reglas**; no depende de nodos, así que el servidor dedicado (headless) lo usa tal cual. El cliente nunca decide a quién llega un mensaje.
- `scripts/chat/gestor_chat.gd` (autoload `Chat`): historial, comandos, avisos del juego, ajustes guardados (`user://chat.cfg`) y la puerta de red: `_rpc_enviar` (cliente → servidor) y `_rpc_recibir` (servidor → cliente). Sin partida en red todo es local.
- `scripts/ui/panel_chat.gd`: pestañas con contador de no leídos, colores por canal, filtros, historial de 300 líneas, se vuelve casi transparente cuando no se usa.

## Seguridad y moderación (en el servidor)
- Límite de tasa: 5 mensajes cada 8 s por jugador, mínimo 0,6 s entre dos; gritar cada 8 s.
- Anti-spam: el mismo texto 3 veces en 30 s se rechaza. 3 infracciones en un minuto = silencio de 60 s.
- Texto limpio: máximo 200 letras, sin corchetes (nadie cuela formato), sin caracteres de control; filtro de palabras feas ampliable (`palabras_feas`).
- Lista de ignorados por jugador; el admin puede silenciar (`silenciar_jugador`).
- El sistema (canal Sistema) solo lo crea el servidor.

## Un jugador
Los avisos de `Juego.avisar` / `nuevo_aviso` entran por Sistema y se clasifican (cobros, encargos, policía, cosechas, otros). Cuatro vecinos simulados (Marta, Dani, Iván, Lucía) se mueven a 9, 18, 70 y 200 m y hablan por todos los canales, así el alcance se nota igual que en un servidor. Marta y Dani están en tu grupo «Callejeros», Marta e Iván en la facción «Círculo de la Bruma».

## Pruebas
```
godot --headless --path . res://tests/prueba_chat.tscn        # reglas, límites, comandos, avisos
godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 res://tests/captura_chat.tscn -- <carpeta>
```
