# Policía por estrellas, taxi, gasolineras y distritos

Probado con Godot 4.6 sin pantalla (`tests/prueba_policia.tscn`). Sin probar a mano en pantalla.

## Policía por estrellas (`scripts/datos/policia.gd`, `Juego.estrellas`)
- 0 a 5 estrellas. Un guardia que te ve con algo ilegal: 1 estrella (y +1 cada 20 s si sigue viéndote, hasta 3).
  Atacar a un guardia: 2. Abatirlo: +1. Atropellar a la vista: 2. Conducir sin carnet: 1.
- Bajan solas cuando te pierden de vista (25 s a 80 s por estrella; el triple si estás en un interior).
- Con 2 o más estrellas aparecen refuerzos a pie a 40-60 m (`GestorPolicia`); desde 3, coches patrulla
  (`CochePatrulla`) que te embisten si huyes en coche y te detienen si vas a pie o parado.
- Con 2 o más estrellas el guardia no pega: te **detiene** (`Juego.detener`): multa (mínimo por estrella o 4 % x
  estrellas de tu dinero), confisca lo ilegal, pasa de 2 a 12 horas y apareces en la plaza.
- La riqueza sube la probabilidad de cacheo y el nº de refuerzos. El distrito también (`vigilancia`).
- Morir quita las estrellas. El HUD muestra ★★☆☆☆.

## Taxi (`scripts/datos/taxi.gd`, pestaña Taxi del móvil)
- Destinos: 5 barrios de la ciudad y las 34 aldeas, pueblos y ciudades. 8 $ + 22 $/km; pasa el tiempo del
  trayecto (a 58 km/h). No funciona con estrellas, dentro de edificios ni en vehículo.
- Tras el fundido el jugador espera sin caer hasta que se carga el suelo del destino.

## Gasolineras y servicios (`scripts/objetos/servicio_mundo.gd`, precios en `economia.gd`)
- Gasolinera: llena el vehículo más cercano (0,375 $/% x gasto); Mayús+E compra un bidón por 15 $.
  Una en la Zona de Campo (junto al concesionario) y una por pueblo o ciudad.
- Taller (repara), hospital (cura), taberna (+10 vida, -15 sospecha) y banco (ingresa, interés 0,5 %/día, retirar
  con Mayús+E; el dinero del banco no se pierde con multas, detención ni muerte).
- `Juego.banco` se guarda con la partida.

## Distritos (`generador_mundo.gd`)
- Cada bloque de una ciudad es centro, barrio alto, industrial o residencial: cambia el tamaño y color de las
  casas y el precio de alquiler (x0,7 a x2,2). Pueblos: centro + residencial.
- Ciudad: banco, taberna, hospital, taller y gasolinera en bloques fijos. Pueblo: gasolinera y taberna.
- Al entrar en un distrito sale un aviso (`GestorPolicia`).

## Pendiente
- Retenes fijos de carretera, comisaría con calabozo en el mundo, taxis como vehículo conducible.
- Distritos en la ciudad original y precios de tiendas por distrito.
