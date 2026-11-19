# Assets y sonidos gratuitos recomendados (Juego Indefinido)

Investigación hecha el 2026-11-18. Cada licencia marcada **✅ verificada** la leí en la propia página del recurso. Lo marcado **⚠️ comprobar** no pude abrirlo (la web bloqueó mi lector) o no está claro: confírmalo tú en la página antes de usarlo en Steam. No es asesoramiento legal.

## Regla de oro de licencias (para Steam)

| Licencia | ¿Vale para Steam? | ¿Hay que dar crédito? |
|---|---|---|
| **CC0** (dominio público) | Sí, sin límites | No |
| **CC-BY** | Sí | Sí: lista de créditos en el juego/Steam |
| **OGA-BY** | Sí | Sí |
| **CC-BY-SA** | Evitar (obliga a compartir las modificaciones con la misma licencia) | Sí |
| **CC-BY-NC / NC** | NO (prohíbe uso comercial) | — |
| **GPL** | Evitar | — |

Consejo: usar solo CC0 siempre que se pueda. Así no hay que llevar créditos y no hay sorpresas. Guardar en cada carpeta de descarga el archivo `LICENSE.txt` / captura de la página.

---

## A) Modelos 3D low poly

### Prioridad 1: los que resuelven la ciudad (todos CC0)

| Recurso | Enlace | Licencia | Tamaño / contenido | Uso en el juego |
|---|---|---|---|---|
| **Kenney City Kit (Commercial)** | https://kenney.nl/assets/city-kit-commercial | CC0 ✅ | 50 archivos, v2.1 | Rascacielos y edificios de centro/comercios |
| **Kenney City Kit (Suburban)** | https://kenney.nl/assets/city-kit-suburban | CC0 ✅ | 40 archivos | Casas de barrio residencial y pueblos |
| **Kenney City Kit (Roads)** | https://kenney.nl/assets/city-kit-roads | CC0 ✅ | 70 archivos | Referencia/variantes de carretera, cruces, señales |
| **Kenney Car Kit** | https://kenney.nl/assets/car-kit | CC0 ✅ | 45 archivos (v3.0) | Coches de tráfico y de jugador |
| **Kenney Furniture Kit** | https://kenney.nl/assets/furniture-kit | CC0 ✅ | 140 archivos | Interiores: casas, tiendas, taberna, comisaría |
| **Quaternius Downtown City MegaKit** | https://quaternius.com/packs/downtowncitymegakit.html | CC0 ✅ (versión Standard gratis; la Source es de pago) | 300+ piezas modulares, FBX/OBJ/glTF | Calles y edificios estilo ciudad grande; ideal para zonas de ocio y noche |
| **Quaternius Modular Streets** | https://quaternius.com/packs/modularstreets.html | CC0 ✅ | 25 modelos, FBX/OBJ/Blend | Aceras, calles, mobiliario base |
| **Quaternius Cars Pack** | https://quaternius.com/packs/cars.html | CC0 ✅ | 8 coches | Más variedad de tráfico |
| **Kay Lousberg City Builder Bits** | https://kaylousberg.itch.io/city-builder-bits | CC0 ✅ | Gratis: 32+ modelos, 4,6 MB, OBJ/FBX/glTF, un solo atlas 1024x1024 | Edificios, farolas, árboles y detalles para rellenar las zonas verdes |

### Prioridad 1: personajes y animaciones (CC0)

| Recurso | Enlace | Licencia | Contenido | Uso |
|---|---|---|---|---|
| **Quaternius Universal Base Characters** | https://quaternius.com/packs/universalbasecharacters.html | CC0 ✅ (Standard gratis) | 6 cuerpos (hombre/mujer, 3 complexiones), 20 peinados, ~13k triángulos, FBX/glTF | Jugador y peatones con variedad |
| **Quaternius Universal Animation Library** | https://quaternius.com/packs/universalanimationlibrary.html | CC0 ✅ (Standard gratis) | 120+ animaciones (andar, correr, sentarse, muerte, combate, emotes) | Animar a todos los personajes |
| **KayKit Character Animations** | https://kaylousberg.itch.io/kaykit-character-animations | CC0 ✅ | 133 animaciones, ~12 MB, FBX/glTF | Alternativa/complemento (combate, magia) |

