# Assets de Unreal para Elixir Clandestino (prueba en Unreal 5.8)

Fecha: 2026-11-21. Esto es una **prueba para comparar con la versión de Godot**. No toca el juego de Godot.

## De dónde sale la lista

- Proyecto Unreal abierto: `C:\PR_UE\UE584\TestClaude` (Unreal 5.8). Está **vacío** (sin assets, solo la plantilla básica con el plugin de modelado).
- La caché local de Fab (`VaultCache`) está vacía: la lista de compras solo vive en tu cuenta. La leí de **fab.com/library** con tu sesión abierta: **1.048 productos**.
- Tipos: 508 modelos 3D, 275 herramientas/plugins, 63 sistemas de juego, 50 tutoriales, 46 efectos (VFX), 42 materiales, 19 audio, 18 plantillas, 15 animaciones, 9 UI, 2 sprites, 1 HDRI.

## Licencias: qué se puede vender en Steam

Fab muestra la licencia de **cada compra**. En tu cuenta hay estas:

| Licencia en Fab | ¿Vale para vender en Steam? |
|---|---|
| Standard / **Professional** | Sí |
| **UE Marketplace License** (los packs comprados en el antiguo Marketplace) | Sí, dentro de un juego hecho con Unreal |
| **CC-BY** | Sí, pero hay que **dar crédito** al autor (poner en CREDITS.md) |
| **Personal** (solo) | **No**: solo aprender o probar. Hay que evitarlo en el juego final |

Los packs marcados **[SOLO PERSONAL]** abajo no se pueden vender. De tus 1.048 compras, unas 125 son solo personales, unas 36 son CC-BY y el resto (~890) vale para uso comercial. Los de Epic Games (Paragon, Infinity Blade, City Sample, Edith Finch...) y Quixel Megascans se pueden usar en juegos hechos con Unreal. **Aviso:** esto es lo que muestra Fab, conviene revisar la licencia concreta de un pack antes de publicar.

## Resumen: los 12 packs más importantes para empezar

Prioridad **A** = imprescindible para el primer prototipo, **B** = muy útil, **C** = más adelante.

| # | Pack | Autor | Para qué | Prioridad |
|---|---|---|---|---|
| 1 | Stylized Character Kit: Casual 01 | Epic Games | Vecinos, clientes, jugador | A |
| 2 | Modern City Downtown Megapack + Dokyo Modular Neighborhood | Leartes / Dokyo | Calles, edificios y barrios | A |
| 3 | Wily Pumpkin: Modular Medieval Town with Interior | Wily Pumpkin | Casas con interior, tono medieval | A |
| 4 | Lowpoly Alchemist's House | Yevheniia Yaremko | Herboristería / casa del alquimista | A |
| 5 | Inventory System (HowToCompute) + Pawnshop System | HowToCompute / DarkDreamStudio | Inventario y tiendas | A |
| 6 | Ultimate Spell System + Advanced Magic FX 12 y 13 | Risecode / Kakky | Magia y efectos | A |
| 7 | Flexible Combat System - Basic + Basic Multiplayer Melee | Jon Beardsell / RodrigoMello | Combate cuerpo a cuerpo | A |
| 8 | Vehicle Game (plantilla) + City Sample Vehicles + Vehicle Variety Pack 1 y 2 | Epic / Switchboard | Coches y tráfico | A |
| 9 | Open World AI Spawn System + Crowd Simulation System Pro | Tim van Kan / varios | Peatones y guardias que aparecen y desaparecen | B |
| 10 | Good SKY + Weather System | Uneasy Game Dev / varios | Día y noche, lluvia, niebla | B |
| 11 | Paragon: Sevarog / Countess / Morigesh / GRIM.exe | Epic Games | Enemigos y jefes oscuros | B |
| 12 | Ultimate Farming + Project Nature (plantas) | CropCraft / Project Nature | Cultivo de hierbas, huertos | B |

## Selección por categoría

### 1. Ciudad, calles y barrios (prioridad A)
- **Modern City Downtown Megapack**, **Bank Building / Interior** (Leartes Studios): ciudad moderna con edificios con interior.
- **Modular Neighborhood Pack**, **Hospitality Pack**, **Shanty Town Slums** (Dokyo): barrios modulares, bares, barrio pobre (tono oscuro).
- **Modular Building Set**, **Downtown West Modular Pack** (PurePolygons): para montar manzanas a medida.
- **Synty POLYGON - Town Pack / City Pack**, **Assetsville Town**: estilo low poly, ligeros (como el Godot actual).
- **City Sample Buildings / Vehicles / Crowds** (Epic): del demo de Matrix. Muy bonito pero **muy pesado**; mejor para sacar piezas sueltas que para usar entero.
- **[Free] Procedural Building Generator**, **Advanced Level Design Tool Kit**, **Prefabricator**: para generar edificios y ciudades rápido.
- Tono oscuro/fantasía: **Fantasy and Medieval Architecture Kit** (Denys Rutkovskyi), **Modular Gothic/Fantasy Environment** (Stormcrow), **Modular Victorian House** (ZhenyaChistovsky), **Modular Old Town** (CropCraft), **Medieval Kingdom** (beffio), **Stylized Village** (Hivemind), **The Bazaar** (Meshingun), **Dark Forest** y **Palace Hall** (Dave Berg), **Ithris Cemetery**, **Greenwood Fantasy Village**.

