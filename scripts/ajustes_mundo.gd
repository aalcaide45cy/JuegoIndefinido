# ajustes_mundo.gd
# -----------------------------------------------------------------------------
# Los ajustes que se tocan desde el panel de administrador (F1 > "Ajustes del
# mundo y presets"): hora, velocidad del tiempo, clima, linterna, velocidad y
# salto del jugador, campo de visión, volumen y policía.
#
# Un "preset" es una foto de todos estos ajustes con un nombre. Se guardan en
# user://presets_admin.json (en Windows: %APPDATA%\Godot\app_userdata\<juego>),
# así que siguen ahí al cerrar y abrir el juego.
#
# Para añadir un ajuste nuevo: ponlo en DEFINICION y en aplicar(); el menú y
# los presets lo recogen solos.
# -----------------------------------------------------------------------------
class_name AjustesMundo
extends RefCounted

const RUTA: String = "user://presets_admin.json"
const PREDETERMINADO: String = "Predeterminado"   # Preset fijo: no se puede borrar ni sobrescribir.

# id -> {nombre, min, max, paso, def}. Los que no son sliders (clima, color, policía) se tratan aparte.
const DEFINICION: Array = [
	{"id": "hora", "nombre": "Hora del día", "min": 0.0, "max": 23.99, "paso": 0.05, "def": 20.0},
	{"id": "velocidad_tiempo", "nombre": "Velocidad del tiempo (x)", "min": 0.0, "max": 60.0, "paso": 1.0, "def": 1.0},
	{"id": "duracion_dia", "nombre": "Minutos reales por día", "min": 2.0, "max": 240.0, "paso": 1.0, "def": 60.0},
	{"id": "linterna_energia", "nombre": "Linterna: intensidad", "min": 0.0, "max": 16.0, "paso": 0.1, "def": 5.0},
	{"id": "linterna_alcance", "nombre": "Linterna: alcance (m)", "min": 5.0, "max": 100.0, "paso": 1.0, "def": 34.0},
	{"id": "linterna_angulo", "nombre": "Linterna: ángulo del haz (°)", "min": 10.0, "max": 80.0, "paso": 1.0, "def": 30.0},
	{"id": "vel_andar", "nombre": "Jugador: velocidad al andar (x)", "min": 0.5, "max": 4.0, "paso": 0.05, "def": 1.0},
	{"id": "vel_correr", "nombre": "Jugador: velocidad al correr (x)", "min": 0.5, "max": 4.0, "paso": 0.05, "def": 1.0},
	{"id": "salto", "nombre": "Jugador: fuerza del salto (x)", "min": 0.5, "max": 3.0, "paso": 0.05, "def": 1.0},
	{"id": "fov", "nombre": "Campo de visión (°)", "min": 50.0, "max": 110.0, "paso": 1.0, "def": 70.0},
	{"id": "vol_musica", "nombre": "Volumen de la música", "min": 0.0, "max": 1.0, "paso": 0.05, "def": 0.7},
	{"id": "vol_ambiente", "nombre": "Volumen del ambiente", "min": 0.0, "max": 1.0, "paso": 0.05, "def": 0.8},
]

# Valores actuales (se leen desde el jugador). Los de aquí son los de un arranque normal.
static var valores: Dictionary = {}
static var linterna_color: Color = Color(1.0, 0.94, 0.8)
static var clima: String = "despejado"
static var policia_activa: bool = true


static func def(id: String) -> Dictionary:
	for d in DEFINICION:
		if d["id"] == id:
			return d
	return {}


static func valor(id: String) -> float:
	if valores.has(id):
		return float(valores[id])
	return float(def(id).get("def", 0.0))


# Una foto de los ajustes ahora mismo (lee también lo que cambió fuera del menú: hora, clima...).
static func capturar() -> Dictionary:
	var d: Dictionary = {}
	for e in DEFINICION:
		d[e["id"]] = valor(e["id"])
	d["hora"] = Juego.hora
	d["velocidad_tiempo"] = Juego.velocidad_tiempo
	d["duracion_dia"] = Juego.duracion_dia_min
	d["vol_musica"] = Musica.volumen_musica
	d["vol_ambiente"] = Musica.volumen_ambiente
	d["linterna_color"] = linterna_color.to_html(false)
	d["clima"] = Clima.actual
	d["policia"] = Juego.policia_activa
	return d


