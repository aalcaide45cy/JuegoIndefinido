# zona_chunga.gd
# -----------------------------------------------------------------------------
# Decoración de los barrios chungos (la zona industrial de las ciudades): un
# bidón con fuego, basura y una valla con pintadas. De noche el fuego ilumina
# la calle con luz naranja que parpadea. Lo crea gestor_trozos.gd a partir de
# los props "chunga" de generador_mundo.gd. Ver docs/MUNDO_NOCTURNO_STATS_BANDAS.md.
# -----------------------------------------------------------------------------
class_name ZonaChunga
extends Interactuable

const Bandas = preload("res://scripts/datos/bandas.gd")
var banda: String = "cuervos"

var semilla: int = 0
var _luz: OmniLight3D = null
var _llama: Node3D = null
var _t: float = 0.0


func _ready() -> void:
	distancia = 3.0
	# La banda del barrio es la dueña de la ciudad donde está este rincón.
	for s in GeneradorMundo.asentamientos_cerca(Rect2(position.x - 2.0, position.z - 2.0, 4.0, 4.0)):
		banda = Bandas.dueno(int(s["ci"]), int(s["cj"]))
		break
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = semilla
	# Bidón oxidado con fuego dentro.
	Construir.cilindro(self, Vector3(0, 0.45, 0), 0.38, 0.9, Color(0.42, 0.2, 0.12), true)
	_llama = Construir.caja(self, Vector3(0, 1.05, 0), Vector3(0.35, 0.4, 0.35), Color(1.0, 0.5, 0.1), false, 3.0)
	_luz = Construir.luz(self, Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.2), 2.5, 11.0)
	# Basura apilada.
	for i in 4:
		var a: float = rng.randf() * TAU
		var c: Color = Color.from_hsv(rng.randf(), 0.25, 0.35)
		Construir.caja(self, Vector3(cos(a) * 1.4, 0.2 + 0.1 * i, sin(a) * 1.4),
				Vector3(0.5 + rng.randf() * 0.4, 0.35, 0.5 + rng.randf() * 0.4), c, false)
	# Valla con pintadas de colores.
	var lado: float = 2.6 if rng.randf() < 0.5 else -2.6
	Construir.caja(self, Vector3(lado, 1.0, 0.0), Vector3(0.12, 2.0, 3.6), Color(0.2, 0.2, 0.22), true)
	for i in 3:
		var col: Color = Color.from_hsv(rng.randf(), 0.8, 0.9)
		Construir.caja(self, Vector3(lado + signf(lado) * 0.08, 0.8 + rng.randf() * 0.8, -1.2 + i * 1.2),
				Vector3(0.05, 0.5, 0.9 + rng.randf() * 0.4), col, false, 1.2)


func _process(delta: float) -> void:
	_t += delta
	var noche: bool = Juego.hora >= 19.5 or Juego.hora < 6.0
	var parpadeo: float = 0.75 + 0.25 * sin(_t * 11.0) * sin(_t * 7.3)
	_luz.light_energy = (2.8 * parpadeo) if noche else 0.8 * parpadeo
	_llama.scale = Vector3(1.0, 0.8 + 0.5 * parpadeo, 1.0)


func _clave() -> String:
	return Bandas.clave_en(global_position.x, global_position.z)


func texto_accion() -> String:
	var clave: String = _clave()
	if clave != "" and Juego.territorios.has(clave):
		if Juego.reclutas >= Bandas.MAX_RECLUTAS:
			return "Barrio tuyo: ya tienes %d hombres (el máximo)" % Juego.reclutas
		return "Barrio tuyo: reclutar un matón (%d $, %d $ al día). Tienes %d" % [Bandas.PRECIO_RECLUTA, Bandas.SUELDO_RECLUTA, Juego.reclutas]
	if Juego.dia <= Juego.proteccion_hasta_dia:
		return "%s: ya estás bajo su protección (hasta el día %d)" % [Bandas.nombre(banda), Juego.proteccion_hasta_dia]
	return "Pagar protección a %s (%d $): hoy sus matones te dejan en paz" % [Bandas.nombre(banda), Bandas.CUOTA_DIA]


func usar(_jugador: Node) -> void:
	var clave: String = _clave()
	if clave != "" and Juego.territorios.has(clave):
		if Juego.reclutas >= Bandas.MAX_RECLUTAS:
			Juego.avisar("No caben más hombres a tu servicio.")
			return
		if not Juego.gastar(Bandas.PRECIO_RECLUTA):
			Juego.avisar("Reclutar cuesta %d $." % Bandas.PRECIO_RECLUTA)
			return
		Juego.reclutas += 1
		Juego.cambio.emit()
		Juego.avisar("Un matón del barrio se une a ti. Te sigue y pelea por ti (%d $ al día)." % Bandas.SUELDO_RECLUTA)
		return
	if Juego.dia <= Juego.proteccion_hasta_dia:
		Juego.avisar("Un tipo te hace un gesto: ya has pagado. Tranquilo.")
		return
	if not Juego.gastar(Bandas.CUOTA_DIA):
		Juego.avisar("La cuota son %d $. Vuelve con dinero." % Bandas.CUOTA_DIA)
		return
	Juego.proteccion_hasta_dia = Juego.dia
	Juego.cambiar_rep("hampa", 3)
	Juego.avisar("Pagas %d $ a %s. Hoy los matones del barrio te dejan pasar." % [Bandas.CUOTA_DIA, Bandas.nombre(banda)])
