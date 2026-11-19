# Indefinido: mundo nocturno, estadísticas y bandas

Documento de diseño (2026-11-18), pedido por Alfonso. Escrito en español sencillo.
**Nada de esto está programado todavía.** Es el plan para que Alfonso decida qué hacer y en qué orden.

Encaja con lo ya hecho o diseñado: dinero limpio y negro y blanqueo (`docs/DINERO_LIMPIO_NEGRO.md`), policía por estrellas
(`docs/POLICIA_TAXI_GASOLINERAS.md`), oficios y avisos (PR 19, `docs/IDEAS_JUEGO_INTERESANTE.md`), chat (`docs/CHAT.md`),
multijugador (`docs/MULTIJUGADOR.md`) y vida urbana (`docs/PLAN_CIUDADES_VIVAS.md`).

## 1. La idea en pocas líneas

Indefinido es "un juego de vida": la misma ciudad es otra de día y de noche. De día es comercio, oficios y tráfico.
De noche se abren **locales de ocio**, **casinos** y **barrios chungos** donde hay más dinero, más riesgo y gente peligrosa.
Todo el mundo (tú, peatones, guardias, bandas) tiene **vida y estadísticas**, y cuando hay pelea se ve su **barra de vida**.
Más adelante, las **bandas** se disputan barrios.

Regla de oro de diseño: **cada atractivo nocturno trae un riesgo** (policía, atracos, adicción al juego, bandas), y todo
engancha con sistemas que ya existen (estrellas, sospecha, dinero negro, reputación), para no crear mundos separados.

## 2. Límites de contenido (decididos aquí, Alfonso puede cambiarlos)

El tono es oscuro y adulto, pero **sugerido, nunca explícito**. Esto además protege la clasificación en Steam.

| Tema | Sí | No |
|---|---|---|
| Discotecas, casinos, tragaperras | Sí, con dinero del juego | Dinero real, tienda de cajas con premios, nada que se pueda comprar con dinero real |
| Alcohol, tabaco, hierbas ficticias | Sí (ya existe la "Hoja de Bruma") | Drogas reales con nombre, instrucciones de fabricación reales |
| Prostitución | Solo como **ambiente y trasfondo**: clubes de copas/cabarets, carteles, gente en la puerta, diálogos con doble sentido, cortinas que "tapan" la escena | Escenas sexuales, desnudos, servicio jugable con animación, explotación, menores, trata como mecánica de beneficio |
| Violencia | Peleas, armas, sangre estilizada low poly, muerte con pantalla de hospital | Tortura detallada, violencia gratuita contra gente indefensa como objetivo del juego |
| Crimen | Extorsión, contrabando, sobornos, atracos (siempre con consecuencias) | Nada que enseñe a hacerlo en la vida real |

Propuesta concreta para "prostitución": **no habrá mecánica de servicio sexual**. Habrá un tipo de local, el **Club de Copas**, con
camareras, música, apuestas y **negocio de protección** (los dueños pagan "cuota" a la banda del barrio). El jugador puede
beber, apostar, hacer tratos y enterarse de rumores. La sugerencia es atmósfera, no acción.
Los personajes del ocio nocturno son siempre adultos, con nombre y vida propia (pueden tener historia y misiones secundarias).

## 3. Locales nocturnos

Se generan en los **distritos** que ya tiene la ciudad (centro, rico, industrial, residencial). Cada tipo va a un distrito
y tiene horario. La hora es la del juego (`Juego.hora`, ciclo día/noche existente).

