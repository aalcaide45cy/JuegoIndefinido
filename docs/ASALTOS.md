# Asaltos a casas

Las casas normales (viviendas de barrio residencial y barrio alto) vienen **cerradas con llave**.
Puedes forzarlas, registrar los muebles y llevarte el botín, pero dentro hay gente: duerme de
noche, y si haces ruido, te ilumina con la linterna o te ve, se despierta y reacciona.
**Nada es obligatorio**: se puede apagar todo desde el panel de administrador (F1 → "Asaltos a
casas") y el juego se queda como antes (puertas abiertas, casas vacías).

## Cómo se juega

1. **Elige casa y hora.** De noche (22:00–06:00) duermen todos. Al anochecer (19–22) y por la
   mañana (06–09) hay gente despierta y atenta (te ve en cuanto te asomas). De día (09–19) la
   casa suele estar vacía (el 70 % de los ocupantes no están).
2. **Fuerza la entrada** (E sobre la puerta o la ventana):
   - `E` = en silencio con **ganzúa** (7 s la puerta, 9 s la ventana; a veces se rompe).
   - `Mayús + E` = a lo bruto: **palanca** si la llevas (3 s / 5 s, ruido alto) y, si no, a
     **patadas** (5 s, ruido máximo, te haces 4 de daño) o **rompiendo el cristal** (2,5 s, 6 de daño).
   - La casa rica tiene mejores cerraduras (+50 % de tiempo); la humilde, peores (−20 %).
   - Si te alejas o te hacen daño mientras fuerzas, lo dejas.
   - Por la ventana entras trepando; por la puerta, cuando cede.
3. **Registra los muebles** (E): cajón, joyero, armario y, en casas ricas, una caja fuerte
   (necesita ganzúa, o palanca con Mayús+E). El dinero va al **dinero negro** si existe esa cuenta
   (rama de blanqueo) y si no, a la cartera. También salen joyas, relojes de oro, plata,
   electrónica, licor y cuadros, que se venden en las tiendas.
4. **Sal sin que se despierten.** Cada ruido sube la "alerta" de cada durmiente (según lo cerca
   que esté, lo profundo que duerma y si el ruido viene de fuera, que la pared lo apaga).
   Agacharte (C) baja mucho el ruido de tus pasos; correr lo sube. La habilidad/efecto de
   **sigilo** también ayuda. La linterna apuntando a su cara de cerca despierta poco a poco.

## Cuando alguien se despierta

Se levanta (casi un segundo) y reacciona según quién es y si va armado:

| Reacción | Qué hace |
|---|---|
| Huir | Corre a la calle gritando y acaba **llamando a la policía**. |
| Llamar | Se esconde junto a la cama y **marca**; si estás a menos de 3 m no le dejas. |
| Puños | Se te echa encima y te pega (6 de daño). |
| Objeto | Sartén, lámpara, bate… (11 de daño). |
| Arma | Pistola: mantiene distancia y dispara (13 de daño, acierta menos si vas agachado o a oscuras). Los tiros suben las estrellas. |

Los roles cambian los pesos: el hombre de la casa se enfrenta más; la mujer y el abuelo llaman
más; el chaval huye más. **Armados:** 15 % de la gente en barrio residencial, 35 % en el barrio
alto y 12 % en el centro (el 40 % en zona industrial, aunque ahí no hay casas asaltables).

## Consecuencias

- Te ven la cara dentro de la casa: **1 estrella** (allanamiento).
- Alguien llama a la policía: **2 estrellas**, bajan tu reputación con la ley y te "buscan"
  durante 2 días (`Juego.asaltos_info["buscado_hasta"]`).
- Hieres a un ocupante: **2 estrellas**. Un golpe flojo (puños) que le deja a cero lo deja
  **inconsciente** 30 s; un golpe fuerte (≥ 15, arma) lo **mata**: **4 estrellas** y −8 con la ley.
- Casas ricas: un 45 % tiene **alarma**; si suena (ruido alto o palanca), despierta a todos y a
  los 4 s llegan **2 estrellas**.
- Cada casa asaltada queda **sin botín 3 días** y con la cerradura rota; tras 3 días se rellena.
- Si la casa pasa a ser tuya (alquilada o comprada), deja de ser un blanco.

## Dificultad (F1 → Asaltos a casas)

Pacífico (nadie se despierta ni ataca), Normal, Duro y Brutal. Cambian: lo fácil que se despiertan
(×0 / 1 / 1,7 / 2,6), cuánta gente va armada (×0 / 1 / 1,5 / 2,2), el daño que hacen y el botín.
Los ajustes se guardan en `user://asaltos.cfg` (no en la partida).

## Dónde está el código

- `scripts/datos/asaltos.gd` – todas las reglas y números (perfiles, métodos, botín, ruido, estrellas).
- `scripts/mundo/casa_asaltable.gd` – una casa asaltable (puertas, muebles, ocupantes, consecuencias).
  Es independiente de cómo se dibuje la casa: solo necesita un diccionario con tamaño, camas y muebles.
- `scripts/objetos/entrada_forzable.gd`, `botin_casa.gd`, `accion_lenta.gd` – lo que fuerzas y registras.
- `scripts/combate/vecino.gd` – el ocupante (dormido, atento, reacciones, daño).
- `scripts/ui/ventana_asaltos.gd` – ajustes y pruebas en el panel de administrador.
- Con el sistema de **interiores** (`GestorInteriores`, `InteriorCasa`, `PuertaMundo`): al acercarte a una
  vivienda se crea su `CasaAsaltable` con las camas y muebles reales del reparto; la puerta del
  juego (`PuertaMundo`) queda cerrada con llave hasta que la fuerzas.
- Ver también `docs/POLICIA_TAXI_GASOLINERAS.md` (estrellas) y `docs/MUNDO_GRANDE.md`.

## Pruebas

```
godot --headless --path . res://tests/prueba_asaltos.tscn   # reglas, entradas, botín, ruido, reacciones, consecuencias, casas reales
godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_asaltos.tscn -- /carpeta   # capturas
```

## Pendiente / ideas

- Tiendas y almacenes (distritos centro e industrial) no se asaltan todavía (guardia nocturno, caja registradora).
- Perros, cámaras y cerraduras con minijuego.
- Que los ocupantes se muevan por la casa con navegación real (ahora van en línea recta).
- Vender el botín a un perista del mercado negro con mejor precio que en las tiendas.
