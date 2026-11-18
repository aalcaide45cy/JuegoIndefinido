# Indefinido: documento de diseño (antes "Elixir Clandestino")

Última revisión: 2026-11-18, sobre la rama `claude/project-thread-bxnc21` (la del PR #2,
con vehículos, granja, inmobiliaria y aspecto del jugador). Es un documento de lectura:
explica cómo encaja todo, qué números tiene el juego hoy, qué está desequilibrado y cómo
crecer hasta un mapa de **10 km x 10 km**. La lista de tareas ordenada está en
[`MEJORAS.md`](MEJORAS.md).

> Todas las cifras de este documento salen de leer el código (no de jugar), porque la
> nube no puede ejecutar Godot. Donde dice "estimado" es un cálculo a mano.

---

## 1. Visión en una frase

Eres un herborista en una ciudad donde la magia está prohibida. De día llevas un negocio
normal (huertos, granja, tienda). De noche cultivas Hoja de Bruma, cocinas pociones
vetadas y las vendes a escondidas mientras la guardia del Prefecto te busca. Con el
dinero amplías el escondite, compras vehículos, aprendes habilidades y llegas más lejos.

Tono: oscuro, algo absurdo. Primera persona por defecto (V cambia a tercera).

## 2. El bucle de juego

**Corto (1 a 5 minutos)**: comprar semillas, tierra y agua → plantar (minijuego) → esperar
(o dormir) → cosechar → machacar o cocinar (minijuego de remover) → empaquetar → vender
(ventanilla de tu casa o encargo del móvil). Cada paso da XP.

**Medio (30 a 90 minutos)**: subir de nivel para abrir objetos en las tiendas, mejorar
macetas (nivel 1-3, riego, abono), poner lámparas y focos, alquilar más casas y huertos,
montar una granja de tapadera, comprar un coche para llegar más lejos.

**Largo (horas)**: aprender habilidades, comprar armas para defenderte, tener vehículos de
carga, propiedades en varios barrios, reputación alta con los clientes. Aquí el juego
**todavía no tiene meta ni dinero que gastar** (ver sección 6).

**Riesgo**: todo lo ilegal (hierba, poción, paquete, arma de fuego, explosivo) sube la
sospecha. La guardia te cachea, te registra la casa o te persigue. Es lo que hace que
vender de noche por la ventana o llevar cosas encima tenga un coste.

Lo que falta para cerrar el bucle: más gastos que se repitan (el personal ya cobra por día),
progresión de riesgo (más policía cuanto más rico eres) y una meta final.

---

## 3. Mapa de sistemas (qué hay y dónde está)