| Local | Dónde | Abre | Qué hay | Riesgo | Gasto típico |
|---|---|---|---|---|---|
| **Discoteca** | Centro, distrito rico | 21:00-06:00 | Música, luces de colores, pista, barra, portero, reservados | Peleas, cacheo en la puerta, taquilla | Entrada 10-40 $, copas 12 $ |
| **Casino** | Distrito rico, algún pueblo grande | 20:00-07:00 | Ruleta, blackjack, tragaperras, caja, VIP | Vigilante, deudas, "casinos de la banda" más tramposos | Fichas desde 10 $ |
| **Salón de tragaperras** | Cualquier barrio, pueblos | 18:00-04:00 | Máquinas, barra | Adicción (ver 4.4), robos al salir | Desde 1 $ |
| **Club de Copas** | Zona chunga | 22:00-05:00 | Camareras, música, reservados, cuota de protección | Peleas, redadas, banda propietaria | Copas 15-25 $ |
| **Timba clandestina** | Trastiendas, zona industrial | 00:00-05:00 | Cartas con apuestas altas, dinero negro | Trampas, atraco, redada | Apuesta mínima 200 $ (negro) |
| **Taberna** (ya existe) | Ciudades y pueblos | 12:00-02:00 | Copa: vida y menos sospecha | Bajo | 12 $ |
| **Prestamista** | Zona chunga | Siempre (llamar a la puerta) | Préstamos rápidos con interés alto | Cobradores de la banda si no pagas | Interés 30 %/día |
| **Mercado negro** | Callejones | 23:00-05:00 | Material ilegal, armas, recetas raras | Policía, estafa | Precios x1,5 pero stock único |

**Zonas chungas**: un "barrio chungo" es un conjunto de manzanas marcadas en el generador (`generador_mundo.gd`), con:
farolas rotas (más oscuro: la linterna se vuelve útil), grafitis, basura, bares abiertos, coches viejos, peatones de tipo
"matón" o "trapicheo". Solo existen en ciudades grandes (las de más de 3 distritos), 1-2 por ciudad.
Se pueden **ver en el mapa grande** en un color distinto (gris-rojo) una vez descubiertas.

**Detalle visual**: cada local tiene fachada reconocible (neones de color, toldo, cartel con nombre), puerta con portero,
luz de color que sale a la calle, y de día queda cerrado y apagado (persiana bajada). Interiores sencillos, en low poly
cuidado, no cajas. Lo que haga falta de modelos se verá como lista aparte de assets gratuitos (sección 10).

## 4. Casinos y tragaperras (solo dinero del juego)

Todo se juega con **dinero del juego**. No hay compra con dinero real y no se puede cambiar moneda real por fichas.
La casa **siempre gana a largo plazo** (como en la realidad) para que no sea fuente infinita de dinero.

### 4.1 Tragaperras
- 3 rodillos, 6 símbolos (hierba, caldero, corona, calavera, moneda, poción). Apuesta 1, 5, 25 o 100 $.
- Retorno teórico del **88 %** (configurable en `scripts/datos/casino.gd`, nuevo): a la larga pierdes el 12 %.
- Animación de rodillos y sonido de monedas. Un contador "racha" avisa si juegas mucho seguido.
- Se puede jugar con negro o con limpio. **Jugar con negro y cobrar en limpio blanquea** una parte, pero la casa se queda 30 % y
  sube la vigilancia fiscal (ya existe), así que no es un truco gratis.

### 4.2 Ruleta y blackjack
- Ruleta de 37 números (una sola cero). Apuestas: color, par/impar, docena, número pleno (x35).
- Blackjack contra el crupier, pago 3:2. Sin dividir al principio (para simplificar).
- El crupier puede "ser de la banda": en casinos de banda hay **trampas** que se pueden descubrir con la estadística *Ojo* (ver 5)
  y a cambio denunciar o chantajear.

### 4.3 Riesgos del casino
- **Seguridad**: si ganas mucho seguido (más de 5.000 $ netos en una noche) los vigilantes te acompañan fuera.
  Si has trampeado, te echan y sube su desconfianza (no puedes volver ese día).
- **Atraco al salir** en zonas chungas, si llevas mucho dinero encima (usa la sospecha y el dinero negro que ya se miden).
- **Deuda**: puedes pedir ficha prestada al casino (límite según reputación); si no la pagas en 3 días, llegan **cobradores**.

