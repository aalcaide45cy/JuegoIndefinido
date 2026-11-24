# Ideas para que el juego sea interesante

Escrito el 2026-11-18 a petición de Alfonso. Parte de lo que **ya existe** (hierbas, pociones y recetas, huertos y granja,
negocios y alquileres, policía por estrellas, taxi, vehículos y gasolina, mapa de 10 x 10 km con ciudades, pueblos, aldeas y
montañas, peatones y tráfico, oficios, niveles y logros) y propone qué añadir y en qué orden.

Escala: **P0** = lo que más cambia cómo se siente el juego, **P1** = siguiente, **P2** = cuando lo anterior esté firme,
**P3** = largo plazo. Esfuerzo: S (horas), M (un día), L (varios días). Cada idea dice **qué**, **por qué** y **dónde engancha**.

## El problema de fondo

Hoy el juego tiene muchas cosas que hacer, pero pocas **razones para hacerlas**. Los dineros suben, y ya está. Falta:
1. Un **objetivo a largo plazo** que dé sentido al dinero.
2. **Decisiones con riesgo**: que ganar más obligue a arriesgar más.
3. **Sorpresas**: que dos días no sean iguales.
4. **Personas**: gente con nombre que te ayude, te robe o te persiga.

## P0: objetivos y rumbo

- [ ] **Imperio en 5 etapas** (M). Un "marcador de carrera" en el móvil: *Vendedor de calle → Boticario con tienda → Distribuidor
  regional → Señor de la ciudad → Leyenda del reino*. Cada etapa pide algo concreto (nivel, dinero, propiedades, reputación) y
  desbloquea algo grande (otra ciudad, otro oficio, un vehículo). Engancha con `metas.gd` (ya hay metas encadenadas) y
  `logros.gd`. *Por qué:* da dirección a todo lo demás.
- [ ] **Encargos con lugares reales** (M). Los encargos del móvil piden "entrega 3 tónicos a Inés en Norlar, antes de la noche":
  destino real del mapa, con distancia y riesgo (más pago si cruzas una ciudad con mucha policía). Engancha con `encargos.gd`,
  `Regiones`, el taxi y las gasolineras. *Por qué:* el mapa grande por fin se usa.
- [ ] **Reputación con tres bandos** (M): **Gente corriente**, **Hampa** y **Ley**. Vender a clientes honrados sube la primera;
  trabajos sucios, la segunda; trabajar de policía o médico, la tercera. Cada bando abre precios, encargos y ayuda distintos y
  cierra otros. Engancha con `Juego.reputacion` (ya existe un número) y los oficios nuevos. *Por qué:* dos formas de jugar de verdad.

## P1: riesgo y recompensa

- [ ] **Mercado vivo** (M). Los precios de pociones suben y bajan por región y por día (fiesta, epidemia, tormenta, redada).
  El móvil avisa: "En Rosgal hay fiebre: el Tónico Sereno vale el doble hoy". Engancha con `economia.gd` y `Regiones`.
- [ ] **Redadas** (M). Si vendes mucho en una zona, sube su "calor" y un día hay redada (policía por todas las calles de
  ese barrio, cacheos). Se baja con sobornos, cambiando de ciudad o con buena reputación. Engancha con `gestor_policia.gd`.
- [ ] **Alijo en el coche** (S). Esconder pociones en el maletero (el policía puede pararte y revisarlo si vas rápido, de noche
  o con las luces apagadas). Engancha con `vehiculo.gd` y los controles de tráfico.
- [ ] **Mezclas arriesgadas** (S). Las recetas muy potentes tienen probabilidad de efecto secundario o explosión del caldero que
  te quema (vida). Engancha con `mezclas.gd` y la curación con coste (hospital, ya hecho).
- [ ] **Seguro y fianza** (S). Pagar una cuota diaria al banco para que la multa o la muerte no te quiten tanto. Engancha con
  `banco`.

## P1: sorpresas (eventos aleatorios)

Un sistema simple: cada cierto tiempo, con probabilidad según la hora y el barrio, sale un **evento** con texto en el móvil y
algo que hacer. Todo en un archivo de datos, como `efectos.gd`.

- [ ] **Eventos de calle** (M): un herido que ayudar (+reputación), un ladrón que te quita dinero y huye (persíguelo), un coche
  averiado en la carretera (pide ayuda), un cliente que paga el triple si llegas en 3 minutos.
- [ ] **Eventos de clima** (S): tormenta que corta la carretera de montaña, niebla que baja la vista de los guardias, calor que
  seca los huertos (hay que regar).
- [ ] **Visitas** (S): un inspector de sanidad revisa tu tienda, un comprador misterioso pide una receta imposible, un
  vagabundo vende un mapa de un escondite.