| Sistema | Archivos | Datos | Estado |
|---|---|---|---|
| Estado de la partida (dinero, vida, hora, XP, inventario) | `scripts/juego.gd` (autoload `Juego`) | variables en el propio script | Hecho |
| Guardado y carga | `scripts/guardado.gd` | `user://partida.json` | Hecho; valida los datos al cargar |
| Objetos y precios | `scripts/datos/objetos.gd` | 56 objetos | Hecho; es la fuente de verdad |
| Hierbas y pociones | `scripts/game_data.gd` | 2 hierbas, 3 pociones | Hecho, **pocas recetas** |
| Habilidades | `scripts/datos/habilidades.gd` | 4 habilidades | Solo abren compras, **no dan efectos** |
| Inventario y barra rápida | `juego.gd`, `ui/casilla_ui.gd`, `ui/ventanas.gd` | 63 casillas, pila máx. 20 | Hecho |
| Tiendas | `mundo/barrio.gd` (`tienda_con_interior`), `ui/ventanas.gd` (`Tienda`) | campo `tienda` de cada objeto | 11 tiendas, 6 tipos |
| Cultivo de hierbas | `objetos/maceta_3d.gd`, `ui/minijuego_plantar.gd` | `GameData.HIERBAS` | Hecho |
| Cocina y empaquetado | `objetos/caldero_3d.gd`, `ui/barra_remover.gd`, `objetos/empaquetadora.gd`, `objetos/mortero.gd` | `GameData.POCIONES` | Hecho |
| Venta (ventanilla) | `objetos/mostrador.gd`, `ui/negociacion.gd` | precio de la poción | Hecho |
| Encargos del móvil | `encargos.gd`, `ui/telefono.gd`, `objetos/comprador.gd` | 10 lugares fijos | Hecho |
| Casas y huertos (alquiler/compra) | `datos/propiedades.gd`, `ui/inmobiliaria.gd`, `objetos/puerta_casa.gd` | 5 casas, 8 huertos | Hecho |
| Cultivo legal | `objetos/parcela.gd` | 3 cultivos | Hecho |
| Granja | `objetos/corral.gd`, `objetos/arbol_frutal.gd` | 2 especies, manzanos | Hecho |
| Vehículos | `vehiculos/vehiculo.gd`, `gestor_vehiculos.gd`, `objetos/concesionario.gd` | `Vehiculo.TIPOS` | Hecho (otro hilo sigue en ello) |
| Policía | `combate/guardia.gd`, `ui/cacheo.gd`, `juego.registrar_casa()` | sospecha 0-100, alerta | Hecho |
| Combate y armas | `combate/combate.gd`, `proyectil.gd`, `c4_carga.gd`, `diana.gd` | daño en `objetos.gd` | Hecho |
| Personal (bolsa de trabajo, sueldo diario) | `gestor_personal.gd`, `datos/personal.gd` | 3 oficios, máx. 8 | Hecho (nuevo, sin probar) |
| Montaje de objetos | `objetos/colocable.gd` | lámpara y foco | Hecho |
| Aspecto del jugador | `jugador/aspecto.gd`, `ui/ventana_aspecto.gd` | trajes, sombrero | Hecho |
| Mundo | `mundo/mundo.gd`, `barrio_*.gd`, `red_calles.gd`, `construir.gd`, `ciclo_dia.gd` | calles a mano | ~400 x 220 m, construido de golpe |
| Interfaz | `ui/hud.gd`, `minimapa.gd`, `mapa_grande.gd`, `brujula.gd`, `panel_estado.gd` | | Hecho |

### Cómo se conectan (flujo del dinero y la XP)

```
 TIENDAS (herbolario, ferretería, panadería, botica, armería)
   │  semillas, tierra, jarra, mejoras, armas        ▲ revender: 50 % del precio
   ▼                                                  │ (solo lo que tiene precio > 0)
 MOCHILA ─────────────────────────────────────────────┘
   │
   ├─► MACETAS (casa)  ──► hierba_* ──► CALDERO ──► pocion_* ──► EMPAQUETADORA ──► paquete_*
   │        15-25 s            (precio 0: no se vende suelta)        (+30 %)
   │                                                   │
   │                                                   ├─► VENTANILLA (cliente en tu casa)   40-85 $
   │                                                   └─► ENCARGOS DEL MÓVIL (x1,15 a x1,6)  + reputación
   │
   ├─► HUERTO (campo, alquilado) ──► trigo/maíz/tomate ──► tienda a 50 %     (legal)
   └─► GRANJA (huevos, leche, manzanas) ──────────────────► tienda a 50 %     (legal)

 Dinero ──► propiedades (inmobiliaria) · vehículos (concesionario) · habilidades (academia) · mejoras
 XP ─────► nivel ─► desbloquea objetos en tiendas ;  Sospecha ─► cacheo/registro/persecución ─► multas
```

---

## 4. Organización de datos y código

### Lo que está bien
- Los objetos, precios, niveles y habilidades necesarios para comprar están en un solo
  archivo de datos (`objetos.gd`). Añadir un objeto no obliga a tocar más código.
- Los barrios son un script cada uno, que se coloca en `mundo.gd`.
- `Juego` guarda todo el estado y `Guardado` lo vuelca, con validación al cargar.

