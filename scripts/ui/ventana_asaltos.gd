# ventana_asaltos.gd
# -----------------------------------------------------------------------------
# Ajustes de los asaltos a casas (desde el panel de administrador, F1). Todo es opcional:
# se pueden apagar los asaltos, dejar las puertas abiertas como antes o bajar la dificultad
# a "Pacífico" (nadie se despierta ni ataca). También ayudas para probar: darte ganzúa y palanca
# y aparecer una casa de prueba delante de ti (de noche, con vecinos durmiendo).
# -----------------------------------------------------------------------------
class_name VentanaAsaltos
extends VentanaOpciones

var jugador: Node3D = null


func construir() -> void:
	if incrustada:
		montar_incrustada()
	else:
		montar("Asaltos a casas", Vector2(760, 620))
	titulo("Ajustes")
	nota_fila("Las casas normales vienen cerradas con llave. Fuerza la puerta o la ventana (E con ganzúa, Mayús+E a lo bruto), registra los muebles y sal antes de que se despierten. Nada de esto es obligatorio.")
	casilla("Asaltos a casas activados", Asaltos.activo, func(v: bool) -> void:
		Asaltos.activo = v
		Asaltos.guardar_ajustes()
		_refrescar())
	casilla("Casas normales con la puerta cerrada con llave", Asaltos.puertas_cerradas, func(v: bool) -> void:
		Asaltos.puertas_cerradas = v
		Asaltos.guardar_ajustes()
		_refrescar())
	opcion("Dificultad", Asaltos.NOMBRES_DIFICULTAD, Asaltos.dificultad, func(i: int) -> void:
		Asaltos.dificultad = i
		Asaltos.guardar_ajustes()
		_refrescar(), "Cuánta gente se despierta, va armada y cuánto pega.")
	titulo("Para probar")
	boton_fila("Darme 3 ganzúas y una palanca", func() -> void:
		Juego.anadir("ganzua", 3)
		Juego.anadir("palanca", 1)
		Juego.avisar("Tienes ganzúas y una palanca en la mochila."))
	boton_fila("Aparecer una casa de prueba delante de mí (de noche)", _casa_de_prueba)
	boton_fila("Quitarme la búsqueda y la denuncia", func() -> void:
		Juego.estrellas = 0
		Juego.asaltos_info["buscado_hasta"] = 0
		Juego.avisar("La policía te ha olvidado.")
		_refrescar())
	_refrescar()


func _refrescar() -> void:
	if aviso == null:
		return
	aviso.text = "Asaltos hechos: %d   ·   Robado en total: %d $   ·   Te buscan hasta el día: %s   ·   Casas asaltadas ahora sin botín: %d" % [
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
	cerrar_raiz()
