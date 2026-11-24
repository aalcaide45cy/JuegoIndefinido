# Plan de mejora general de Indefinido

Fecha: 24 de noviembre de 2026. Rama: `claude/project-thread-q6xo1q`.

Este documento revisa **todo** el juego, lo compara con juegos conocidos y propone qué mejorar, en
qué orden y cómo saber que está bien hecho. Está escrito para leerlo sin saber programar: cada punto
dice **qué** se hace, **por qué** importa y **cómo se comprueba**. Los detalles técnicos van en
letra pequeña (`así`) para quien programe.

Cómo leer las marcas:

- **[EN CURSO: hilo X]**: lo está haciendo ahora otro hilo con Opus 5.5. Aquí solo va el objetivo, para
  poder comprobar después que se ha cumplido.
- **[HECHO EN ESTE PR]**: hecho y probado en esta rama.
- **[PENDIENTE]**: propuesto, sin empezar.
- Prioridad: **P0** (antes que nada), **P1** (siguiente), **P2** (cuando lo anterior esté firme),
  **P3** (pulido). Esfuerzo: **S** (horas), **M** (un día), **L** (varios días), **XL** (semanas).

---

## 0. Resumen en un minuto

1. **El mayor problema no era de juego, era de organización.** Había **40 PR abiertos** encadenados
   unos encima de otros (el 2 sobre el 1, el 12 sobre el 2, el 13 sobre el 12...). Nada estaba unido
   a `main`, y cada hilo nuevo partía de una rama distinta, así que los arreglos de uno no llegaban a
   los otros. **[HECHO EN ESTE PR]**: esta rama une las 12 ramas más recientes en una sola, con los
   choques resueltos, y pasa las pruebas automáticas.
2. **Ya se puede ejecutar Godot en la nube.** Hasta ahora todo se probaba en tu PC. He descargado
   Godot 4.7.1 en la nube y las pruebas automáticas y las capturas funcionan aquí. Eso acelera mucho
   el trabajo y no te ocupa el ordenador.
3. **Lo que más se nota al jugar** (y lo que pediste): personajes que solo andan, coches que parecen
   cajas que se deslizan, atropellos raros, nada se rompe, las armas no tienen peso. Esas cuatro áreas
   están **en curso** en hilos aparte (sección 3).
4. **Lo que falta para que sea un juego de Steam y no una demo**: mando, reasignar teclas, opciones de
   sonido, autoguardado, nombre definitivo, icono propio, página de tienda, logros dados de alta,
   y una "primera hora" de juego guiada. Parte de eso está **hecho en este PR** (sección 5).
5. **Lo que hace único al juego** ("vivir la vida": ser peluquero, fontanero, médico... con magia y
   un mundo enorme) está a medias: hay 10 oficios, pero la **magia no existe** todavía como sistema.
   Es el pilar más flojo y el que más diferencia al juego de otros.

---

## 1. Auditoría: cómo está cada parte hoy

Nota de 1 a 10 comparando con un juego indie de Steam de precio medio (15-25 €) en su lanzamiento en
acceso anticipado. Un 5 es "funciona pero se nota que es un prototipo".

| Área | Nota | Lo bueno | Lo que falla |
|---|---|---|---|
| Organización del trabajo | 3 → 7 | Mucho trabajo hecho, con pruebas automáticas (60 escenas de prueba) | 40 PR sin unir; ramas que se pisan. Arreglado en este PR (ver 1.1) |
| Mundo y ciudades | 7 | 10x10 km generado, 119 asentamientos, 6 estilos, montañas, túneles, aceras, casco antiguo | Repetitivo visto de cerca; poca "historia" en cada pueblo |
| Edificios e interiores | 6 | Todas las casas son huecas, con escaleras, pisos y muebles; negocios con mostrador | Muebles sin uso; nadie vive dentro de verdad; sin puertas interiores animadas |
| Personajes (IA) | 3 | Peatones con cebras, semáforos, charlas, huida | Solo andan por raíles; no se esquivan; no pelean bien |
| Combate, armas y heridas | 4 | 16 armas, sangre, charcos, trozos, opción de violencia | Sin retroceso ni impacto; heridas genéricas; no hay zonas del cuerpo |
| Física y destrucción | 2 | Cráteres y coches que revientan (tanda 1) | Casi todo es estático; las cosas no se caen ni se rompen |
| Vehículos y tráfico | 4 | 15+ modelos, ruedas que giran, semáforos, ceder el paso | Conducción sin peso, sin suspensión, sin daños; tráfico rígido |
| Jugabilidad y economía | 6 | Bucle cultivar-mezclar-vender, negocios, blanqueo, metas, logros | Poco rumbo tras la primera hora; pocas decisiones con consecuencia |
| Oficios ("ser cualquier cosa") | 5 | 10 oficios con avisos, peluquería con catálogo de peinados | Minijuegos simples; sin carrera ni ascensos de verdad |
| Magia | 1 | Pociones con efectos | No hay hechizos, ni escuela de magia, ni progresión mágica |
| Interfaz (UI) | 6 | Tema común, móvil con pestañas, mapa grande, inventario | Mucho texto pequeño; sin mando; ventanas que tapan el juego |
| Controles y accesibilidad | 2 → 5 | Teclas por posición física (sirve en cualquier teclado) | Sin mando ni reasignar teclas (hecho en este PR); sin opciones de accesibilidad |
| Sonido y música | 4 | Música y ambiente generados por código, mezcla por zona y hora | Sin sonido 3D (todo suena "en la cabeza"); sin control de volumen de efectos (hecho en este PR) |
| Guardado | 6 | 5 ranuras, migración del mundo | Sin autoguardado (hecho en este PR); sin copia de seguridad |
| Rendimiento | 6 | Fusión de mallas, luces por distancia, carga por trozos con hilos | Ver mediciones en 1.2; mucho trabajo por fotograma en la IA de tráfico |
| Gráficos y arte | 5 | Low poly con estilo común, ciclo día/noche, clima | Personajes de kits distintos; poca iluminación de ambiente; sin postproceso cuidado |
| Multijugador | 1 | Diseño escrito (docs/MULTIJUGADOR.md) y chat preparado | Nada jugable; el código no está pensado para red |
| Publicación en Steam | 2 | Logros preparados con nombres `ACH_*` | Sin nombre definitivo, icono, exportación, página, ni pruebas en otros PC |