### 2. Casas con interior y muebles (A)
- **Wily Pumpkin: Modular Medieval Town with Interior**, **Interior Toolkit** (ZhenyaChistovsky), **Mediterranean Rustic Interior**, **Fantasy Interior Environment** (Leartes), **Low Poly Medieval Interior and Constructions** (PolyArt3D).
- Muebles: **Old West VOL.1 Interior Furniture** (Dekogon), **Free Furniture Pack** y **Modern House** (Next Level 3D), **MEDA Furniture Pack**, **Houseplant Pack**.
- Tiendas y oficios: **Grocery store props collection** (JessyStorm), **Toolshed / Garage Props**, **Old West Tradesmen Tools and Props**, **Goods and Supplies**, **Clay Pots Pack**, **Food Pack 01**, **Steampunk Props Pack**, **Hospitality Pack**.
- Para que las casas "huecas" funcionen: **Easy Building System V10**, **Player Building System V1**, **Ultimate Interaction Manager**, **Interaction System**.

### 3. Personajes, vecinos y NPC (A/B)
- **Stylized Character Kit: Casual 01** (Epic), **Renderpeople Scanned 3D People** (realistas), **Ultimate Character** (Vahid), **Posed Humans** (Twinmotion).
- Fantasía: **Fantasy Characters pack**, **Hero for RPG**, **Wizard for Battle**, **Skeleton Knight Modular**, **Goblin warrior**, **Werewolf**, **Ancient Golem**, **Undead Pack**.
- Movimiento: **Advanced Locomotion System V4**, **Dynamic Locomotion**, **Rolls and Dodges Animation Set**, **Strike A Pose**, **Foot IK**, **Mantling System**.
- IA y multitudes: **Open World AI Spawn System**, **Advanced AI Spawn System**, **Crowd Simulation System Pro**, **World Director NPC PRO**, **GOAP NPC**, **VisAI**, **City Sample Crowds** (Epic), **NPC Optimizator**.

### 4. Combate y sangre (A/B)
- Sistemas: **Flexible Combat System - Basic**, **Basic Multiplayer Melee Combat System**, **Close Combat: Swordsman**, **Combat Systems - Constructor**, **Action RPG** (plantilla de Epic), **Target System**, **Event-Driven Hit Trace System [SOLO PERSONAL]**.
- Animaciones: **Death Animations - MoCap Pack**, **Close Combat Animset**, **Sword and Shield First Person Animation Set**, **Zombie Movement and Modular Interaction Animations**, **Phoenyx Anim Pack 3**.
- Física: **Multiplayer Ragdoll**, **Passive Ragdoll**.
- Armas: **Infinity Blade: Weapons**, **Over 9000 Swords**, **FPS Weapon Bundle / Assault Pack** (Deadghost), **Military Weapons Dark/Silver**, **Dunpix Weapon Customization System**, **EasyBallistics**, **Ballistics FX**.
- Enemigos y jefes: **Paragon** (Sevarog, Countess, Morigesh, GRIM.exe, Revenant, Greystone...), **Infinity Blade: Adversaries**, **City of Brass: Enemies**.
- **Hueco:** no he visto un pack de sangre/gore específico. Habría que hacerlo con Niagara (partículas) o buscar uno aparte.

### 5. Magia y efectos (A)
- **Ultimate Spell System** (Risecode), **Ability Pack - Time And Space**, **Advanced Magic FX 12 y 13** (Kakky), **Mega Magic VFX Bundle**, **RPG FX Starter Pack**, **Infinity Blade: Effects**, **Absorption FX**, **Luos's Particle Toolkit Vol. 1**, **Explosions Builder**, **Smoke Builder**, **Character Body FX**, **Materialize VFX**.
- **Solo personales** (no para vender): Zap VFX, Easy Shockwaves, Niagara Slash, Cinematic Magic 3D VDB Pack, Basic VFX Pack (Free).