### Fuentes de verdad duplicadas (riesgo de que se descuadren)
| Dato | Dónde está repetido | Qué hacer |
|---|---|---|
| Precio de las semillas | `GameData.HIERBAS[...]["precio_semilla"]` y `objetos.gd` | Borrar el de `GameData` y leer de `objetos.gd` |
| Precio de alquiler de casas | `propiedades.gd`, `barrio_residencial.gd` (CASAS) y `GameData.PRECIO_ALQUILER` | Que los barrios lean `propiedades.gd` |
| Precio de huertos | `propiedades.gd` y `barrio_campo.gd` (HUERTOS) | Igual: una sola lista, el barrio la lee |
| Cultivos legales | constantes dentro de `parcela.gd` | Mover a `scripts/datos/cultivos.gd` |
| Animales y árboles | constantes dentro de `corral.gd` y `arbol_frutal.gd` | Mover a `scripts/datos/granja.gd` |
| Vehículos | `Vehiculo.TIPOS` dentro del script del vehículo | Mover a `scripts/datos/vehiculos.gd` |
| Lugares de encargos | lista fija en `encargos.gd` | Generar desde los datos del mapa (ver sección 7) |
| Calles y rutas de guardias | `red_calles.gd` a mano | Datos por zona, cargados con cada chunk |
| Objetivo "reunir 1000 $" | `GameData.OBJETIVO_DINERO` | Se cumple en ~10 minutos y sale "Prototipo superado": quitarlo o cambiarlo por metas reales |

### Propuesta de estructura de carpetas
```
scripts/
  datos/        objetos, habilidades, propiedades, cultivos, granja, vehiculos,
                recetas, economia  (SOLO datos, sin lógica)
  nucleo/       juego (autoload), guardado, reloj, economia (funciones de precio)
  mundo/        chunks, terreno, zonas, red de calles, barrios, ciclo día/noche
  sistemas/     encargos, policia, cultivo, cocina, granja, vehiculos, negocios
  ui/           ventanas, hud, mapa
```
No hace falta mover archivos ya: se hace a medida que se toquen, para no chocar con los
otros hilos que están programando.

### Reglas para el código nuevo (resumen de lo ya acordado)
1. **Datos fuera del código**: precios, tiempos, cantidades y listas van en `scripts/datos/`.
2. **Todo lo que crece o produce usa tiempo absoluto** (ver 7.4). Hoy `Parcela`, `Corral`,
   `ArbolFrutal` y las macetas solo avanzan mientras el nodo existe en la escena.
3. **Materiales compartidos**: si algo cambia de color, `Construir.material_propio()`.
4. **Mallas sin script se fusionan** al arrancar: lo que se mueva debe colgar de un nodo
   con script.
5. **Cada ventana nueva** sigue el patrón de `ui/ventana.gd` (cabecera, recetas a un lado,
   inventario al otro).
6. Un cambio de reglas de juego se anota en este documento (sección 5 o 6).

---

## 5. Economía: números actuales y diagnóstico

### 5.1 Punto de partida
- Empiezas con **200 $**. Alquilar la casa de la plaza cuesta 100 $; semillas 10 $, tierra 8 $,
  jarra 25 $, maceta 20 $. Con lo que queda se puede montar una maceta y empezar. Es un
  inicio ajustado pero jugable (bien).
- Revender a una tienda paga **el 50 %** del precio, sin XP. No se puede ganar dinero
  comprando y vendiendo (bien).
- Hierbas, pociones y paquetes tienen precio 0: **no se pueden vender a una tienda**, solo a
  clientes. Esto es lo que mantiene el riesgo del negocio ilegal (bien).

### 5.2 Las pociones (negocio ilegal)
| Poción | Receta | Precio ventanilla | Encargo (x1,15 a x1,6) | Tiempo de la hierba |
|---|---|---|---|---|
| Humo del Olvido | 2 Bruma | 40 $ | 46 a 64 $ | Bruma 15 s |
| Elixir del Mal Sueño | Bruma + Sepulcral | 65 $ | 75 a 104 $ | Sepulcral 25 s |
| Tónico de la Sombra | 2 Sepulcral | 85 $ | 98 a 136 $ | Sepulcral 25 s |

Cuántas pociones salen (estimado, maceta nivel 1):
- Plantar con nota alta da **3 hierbas** (+1 con abono, +1 por cada nivel de maceta).
- Cocinar 2 hierbas da **1, 2 o 3 pociones** según el minijuego. Con el 3 perfecto: 3 por 2 hierbas.
- Un ciclo de plantar con buena nota y cocinar perfecto: **unas 4,5 pociones** por maceta.
- Coste de un ciclo de Bruma: semilla 10 + tierra 8 = **18 $**. Ingreso: 4,5 x 40 = **180 $**
  (234 $ empaquetado, más si es encargo).