### 1.1 Lo que había en GitHub (y cómo queda)

- 40 PR abiertos. Las ramas más nuevas (21 de noviembre) ya contenían a casi todas las anteriores,
  pero estaban **separadas en 12 puntas**: interiores (PR 37), negocios (PR 32), ciudades variadas
  (PR 38), destrucción (PR 36), combate y sangre (PR 35), panel de administrador (PR 34), carreteras
  (PR 33), peluquería (PR 26), peatones (PR 28) y gráficos (PR 30, dentro del 35).
- **Hecho en este PR**: todas unidas en `claude/project-thread-q6xo1q`. Hubo choques en 6 archivos;
  los importantes:
  - `generador_mundo.gd`: las casas de "ciudades variadas" (aceras, casco antiguo) y las de "peatones"
    (separación de la calle) se colocaban de dos maneras distintas. Ahora: casco antiguo como en
    ciudades variadas, y el resto con la separación mínima de 3,5 m que evita que los peatones
    atraviesen fachadas.
  - Negocios con interior propio (restaurante, bar...) e interiores generados para todos los edificios
    se montaban a la vez, uno encima del otro. Ahora los negocios de `datos/locales.gd` usan su interior
    propio y no se duplican.
  - Al unir salieron **dos fallos nuevos**, ya arreglados: (1) los interiores de peluquería, barbería y
    negocios nuevos daban error porque no tenían "programa" de salas; (2) con las aceras elevadas de
    ciudades variadas, los peatones andaban **hundidos 30 cm** dentro de la acera (la prueba los
    contaba "dentro de algo macizo" en 768 de 924 muestras; ahora 0).
- **Qué tienes que hacer tú**: en vez de unir 40 PR, basta con unir **uno**: el de esta rama (ver
  sección 7). Los PR viejos se pueden cerrar después, porque su contenido ya está dentro.

### 1.2 Mediciones de rendimiento

Hechas con la prueba nueva `tests/medir_rendimiento.tscn` (sitios fijos, de día y de noche). En la nube
no hay tarjeta gráfica, así que **los FPS de la nube no valen**; lo que sí vale es cuánto se dibuja
(llamadas de dibujo, objetos, triángulos) y cuántos nodos hay, porque eso es igual en cualquier PC.

| Sitio (día / noche) | Llamadas de dibujo | Objetos | Triángulos | Nodos | Vídeo (MB) |
|---|---|---|---|---|---|
| Plaza de la ciudad original | 1.148 / 1.236 | 1.778 / 1.890 | 1,03 M / 1,04 M | 13.205 | 258 |
| Aldea (Calseca) | 242 / 286 | 738 / 893 | 0,45 M / 0,48 M | 13.830 | 257 |
| Pueblo (Rosgal) | 428 / 436 | 915 / 1.023 | 0,83 M / 0,84 M | 14.835 | 275 |
| Ciudad (Norlar) | 459 / 436 | 1.030 / 1.018 | 0,95 M / 0,95 M | 15.069 | 296 |
| Pueblo de montaña | 443 / 443 | 988 / 1.019 | 0,79 M / 0,83 M | 14.243 | 274 |
| Vista aérea a 300 m | 2.200 / 2.378 | 2.737 / 2.952 | 1,71 M / 1,75 M | 13.233 | 256 |

Qué dicen estos números:

- **Las llamadas de dibujo están bien** (de 250 a 2.400; antes de la optimización de noviembre había
  20.000). La fusión de mallas funciona.
- **Los triángulos son muchos para un juego low poly**: casi 1 millón a pie y 1,75 millones desde el
  aire. Vienen sobre todo de los trozos lejanos y de los modelos de Quaternius, que tienen más detalle
  del que se ve. Hay margen con LOD (REN-2) y con mallas más simples para lo lejano.
- **Hay entre 13.000 y 15.000 nodos** en la escena. Cada nodo cuesta algo aunque no se vea; la IA, la
  física y el gore nuevos van a sumar más. Conviene vigilarlo (REN-3).
- Memoria de vídeo baja (unos 300 MB): no es un problema.
- Las capturas de cada sitio están en la carpeta del proyecto (`rend_*.jpg`).

Lectura: por debajo de **3.000 llamadas de dibujo** un PC medio va holgado a 60 FPS con el
renderizador de compatibilidad; por encima de **6.000** empieza a costar en tarjetas modestas. La meta
para Steam es que un PC de gama media (GTX 1660 / RX 580, 16 GB) vaya a **60 FPS en 1080p en calidad
media** en el peor sitio (ciudad de noche con lluvia).

### 1.3 Resultado de las pruebas automáticas en la rama unida

Se pasaron las 31 pruebas automáticas (`tests/prueba_*.tscn` y `prueba_recetas.gd`) con Godot 4.7.1
en la nube, más la nueva `prueba_opciones`:

