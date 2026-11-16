# maceta_3d.gd
# -----------------------------------------------------------------------------
# Una maceta de tu casa. Tiene tres estados: VACIA -> CRECIENDO -> LISTA.
#   - Vacía: E abre el minijuego de plantar (tierra, semilla, agua y abono).
#     Necesitas un saco de tierra, una semilla y la jarra con agua.
#   - Creciendo: hay que esperar (o dormir en la cama).
#   - Lista: E cosecha. Cuanto mejor lo hiciste en el minijuego, más hierbas.
# -----------------------------------------------------------------------------
class_name Maceta3D
extends Interactuable

enum Estado { VACIA, CRECIENDO, LISTA }

var estado: Estado = Estado.VACIA
var tipo_hierba: String = ""
var progreso: float = 0.0    # De 0.0 (recién plantada) a 1.0 (lista).
var cosecha: int = 1         # Hierbas que dará al cosechar (según la calidad).
var calidad: float = 0.0     # De 0 a 1, sale del minijuego.
var velocidad: float = 1.0   # 1 = normal; con abono, más rápido.
var nivel: int = 1           # 1-3: sube con "Mejora de maceta" (más rápida y más cosecha).
var riego: bool = false      # Kit de riego instalado: +20% de velocidad.
var abonada_extra: bool = false   # Ya recibió abono mejorado.
var _anillo: Node3D
var _grifo: Node3D

var _tierra: Node3D
var _planta: Node3D = null
var _materiales_planta: Array[StandardMaterial3D] = []


func _enter_tree() -> void:
	super()
	add_to_group("macetas")


func _ready() -> void:
	Construir.cilindro(self, Vector3(0, 0.15, 0), 0.2, 0.3, Color(0.45, 0.25, 0.18), false, 0.0, 0.25)
	Construir.cilindro(self, Vector3(0, 0.29, 0), 0.22, 0.02, Color(0.08, 0.06, 0.05))  # Hueco vacío.
	_tierra = Construir.cilindro(self, Vector3(0, 0.27, 0), 0.23, 0.05, Color(0.17, 0.11, 0.08))
	_tierra.visible = false
	_decorar()


# Aspecto de las mejoras: anillo plateado (nivel 2) o dorado (nivel 3) y un tubito azul de riego.
func _decorar() -> void:
	if _anillo != null:
		_anillo.queue_free()
		_anillo = null
	if _grifo != null:
		_grifo.queue_free()
		_grifo = null
	if nivel >= 2:
		_anillo = Construir.cilindro(self, Vector3(0, 0.24, 0), 0.235, 0.05,
				Color(0.85, 0.85, 0.9) if nivel == 2 else Color(0.95, 0.78, 0.25), false, 0.2)
	if riego:
		_grifo = Construir.cilindro(self, Vector3(0.22, 0.2, 0), 0.025, 0.4, Color(0.3, 0.6, 0.9), false, 0.3)


func _factor_velocidad() -> float:
	return (1.0 + 0.25 * (nivel - 1)) * (1.2 if riego else 1.0)


func _process(delta: float) -> void:
	if estado == Estado.CRECIENDO:
		adelantar(delta)
	elif estado == Estado.LISTA:
		# La planta lista brilla un poco, como respirando.
		var pulso: float = 0.6 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
		for mat in _materiales_planta:
			mat.emission_energy_multiplier = pulso


# Hace crecer la planta "segundos" (lo usa también la cama al dormir).
func adelantar(segundos: float) -> void:
	if estado != Estado.CRECIENDO:
		return
	progreso += segundos * velocidad / GameData.HIERBAS[tipo_hierba]["tiempo"]
	if progreso >= 1.0:
		progreso = 1.0
		estado = Estado.LISTA
	_planta.scale = Vector3.ONE * lerpf(0.15, 1.0, progreso)


func texto_accion() -> String:
	match estado:
		Estado.VACIA:
			return "Plantar en la maceta (nivel %d%s)" % [nivel, ", riego" if riego else ""]
		Estado.CRECIENDO:
			return "%s creciendo... %d%%" % [GameData.HIERBAS[tipo_hierba]["nombre"], int(progreso * 100)]
		_:
			return "Cosechar %s (x%d)" % [GameData.HIERBAS[tipo_hierba]["nombre"], cosecha]


func usar(jugador: Node) -> void:
	# Con una mejora en la mano, E la aplica en vez de la acción normal.
	var mano: String = Juego.id_en_mano()
	if mano == "mejora_maceta":
		if nivel >= 3:
			Juego.avisar("Esta maceta ya está al nivel máximo.")
		else:
			Juego.quitar(mano, 1)
			var antes: float = _factor_velocidad()
			nivel += 1
			if estado == Estado.CRECIENDO:
				velocidad *= _factor_velocidad() / antes
				cosecha += 1
			_decorar()
			Juego.avisar("Maceta mejorada al nivel %d." % nivel)
		return
	if mano == "kit_riego":
		if riego:
			Juego.avisar("Esta maceta ya tiene riego automático.")
		else:
			Juego.quitar(mano, 1)
			riego = true
			if estado == Estado.CRECIENDO:
				velocidad *= 1.2
			_decorar()
			Juego.avisar("Riego automático instalado.")
		return
	if mano == "abono_mejorado":
		if estado != Estado.CRECIENDO or abonada_extra:
			Juego.avisar("El abono mejorado se echa sobre una planta que esté creciendo (una vez).")
		else:
			Juego.quitar(mano, 1)
			abonada_extra = true
			velocidad *= 1.5
			cosecha += 1
			Juego.avisar("Abono mejorado aplicado: crece más rápido y dará una hierba más.")
		return
	match estado:
		Estado.VACIA:
			var falta: String = _que_falta()
			if falta != "":
				Juego.avisar("Para plantar te falta: %s. Todo se vende en la herboristería." % falta)
				return
			jugador.hud.abrir_minijuego(self)
		Estado.CRECIENDO:
			Juego.avisar("Todavía está creciendo. Puedes dormir en la cama para que pase el tiempo.")
		Estado.LISTA:
			var id_hierba: String = "hierba_" + tipo_hierba
			if not Juego.cabe(id_hierba, cosecha):
				Juego.avisar("No te cabe la cosecha. Haz sitio en el inventario.")
				return
			Juego.anadir(id_hierba, cosecha)
			Juego.ganar_xp(15)
			Juego.avisar("Has cosechado %d %s." % [cosecha, GameData.HIERBAS[tipo_hierba]["nombre"]])
			_vaciar()