- [ ] **Accidentes** (ya empezado): los coches pueden atropellar a peatones imprudentes; el médico o el policía de servicio
  los atiende. Siguiente paso: que un atropello deje un aviso real de oficio.

## P1: oficios con ascensos (base ya hecha en este PR)

Ya existen policía, médico, bombero y mecánico con turnos, avisos y 4 rangos. Falta:

- [ ] **Más oficios** (M cada uno): **taxista** (usa el sistema de taxi), **repartidor** (entregas del móvil), **herbolario**
  (vendedor del mercado), **juez/alguacil** (multas), **guardia de banco** (protege contra atracos), **piloto** (con aviones, P3).
- [ ] **Misiones por rango** (M). En rango 2 salen avisos nuevos (policía: persecución en coche; médico: operación en la mesa;
  bombero: rescate en un edificio alto; mecánico: remolcar un coche). En rango 4 un **encargo del jefe** semanal con
  recompensa grande.
- [ ] **Uniforme y vehículo oficial** (M): coche patrulla, ambulancia, camión de bomberos y grúa que puedes conducir de servicio
  (sirena, paso libre en los semáforos). Engancha con `vehiculo.gd` y `coche_patrulla.gd`.
- [ ] **Doble vida** (M): ser policía **y** vender pociones. Si te pillan, pierdes el rango. Muy buena tensión con `sospecha`.
- [ ] **Sueldo fijo y gastos** (S): oficio = ingreso seguro pero bajo; negocio ilegal = ingreso alto con riesgo. Que ambos
  convivan hasta que elijas.

## P2: historia y rivales

- [ ] **Hilo de historia en 5 capítulos** (L). Un hilo corto y oscuro (tono del juego): quién te enseñó la magia prohibida, por
  qué la ley la persigue, quién te traiciona. Cada capítulo se desbloquea con una etapa del imperio y se cuenta con cartas,
  llamadas del móvil y 2-3 escenas. Hay que decidir el tono con Alfonso antes de escribir.
- [ ] **Rivales con nombre** (M). Dos o tres boticarios rivales que compiten por las mismas ciudades: bajan precios, te
  denuncian, roban cosechas, o te proponen un pacto. Se ven en el mapa grande con su zona de influencia. Engancha con
  `Regiones` y reputación.
- [ ] **Aliados** (M): el médico de la botica, un guardia corrupto, un mecánico. Cada uno ofrece una ventaja si tienes buena
  relación (regalos, favores). Engancha con las personas que ya hay en las tiendas.

## P2: misiones por región

Cada región ya tiene identidad económica (ciudad, pueblo, aldea, montaña, campo). Que también tenga **misiones propias**:

| Región | Tipo de misión | Recompensa especial |
|---|---|---|
| Ciudad | Encargos de lujo, contactos, tienda propia | Reputación alta, clientes ricos |
| Pueblo | Favores a vecinos, ferias semanales | Recetas locales |
| Aldea | Ingredientes raros, curanderos | Semillas únicas |
| Montaña | Mina abandonada, bandidos, túnel | Minerales para pociones |
| Campo | Cosechas gigantes, ganado, tractor | Vehículos agrícolas |

Engancha con `economia.gd` por región y con los pueblos de montaña/túnel del PR 13.

## P3: largo plazo

- [ ] **Multijugador** (L): ya hay un diseño del modo servidor. Los oficios y los rivales encajan muy bien (un jugador policía,
  otro boticario).
- [ ] **Barcos y aviones** (L): rutas de contrabando, aeropuerto con control.
- [ ] **Casa y decoración con efectos** (M): una casa bien montada da bonificaciones (más descanso, más huerto).
- [ ] **Mazmorras o ruinas** (L): zonas de peligro con ingredientes raros.
- [ ] **Estaciones del año** (M): cultivos distintos en cada una.

## Orden recomendado (los siguientes 6 pasos)

1. **Imperio en 5 etapas** (P0): sin esto lo demás no tiene hilo.
2. **Encargos con lugares reales** (P0): usa el mapa y sirve para todo.
3. **Eventos de calle y de clima** (P1): barato y se nota enseguida.
4. **Redadas y mercado vivo** (P1): riesgo y recompensa de verdad.
5. **Misiones por rango y vehículo oficial** (P1): hace que los oficios no sean "esperar el aviso".
6. **Rivales y primer capítulo de historia** (P2): da personalidad.

## Qué no conviene hacer todavía

- Meter más recetas o más armas sin objetivos: sube el número de cosas, no las ganas de jugar.
- Mapa aún más grande: ya hay 119 asentamientos y pocos motivos para visitarlos todos.
- Multijugador antes del imperio y los eventos: hay que saber qué hace divertido al juego en solitario.