- **Todas en verde** después de los arreglos de este PR, incluidas interiores, negocios, peatones,
  asaltos, policía, gore, destrucción, carreteras, partidas e interfaz.
- `prueba_policia` esperaba "exactamente 14 servicios" por ciudad; con los negocios nuevos (restaurante,
  bar, peluquería...) hay más. Se cambió a "al menos 14".
- `prueba_trafico` falló **una vez** ("coches sin ceder el paso") y pasó en la siguiente ejecución. Es
  intermitente: lo tiene en cuenta el hilo de vehículos y circulación.
- `prueba_peatones`: en una ejecución salió 1 peatón de 1.055 que cruzaba "por donde no debe" a través
  del tronco de un árbol de la acera. Lo tiene en cuenta el hilo de personajes (esquivar obstáculos).
- `prueba_graficos` necesita pantalla (saca capturas): no vale en modo sin ventana.

---

## 2. Comparativa con juegos de referencia

Se compara para **aprender ideas**, no para copiar contenido (nombres, personajes, mapas o arte de
otros juegos no se usan nunca). La columna "Coste en Godot" es realista para un equipo de una persona
con Claude programando.

### 2.1 Personajes que parecen vivos

| Juego | Qué hace bien | Qué tomamos | Coste en Godot |
|---|---|---|---|
| GTA V | Cada peatón tiene horario, reacciona al ruido, a las armas y a los coches; unos huyen, otros graban con el móvil, otros pelean | Reacciones por **personalidad** (cobarde, valiente, curioso, agresivo) en vez de una sola reacción | M |
| Red Dead Redemption 2 | Los PNJ recuerdan lo que les hiciste, saludan, discuten, tienen rutinas de trabajo | **Memoria corta**: si le pegas a alguien, te reconoce un rato; rutinas por oficio | L |
| Cyberpunk 2077 (tras sus parches) | Multitudes densas que se apartan entre sí de forma suave | **Evitación local** entre peatones (cada uno esquiva a los cercanos), barata y sin navegación | M |
| The Sims | Necesidades (hambre, sueño, ocio) que deciden qué hace cada uno | **Necesidades sencillas** para los vecinos de las casas: por eso duermen, comen o salen | L |
| Kenshi | Cada cuerpo tiene miembros con vida propia | Base para heridas por zona (ver 2.2) | — |