- Con 3 macetas mejoradas (nivel 3, riego y foco) un ciclo puede dar 30 pociones.

**Diagnóstico**: el margen es de casi 10 a 1 y la hierba crece en 15 s. Con 2 o 3 macetas y
algo de práctica salen **5.000 a 8.000 $ por hora** (estimado) en el nivel 1. La demanda no
limita: llega un encargo cada 50-90 s y un cliente a la ventanilla cada 15-55 s, con pagos
de 40-136 $. El único tope es la paciencia del jugador.

### 5.3 Cultivos legales (huertos del campo)
Una cosecha produce `m2 / 12` unidades (máximo 60) y gasta `m2 / 50` semillas (máximo 20).
Se vende a la mitad del precio de la lista.

| Huerto | Alquiler | Compra (x25) | Unidades | Semillas | Beneficio por cosecha (tomate) | Por hora (estimado) |
|---|---|---|---|---|---|---|
| A y B (144 m²) | 80 $ | 2.000 $ | 12 | 3 | 117 $ | 1.750 $ |
| C y D (288 m²) | 180 $ | 4.500 $ | 24 | 6 | 234 $ | 3.500 $ |
| E y F (572 m²) | 400 $ | 10.000 $ | 47 | 12 | 456 $ | 6.800 $ |
| G y H (1.020 m²) | 900 $ | 22.500 $ | **60** (tope) | 20 | 540 $ | 8.100 $ |

**Diagnósticos**:
1. **El alquiler se paga una sola vez**, por adelantado. Un huerto pequeño se paga con una
   cosecha. No hay renta mensual, así que alquilar equivale a comprar casi gratis.
2. **El tope de 60 unidades rompe la escala**: el huerto G cuesta 2,25 veces el E y da solo un
   28 % más. El tamaño grande no compensa.
3. **El negocio legal gana tanto como el ilegal** (6.000 a 8.000 $/h, sin minijuegos, sin
   policía). El riesgo no se paga: no hay motivo para vender pociones si ya tienes un huerto.
4. Los tres cultivos rinden casi igual por segundo (1,9 a 2,25 $/s por huerto grande), así que
   no hay una elección interesante.

### 5.4 Granja
| Producto | Coste | Producción | Venta por unidad | Ingreso por animal/árbol | Se amortiza en |
|---|---|---|---|---|---|
| Gallina | 45 $ | 1 huevo/min | 3,5 $ | 3,5 $/min | **13 min** |
| Vaca | 260 $ | 1 leche/2 min | 8 $ | 4 $/min | **65 min** |
| Manzano (hay 3, gratis) | 0 $ | 4 manzanas/3 min | 4 $ | 5,3 $/min | inmediato |

Capacidad: 4 animales por nivel de corral, hasta 12 (mejora de equipo 90 $).
Diagnóstico: **la vaca es cuatro veces peor inversión que la gallina**, y el manzano gratis
rinde más que ambas. Hay que subir lo que da la vaca (más leche o más precio) y limitar los
manzanos.

### 5.5 Dinero que sale (gastos)
- Propiedades: casas 100 a 700 $ de alquiler (compra 2.500 a 17.500 $), huertos 80 a 900 $.
- Vehículos: 2.400 $ (utilitario) hasta 12.000 $ (deportivo/cabeza tractora); helicóptero 90.000 $
  y avioneta 150.000 $. Se revenden al 60 % y según el estado.
- Habilidades: 300 a 1.000 $. Armas: 5 a 2.500 $. Mejoras de maceta/equipo: 90 a 120 $.
- Multas: cacheo 20 $ por montón + 5 $ por unidad, registro de casa 30 $ + 5 $, morir -20 % del dinero.
- Gasolina: bidón 30 $ (+40 % de depósito). El depósito dura unos 6 minutos a tope de velocidad
  (consumo 0,02 + 0,25 x velocidad relativa, en % por segundo, por el factor `gasto` del vehículo).
  Cruzar 10 km en sedán son unos 8 minutos: **unos 80 a 100 $ de gasolina**. Es poco frente a los ingresos.