### 4.4 Adicción al juego
- Estadística oculta "Vicio" (0-100): sube un poco con cada hora de juego seguida y con cada pérdida grande.
- Con Vicio alto, el personaje empieza a "pedir" (mensaje en el móvil: "una más") y baja la puntería y la paciencia hasta que
  descansa o toma una copa/medicina. No es castigo gordo, es consecuencia narrada.
- Es un **mensaje del juego sobre el riesgo**, no un gancho: no hay recompensa por seguir.

## 5. Estadísticas

Todos los seres tienen estadísticas. El jugador las ve en su ficha; los NPC solo se ven si tienes la habilidad *Ojo*
o en pelea (barra).

### 5.1 Estadísticas del jugador

**Vitales** (suben y bajan solas, son barras):

| Estadística | Qué es | Efecto |
|---|---|---|
| **Vida** (`Juego.vida`, ya existe) | Salud | 0 = desmayo y hospital (ya hecho) |
| **Resistencia** | Energía para correr, pelear, saltar | Se gasta al correr y pelear; si llega a 0 no corres |
| **Hambre** | Comer | Si está alta baja la resistencia máxima |
| **Sed** | Beber | Igual, más rápido |
| **Sueño** | Descanso | Mal sueño reduce *Atención* y *Puntería* |
| **Embriaguez** | Copas, pociones | Baja puntería y sigilo; sube *Carisma* un poco |
| **Estrés** | Policía, peleas, deudas | Sube la sospecha de forma pasiva, se baja durmiendo o con tabernas |

**Atributos** (suben con el uso y con puntos de nivel; rangos 1-20):

| Atributo | Para qué sirve |
|---|---|
| **Fuerza** | Daño cuerpo a cuerpo, cargar peso (inventario) |
| **Agilidad** | Velocidad al esquivar, saltar, correr |
| **Constitución** | Vida máxima, resistencia a venenos y golpes |
| **Puntería** | Dispersión de armas a distancia |
| **Carisma** | Precios de venta, regateos, intimidar, contratar |
| **Sigilo** | Sospecha que ganas, evitar cacheos, entrar sin ser visto |
| **Ojo** | Ver trampas, mentiras, estadísticas de otros, buscar objetos |
| **Mecánica / Química / Cocina...** | Se mantienen como `habilidades` actuales (`habilidades.gd`), no se tocan |

Estos atributos son **nuevos** pero se guardan junto a `habilidades` y `nivel` (`Juego`). Una partida antigua carga con todos a 5.

### 5.2 Estadísticas de NPC

Un NPC es un `Resource` ligero (`DatosNPC`) generado al aparecer, con semilla: así no cuesta memoria en 10x10 km.

```
nombre, edad_aprox, oficio, banda (o ninguna)
vida_max, fuerza, agilidad, punteria, valentia, lealtad, avaricia
estado_animo (tranquilo, borracho, asustado, furioso), dinero_encima
```

- **Peatones normales**: vida 40-80, valentía baja; huyen si ven un arma, llaman a la policía.
- **Matones y miembros de banda**: vida 80-150, fuerza alta, arma blanca o de fuego, no huyen.
- **Guardias, policías**: usan lo que ya tiene `guardia.gd` y `gestor_policia.gd`, y se les añade vida visible.
- **Guardias de local y porteros**: fuerza alta, empujan y te echan; con reputación baja te cachean.

### 5.3 Barra de vida en combate

- **Cuándo se ve**: solo cuando hay pelea. Un NPC muestra su barra durante 5 s tras recibir o dar daño, y siempre mientras te mira con intención de pelea.
- **Cómo se ve**: barra fina sobre la cabeza, color según bando (verde = neutral, rojo = enemigo, azul = ley, naranja = banda).
  Debajo, el nombre y el nivel de amenaza (calavera si es de mucho más nivel que tú).
