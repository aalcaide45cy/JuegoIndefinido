# ventana_sonido.gd
# -----------------------------------------------------------------------------
# Esc > "Sonido y juego…": volumen general, de la música, del ambiente y de los efectos
# (se guardan en user://opciones.cfg con los de Musica), y cada cuánto se autoguarda.
# -----------------------------------------------------------------------------
class_name VentanaSonido
extends VentanaOpciones

const MINUTOS_AUTOGUARDADO: Array = [0, 2, 5, 10, 15, 30]


func construir() -> void:
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
	titulo("Partida")
	var etiquetas: Array = MINUTOS_AUTOGUARDADO.map(func(m: int) -> String:
		return "Apagado" if m == 0 else "Cada %d minutos" % m)
	var actual: int = maxi(0, MINUTOS_AUTOGUARDADO.find(Autoguardado.minutos))
	opcion("Autoguardado", etiquetas, actual, func(i: int) -> void:
		Autoguardado.poner_minutos(int(MINUTOS_AUTOGUARDADO[i]))
		aviso.text = "Autoguardado apagado." if Autoguardado.minutos == 0 else \
				"Se guardará solo cada %d minutos (y al cerrar la ventana del juego)." % Autoguardado.minutos)
	aviso.text = "Al guardar se conserva una copia de la partida anterior (.bak) por si algo falla."