**Diagnóstico**: con unos 5.000 a 8.000 $/h, el deportivo se compra en 2 horas y la avioneta en unas
20. Pero los gastos son casi todos **de una sola vez**. El único recurrente es el sueldo del personal (muy bajo,
ver 5.5b); alquiler, impuestos y mantenimiento no existen, así que el dinero solo sube. Las multas son ridículas cuando se tiene mucho.

### 5.5b Personal (añadido por otro hilo mientras se escribía esto)
Agricultor 40 $/día, ganadero 35 $/día, guardaespaldas 60 $/día (suben con el nivel del empleado).
Un día de juego dura **60 minutos reales**, así que un agricultor cuesta 40 $ por hora. Un huerto
grande rinde unos 6.000-8.000 $/h: **el sueldo es el 0,5 % de lo que produce**. Es el único gasto
recurrente y no pesa. Propuesta: sueldo del 25 % al 40 % de lo que rinde el puesto (agricultor
~1.500 $/día en huerto grande), o duración del día más corta (20 a 24 min). Además el ganador
claro es el agricultor en huerto G/H; tiene que haber algo que lo limite (cosecha del 70 al 100 %,
semillas del almacén, un solo agricultor por huerto).

### 5.6 Objetivo de ritmo (propuesta)
Dinero ganado por hora de juego, según etapa, para que cada compra grande llegue cuando toca:

| Etapa | Nivel | Dinero/hora objetivo | Qué se compra |
|---|---|---|---|
| 1. Arranque (0-45 min) | 1-3 | 400 a 1.500 | Casa, macetas, herramientas |
| 2. Primer negocio (1-4 h) | 4-7 | 2.000 a 5.000 | Huerto, coche, armas básicas |
| 3. Expansión (4-12 h) | 8-12 | 8.000 a 15.000 | Propiedades, camión, personal |
| 4. Imperio (12 h +) | 13-20 | 20.000 a 40.000 | Avioneta, negocios, fincas |

Hoy el juego está en la etapa 3 desde el minuto 15. **Palancas, de la más a la menos importante**
(se cambian todas en datos):
1. **Subir el tiempo de las hierbas** (Bruma 15 s → 60 s, Sepulcral 25 s → 120 s en `GameData.HIERBAS`)
   y que dormir sea la forma normal de adelantarlo.
2. **Bajar la cosecha de la maceta**: 1/2/3 hierbas según nota ya está bien; que las mejoras
   (+1 por nivel, +1 abono) cuesten más o den +25 % en vez de +1 plana.
3. **Recetas más caras en ingredientes**: pociones nuevas que necesiten 3 o 4 ingredientes y
   hierbas que solo se vendan a partir de cierto nivel (ver 6.3).
4. **Alquiler recurrente** (cada día de juego) y compra más cara que 25 veces (propuesta: 40x).
5. **Cultivos legales a un tercio del beneficio** (precio de venta a las tiendas al 33 % en vez
   de al 50 %, o tiempos x2) y tope de unidades que escale con el tamaño (sin tope de 60).
6. **Multas y confiscaciones proporcionales** al dinero y al valor de lo que llevas.

Con las palancas 1, 3 y 5 el negocio ilegal quedaría en 1.500 a 3.000 $/h al principio y el legal
en unos 800 $/h con huerto pequeño: arriesgar vuelve a compensar.

---

## 6. Progresión del jugador

### 6.1 XP y niveles hoy
- Se necesita `100 x nivel` de XP para subir (nivel 5 = 1.000 XP acumulada, nivel 10 = 4.500, nivel 20 = 19.000).
- Fuentes: plantar 10, cosechar maceta 15, cocinar 10 a 34, vender en ventanilla 25, encargo 15 por poción,
  empaquetar 3 por unidad, machacar 4 por polvo, cosecha de huerto = unidades (hasta 60),
  huevos, leche y manzanas 1 por unidad.