# Deja los ajustes como dice "d" (los que falten se quedan como estaban) y los aplica al juego.
static func aplicar(d: Dictionary) -> void:
	for e in DEFINICION:
		var id: String = e["id"]
		if d.has(id):
			valores[id] = clampf(float(d[id]), float(e["min"]), float(e["max"]))
	if d.has("linterna_color"):
		linterna_color = Color.html(String(d["linterna_color"]))
	if d.has("clima") and Clima.TIPOS.has(String(d["clima"])):
		clima = String(d["clima"])
		Clima.poner(clima, 6.0)
	if d.has("policia"):
		policia_activa = bool(d["policia"])
		Juego.policia_activa = policia_activa
		if not policia_activa:
			Juego.alerta = 0.0
	if d.has("hora"):
		Juego.hora = valor("hora")
	if d.has("velocidad_tiempo"):
		Juego.velocidad_tiempo = valor("velocidad_tiempo")
	if d.has("duracion_dia"):
		Juego.duracion_dia_min = valor("duracion_dia")
	if d.has("vol_musica"):
		Musica.volumen_musica = valor("vol_musica")
	if d.has("vol_ambiente"):
		Musica.volumen_ambiente = valor("vol_ambiente")
	Musica.guardar_opciones()
	aplicar_al_jugador()


# Pone en el jugador lo que le toca (linterna y cámara); la velocidad y el salto los lee él cada vez.
static func aplicar_al_jugador() -> void:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	for j in arbol.get_nodes_in_group("jugador"):
		if j.has_method("aplicar_ajustes"):
			j.aplicar_ajustes()


static func predeterminado() -> Dictionary:
	var d: Dictionary = {}
	for e in DEFINICION:
		d[e["id"]] = e["def"]
	d["linterna_color"] = Color(1.0, 0.94, 0.8).to_html(false)
	d["clima"] = "despejado"
	d["policia"] = true
	return d


# ------------------------------ Presets en disco ------------------------------

static func _leer() -> Dictionary:
	if not FileAccess.file_exists(RUTA):
		return {}
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if datos is Dictionary and datos.get("presets") is Dictionary:
		return datos["presets"]
	return {}


static func _escribir(presets: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "presets": presets}, "\t"))
	f.close()
	return true


# Nombres de los presets: primero el fijo, luego los tuyos por orden alfabético.
static func nombres() -> PackedStringArray:
	var lista: Array = _leer().keys()
	lista.sort()
	var r: PackedStringArray = PackedStringArray([PREDETERMINADO])
	for n in lista:
		r.append(String(n))
	return r


static func existe(nombre: String) -> bool:
	return nombre == PREDETERMINADO or _leer().has(nombre)


# Guarda los ajustes actuales con ese nombre (si ya existía, lo sobrescribe). Devuelve "" si fue bien, o el motivo.
static func guardar(nombre: String) -> String:
	nombre = nombre.strip_edges()
	if nombre == "":
		return "Escribe un nombre para el preset."
	if nombre == PREDETERMINADO:
		return "«%s» es un preset fijo: elige otro nombre." % PREDETERMINADO
	var presets: Dictionary = _leer()
	presets[nombre] = capturar()
	return "" if _escribir(presets) else "No se pudo escribir el archivo."


static func cargar(nombre: String) -> bool:
	if nombre == PREDETERMINADO:
		aplicar(predeterminado())
		return true
	var presets: Dictionary = _leer()
	if not presets.has(nombre) or not presets[nombre] is Dictionary:
		return false
	aplicar(presets[nombre])
	return true


static func borrar(nombre: String) -> bool:
	var presets: Dictionary = _leer()
	if nombre == PREDETERMINADO or not presets.has(nombre):
		return false
	presets.erase(nombre)
	return _escribir(presets)
