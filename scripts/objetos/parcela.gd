# parcela.gd
# -----------------------------------------------------------------------------
# La entrada de un huerto. Si lo tienes alquilado o comprado:
#   - Con semillas de cultivo legal en la mano, E siembra todo el huerto
#     (gasta 1 semilla por cada 50 m², máx. 20).
#   - Cuando está maduro, E cosecha (1 unidad por cada 12 m², máx. 60).
# El estado vive en Juego.parcelas (se guarda con la partida).
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Parcela
extends Interactuable

const DatosCultivos = preload("res://scripts/datos/cultivos.gd")
const CULTIVOS: Dictionary = DatosCultivos.CULTIVOS

var id_huerto: String = ""
var m2: int = 144
var centro_cultivo: Vector3 = Vector3.ZERO   # Dónde dibujar el cultivo (locales al padre).
var tam_cultivo: Vector2 = Vector2(10, 10)

var _cultivo: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	distancia = 3.0
	_mat = StandardMaterial3D.new()
	var malla: BoxMesh = BoxMesh.new()
	malla.size = Vector3(tam_cultivo.x, 1.0, tam_cultivo.y)
	malla.material = _mat
	_cultivo = MeshInstance3D.new()
	_cultivo.mesh = malla
	_cultivo.top_level = false
	add_child(_cultivo)
	_cultivo.global_position = get_parent().to_global(centro_cultivo) if get_parent() is Node3D else Vector3.ZERO
	_cultivo.visible = false


func _estado() -> Dictionary:
	return Juego.parcelas.get(id_huerto, {})


func _process(_delta: float) -> void:
	var e: Dictionary = _estado()
	if e.is_empty() or not Juego.huertos.has(id_huerto):
		_cultivo.visible = false
		return
	var prog: float = clampf(1.0 - float(e["t"]) / float(e["total"]), 0.0, 1.0)
	# (El tiempo lo descuenta GestorTrozos para TODOS los huertos, estén cerca o lejos.)
	_cultivo.visible = true
	var altura: float = lerpf(0.1, 0.9, prog)
	_cultivo.scale.y = altura
	_cultivo.position.y = altura / 2.0
	var color: Color = CULTIVOS[e["semilla"]]["color"]
	_mat.albedo_color = Color(0.2, 0.45, 0.15).lerp(color, prog)


func texto_accion() -> String:
	if not Juego.huertos.has(id_huerto) and Propiedades.es_del_mundo(id_huerto):
		var ficha: Dictionary = Propiedades.de_id(id_huerto)
		if not ficha.is_empty():
			return "%s: alquilar %d $  ·  Mayús+E comprar %d $" % [ficha["nombre"], ficha["alquiler"],
					Propiedades.precio_compra(ficha)]
	if not Juego.huertos.has(id_huerto):
		return "Huerto de %d m² (alquílalo en la inmobiliaria de la plaza)" % m2
	var e: Dictionary = _estado()
	if e.is_empty():
		var semilla: String = Juego.id_en_mano()
		if CULTIVOS.has(semilla):
			return "Sembrar %d semillas de %s (huerto de %d m²)" % [_semillas_necesarias(), DatosObjetos.nombre(semilla), m2]
		return "Huerto vacío (%d m²): ten semillas de trigo, maíz o tomate en la mano" % m2
	if float(e["t"]) > 0.0:
		return "Creciendo... faltan %d s" % int(e["t"])
	return "Cosechar %d x %s" % [_unidades(), DatosObjetos.nombre(CULTIVOS[e["semilla"]]["cosecha"])]


const Economia = preload("res://scripts/datos/economia.gd")
const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const Propiedades = preload("res://scripts/datos/propiedades.gd")


func _semillas_necesarias() -> int:
	return clampi(int(ceil(m2 / 50.0)), 1, 20)


func _unidades() -> int:
	return clampi(m2 / Economia.M2_POR_UNIDAD, 1, Economia.MAX_UNIDADES_HUERTO)


func usar(_jugador: Node) -> void:
	if not Juego.huertos.has(id_huerto) and Propiedades.es_del_mundo(id_huerto):
		var ficha: Dictionary = Propiedades.de_id(id_huerto)
		if not ficha.is_empty():
			Propiedades.contratar(ficha, Input.is_action_pressed("correr"))
			return
	if not Juego.huertos.has(id_huerto):
		Juego.avisar("Este huerto no es tuyo. Alquílalo o cómpralo en la inmobiliaria de la plaza.")
		return
	var e: Dictionary = _estado()
	if e.is_empty():
		var semilla: String = Juego.id_en_mano()
		if not CULTIVOS.has(semilla):
			Juego.avisar("Coge semillas de trigo, maíz o tomate (herboristería) con la barra rápida.")
			return
		var n: int = _semillas_necesarias()
		if not Juego.tiene(semilla, n):
			Juego.avisar("Necesitas %d semillas para sembrar este huerto." % n)
			return
		Juego.quitar(semilla, n)
		var total: float = CULTIVOS[semilla]["tiempo"] * Economia.FACTOR_TIEMPO_CULTIVO * (0.85 if Juego.habilidades.has("cultivo") else 1.0)
		Juego.parcelas[id_huerto] = {"semilla": semilla, "t": total, "total": total}
		Juego.avisar("Huerto sembrado. Tardará %d s en madurar." % int(total))
		return
	if float(e["t"]) > 0.0:
		Juego.avisar("Todavía no está maduro.")
		return
	var cosecha: String = CULTIVOS[e["semilla"]]["cosecha"]
	var unidades: int = _unidades()
	var sobra: int = Juego.anadir(cosecha, unidades)
	if sobra > 0:
		Juego.avisar("Cosechaste %d x %s; no cabían %d más y se pudrieron." % [unidades - sobra, DatosObjetos.nombre(cosecha), sobra])
	else:
		Juego.avisar("Cosechaste %d x %s." % [unidades, DatosObjetos.nombre(cosecha)])
	Juego.ganar_xp(unidades)
	Juego.parcelas.erase(id_huerto)
