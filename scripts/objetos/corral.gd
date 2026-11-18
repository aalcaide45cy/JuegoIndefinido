# corral.gd
# -----------------------------------------------------------------------------
# Corrales de la granja: gallinero (gallinas -> huevos) y establo (vacas ->
# leche). Con un animal en la mano, E lo mete en el corral (hasta la capacidad,
# que sube con "Mejora de equipo": 4 / 8 / 12). Sin animal en la mano, E recoge
# el producto. Cada animal produce 1 unidad cada cierto tiempo (se acumula, máx.
# 20). Hace falta tener algún huerto alquilado o comprado. El estado vive en
# Juego.granja (se guarda). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Corral
extends Interactuable

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const ESPECIES: Dictionary = {
	"gallina": {"producto": "huevo", "tiempo": 60.0, "color": Color(0.95, 0.93, 0.85), "tam": Vector3(0.35, 0.35, 0.45)},
	"vaca": {"producto": "leche", "tiempo": 180.0, "color": Color(0.9, 0.9, 0.9), "tam": Vector3(0.9, 0.9, 1.6)},
}
const MAX_ACUMULADO: int = 20

var id_corral: String = "gallinero"
var especie: String = "gallina"
var _animales: Node3D
var _dibujados: int = -1


func _ready() -> void:
	distancia = 4.6   # El corral mide 6 m y tiene valla maciza: desde fuera hay que llegar al centro.
	_animales = Node3D.new()
	add_child(_animales)
	var tam: float = 6.0
	# Vallado y suelo de paja.
	Construir.caja(self, Vector3(0, 0.02, 0), Vector3(tam, 0.04, tam), Color(0.55, 0.45, 0.2), false)
	for lado in [-1.0, 1.0]:
		Construir.caja(self, Vector3(lado * tam / 2.0, 0.5, 0), Vector3(0.12, 1.0, tam), Color(0.4, 0.28, 0.17), true)
		Construir.caja(self, Vector3(0, 0.5, lado * tam / 2.0), Vector3(tam, 1.0, 0.12), Color(0.4, 0.28, 0.17), true)
	var t: Label3D = Construir.texto(self, Vector3(0, 1.8, 0), "GALLINERO" if especie == "gallina" else "ESTABLO", 56, Color(1.0, 0.9, 0.7))
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _estado() -> Dictionary:
	if not Juego.granja.has(id_corral):
		Juego.granja[id_corral] = {"n": 0, "prod": 0, "t": 0.0, "nivel": 1, "u": Juego.reloj}
	return Juego.granja[id_corral]


func capacidad() -> int:
	return 4 * int(_estado()["nivel"])


func _process(_delta: float) -> void:
	var e: Dictionary = _estado()
	var n: int = int(e["n"])
	# Reloj absoluto: aunque el corral estuviera descargado (lejos), al volver se cuenta el tiempo que pasó.
	var pasado: float = maxf(0.0, Juego.reloj - float(e.get("u", Juego.reloj)))
	e["u"] = Juego.reloj
	if n > 0 and not Juego.huertos.is_empty():
		e["t"] = float(e["t"]) + pasado * n
		var tiempo: float = ESPECIES[especie]["tiempo"]
		while float(e["t"]) >= tiempo and int(e["prod"]) < MAX_ACUMULADO:
			e["t"] = float(e["t"]) - tiempo
			e["prod"] = int(e["prod"]) + 1
	if n != _dibujados:
		_dibujados = n
		_dibujar(n)


func _dibujar(n: int) -> void:
	for h in _animales.get_children():
		h.queue_free()
	var datos: Dictionary = ESPECIES[especie]
	for i in n:
		var a: float = i * 2.399   # Reparto en espiral.
		var r: float = 0.8 + 0.28 * i
		var pos: Vector3 = Vector3(cos(a) * r * 0.6, datos["tam"].y / 2.0 + 0.05, sin(a) * r * 0.6)
		var cuerpo: Node3D = Construir.caja(_animales, pos, datos["tam"], datos["color"], false)
		cuerpo.rotation.y = a


func texto_accion() -> String:
	var e: Dictionary = _estado()
	var mano: String = Juego.id_en_mano()
	if mano == "mejora_equipo" and int(e["nivel"]) < 3:
		return "Ampliar el corral (capacidad %d)" % (capacidad() + 4)
	if mano == especie:
		return "Meter %s en el corral (%d/%d)" % [DatosObjetos.nombre(especie), e["n"], capacidad()]
	if int(e["prod"]) > 0:
		return "Recoger %d x %s" % [e["prod"], DatosObjetos.nombre(ESPECIES[especie]["producto"])]
	return "%s: %d/%d animales (compra %s en la herboristería)" % [id_corral.capitalize(), e["n"], capacidad(), DatosObjetos.nombre(especie)]


func usar(_jugador: Node) -> void:
	if Juego.huertos.is_empty():
		Juego.avisar("Primero necesitas un huerto alquilado o comprado (inmobiliaria de la plaza).")
		return
	var e: Dictionary = _estado()
	var mano: String = Juego.id_en_mano()
	if mano == "mejora_equipo":
		if int(e["nivel"]) >= 3:
			Juego.avisar("El corral ya está ampliado al máximo.")
		else:
			Juego.quitar(mano, 1)
			e["nivel"] = int(e["nivel"]) + 1
			Juego.avisar("Corral ampliado: capacidad %d." % capacidad())
		return
	if mano == especie:
		if int(e["n"]) >= capacidad():
			Juego.avisar("El corral está lleno. Amplíalo con una Mejora de equipo.")
			return
		Juego.quitar(mano, 1)
		e["n"] = int(e["n"]) + 1
		Juego.avisar("Animal al corral: %d/%d." % [e["n"], capacidad()])
		return
	var producto: String = ESPECIES[especie]["producto"]
	var cantidad: int = int(e["prod"])
	if cantidad <= 0:
		Juego.avisar("Todavía no hay nada que recoger.")
		return
	var sobra: int = Juego.anadir(producto, cantidad)
	e["prod"] = sobra
	Juego.ganar_xp(cantidad - sobra)
	Juego.avisar("Has recogido %d x %s." % [cantidad - sobra, DatosObjetos.nombre(producto)])