- **Rendimiento**: una sola `MultiMesh` de planos de barra con shader; solo se actualizan los NPC en combate (máx. 12 a la vez),
  siguiendo `docs/graficos.md` y las reglas de materiales compartidos.
- **Jugador**: barra grande abajo a la izquierda (ya hay `vida`), con resistencia, hambre y sed en pequeño.

## 6. Combate

Ya existen `combate.gd`, `proyectil.gd`, `diana.gd` y los guardias armados. El sistema se amplía así:

1. **Cuerpo a cuerpo**: puñetazo (rápido) y golpe fuerte (carga con clic mantenido, gasta resistencia). Con arma blanca (barra, cuchillo)
   más daño. Esquiva con una tecla (dash corto, gasta resistencia). Bloqueo con clic derecho.
2. **A distancia**: armas ya del juego, con dispersión según *Puntería*, embriaguez y estrés.
3. **Daño**: `daño = base_arma * (1 + fuerza/20) * (1 - armadura)`; críticos al subir *Ojo*. Todo en una función única `Combate.aplicar_daño(origen, destino, arma)`.
4. **Efectos**: sangrado (pierde vida lento, se cura con vendaje), aturdido, borracho. Se reutiliza `efectos.gd`.
5. **Muerte y consecuencias**: lo que ya hay (hospital, pérdida de dinero negro por muerte). NPC muerto cae y puede ser **registrado** (objetos, dinero) o
   atendido por el médico de servicio (PR 19). Matar a un inocente suma **2 estrellas** y baja reputación con *Gente corriente*.
6. **IA de pelea**: estados `calma → alerta → pelea → huida`. Los matones pelean en grupo; los peatones huyen o llaman a la policía.
   Coordinación con el tráfico: nadie pelea en mitad de la calzada con coches.

## 7. Reputación y bandos

Se amplía `Juego.reputacion` (hoy un solo número) a **tres bandos**, como ya proponía `IDEAS_JUEGO_INTERESANTE.md`:
**Gente corriente**, **Hampa** y **Ley**. Cada local nocturno y cada banda mira uno o más.

| Reputación alta con... | Abre | Cierra |
|---|---|---|
| Gente corriente | Mejores precios, ayuda de peatones, clientes ricos | Trabajos sucios |
| Hampa | Casinos VIP, mercado negro, protección, encargos de banda | La policía te mira más |
| Ley | Rangos de policía, informantes, rebajas de multa | Entrar en locales de banda |

Cada barrio tiene además una **"calor"** (ya propuesto en redadas): si haces ruido de noche, sube; se enfría con tiempo, soborno o cambio de zona.

## 8. Guerra de bandas (base, para más adelante)

No es lo primero a programar, pero las bases de datos se preparan ya para no rehacer nada.

### 8.1 Las bandas
- 4 bandas por mapa grande, cada una con **nombre, color, símbolo, líder, jefes de barrio y reclutas**.
- Ejemplo de tono (no cerrado, nombres libres): *Los Cuervos del Puerto* (contrabando), *La Mano Gris* (casinos y préstamos),
  *Hijos de la Niebla* (hierbas y pociones), *Los Cerrojos* (robos y talleres).
- Cada banda tiene su **zona de influencia**: un conjunto de celdas de 128 m (las mismas de los trozos) con grafitis de su color.
  Se ve en el mapa grande como manchas de color.

### 8.2 Territorio
- Un barrio chungo tiene un **dueño** y **estado**: *firme*, *en disputa* o *vacío*.
- El dueño cobra una **cuota** de los locales (un porcentaje de lo que ganan). Si tú eres dueño, esa cuota es tu ingreso (dinero negro).
- Para tomar un barrio: reducir a sus **jefes de barrio** (peleas o encargos) o **convencerlos** (dinero, reputación, carisma).