- El huerto grande da hasta 60 XP cada 150 s sin esfuerzo: es la forma más fácil de subir de nivel.
- **No hay nivel máximo** y **después del nivel 10 no se desbloquea nada**.

### 6.2 Qué desbloquea cada nivel hoy
| Nivel | Objetos |
|---|---|
| 2 | Bate, cuchillo, tónico, regadera, mejora de maceta, kit de riego, foco, mejora de equipo |
| 3 | Pistola, munición de pistola, barra de hierro, abono mejorado |
| 5 | Escopeta |
| 6 | Katana (+ Esgrima), granada (+ Explosivos) |
| 7 | Rifle |
| 8 | C4 y detonador |
| 9 | Francotirador (+ Puntería) |
| 10 | Lanzagranadas |

Casi todo lo desbloqueado son **armas**. Las hierbas, recetas, vehículos, propiedades y la granja
**no dependen del nivel**. Un jugador de nivel 1 con 22.500 $ puede comprar el mejor huerto.

### 6.3 Propuesta de curva de progresión
| Nivel | Se abre |
|---|---|
| 1 | Bruma, Humo del Olvido, casa de la plaza, huerto A/B |
| 2 | Maceta nivel 2, kit de riego, regadera, Hongo Sepulcral, empaquetadora |
| 3 | Mal Sueño, abono mejorado, lámparas, coche usado (utilitario), huerto C/D |
| 4 | Pistola (con habilidad), gallinas, tienda alquilada en el mercado (negocio legal) |
| 5 | Tónico de la Sombra, casas del barrio residencial, camión de reparto |
| 6-7 | Nueva hierba (ej. "Lágrima de Cuervo"), pociones de 3 ingredientes, huertos E/F, vacas |
| 8-9 | Contratar el primer empleado, taller de vehículos, rifle, explosivos |
| 10-12 | Ático, huertos G/H, tractor y maquinaria, segunda tienda |
| 13-20 | Segundo distrito, avioneta, finca, negocios que dan ingresos pasivos, jefe de la guardia |

### 6.4 Habilidades: que den efectos
Hoy solo abren compras. Propuesta (cada una con 3 niveles, pagando a un instructor):
Cultivo (+10 % de velocidad por nivel), Cocina (más pociones), Persuasión (más probabilidad de
aceptar contraofertas), Sigilo (la sospecha sube más despacio), Conducción (el vehículo se
daña menos), Mecánica (reparar sin kit). Las de armas se quedan como están.

### 6.5 Meta final
Sustituir "reunir 1.000 $" por **metas encadenadas** que se vean en el móvil: (1) montar tu primera
cosecha, (2) pagar el alquiler al casero, (3) tener 5 clientes fijos, (4) comprar un negocio legal,
(5) que el Prefecto deje de buscarte (soborno o ascender a la guardia), (6) ser dueño del distrito.
Cada meta da dinero o un objeto único. El final no hace falta de momento: la meta es dar rumbo.

---

## 7. El mapa de 10 km x 10 km

### 7.1 Cuánto es
- Hoy la ciudad mide unos **400 x 220 m = 0,09 km²**. Un mapa de 10 x 10 km son **100 km²: unas
  1.100 veces más superficie.** No cabe en una escena construida de golpe: hace falta
  **cargar por trozos (chunks) según la distancia del jugador**, y generar la mayor parte
  por código a partir de datos, no a mano.
- Tiempos para cruzar 10 km en línea recta (estimados):

| Cómo | Velocidad | Tiempo |
|---|---|---|
| Andando | 3,5 m/s | 48 min |
| Corriendo | 6,5 m/s | 26 min |
| Tractor | 9 m/s | 18 min |
| Furgoneta | 18 m/s | 9 min |
| Sedán | 22 m/s | 8 min |
| Deportivo | 34 m/s | 5 min |
| Helicóptero | 45 m/s | 4 min |
| Avioneta | 60 m/s | 3 min |

Es razonable para un mundo donde el coche importa. A pie es demasiado, así que **hace falta viaje rápido**
(taxi con tarifa por distancia, estaciones de autobús o tren). Eso además sirve de gasto.

