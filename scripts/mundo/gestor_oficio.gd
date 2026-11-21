# gestor_oficio.gd
# -----------------------------------------------------------------------------
# Lleva el turno de tu oficio (datos/oficios.gd): cobra el sueldo por hora de
# juego, gana experiencia, y de vez en cuando crea un AVISO por las calles cercanas
# (aviso_oficio.gd) para que lo atiendas. Solo actúa si estás "de servicio".
# Un policía con búsqueda activa (estrellas) es expulsado del turno.
# -----------------------------------------------------------------------------
class_name GestorOficio
extends Node

var aviso: AvisoOficio = null
var _t_aviso: float = 20.0
var _xp_frac: float = 0.0
var _t_texto: float = 0.0


func _process(delta: float) -> void:
	if not Juego.en_turno:
		if aviso != null and is_instance_valid(aviso):
			aviso.queue_free()
		aviso = null
		Juego.texto_aviso_oficio = ""
		_t_aviso = 15.0
		return
	var id: String = Juego.oficio
	if id == "policia" and Juego.estrellas > 0:
		Juego.oficios_xp[id] = int(Juego.xp_oficio() * 0.5)
		Juego.terminar_turno()
		Juego.avisar("Te expulsan del turno: la policía te busca. Pierdes la mitad de tu experiencia de policía.")
		return
	# Sueldo y experiencia por hora de juego.
	var horas: float = delta * 24.0 / (maxf(1.0, Juego.duracion_dia_min) * 60.0) * Juego.velocidad_tiempo
	Juego.turno_pago += float(Juego.DatosOficios.LISTA[id]["sueldo_hora"]) * Juego.DatosOficios.multiplicador(id, Juego.xp_oficio()) * horas
	_xp_frac += Juego.DatosOficios.XP_POR_HORA * horas
	if _xp_frac >= 1.0:
		Juego.ganar_xp_oficio(int(_xp_frac))
		_xp_frac -= floorf(_xp_frac)
	# Aviso activo: indica dónde está.
	if aviso != null and not is_instance_valid(aviso):
		aviso = null
	if aviso != null:
		_t_texto -= delta
		if _t_texto <= 0.0:
			_t_texto = 0.4
			var jug: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
			if jug != null:
				Juego.texto_aviso_oficio = "AVISO: %s · a %d m al %s · %d s" % [str(aviso.datos.get("texto", "")),
						int(jug.global_position.distance_to(aviso.global_position)), _rumbo(jug.global_position, aviso.global_position),
						int(aviso.tiempo)]
		return
	Juego.texto_aviso_oficio = ""
	_t_aviso -= delta
	if _t_aviso <= 0.0:
		_t_aviso = randf_range(Juego.DatosOficios.AVISO_ESPERA_MIN, Juego.DatosOficios.AVISO_ESPERA_MAX)
		crear_aviso()


func crear_aviso() -> bool:
	var vida: Node = get_tree().get_first_node_in_group("vida_urbana")
	var jug: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if vida == null or jug == null or Juego.oficio == "":
		return false
	var punto = vida.punto_de_calle(Juego.DatosOficios.AVISO_DIST_MIN, Juego.DatosOficios.AVISO_DIST_MAX)
	if punto == null:
		_t_aviso = 8.0   # No hay calles cerca: vuelve a intentarlo enseguida.
		return false
	var lista: Array = Juego.DatosOficios.LISTA[Juego.oficio]["avisos"]
	var a: AvisoOficio = AvisoOficio.new()
	a.oficio = Juego.oficio
	a.datos = (lista[randi() % lista.size()] as Dictionary).duplicate()
	if a.datos.has("local"):
		# Un cliente que pide un peinado (peluquero y barbero): ver datos/peluqueria.gd.
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var c: Dictionary = Juego.DatosPeluqueria.cliente_al_azar(str(a.datos["local"]), rng, Juego.DatosAspecto)
		var asp: Dictionary = Juego.DatosAspecto.POR_DEFECTO.duplicate()
		for k in (c["pide"] as Dictionary):
			asp[k] = c["pide"][k]
		asp["piel"] = rng.randi() % 5
		asp["abrigo"] = rng.randi() % 7
		a.datos["aspecto_cliente"] = asp
		a.datos["texto"] = "%s: %s" % [a.datos["texto"], c["texto"]]
	a.tiempo = Juego.DatosOficios.AVISO_DURACION
	a.position = punto
	get_parent().add_child(a)
	a.resuelto.connect(func(): aviso = null)
	a.caducado.connect(func():
		aviso = null
		Juego.avisar("Se ha perdido un aviso: llegaste tarde."))
	aviso = a
	Juego.avisar("Nuevo aviso: %s (%s)." % [str(a.datos.get("texto", "")), _rumbo(jug.global_position, punto)])
	return true


static func _rumbo(desde: Vector3, hasta: Vector3) -> String:
	var d: Vector3 = hasta - desde
	var ang: float = fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)   # 0 = norte (-Z), 90 = este (+X).
	var nombres: Array = ["norte", "noreste", "este", "sureste", "sur", "suroeste", "oeste", "noroeste"]
	return str(nombres[int(round(ang / 45.0)) % 8])