Nota técnica: las animaciones Quaternius y KayKit usan rigs distintos; elegir una familia y retargetear con Godot (`BoneMap` / `SkeletonProfileHumanoid`).

### Prioridad 2: cuando haga falta más variedad

| Recurso | Enlace | Licencia | Nota |
|---|---|---|---|
| **Poly Pizza** (7000+ modelos) | https://poly.pizza | **Mezcla CC0 y CC-BY** ⚠️ | No pude abrir su página de licencias. Mirar la licencia de CADA modelo; filtrar solo CC0. Bueno para objetos sueltos: tragaperras, neones, barra de bar, sofá, fuente |
| **Quaternius Medieval Village MegaKit** | https://quaternius.com/packs/medievalvillagemegakit.html | CC0 (por política de Quaternius) ⚠️ no abrí la página | Por si algún pueblo quiere estilo antiguo |
| **Quaternius Public Transport Pack** | https://quaternius.com/packs/publictransport.html | ⚠️ comprobar | Autobuses/tranvías |
| **OpenGameArt** (filtrar CC0) | https://opengameart.org | Varía por archivo | Aceptable: **CC0** y **OGA-BY** (con crédito). Evitar CC-BY-SA y GPL |
| **Poly Haven** (modelos, texturas, HDRIs) | https://polyhaven.com | CC0 ✅ | Texturas de asfalto, ladrillo, hormigón; cielos HDRI para el ciclo día/noche |
| **ambientCG** (texturas PBR) | https://ambientcg.com | CC0 ✅ (verificada en https://docs.ambientcg.com/license/, sin crédito obligatorio) | Texturas para suelos y paredes |

### Huecos que ninguno cubre bien (decirlo ya)
- Segunda búsqueda (2026-11-19): las tragaperras y packs de casino que salen son casi todos de pago (CGTrader, etc.); no los recomiendo. No hay pack gratuito CC0 verificado.
- **Discotecas / casinos / tragaperras / neones**: no hay un pack gratuito grande verificado. Plan: Poly Pizza (filtrando CC0) para tragaperras, barra y sofás, y **hacerlos nosotros** con cubos + materiales emisivos (neones) en Godot, que además queda coherente con el estilo. El pack de sonido Casino de Kenney ayuda mucho al ambiente.
- **Fuente de plaza**: probar en Poly Pizza; si no, la modelamos nosotros (piedra + agua con shader) que es lo que más mejora la plaza inicial.

---

## B) Sonidos y música

### Prioridad 1 (CC0, fáciles)

| Recurso | Enlace | Licencia | Contenido | Uso |
|---|---|---|---|---|
| **Kenney Casino Audio** | https://kenney.nl/assets/casino-audio | CC0 ✅ | 50 archivos (cartas, dados, fichas) | Casinos y tragaperras (monedas/fichas) |
| **Kenney Interface Sounds** | https://kenney.nl/assets/interface-sounds | CC0 ✅ | 100 archivos | Menús, móvil del jugador, avisos |
| **Kenney UI Audio** | https://kenney.nl/assets/ui-audio | CC0 ✅ | 50 archivos | Botones e inventario |
| **Kenney Impact Sounds / Digital / RPG Audio** | https://kenney.nl/assets (buscar "audio") | CC0 (política general de Kenney ✅) | ⚠️ no pude abrir estas páginas para ver el nº de archivos | Golpes, pasos, puertas, combate |
| **Sonniss GDC Game Audio Bundle** | https://gdc.sonniss.com | Licencia propia royalty-free: según prensa, sin atribución y uso en proyectos ilimitados ⚠️ no pude abrir la web ni leer el texto completo | La de 2026: 7,47 GB o más, 17 proveedores, efectos de calidad profesional (ambientes, tráfico, sirenas, puertas, lluvia, multitudes) | **La mejor fuente única** de ambientes de ciudad, tráfico, lluvia y discoteca. Leer el `License.pdf` que viene dentro del zip antes de usar |

### Prioridad 2