### 7.2 Distribución propuesta
Coordenadas de mundo en metros. El origen sigue siendo la Plaza del Ahorcado, así que los
guardados actuales y los huertos del campo (x hasta 300) **no se mueven**. El mundo va de
−5.000 a +5.000 en x y z (con la ciudad algo hacia el centro).

```
 N   -5000                                                      +5000
      ┌───────────────────────────────────────────────────────────┐
      │ Montañas y mina      Bosque del Norte      Lago          │ -5000
      │ (pueblo minero)      (cabaña, caza)        (pesca, puerto)│
      │                                                           │
      │ Aeródromo      Anillo de barrios      Pueblo del Este     │
      │ (pista 800 m)  (residencial, mercado)  (campo medio)     │
      │            ┌────────────────────┐                         │
      │   Pueblos  │  CIUDAD (2 x 2 km) │  Campo grande          │ 0
      │   del Oeste│  plaza, mercado,   │  (huertos, granja,     │
      │            │  industrial, puerto│   tractores)           │
      │            └────────────────────┘                         │
      │ Costa y playa        Zona industrial grande   Colinas     │
      │ (contrabando)        (almacenes, fábricas)    (viñedos)   │
      └───────────────────────────────────────────────────────────┘ +5000
        Autopista circular + carreteras radiales (datos en RedCalles)
```

Regla de contenido: una cosa interesante (tienda, casa, huerto, encuentro, vista) cada
150 a 250 m a lo largo de las carreteras, y descampado entre pueblos sin llenarlo de cajas.

| Zona | Tamaño | Qué hay | Peligro | Dinero |
|---|---|---|---|---|
| Ciudad | 2 x 2 km | Lo actual, ampliado: más tiendas, bancos, negocios en alquiler | Alto (guardia) | Alto |
| Anillo de barrios | hasta 4 x 4 km | Casas, tiendas pequeñas, parques | Medio | Medio |
| Pueblos satélite (6) | 300 a 500 m c/u | Tienda, huertos, mercado semanal | Bajo | Medio |
| Campo grande | 3 x 3 km | Huertos, granjas, tractores (ya existe el primero) | Bajo | Pasivo |
| Industrial | 1 x 1 km | Fábricas, almacenes, camiones | Medio | Alto |
| Costa / lago | 1 x 4 km | Puerto, pesca, contrabando | Medio | Medio |
| Montaña / bosque | resto | Mina, caza, cuevas, cultivos escondidos | Bajo | Variable |
| Aeródromo | 1 km | Avioneta y helicóptero | Bajo | — |

### 7.3 Cómo se construye (técnica)
1. **Chunks de 128 m** (78 x 78 = 6.084 en total). Un `GestorChunks` mira la posición del jugador
   cada 0,5 s, construye los de menos de ~300 m (uno por fotograma como máximo, o los que
   quepan en 4 ms) y libera los de más de ~450 m. Es el diseño que ya escribió el hilo de la ciudad
   grande, con 128 m en lugar de 160 para casar con las celdas de fusión de 16 m.
2. **El mapa es un dato**: una lista de zonas (rectángulos con tipo y semilla), una lista de puntos
   de interés (con ID, tipo, posición, escena) y la red de carreteras. El terreno, árboles y casas de
   relleno se generan con una semilla fija, para que el mundo sea siempre igual.
3. **Terreno**: malla por chunk calculada con ruido (colinas suaves, llano en ciudad y campo),
   con la altura también disponible por código para colocar casas, coches y árboles.
   Generar la malla en un hilo (`WorkerThreadPool`) y añadirla en el hilo principal.
4. **Lejos se dibuja barato**: árboles y casas de relleno con `MultiMeshInstance3D`; sombras solo
   cerca (ya hecho en `ciclo_dia.gd`); niebla para ocultar el corte; sin luces a más de unos
   metros (ya existe el grupo `luces_lod`).
5. **Los edificios con interior** (tiendas, casas) siguen siendo escenas hechas a mano y solo
   existen mientras su chunk está cargado.
6. **Límite del mapa**: hoy `_cerrar_ciudad()` calcula el muro con las mallas que existen. Con
   chunks hay que sustituirlo por un rectángulo fijo (−5.000 a +5.000) con montañas o mar como
   barrera, no un muro de cajas.