# Devuelve lo que falta para poder plantar ("" si no falta nada).
func _que_falta() -> String:
	var faltas: PackedStringArray = []
	if not Juego.tiene("tierra"):
		faltas.append("un saco de tierra")
	var alguna_semilla: bool = false
	for id_hierba in GameData.HIERBAS:
		if Juego.tiene("semilla_" + id_hierba):
			alguna_semilla = true
	if not alguna_semilla:
		faltas.append("alguna semilla")
	if not Juego.tiene_recipiente():
		faltas.append("una jarra de agua")
	elif Juego.recipiente_de_agua() == null:
		faltas.append("agua en la jarra (llénala en el grifo de la cocina)")
	return ", ".join(faltas)


# La llama el minijuego al terminar bien.
func plantar(id_hierba: String, nota: float, con_abono: bool) -> void:
	tipo_hierba = id_hierba
	calidad = nota
	progreso = 0.0
	velocidad = (1.5 if con_abono else 1.0) * _factor_velocidad()
	abonada_extra = false
	# Calidad baja: 1 hierba; media: 2; alta: 3. El abono suma una más.
	cosecha = 1
	if nota >= 0.45:
		cosecha = 2
	if nota >= 0.8:
		cosecha = 3
	if con_abono:
		cosecha += 1
	cosecha += nivel - 1
	estado = Estado.CRECIENDO
	_tierra.visible = true
	_crear_planta(id_hierba)
	_planta.scale = Vector3.ONE * 0.15


# Datos para guardar la partida.
func exportar() -> Dictionary:
	return {"estado": int(estado), "tipo": tipo_hierba, "progreso": progreso,
			"cosecha": cosecha, "calidad": calidad, "velocidad": velocidad,
			"nivel": nivel, "riego": riego, "extra": abonada_extra}


# Restaura una maceta guardada (lo inverso de exportar).
func importar(d: Dictionary) -> void:
	_vaciar()
	nivel = clampi(int(d.get("nivel", 1)), 1, 3)
	riego = bool(d.get("riego", false))
	_decorar()
	var guardado: int = int(d.get("estado", 0))
	if guardado == int(Estado.VACIA) or not GameData.HIERBAS.has(str(d.get("tipo", ""))):
		return
	plantar(str(d["tipo"]), float(d.get("calidad", 0.5)), false)
	velocidad = float(d.get("velocidad", 1.0))
	cosecha = clampi(int(d.get("cosecha", 1)), 1, 20)
	abonada_extra = bool(d.get("extra", false))
	progreso = clampf(float(d.get("progreso", 0.0)), 0.0, 1.0)
	if guardado == int(Estado.LISTA):
		progreso = 1.0
		estado = Estado.LISTA
	else:
		estado = Estado.CRECIENDO
	_planta.scale = Vector3.ONE * lerpf(0.15, 1.0, progreso)


func _crear_planta(id_hierba: String) -> void:
	_planta = Node3D.new()
	_planta.position.y = 0.3
	add_child(_planta)
	var color: Color = GameData.HIERBAS[id_hierba]["color"]
	if GameData.HIERBAS[id_hierba]["forma"] == "seta":
		# Hongo: un tallo pálido y un sombrero aplastado.
		Construir.cilindro(_planta, Vector3(0, 0.12, 0), 0.04, 0.24, Color(0.85, 0.82, 0.75), false, 0.3)
		Construir.esfera(_planta, Vector3(0, 0.26, 0), 0.15, color, Vector3(1, 0.5, 1), 0.3)
	else:
		# Hoja de Bruma: un tallo y hojas alargadas en abanico.
		Construir.cilindro(_planta, Vector3(0, 0.2, 0), 0.015, 0.4, color.darkened(0.3), false, 0.3)
		for i in 7:
			var hoja: Node3D = Construir.caja(_planta, Vector3.ZERO, Vector3(0.05, 0.3, 0.01), color, false, 0.3)
			hoja.rotation = Vector3(0.0, i * TAU / 7.0, 0.7)
			hoja.position = Vector3(0, 0.3, 0) + hoja.basis * Vector3(0, 0.15, 0)
	# Materiales propios: la planta lista "respira" brillando, sin tocar a las demás.
	for hijo in _planta.get_children():
		var mat: StandardMaterial3D = Construir.material_propio(hijo as Node3D)
		if mat != null:
			_materiales_planta.append(mat)


func _vaciar() -> void:
	tipo_hierba = ""
	progreso = 0.0
	estado = Estado.VACIA
	_tierra.visible = false
	_materiales_planta.clear()
	if _planta != null:
		_planta.queue_free()
		_planta = null