| Recurso | Enlace | Licencia | Nota |
|---|---|---|---|
| **Freesound** (filtrar a CC0) | https://freesound.org | CC0 ✅ / CC-BY ✅ (con crédito) / **CC-BY-NC NO** | Requiere cuenta para descargar. Búsquedas útiles con filtro de licencia CC0: "city ambience", "traffic loop", "footsteps concrete", "rain loop", "door open", "cash register", "slot machine", "nightclub bass muffled", "siren police", "crowd bar". Anotar usuario+título de cada uno |
| **Pixabay** (sonido y música) | https://pixabay.com/sound-effects/ | Licencia Pixabay ✅: uso comercial, sin atribución, modificable; **prohíbe revender el archivo suelto** y usarlo como marca | Vale para incluirlo en el juego (no se reparte suelto). Algunos temas pueden tener reclamaciones de Content ID si se sube un vídeo a YouTube: ⚠️ no verificado |
| **Mixkit** | https://mixkit.co/free-sound-effects/ | "Sound Effects Free License" ⚠️ no pude leer los términos | Revisar su página de licencia antes |
| **OpenGameArt audio** | https://opengameart.org | Varía; solo CC0 / OGA-BY | Música de ambiente y loops |

Música: para el tono oscuro/nocturno buscar en OpenGameArt y Pixabay "dark ambient", "synthwave", "lofi noir", "club house loop" (los de discoteca pueden ser música cantada con copyright dudoso: elegir solo instrumentales con licencia clara). **Evitar cualquier música en Steam cuya licencia no puedas guardar por escrito.**

---

## C) Lista corta: "descargar primero"

Carpeta sugerida en tu PC: `M:\apps\JuegoIndefinido\assets_descargas\`

1. `modelos\kenney\` → City Kit Commercial, Suburban, Roads, Car Kit, Furniture Kit
2. `modelos\quaternius\` → Downtown City MegaKit (Standard), Modular Streets, Cars Pack
3. `modelos\kaylousberg\` → City Builder Bits (Free)
4. `personajes\` → Quaternius Universal Base Characters + Universal Animation Library
5. `sonidos\kenney\` → Casino Audio, Interface Sounds, UI Audio (+ Impact Sounds si lo ves)
6. `sonidos\sonniss_gdc\` → Bundle GDC (es grande, ~7,5 GB: descargarlo cuando puedas; guardar el PDF de licencia)
7. `sonidos\freesound\` → solo CC0, con un `creditos.txt` (usuario, título, enlace, licencia)
8. `texturas\polyhaven\` → asfalto, hormigón, ladrillo, cielos HDRI (opcional)

En cada carpeta, conserva el `License.txt` que traiga el zip y no mezcles archivos de distinta licencia.

## D) Cómo importarlos a Godot 4.7

- **Modelos**: preferir **glTF/GLB**; Godot los importa solos arrastrándolos a `res://assets/...`. FBX también funciona (Godot lo convierte). Los packs "kit" traen una textura atlas pequeña: déjala con filtro **Nearest** si quieres look low poly nítido.
- **Escenas por pieza**: doble clic en el modelo → *New Inherited Scene* → guardar como `.tscn` para añadirle colisión (`StaticBody3D`) y material.
- **Personajes**: importar el GLB, asignar un `AnimationLibrary` con las animaciones de Universal Animation Library y retargetear al esqueleto (Import → *Skeleton → Bone Map → SkeletonProfileHumanoid*).
- **Sonidos**: WAV para efectos cortos, OGG para ambientes/música largos. En el importador marcar *Loop* en ambientes y lluvia. Crear *Audio Buses* (Música, Efectos, Ambiente, UI) y reproducir con `AudioStreamPlayer3D` para sonidos en el mundo.
- **Orden**: copiar solo lo usado a `res://assets/` (no todo el bundle de Sonniss; pesa GB y llenaría el repositorio de GitHub).
- **Créditos**: crear `CREDITOS.md` con todo lo que tenga CC-BY y mencionar a Kenney, Quaternius y Kay Lousberg (no obligatorio en CC0 pero es buena práctica).

## E) Qué NO usar
Cualquier cosa con **NC** (no comercial), **SA/GPL** si no hay otra opción, packs de pago de la Unity/Unreal Asset Store (licencias que suelen prohibir su uso en otros motores) y música "gratis" de YouTube sin licencia escrita.
