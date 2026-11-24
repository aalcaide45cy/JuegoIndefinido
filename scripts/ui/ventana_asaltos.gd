# ventana_asaltos.gd
# -----------------------------------------------------------------------------
# Ajustes de los asaltos a casas (desde el panel de administrador, F1). Todo es opcional:
# se pueden apagar los asaltos, dejar las puertas abiertas como antes o bajar la dificultad
# a "Pacífico" (nadie se despierta ni ataca). También ayudas para probar: darte ganzúa y palanca
# y aparecer una casa de prueba delante de ti (de noche, con vecinos durmiendo).
# -----------------------------------------------------------------------------
class_name VentanaAsaltos
extends Ventana

var jugador: Node3D = null
var _estado: Label = null


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(680, 560))
	cabecera(caja, "Asaltos a casas")
	var texto: Label = Hud.crear_label(16, Color(0.8, 0.82, 0.76))
	texto.text = "Las casas normales vienen cerradas con llave. Fuerza la puerta o la ventana (E con ganzúa, Mayús+E a lo bruto), registra los muebles y sal antes de que se despierten. Nada de esto es obligatorio."
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 620
	caja.add_child(texto)

	var activo: CheckButton = CheckButton.new()
	activo.text = "Asaltos a casas activados"
	activo.button_pressed = Asaltos.activo
	activo.focus_mode = Control.FOCUS_NONE
	activo.toggled.connect(func(v: bool) -> void:
		Asaltos.activo = v
		Asaltos.guardar_ajustes()
		_refrescar())
	caja.add_child(activo)

	var cerradas: CheckButton = CheckButton.new()
	cerradas.text = "Las casas normales tienen la puerta cerrada con llave"
	cerradas.button_pressed = Asaltos.puertas_cerradas
	cerradas.focus_mode = Control.FOCUS_NONE
	cerradas.toggled.connect(func(v: bool) -> void:
		Asaltos.puertas_cerradas = v
		Asaltos.guardar_ajustes()
		_refrescar())
	caja.add_child(cerradas)

	subtitulo(caja, "Dificultad (cuánta gente se despierta, va armada y cuánto pega)")
	var dif: OptionButton = OptionButton.new()
	dif.focus_mode = Control.FOCUS_NONE
	for i in Asaltos.NOMBRES_DIFICULTAD.size():
		dif.add_item(Asaltos.NOMBRES_DIFICULTAD[i], i)
	dif.select(Asaltos.dificultad)
	dif.item_selected.connect(func(i: int) -> void:
		Asaltos.dificultad = i
		Asaltos.guardar_ajustes()
		_refrescar())
	caja.add_child(dif)

	subtitulo(caja, "Para probar")
	caja.add_child(Hud.crear_boton("Darme 3 ganzúas y una palanca", func() -> void:
		Juego.anadir("ganzua", 3)
		Juego.anadir("palanca", 1)
		Juego.avisar("Tienes ganzúas y una palanca en la mochila.")))
	caja.add_child(Hud.crear_boton("Aparecer una casa de prueba delante de mí (de noche)", _casa_de_prueba))
	caja.add_child(Hud.crear_boton("Quitarme la búsqueda y la denuncia", func() -> void:
		Juego.estrellas = 0
		Juego.asaltos_info["buscado_hasta"] = 0
		Juego.avisar("La policía te ha olvidado.")
		_refrescar()))
	_estado = Hud.crear_label(15, Color(1, 0.92, 0.6))
	caja.add_child(_estado)
	_refrescar()


func _refrescar() -> void:
	if _estado == null:
		return
	_estado.text = "Asaltos hechos: %d   ·   Robado en total: %d $   ·   Te buscan hasta el día: %s   ·   Casas asaltadas ahora sin botín: %d" % [
			int(Juego.asaltos_info.get("asaltos", 0)), int(Juego.asaltos_info.get("robado", 0)),
			"—" if int(Juego.asaltos_info.get("buscado_hasta", 0)) < Juego.dia else str(Juego.asaltos_info["buscado_hasta"]),
			(Juego.asaltos_info.get("casas", {}) as Dictionary).size()]


# Una casa con paredes, puerta y ventana a unos 14 m, mirando hacia ti, de noche.
func _casa_de_prueba() -> void:
	if jugador == null:
		return
	var adelante: Vector3 = -jugador.global_basis.z
	adelante.y = 0.0
	adelante = adelante.normalized() if adelante.length() > 0.01 else Vector3.FORWARD
	var punto: Vector3 = jugador.global_position + adelante * 16.0
	var choque: Dictionary = Combate.rayo(jugador.get_world_3d(), punto + Vector3.UP * 60.0, Vector3.DOWN, 140.0, [jugador.get_rid()])
	if not choque.is_empty():
		punto = choque["position"]
	Juego.hora = 23.0
	var cara: float = 1.0 if (jugador.global_position.z - punto.z) > 0.0 else -1.0
	var distr: String = "rico" if randi() % 2 == 0 else "residencial"
	var semilla: int = randi()
	var casa: CasaAsaltable = CasaAsaltable.casa_de_prueba(jugador.get_parent(), punto, {
			"id": "prueba_%d" % semilla, "distrito": distr, "ancho": 11.0, "fondo": 9.0, "cara": cara, "semilla": semilla})
	Juego.avisar("Casa de prueba (%s) aparecida delante de ti. Las puertas y ventanas están cerradas." % str(Asaltos.PERFILES[casa.perfil]["nombre"]))
	cerrar()