Técnica recomendada: **árbol de comportamiento** ligero hecho en GDScript (sin complementos), con
**utilidad** para elegir objetivo (cada opción tiene una puntuación según la situación) y **evitación
local por fuerzas** (RVO simplificado) para no chocar. Navegación de Godot (`NavigationAgent3D`) solo
para interiores y persecuciones, no para cada peatón de la calle. **[EN CURSO: hilo "Dar comportamiento
realista a los personajes"]**.

### 2.2 Combate, heridas y desmembramiento

| Juego | Qué hace bien | Qué tomamos | Coste |
|---|---|---|---|
| Soldier of Fortune (2000) | Zonas de impacto: cabeza, brazos, piernas, torso; cada zona reacciona distinto | **Zonas de impacto** con multiplicador de daño y reacción propia | M |
| Dead Island 2 | Heridas que se ven en el cuerpo, miembros que se separan por zona | **Miembros separables** en personajes low poly (cada miembro es una malla aparte) | L |
| Fallout (3, NV, 4) | Miembros "tullidos": brazo herido apunta peor, pierna herida cojea | **Efecto de juego** de cada herida, no solo visual | M |
| GTA V / Max Payne 3 | Personajes que caen con física y se agarran la herida | **Muñeco de trapo** (ragdoll) al morir y tambaleo al recibir | L |
| Hotline Miami | Impacto brutal con pocos medios: sacudida de cámara, pausa de 2 fotogramas, sonido seco | **"Jugo" del disparo**: retroceso, destello, sacudida, casquillos, marcas | S-M |

Objetivo: cada disparo **se siente** (retroceso, destello, sonido, marca en la pared, reacción del
blanco) y el cuerpo responde según dónde le das: cabeza = muerte en 1-2 balas, pierna = cojea y cae,
brazo = suelta el arma, torso = sangra. Siempre con la opción de violencia (apagada / reducida /
completa) que ya existe en Gráficos, y con aviso de contenido en la tienda de Steam.
**[EN CURSO: hilo "Mejorar armas, heridas y desmembramiento"]**.

### 2.3 Física y destrucción

| Juego | Qué hace bien | Qué tomamos | Coste |
|---|---|---|---|
| Teardown | Todo se rompe (vóxeles) | Demasiado caro para un mundo de 100 km². **No** | XL |
| Red Faction: Guerrilla | Edificios que se derrumban por piezas | Solo para **objetos pequeños y medianos** (vallas, farolas, buzones, mesas, cristales) | L |
| GTA V | Mobiliario urbano que salta al chocarlo, cristales que se rompen | **Objetos que pasan de quietos a físicos** al recibir un golpe, y vuelven a quietos al pararse | M |
| Half-Life 2 | Cajas, barriles y botellas con física por todas partes | Cajas, barriles, sillas, botellas en interiores: **física solo cerca del jugador** | M |

Regla de rendimiento: los objetos son **estáticos fusionados** hasta que algo los toca; entonces se
cambian por un `RigidBody3D` suelto, y cuando se paran y el jugador se aleja vuelven a dormir. Máximo
unos 150 cuerpos activos a la vez. **[EN CURSO: hilo "Añadir física y destrucción al escenario"]**.

### 2.4 Vehículos y tráfico

| Juego | Qué hace bien | Qué tomamos | Coste |
|---|---|---|---|
| GTA V | Conducción "arcade con peso": suspensión que se nota, derrapes controlables, daños visibles | **Suspensión por rueda con rayos**, inercia, derrape, carrocería que se abolla por zonas | L |
| BeamNG.drive | Deformación real | Demasiado caro. Tomamos solo **abolladuras por zona** y piezas que se caen (puertas, capó, parachoques) | — |
| My Summer Car | Cada coche "tiene carácter": ruido, arranque, marchas | **Sonido de motor por revoluciones** y marchas (generado por código, como la música) | M |
| Cities: Skylines | Tráfico que fluye: carriles, giros con prioridad, atascos que se disuelven | Tráfico con **distancia de seguridad**, frenada suave, cambios de carril y adelantamientos | M |

**[EN CURSO: hilo "Mejorar vehículos y circulación"]**.

### 2.5 Vida, oficios y economía

| Juego | Qué hace bien | Qué tomamos | Coste |
|---|---|---|---|
| Schedule I (tu referencia) | Bucle de negocio claro: producir, mejorar, contratar, expandir; cada mejora se nota | Ya está en el núcleo. Falta **que cada mejora cambie cómo juegas**, no solo los números | M |
| The Sims 4 | Carreras con niveles, horario y tareas; vida diaria con necesidades | **Carrera por oficio** con 5 rangos, horario, sueldo y ascensos | L |
| Stardew Valley | Rutina diaria con sorpresas; relación con vecinos; estaciones | **Eventos aleatorios** y **relación con vecinos** (amistad, favores, enemistad) | L |
| Medieval Dynasty | Construir y ser cualquier cosa (cazador, granjero, artesano) | Oficios que **producen cosas** que otros oficios usan (cadena de producción) | L |
| Kenshi | Libertad total: sin camino marcado | Mantener la libertad, pero con **metas visibles** para no perderse | — |

### 2.6 Magia (el pilar que falta)

| Juego | Qué hace bien | Qué tomamos | Coste |
|---|---|---|---|
| Skyrim | Escuelas de magia que suben al usarlas | **Escuelas** (alquimia, ilusión, naturaleza, sombras) que suben con el uso | M |
| Noita | Hechizos que se combinan de formas raras | **Combinar ingredientes** (ya existe en las pociones) también para hechizos | L |
| Harry Potter: Hogwarts Legacy | Hechizos útiles fuera del combate (abrir, levantar, reparar) | **Magia útil en los oficios**: el fontanero que arregla con un hechizo, el peluquero que tiñe con magia | M |
| Elixir Clandestino (la idea original del juego) | La magia es ilegal | **Riesgo**: usar magia en público sube la sospecha de la policía; de noche o a escondidas, no | S |

---

## 3. Las cuatro áreas que están en curso (objetivos para comprobar)

Estas las hacen otros hilos. Aquí va **qué tiene que cumplirse** para darlas por buenas, para que
puedas comprobarlo tú o el siguiente hilo.

### 3.1 Personajes: comportamiento, esquivar, pelear **[EN CURSO]**

- [ ] Los peatones **se esquivan entre ellos** sin tocarse y sin pararse en seco (prueba: 40 peatones en
  una acera de 2,5 m en ambos sentidos, ninguno se solapa más de 10 cm durante 60 s).
- [ ] Cada uno tiene **personalidad** (cobarde, normal, valiente, agresivo) y **rutina** (casa, trabajo,
  ocio) según la hora.
- [ ] Ante un disparo o un atropello: unos huyen, otros se esconden, otros miran o llaman a la policía,
  algunos **pelean a puñetazos** y unos pocos **sacan un arma** (más en barrios peligrosos).
- [ ] Dentro de las casas: el dueño **vive** (duerme, come, ve la tele) y si entras reacciona según su
  personalidad (grita, llama a la policía, te ataca con las manos o con lo que tenga).
- [ ] Animaciones que casan con lo que hacen (andar, correr, agacharse, golpear, caer, levantarse).
- [ ] Rendimiento: 60 peatones cerca sin bajar de 60 FPS en tu PC.

### 3.2 Armas, heridas y desmembramiento **[EN CURSO]**

- [ ] Zonas de impacto: cabeza, torso, brazos, piernas, con daño y reacción distintos.
- [ ] Desmembramiento de cabeza, brazos y piernas con muñón, sangre y trozo que cae con física.
- [ ] Efectos de arma: retroceso de cámara, destello, casquillos, humo, marcas de bala en paredes,
  chispas en metal, astillas en madera.
- [ ] Atropellos: el cuerpo sale despedido con física según la velocidad (no un salto raro),
  rueda por el suelo y queda tendido.
- [ ] Todo respeta la opción de violencia (apagada = sin sangre ni miembros).

### 3.3 Física y destrucción **[EN CURSO]**

- [ ] Farolas, vallas, señales, buzones, bancos, papeleras, cajas y barriles caen o salen volando al
  chocarlos o dispararlos.
- [ ] Cristales de ventanas y escaparates se rompen.
- [ ] Explosiones empujan todo lo cercano.
- [ ] Nada atraviesa el suelo; nada tiembla quieto; se duermen al pararse.
- [ ] Límite de cuerpos activos y limpieza de restos para no perder rendimiento.

### 3.4 Vehículos y circulación **[EN CURSO]**

- [ ] Conducción con peso: aceleración, frenada, derrape, suspensión que se nota en baches y curvas.
- [ ] Daños por zona: abolladuras, cristales rotos, humo, piezas que se caen, rueda pinchada.
- [ ] Sonido de motor por revoluciones.
- [ ] Modelos mejorados (proporciones, ruedas, luces que funcionan de noche, intermitentes).
- [ ] Tráfico: distancia de seguridad, frenada suave, adelantar, reaccionar a accidentes y al jugador
  (pitar, esquivar, huir, perseguir si eres policía).

---

## 4. Plan por áreas (todo lo demás)

### 4.1 Organización, pruebas y calidad

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| ORG-1 | Unir todas las ramas abiertas en una | Sin esto cada hilo trabaja sobre un juego distinto | La rama arranca y pasa las pruebas | P0 | M | **HECHO EN ESTE PR** |
| ORG-2 | Unir esa rama a `main` y cerrar los PR viejos | Una sola versión del juego | `main` contiene todo; 0 PR viejos abiertos | P0 | S | Pendiente de ti (sección 7) |
| ORG-3 | Ejecutar Godot en la nube | Probar sin ocupar tu PC | Pruebas y capturas desde la nube | P0 | S | **HECHO** (Godot 4.7.1) |
| ORG-4 | Prueba de rendimiento con sitios fijos | Saber si cada cambio lo empeora | `tests/medir_rendimiento.tscn` escribe un CSV | P0 | S | **HECHO EN ESTE PR** |
| ORG-5 | Comprobación automática en GitHub (CI) | Que cada PR diga solo si rompe algo | Al abrir un PR sale verde/rojo | P1 | M | Pendiente |
| ORG-6 | Regla: cada hilo parte de la rama de integración y abre su PR contra ella | Evitar volver a 40 PR encadenados | Todos los PR nuevos apuntan a la misma base | P0 | S | Comunicado a los 4 hilos |

### 4.2 Rendimiento

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| REN-1 | Presupuesto por fotograma: IA ≤ 3 ms, física ≤ 3 ms, dibujo ≤ 8 ms en tu PC | Que lo nuevo no se coma el rendimiento | Monitor de F3 y CSV de medidas | P0 | S | Pendiente |
| REN-2 | Nivel de detalle (LOD) en personajes y coches: lejos, malla simple y sin animación | Los personajes animados son lo más caro | 60 peatones + 40 coches sin bajar de 60 FPS | P1 | M | Pendiente |
| REN-3 | IA escalonada: lejos, piensa 2 veces por segundo; cerca, cada fotograma | Ahorra CPU | Tiempo de `_process` de VidaUrbana < 2 ms | P1 | S | Pendiente (coordinar con hilo IA) |
| REN-4 | Ocultar interiores que no se ven (oclusión simple por habitación) | Muchos muebles dibujados detrás de muros | Bajan las llamadas dentro de ciudad | P2 | M | Pendiente |
| REN-5 | Probar en un PC modesto o en la nube con límites (gráfica integrada) | Steam lo juega gente con PC normales | 30+ FPS en "bajo" con gráfica integrada | P2 | M | Pendiente |
| REN-6 | Tiempos de carga: medir arranque y aparición de trozos | Los tirones al conducir rápido molestan mucho | Sin pausas > 50 ms conduciendo a 120 km/h | P1 | M | Pendiente |

### 4.3 Gráficos y arte

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| GRA-1 | Guía de estilo low poly de una página: paleta, tamaño de polígono, cómo se ilumina | Mezclar kits (Quaternius, Kenney, IA) da un aspecto desigual | Capturas lado a lado coherentes | P1 | S | Pendiente |
| GRA-2 | Un solo tipo de personaje base para todos (mismo esqueleto, ropa y peinado intercambiables) | Hoy hay personajes de kits distintos | Todos los PNJ con el mismo esqueleto | P1 | L | Pendiente (coordinar con hilo IA y armas: el desmembramiento lo necesita) |
| GRA-3 | Iluminación de ambiente: cielo con degradado, niebla de altura, luz rebotada falsa | Le da "atmósfera" y oculta la distancia | Capturas antes/después | P1 | M | Pendiente |
| GRA-4 | Postproceso por hora y clima (corrección de color, viñeta suave, bloom de noche) | Estilo propio y tono oscuro del juego | Preset "cinematográfico" en Gráficos | P2 | S | Pendiente |
| GRA-5 | Ventanas iluminadas por dentro de noche y farolas con halo | La ciudad de noche es la imagen del juego | Captura aérea nocturna | P1 | S | Pendiente |
| GRA-6 | Variedad de fachadas: balcones, toldos, macetas, cables, carteles por estilo | Las calles se repiten | 10 casas seguidas sin dos iguales | P2 | M | Pendiente |

### 4.4 Mundo y ciudades

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| MUN-1 | Un "sitio con nombre" en cada pueblo: iglesia, castillo, mercado, molino, faro | Que cada pueblo se recuerde | Cada asentamiento tiene un punto de interés en el mapa | P1 | M | Pendiente |
| MUN-2 | Rutas y señales: nombres de calles, carteles de distancia en carretera | Orientarse sin abrir el mapa | Cartel en cada cruce de carretera | P2 | M | Pendiente |
| MUN-3 | Zonas con identidad: barrio rico, barrio peligroso (más bandas, más armas), polígono, campo | El riesgo y la recompensa cambian según dónde estés | Distintos PNJ, precios y policía por zona | P1 | M | Parte hecha (distritos) |
| MUN-4 | Fauna: perros, gatos, pájaros, ganado en el campo | Vida fuera de las ciudades | Animales con comportamiento sencillo | P2 | M | Pendiente |
| MUN-5 | Estaciones del año (colores de árboles, nieve en montaña en invierno) | Paso del tiempo | Cambia cada 7 días de juego | P3 | M | Pendiente |

### 4.5 Edificios e interiores

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| EDI-1 | Que **todos** los edificios se puedan entrar (también comisaría, hospital, iglesias, naves) | Lo pediste expresamente | Auditoría automática: 0 edificios con puerta falsa | P0 | M | Casi hecho (PR 37 + este PR); falta la ciudad original |
| EDI-2 | Muebles que se usan: sentarse, tumbarse, abrir neveras y armarios, encender la tele | Que el interior no sea decorado | 6 muebles con acción | P1 | M | Pendiente |
| EDI-3 | Puertas interiores que se abren, ascensor en edificios altos | Moverse por dentro | Recorrido completo de un edificio de 5 pisos | P2 | M | Pendiente |
| EDI-4 | Personas dentro según la hora (dueño, familia, clientes, empleados) | Lo pediste | Ver 3.1 | P1 | — | **EN CURSO** (hilo IA) |
| EDI-5 | Tu casa personalizable: comprar y colocar muebles libremente | Construir/bases (tus gustos) | Colocar, girar, vender muebles | P1 | M | Parte hecha (colocar con G) |

### 4.6 Jugabilidad, economía y progresión

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| JUG-1 | **Primera hora guiada**: 8 pasos que enseñan cultivar, mezclar, vender, oficio, coche, policía | Las reseñas de Steam se escriben en las 2 primeras horas | Alguien nuevo llega solo al paso 8 | P0 | M | Pendiente |
| JUG-2 | Metas a 3 plazos siempre visibles: hoy, esta semana, la gran meta | "No sé qué hacer" es la queja n.º 1 de los juegos de mundo abierto | Siempre hay una meta en el HUD | P1 | S | Parte hecha (metas del móvil) |
| JUG-3 | Eventos aleatorios: redada, robo en tu negocio, cliente famoso, tormenta que arruina cosecha | Sorpresa y decisiones | 1 evento cada 10-15 min de juego | P1 | M | Pendiente (ver IDEAS_JUEGO_INTERESANTE.md) |
| JUG-4 | Reputación por grupo: vecinos, policía, bandas, gremio de magos | Consecuencias de tus actos | La gente te trata distinto según tu fama | P1 | M | Pendiente |
| JUG-5 | Dormir y esperar con resumen de lo que pasó | Ritmo; pedido en MEJORAS.md | Al despertar, lista de cosechas, cobros, avisos | P2 | S | Pendiente |
| JUG-6 | Equilibrio de armas y combate (tabla de daño frente a vida de enemigos) | Hoy el lanzagranadas no tiene rival que lo justifique | Tabla en `datos/` y prueba automática | P2 | S | Pendiente (después del hilo de armas) |
| JUG-7 | Muerte con consecuencias claras (hospital, pierdes dinero negro, el coche queda donde estaba) | Riesgo | Mensaje claro al morir | P2 | S | Parte hecha |

### 4.7 Oficios ("ser cualquier cosa")

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| OFI-1 | Carrera de 5 rangos por oficio (aprendiz → maestro) con sueldo y herramientas mejores | Progresión dentro de cada vida | Subir de rango cambia lo que puedes hacer | P1 | M | Pendiente |
| OFI-2 | Un **minijuego propio** por oficio (cortar pelo, desatascar, curar, apagar fuego, cocinar) | Que cada oficio se juegue distinto | 10 oficios = 10 minijuegos | P1 | L | Parte (peluquería, cocina, mortero) |
| OFI-3 | 10 oficios nuevos: fontanero, electricista, taxista, repartidor, mecánico, cocinero, granjero, pescador, albañil, ladrón profesional | Lo pediste | Cada uno con aviso de trabajo y paga | P1 | L | Pendiente (ver OFICIOS_Y_VARIEDAD.md) |
| OFI-4 | Montar tu propio negocio de cualquier oficio y contratar | Gestión (tu gusto favorito) | Peluquería propia con 2 empleados | P2 | L | Parte (negocios y personal) |
| OFI-5 | Oficios que se ayudan: el granjero vende al cocinero, el mecánico arregla el taxi | Economía viva | Cadena de 3 oficios funcionando | P3 | L | Pendiente |

### 4.8 Magia

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| MAG-1 | Diseño del sistema de magia en `docs/MAGIA.md` (escuelas, maná, aprendizaje, riesgo legal) | Es el pilar que diferencia al juego | Documento aprobado por ti | P0 | S | Pendiente (necesita tu visto bueno) |
| MAG-2 | 4 escuelas con 3 hechizos cada una: Naturaleza (crecer cultivo, calmar animal, curar), Ilusión (disfraz, invisibilidad corta, distraer), Fuerza (empujar, levantar, escudo), Sombras (abrir cerraduras, apagar luces, miedo) | Magia útil en combate y fuera | 12 hechizos jugables | P1 | L | Pendiente |
| MAG-3 | Magia en los oficios (tinte mágico en la peluquería, desatasco mágico, curación mágica) | Une los dos pilares | 1 uso mágico por oficio | P2 | M | Pendiente |
| MAG-4 | Riesgo: lanzar en público con testigos sube la sospecha y las estrellas | Tono del juego (la magia es ilegal) | Testigos → policía | P1 | S | Pendiente |
| MAG-5 | Efectos visuales mágicos low poly (partículas de colores, runas en el suelo) | Que se vea espectacular | Capturas | P1 | M | Pendiente |

### 4.9 Interfaz

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| UI-1 | Opciones agrupadas: Gráficos, **Sonido**, **Controles**, Juego | Hoy el volumen solo está en el panel de administrador (F1) | Menú de pausa con las 4 entradas | P0 | S | **HECHO EN ESTE PR** (Sonido y Controles) |
| UI-2 | Escala de la interfaz (80 %-150 %) y tamaño de texto | Legibilidad en monitores grandes y pequeños | Opción en Juego | P1 | S | Pendiente |
| UI-3 | Navegar todos los menús con mando | Steam Deck y mando | Abrir, mover y cerrar cada ventana sin ratón | P1 | M | Parte (ver CTR-2) |
| UI-4 | Iconos en lugar de texto en el HUD (vida, dinero, estrellas, hambre) | Menos lectura, más juego | HUD con iconos | P2 | S | Parte hecha |
| UI-5 | Pantalla de carga con consejos | Primeras impresiones | Consejo al arrancar | P3 | S | Pendiente |

### 4.10 Controles y accesibilidad

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| CTR-1 | Reasignar teclas y guardarlas | Básico en cualquier juego de PC | Cambiar "usar" a F y que funcione al reiniciar | P0 | S | **HECHO EN ESTE PR** |
| CTR-2 | Mando (Xbox/PlayStation/Steam Deck): moverse, mirar, disparar, usar, saltar, correr, inventario, móvil | Steam muestra "compatible con mando" y eso vende | Jugar 10 min sin teclado | P0 | M | **HECHO EN ESTE PR** (juego; menús con ratón todavía) |
| CTR-3 | Sensibilidad del ratón y del mando, invertir eje vertical | Comodidad | Opciones en Controles | P0 | S | **HECHO EN ESTE PR** |
| CTR-4 | Modo daltónico (marcadores del mapa y del HUD) | 1 de cada 12 hombres es daltónico | Filtros en Juego | P2 | S | Pendiente |
| CTR-5 | Reducir sacudidas de cámara y destellos | Mareo y fotosensibilidad | Opción "reducir efectos" | P1 | S | Pendiente (coordinar con hilo de armas) |

### 4.11 Sonido y música

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| SON-1 | Volumen general, música, ambiente y **efectos** por separado | Básico | 4 deslizadores en Sonido | P0 | S | **HECHO EN ESTE PR** |
| SON-2 | Sonido 3D: los disparos, coches y voces suenan desde donde están y bajan con la distancia | Hoy todo suena "dentro de la cabeza" | Un disparo a tu izquierda suena por la izquierda | P1 | M | Pendiente (coordinar con hilos de armas y coches) |
| SON-3 | Voces cortas de PNJ (gritos, saludos, quejas) generadas o grabadas | Vida | 20 frases por tipo de personaje | P2 | M | Parte (gritos) |
| SON-4 | Música con licencia o hecha a medida, por zona y tensión | La música generada sirve de base pero se nota | 6 pistas | P2 | M | Pendiente |
| SON-5 | Eco y reverberación dentro de edificios y túneles | Realismo barato | Bus con reverb al entrar | P2 | S | Pendiente |

### 4.12 Guardado

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| GUA-1 | Autoguardado cada X minutos (elegible) y al salir | Perder una hora de partida = reseña negativa | Matar el juego y volver: como mucho X min perdidos | P0 | S | **HECHO EN ESTE PR** |
| GUA-2 | Copia de seguridad: el guardado anterior se conserva como `.bak` | Un guardado corrupto no pierde la partida | Si el archivo se rompe, carga el `.bak` | P1 | S | **HECHO EN ESTE PR** |
| GUA-3 | Guardado en la nube de Steam | Jugar en dos PC | Config en Steamworks (carpeta `user://`) | P2 | S | Pendiente (al publicar) |
| GUA-4 | Migración de guardados entre versiones con prueba automática | Las actualizaciones no rompen partidas | Cargar guardado viejo en versión nueva | P1 | M | Parte (versión del mundo) |

### 4.13 Multijugador

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| MUL-1 | **No empezar** hasta tener el juego de un jugador firme | Meter red en un juego sin terminar multiplica el trabajo por 3 | — | — | — | Decisión |
| MUL-2 | Mientras tanto: separar "estado del juego" de "lo que se ve" en los sistemas nuevos | Preparar sin coste | Revisión de código | P2 | S | Regla para los hilos |
| MUL-3 | Cooperativo de 2-4 jugadores como primer paso (no servidor de 8) | Mucho más sencillo y probado en indies | Prototipo en red local | P3 | XL | Pendiente (ver MULTIJUGADOR.md) |

### 4.14 Publicación en Steam

| ID | Qué | Por qué | Cómo se comprueba | Prio | Esf. | Estado |
|---|---|---|---|---|---|---|
| STE-1 | Nombre definitivo (propuesta: **Indefinido** o **Contrato Indefinido**) | Hoy el proyecto aún se llama "Elixir Clandestino" | Búsqueda de marca y en Steam | P0 | S | Necesita tu decisión |
| STE-2 | Icono y cápsulas (imágenes de la tienda) propias | El icono actual es el de Godot | Imágenes en los tamaños de Steam | P1 | M | Pendiente |
| STE-3 | Configuración de exportación para Windows (y Linux para Steam Deck) | Sin esto no hay ejecutable | `export_presets.cfg` y prueba de exportar | P0 | S | **HECHO EN ESTE PR** (plantilla) |
| STE-4 | GodotSteam para logros, nube y estadísticas | Integración | Logros que saltan en Steam | P2 | M | Parte (código preparado) |
| STE-5 | Aviso de contenido (violencia, sangre, drogas ficticias) y edad | Obligatorio en Steam | Cuestionario de Steam | P1 | S | Pendiente |
| STE-6 | Créditos y licencias de todos los assets (Quaternius CC0, Kenney CC0, Fab estándar) | Legal | `CREDITS.md` completo | P1 | S | Parte hecha |
| STE-7 | Demo para el Steam Next Fest | La forma más barata de conseguir listas de deseos | Demo de 60 min estable | P2 | M | Pendiente |

---

## 5. Lo que hace este PR (además del plan)

1. **Une las 12 ramas abiertas** en una sola y resuelve los choques (sección 1.1).
2. **Arregla los dos fallos de la unión**: interiores de servicios sin programa y peatones hundidos en
   la acera.
3. **Controles** (`scripts/controles.gd`, `scripts/ui/ventana_controles.gd`):
   - Reasignar cualquier tecla (Esc → Controles → pulsa la acción y luego la tecla nueva). Se guarda en
     `user://controles.cfg`.
   - **Mando**: stick izquierdo para andar o conducir, stick derecho para mirar, gatillo derecho
     disparar, gatillo izquierdo apuntar, A saltar, B agacharse, X usar, Y recargar, LB/RB cambiar de
     objeto, pulsar stick izquierdo correr, Select móvil, Start pausa, cruceta arriba mapa.
   - Sensibilidad del ratón y del mando, e invertir el eje vertical.
4. **Sonido** (`scripts/ui/ventana_sonido.gd`): volumen general, música, ambiente y efectos (bus nuevo
   "Efectos" para los sonidos del juego).
5. **Autoguardado** (`scripts/autoguardado.gd`): cada 5 minutos por defecto (se puede cambiar o apagar
   en Esc → Sonido y juego), y copia `.bak` del guardado anterior.
6. **Steam**: plantilla de exportación para Windows y Linux (`export_presets.cfg`) y lista de
   publicación (`docs/STEAM.md`).
7. **Prueba de rendimiento** con sitios fijos y CSV (`tests/medir_rendimiento.tscn`) y prueba
   automática de lo nuevo (`tests/prueba_opciones.tscn`).

---

## 6. Hoja de ruta por hitos

| Hito | Qué contiene | Cuándo está listo |
|---|---|---|
| **H1. Base sana** | Rama única unida a `main`; 4 hilos en curso terminados (IA, armas, física, coches); controles, sonido y autoguardado | Todas las pruebas en verde y 30 min de juego sin errores en tu PC |
| **H2. Primera hora** | Tutorial de 8 pasos, metas visibles, eventos aleatorios, reputación | Alguien nuevo juega 1 h sin preguntar qué hacer |
| **H3. Vivir la vida** | Carrera en 5 rangos, 10 oficios nuevos con minijuego, negocio propio de cualquier oficio | Se puede "vivir" de 5 oficios distintos |
| **H4. Magia** | 4 escuelas, 12 hechizos, magia en oficios, riesgo legal, efectos | La magia se usa a diario en una partida |
| **H5. Pulido** | Estilo visual unificado, personajes con un solo esqueleto, sonido 3D, música, accesibilidad, LOD | Capturas y vídeo de tráiler que se ven profesionales |
| **H6. Steam** | Nombre, icono, cápsulas, exportación, logros, nube, página, demo | Página publicada y demo en Next Fest |
| **H7. Después del lanzamiento** | Cooperativo 2-4, estaciones, fauna, más ciudades | Según las reseñas |

Regla de oro: **no empezar un hito nuevo con el anterior roto**. Cada hito termina con una partida de
prueba de 30 minutos en tu PC y las pruebas automáticas en verde.

---

## 7. Qué tienes que hacer tú (en orden)

1. **Revisar y unir el PR de esta rama** (`claude/project-thread-q6xo1q`) en GitHub. Contiene todo lo
   de los PR 26 a 38 más lo de este plan.
2. Cuando los 4 hilos en curso terminen, **unir sus PR** (irán contra esta misma rama o contra `main`).
3. Decidir el **nombre definitivo** (STE-1) y si quieres el **diseño de magia** (MAG-1) tal como se
   propone en 4.8.
4. Después, los PR viejos (1 a 39) se pueden **cerrar sin unir**: su contenido ya está dentro.

---

## 8. Riesgos

| Riesgo | Probabilidad | Impacto | Qué hacemos |
|---|---|---|---|
| Los 4 hilos en curso tocan los mismos archivos (`vida_urbana.gd`, `jugador.gd`, `guardia.gd`) | Alta | Choques al unir | Todos parten de esta rama; se unen de uno en uno con las pruebas en verde |
| El rendimiento cae al sumar IA + física + gore | Alta | 30 FPS en PC medio | Presupuesto por fotograma (REN-1) y prueba de rendimiento en cada PR |
| El alcance crece sin fin ("ser cualquier cosa" es infinito) | Alta | El juego nunca sale | Hitos cerrados; lo que no entra va a "después del lanzamiento" |
| Contenido violento y drogas ficticias | Media | Clasificación por edad, menos visibilidad | Opción de violencia, aviso de contenido, hierbas ficticias |
| Assets de distintas fuentes y licencias | Media | Problemas legales | `CREDITS.md` al día; solo CC0 o licencia Fab estándar |
| Todo probado en un solo PC (RTX 4090) | Alta | Va mal en PC normales | REN-5 y pruebas con usuarios antes de la demo |

---

## 9. Reglas para los hilos que programen (resumen)

1. Partir de la rama de integración (`claude/project-thread-q6xo1q` o `main` cuando se una).
2. Un PR por tema, contra esa misma base. Nunca encadenar PR.
3. Pasar las pruebas automáticas en la nube antes de pedir revisión (`tests/LEEME.md`) y adjuntar capturas.
4. Seguir las reglas de rendimiento: materiales compartidos, fusión de mallas, luces por distancia,
   física solo cerca, IA escalonada.
5. Todo lo que se pueda ajustar va en `scripts/datos/` (números en un solo sitio).
6. Escribir en español sencillo los comentarios y los documentos.