### 8.3 Reclutas
- Con reputación en el Hampa puedes **reclutar** peatones tipo matón (cuestan sueldo diario, como el personal que ya existe en `GestorPersonal`).
- Cada recluta tiene estadísticas (ver 5.2), **lealtad** y **hambre de dinero**: si no cobran o pierden mucho, se van o te traicionan.
- Se pueden mandar a **vigilar un local**, **acompañarte** o **defender una casa** (límite de 4 al principio).

### 8.4 Enfrentamientos
- **Escaramuza**: grupos pequeños en una calle, 3-6 por lado, con barras de vida, sirenas de policía a los 60-90 s.
- **Asalto a local**: tomas un casino o club; si ganas, cambia de dueño y se queda cerrado un día.
- **Guerra abierta**: tras varias victorias, una banda ataca tus negocios. Mueren NPC, suben las estrellas y **los peatones se encierran**.
- **Policía**: la ley también interviene; con *Ley* alta puedes ayudar a la policía y ganar rangos en vez de ensuciarte.
- **Condiciones de fin**: una banda solo cae si pierde a su líder y todos sus barrios. El mapa permite varias formas de acabar.

### 8.5 Multijugador
Las bandas encajan con `MULTIJUGADOR.md`: la banda es un `EstadoEquipo` y el territorio vive en `mundo.json`, validado por el servidor.
Con PvP apagado (propuesta actual), solo hay guerra contra NPC. Con PvP encendido, los jugadores pueden ser bandas rivales.

## 9. Cómo engancha con lo que ya existe

| Sistema actual | Se amplía con |
|---|---|
| `Juego.vida`, hospital, curación con coste | Barra de vida, sangrado, resistencia, hambre, sed |
| `Juego.sospecha`, estrellas, cacheo | Cacheo en discotecas y casinos; el sigilo reduce la sospecha |
| Dinero limpio y negro, blanqueo | Casinos y timbas con negro; cuotas de banda en negro |
| Oficios (policía, médico, bombero) | Avisos nocturnos nuevos: pelea en discoteca, desmayo en el casino, incendio en un club |
| `Juego.reputacion` (1 número) | Tres bandos |
| Chat (PR 20) | Canal de banda; mensajes del móvil de prestamistas o cobradores |
| Vida urbana (peatones, tráfico) | Peatones de noche (borrachos, porteros, matones) y menos tráfico |
| Ciclo día/noche, linterna | De noche las zonas chungas son oscuras; la linterna es imprescindible |
| Multijugador (PR 14) | Estadísticas y banda en `EstadoJugador`/`EstadoEquipo`; combate validado en servidor |

## 10. Assets y sonido (a decidir con Alfonso)

- **Sonidos libres de derechos** (CC0): música de discoteca/club (loops sintéticos), tragaperras (monedas, rodillos), pasos, golpes, ambiente de calle de noche,
  multitud. Fuentes que se pueden revisar: Kenney (CC0), OpenGameArt (filtrar CC0), Freesound (filtrar CC0), Pixabay (licencia propia, revisar), Sonniss GDC (gratis comercial).
- **Modelos low poly gratis**: Kenney (City Kit Commercial/Suburban/Roads), Quaternius (CC0), Poly Pizza (CC0 / CC-BY, revisar cada uno).
- En un hilo aparte se hará la lista detallada con enlaces y qué pide cada licencia (Alfonso baja los que quiera a una carpeta y se montan).
- **Regla**: toda licencia CC-BY exige poner los créditos en el menú; se llevará un archivo `CREDITOS.md`.

## 11. Plan por fases y esfuerzo

Escala: **S** = horas, **M** = un día, **L** = varios días.

