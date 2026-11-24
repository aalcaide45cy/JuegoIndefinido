# ventana_sonido.gd
# -----------------------------------------------------------------------------
# Esc > "Sonido y juego…": volumen general, de la música, del ambiente y de los efectos
# (se guardan en user://opciones.cfg con los de Musica), y cada cuánto se autoguarda.
# -----------------------------------------------------------------------------
class_name VentanaSonido
extends VentanaOpciones

const MINUTOS_AUTOGUARDADO: Array = [0, 2, 5, 10, 15, 30]


func construir() -> void:
	if incrustada:
		montar_incrustada()
	else:
		montar("Sonido y juego", Vector2(820, 560))
	titulo("Volumen")
	deslizador("General", Musica.volumen_general, 0.0, 1.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Musica.volumen_general = x
		Musica.aplicar_buses()
		Musica.guardar_opciones())
	deslizador("Música", Musica.volumen_musica, 0.0, 1.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Musica.volumen_musica = x
		Musica.guardar_opciones())
	deslizador("Ambiente (calle, campo, lluvia)", Musica.volumen_ambiente, 0.0, 1.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Musica.volumen_ambiente = x
		Musica.guardar_opciones())
	deslizador("Efectos (disparos, golpes, coches...)", Musica.volumen_efectos, 0.0, 1.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Musica.volumen_efectos = x
		Musica.aplicar_buses()
		Musica.guardar_opciones()
		Sonido.tocar(self, "comprar"))
	titulo("Interfaz")
	deslizador("Tamaño de la interfaz", Controles.escala_interfaz, 0.8, 1.4, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Controles.escala_interfaz = x
		Controles.guardar()
		Controles.escala_cambiada.emit(), "Agranda o encoge menús y HUD (útil en pantallas pequeñas o de sofá).")
	casilla("Mostrar la ayuda de teclas en pantalla", Controles.mostrar_ayuda, func(on: bool) -> void:
		Controles.mostrar_ayuda = on
		Controles.guardar(), "La línea de controles de abajo en el juego.")
	titulo("Partida")
	var etiquetas: Array = MINUTOS_AUTOGUARDADO.map(func(m: int) -> String:
		return "Apagado" if m == 0 else "Cada %d minutos" % m)
	var actual: int = maxi(0, MINUTOS_AUTOGUARDADO.find(Autoguardado.minutos))
	opcion("Autoguardado", etiquetas, actual, func(i: int) -> void:
		Autoguardado.poner_minutos(int(MINUTOS_AUTOGUARDADO[i]))
		aviso.text = "Autoguardado apagado." if Autoguardado.minutos == 0 else \
				"Se guardará solo cada %d minutos (y al cerrar la ventana del juego)." % Autoguardado.minutos)
	aviso.text = "Al guardar se conserva una copia de la partida anterior (.bak) por si algo falla."