### 6. Oficios, cultivo y economía (A/B)
- Inventario: **Inventory System** (HowToCompute), **Inventory System V1** (Gamma), **Action RPG Inventory System**, **Elementus Inventory**, **Adventurer's Inventory Kit**.
- Tiendas: **Pawnshop System**. Recolección: **Gathering Resources - Advanced System**. Misiones: **Ultimate Quest Manager**, **Quest Editor Plugin**. Diálogos: **Blueprint Dialogues**, **Dialogue System X**, **Dialogue Plugin**.
- RPG: **RPG Stats**, **Advanced RPG System**, **Open World RPG Toolkit**, **Easy Multi Save** (guardar partida), **Save Extension**.
- Plantas y granja: **Ultimate Farming** (CropCraft), **Farm Animals Pack**, **Project Nature** (muchas plantas, flores, helechos, bayas), **NatureManufacture Meadow**, **Dragon Motion Flowers and Plants**, **Dynamic Grass System Lite**, **Megascans (Meadow Pack, Forest Undergrowth...)**.
- Pociones: **200 Potion RPG icons [SOLO PERSONAL]** y **Craft Resources Icons** (REXARD, comercial) para iconos.
- Notas: hay **63 "game systems"** y **18 plantillas** en total; arriba solo van las más relevantes.

### 7. Vehículos y tráfico (A)
- **Vehicle Game** (Epic), **City Sample Vehicles** (Epic), **Vehicle Variety Pack 1 y 2** (Switchboard), **Drivable Cars: Basic Vehicle System**, **Truck and Trailers** (VMR), **Stylized Truck Pack**, **Car Dealer [CC-BY]**.
- Física y manejo: **Easy Vehicle Suspension [v2]**, **VehicleSim Dynamics**. Tráfico: **Vehicle Navigation**, **Open World AI Spawn System**.

### 8. Cielo, clima, luz (B)
- **Good SKY**, **Dynamic Volumetric Sky**, **Weather System**, **Clouds Lighting System**, **Matte Painting Skybox Pack**, **Rain - Water Drop - Flow Material**, **IES Light Profile Pack**, **Fog Gradients**, **Interactive Lights System**.

### 9. Materiales y texturas (B)
- **Megascans** (30 colecciones gratuitas con Unreal), **Urban Material Pack**, **56 Fabric & Textile Materials**, **4K Wood Flooring 01 y 02**, **Hand Painted Textures Starter Kit**, **Advanced Glass Material Pack**, **Brushify - Environment Shaders**.

### 10. Interfaz (B)
- **User Interface Kit**, **Generic Radial Menus**, **Menu Builder Carousel**, **Craft Resources Icons**, **Pro Icon Pack**, **SDF Robo Progress Bars**. **Basic RPG UI Starter Kit [SOLO PERSONAL]**.

### 11. Audio (B)
- Comerciales: **Human Vocalizations** (gritos), **Interface & Item Sounds Pack**, **Sound Phenomenon Fantasy Orchestra**, **Autumn Audio Bundle**, **Retro 8Bit Sounds**, **Paragon: Male Announcer**.
- Con crédito (CC-BY): **Free Fantasy Music Pack**, **Cinematic Trailer Music**, **Classical Music Collection**, **Free City & Nature Sounds** (Gregor Quendel y otros).
- **Solo personales:** Free City Ambiences, Essential Footsteps SFX, General Whoosh SFX, Free UI Soundpack.

## Qué evitar (licencia solo personal)

Por ejemplo: Survival Craft: Inventory, Height Lighting, Virtual Photography Kit, Simple Inventory System, Time Clock, Auto Footstep, Death Area System, Nurc Studio Stylized Weapons, Low Poly Buildings WI, Modern Japanese Furniture, Luxury Vehicle, Stylized Female Character, Skeleton Guard (Modular), todos los VDB Pack de one.studio2, Zap VFX y Tentacles VFX. La lista completa se saca filtrando "Licencia" en fab.com/library.

## Qué falta (si hace falta comprar)

- Sangre y gore (decales de sangre, salpicaduras, miembros).
- Un barrio medieval-oscuro hecho y derecho con casas con interior para **todo** el mapa (tenemos piezas modulares, no una ciudad).
- Sonidos de ambiente y pasos de licencia comercial (los gratuitos son personales).

## Plugin MCP para que Claude maneje el editor de Unreal (sin instalar)

- **En tu biblioteca:** "Unreal-MCPython: AI Assistant Plugin" (licencia **solo personal**). Sirve para probar, no para el producto final.
- Otros conocidos (no los he revisado ni instalado): proyectos de código abierto en GitHub llamados `unreal-mcp`. Antes de instalar uno hay que revisar el código y que soporte Unreal 5.8.
- Pendiente: decidir con Alfonso si lo probamos.

## Plan sugerido para la prueba

1. Crear un mapa pequeño: 1 calle, 2 casas con interior (Wily Pumpkin + muebles de Dekogon) y la herboristería (Alchemist's House).
2. Personaje de Epic (Stylized Character Kit) con Advanced Locomotion + Flexible Combat.
3. Un coche de Vehicle Game y un peatón con Open World AI Spawn System.
4. Un hechizo con Ultimate Spell System + Advanced Magic FX.
5. Comparar el resultado con el Godot actual.

## Pendiente de comprobar

- Compatibilidad exacta con Unreal 5.8 de cada pack (los antiguos pueden pedir actualizar).
- Peso en disco de los packs grandes (City Sample, Paragon, Megascans).
- Licencia concreta de cada pack antes de publicar en Steam.