| Fase | Contenido | Esfuerzo | Depende de |
|---|---|---|---|
| **0** | Estadísticas base en `Juego` (resistencia, hambre, sed, atributos) + ficha en el móvil. Guardado compatible | M | nada |
| **1** | Barra de vida en NPC y jugador, `DatosNPC` ligero, combate cuerpo a cuerpo con esquiva | L | fase 0 |
| **2** | Horarios y fachadas nocturnas (discoteca, tragaperras, taberna mejorada), luz de neones, música ambiente | M | nada |
| **3** | Casino: tragaperras + ruleta + blackjack, casa gana 12 %, vigilantes | L | fase 2 |
| **4** | Zonas chungas en el generador, peatones nocturnos (matones, borrachos), cacheos y atracos al salir | L | fases 1 y 2 |
| **5** | Tres bandos de reputación, calor del barrio, redadas | M | fase 4 |
| **6** | Club de Copas, timba clandestina, prestamista, mercado negro (todo con los límites de la sección 2) | L | fases 3 y 4 |
| **7** | Bandas: territorio, cuotas, jefes de barrio, reclutas | L | fases 5 y 6 |
| **8** | Escaramuzas, asaltos y guerra abierta | L | fase 7 |
| **9** | Adaptar a multijugador (EstadoJugador/EstadoEquipo, validar en servidor) | L | PR 14 y fases anteriores |

**Orden recomendado**: 0 → 1 → 2 → 3 → 4 (el primer "mundo de noche" completo) → 5 → 6 → 7 → 8 → 9.
Con esto, tras la fase 4 ya hay una noche distinta a la del día; las bandas llegan solo cuando lo anterior es sólido.

## 12. Riesgos y cosas por decidir

1. **Prostitución**: se propone **solo ambiente** y sin servicio jugable (sección 2). ¿Lo dejas así?
2. **Rendimiento**: muchos neones, NPC con barra y peleas a la vez gastan mucho. Reglas: luces solo cerca (`luces_lod`), barras en MultiMesh, tope de NPC en pelea.
3. **Juego con dinero real**: descartado. No se añaden cajas de botín ni compras dentro del juego.
4. **Estadísticas de NPC**: ¿qué nivel de detalle quieres a la vista del jugador (nada, solo en pelea, o siempre con *Ojo*)? Propuesta: solo en pelea y con *Ojo*.
5. **Número de bandas**: 4 propuestas. Más bandas = más trabajo de diseño y más dispersión.
6. **Clasificación de edad**: antes de publicar en Steam, revisar el cuestionario de contenido y los países con reglas estrictas sobre apuestas simuladas.
7. **Nombre de la banda y locales**: libres, se pueden cambiar sin tocar código si van en datos (`scripts/datos/bandas.gd`).

## 13. Decisiones pendientes de Alfonso

- Aprobar o ajustar los **límites de contenido** (sección 2).
- Confirmar el **orden de fases** y por cuál empezar (recomendado: 0 y 1).
- Decidir si el multijugador entra antes o después de las bandas (recomendado: después).
- Dar visto bueno a la **lista de assets gratuitos** cuando se prepare (sección 10).

## 14. Estado de la implementación (2026-11-19)

| Fase | Estado | Notas |
|---|---|---|
| 0 Estadísticas | Hecha | Aliento, hambre, sed y 7 atributos en `Juego`; panel en el HUD; guardado |
| 1 Barras de vida | Hecha | `BarraVida` sobre guardias y peatones al recibir daño. Falta el combate cuerpo a cuerpo con esquiva |
| 2 Locales nocturnos | Hecha | Discoteca y tragaperras con horario, neones y focos (`scripts/datos/casino.gd`) |
| 3 Casino | Hecha | Ruleta y blackjack en `VentanaCasino`; seguridad te echa si ganas 5.000 $ en una noche |
| 4 Zonas chungas | Parcial | Zona industrial de las ciudades con bidones con fuego, basura y pintadas; atracos de noche (menos con *Sigilo*). Faltan matones y borrachos como peatones y los cacheos al salir del casino |
| 5-9 | Pendiente | Reputación en tres bandos, Club de Copas, bandas, guerra, multijugador |
