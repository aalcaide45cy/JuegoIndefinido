# Plaza nueva, parques, linterna y parpadeo

- **Linterna**: tecla F (`Jugador.poner_linterna`). Foco que sale de la cámara, sin sombras. Con ella encendida los guardias te ven desde 1,4 veces más lejos y no cuentas como "en la sombra".
- **Parpadeo (z-fighting)**: la cámara usa `near = 0.1` (antes 0.05, el doble de precisión de profundidad); no se toca `far = 4000` porque acortarlo estropea las sombras de las paredes. Los tejados llevan un desnivel de 0-4 cm distinto en cada edificio y los marcos de puerta/ventana ya no comparten plano con la pared.
- **Plaza inicial** (`barrio_plaza.gd`): fuente de tres pisos con agua, chorros, luz azul de noche y sonido de agua (generado por código, `Sonido.fuente()`), estatua del alquimista, círculos de adoquín, 6 árboles en alcorques, 4 parterres y guirnaldas de bombillas que se encienden de noche.
- **Parques y aceras del mundo grande** (`parques.gd`, llamado desde `generar_cercano`): cada bloque lleva acera; los 4 bloques de la plaza mayor de las ciudades son parques (fuente, bosquecillo con picnic, juegos infantiles, estatua con quiosco) y los solares sin casa se llenan de jardines. Las farolas encienden una luz de noche.
- Pruebas: `tests/captura_plaza.tscn -- <carpeta> <prefijo> [filtro]` (ventana fuera de pantalla).
- Sonidos: no hay assets descargados todavía; todo sigue generado por código. Cuando se descarguen, `Sonido` ya usa `assets/sonidos/NOMBRE.ogg|wav` si existe.