7. **Precisión**: a ±5 km los números de coma flotante aún dan precisión de milímetros.
   No hace falta mundo de coordenadas dobles. Basta con no ir más allá de ±10 km.
8. **Personas y vehículos**: guardias, clientes, peatones y tráfico **solo se crean cerca del jugador**
   (radio ~150 m) y desaparecen al alejarse. Hoy los guardias nocturnos recorren los nodos de
   `RedCalles.NODOS`; con el mapa grande deben nacer en el chunk donde está el jugador.
9. **Encargos**: los 10 lugares fijos pasan a ser puntos elegidos entre los puntos de interés
   cercanos (radio 80 a 600 m según nivel), con tiempo de espera ajustado a la distancia.
10. **Mapa grande**: ya no puede ser una cámara ortogonal sobre la escena. Debe dibujarse
    desde los datos (zonas, carreteras, puntos de interés) en teselas, con zoom y marcadores.

### 7.4 Producción y tiempo con chunks descargados
Hoy `Parcela._process`, `Corral._process` y `ArbolFrutal._process` descuentan o acumulan tiempo
solo si el nodo existe. Con chunks, **un huerto o una granja lejos dejaría de producir**. Solución:
- `Juego.reloj_total` (segundos de juego, ya implícito en `hora` + `dia`) y cada cultivo o corral
  guarda `inicio` o `ultima_actualizacion`.
- Al cargar el chunk, o al interactuar, se calcula lo que pasó con la diferencia de tiempo.
- Es un cambio pequeño y evita rehacer el sistema más tarde. Debe hacerse **antes** de
  meter los chunks.

### 7.5 Orden de trabajo del mapa
| Hito | Qué | Depende de |
|---|---|---|
| M0 | Relojes absolutos en cultivos, granja y macetas | Nada |
| M1 | `GestorChunks`, límite fijo del mundo, terreno plano de relleno | M0 |
| M2 | Red de carreteras como datos y autopista circular | M1 |
| M3 | Campo grande y pueblos satélite (reutilizando `Parcela`, `Corral`) | M2 |
| M4 | Naturaleza: colinas, árboles con MultiMesh, lago y costa | M1 |
| M5 | Tráfico y peatones cercanos; guardias por chunk | M2 |
| M6 | Mapa grande por teselas, viaje rápido (taxi, estaciones) | M2 |
| M7 | Distritos de ciudad grandes, negocios, aeródromo | M3 |

---

## 8. Huecos e incoherencias que he encontrado

Pequeños (de datos), el resto en `MEJORAS.md`:
1. `GameData.OBJETIVO_DINERO = 1000` y el aviso "Prototipo superado" siguen activos.
2. `GameData.PRECIO_ALQUILER`, `precio_semilla` y `DINERO_INICIAL` duplican datos de otros sitios.
3. El alquiler se paga una vez y no caduca: no hay "alquilar" de verdad.
4. La vaca rinde cuatro veces peor que la gallina; el manzano es gratis y rinde más que ambas.
5. Los huertos G y H son caros para lo que dan por el tope de 60 unidades.
6. Los niveles pasan del 10 sin dar nada. No hay nivel máximo.
7. Solo hay 3 pociones y 2 hierbas; todas se abren en el nivel 1.
8. Las habilidades solo abren compras.
9. Multas y confiscaciones no escalan con la riqueza.
10. Falta el negocio legal (tienda propia). El personal ya existe, pero cobra muy poco para lo que produce.
11. Los encargos usan 10 puntos fijos de la ciudad actual.
12. `RedCalles` y los nodos de guardias están hechos a mano.
13. Gasolina: no hay gasolineras (solo bidón en la ferretería). Cruzar el mapa cuesta ~90 $: hace falta gasolineras repartidas y precio más alto.
14. Cuando aparezcan chunks, `Corral`, `Parcela` y `ArbolFrutal` dejarán de producir si el nodo no existe.

## 9. Lo que no cambia
La identidad del juego: Hoja de Bruma, Prefecto, pociones absurdas, ciudad oscura.
Todo lo nuevo tiene que poder explicarse en una frase de ese mundo.
