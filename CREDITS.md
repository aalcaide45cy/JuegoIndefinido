# Créditos y licencias

Aquí se apunta **cada** asset de terceros que se meta en el juego: nombre del
paquete, autor, web y licencia. Solo licencias aptas para uso comercial
(CC0, o CC-BY con crédito). Nunca CC-NC.

| Asset | Autor | Web | Licencia |
|---|---|---|---|
| Fantasy Props MegaKit (versión Standard gratuita) | Quaternius | https://quaternius.com/packs/fantasypropsmegakit.html | CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/ |
| Medieval Village MegaKit (versión Standard gratuita) | Quaternius | https://quaternius.com/packs/medievalvillagemegakit.html | CC0 1.0 |
| Toon Shooter Game Kit | Quaternius | https://quaternius.com/ (https://quaternius.com/packs/toonshootergamekit.html) | CC0 según su web; el zip descargado no trae archivo de licencia |
| Universal Base Characters (versión Standard gratuita) | Quaternius | https://quaternius.com/packs/universalbasecharacters.html | CC0 1.0 |
| Downtown City MegaKit (versión Standard gratuita, 153 modelos glTF) | Quaternius | https://quaternius.com/packs/downtowncitymegakit.html (descarga: https://quaternius.itch.io/downtown-city-megakit) | CC0 1.0, según `License_Standard.txt` del zip |
| Game Icons (213 iconos de interfaz, en blanco y en negro) | Kenney | https://kenney.nl/assets/game-icons | CC0 1.0, según `license.txt` del zip |
| Car Kit 3.1 (coches, furgonetas, camiones, tractores y ruedas, en GLB) | Kenney | https://kenney.nl/assets/car-kit | CC0 1.0, según `License.txt` del zip |

Los archivos están en `assets/quaternius/` y `assets/kenney/` (cada paquete con su archivo
de licencia cuando lo trae). Los tres últimos se descargaron el 2026-11-16; del zip de cada uno
solo se copió la parte para Godot (glTF/GLB y PNG). El CC0 no obliga a dar crédito, pero se agradece.
No hay arte generado con IA en el juego.

Otros recursos:

| Recurso | Autor | Licencia | Nota |
|---|---|---|---|
| `icon.svg` (icono del proyecto) | Logotipo de Godot, de Andrea Calabró | CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ | Es el icono por defecto de Godot. **Hay que cambiarlo por uno propio antes de publicar en Steam.** |
| Sonidos (disparo, golpe, explosión, ambiente...) | Generados por código en `scripts/sonido.gd` | Propios | No hay archivos de audio de terceros. |
| Texturas de ruido de paredes y suelos | Generadas por código en `scripts/mundo/construir.gd` | Propias | |
| Fuente de letra | La que trae Godot por defecto | MIT / OFL (incluida en el motor) | |

Motor: Godot Engine (licencia MIT), https://godotengine.org
