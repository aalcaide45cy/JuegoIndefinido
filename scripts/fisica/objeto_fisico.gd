# objeto_fisico.gd
# -----------------------------------------------------------------------------
# Un objeto suelto del escenario que reacciona de verdad: farolas, bancos,
# papeleras, bolardos, barriles, cajas, conos, vallas de obra, señales, sillas...
#
# Cómo funciona (pensado para que miles de objetos no gasten nada):
#   - Nace CONGELADO (freeze en modo estático): para el motor de física es igual
#     que una pared, así que mil farolas quietas no cuestan casi nada.
#   - Se DESPIERTA cuando algo lo golpea con fuerza: una bala, un puñetazo, una
#     explosión, un coche o el propio jugador al empujarlo. Desde ese momento es
#     un cuerpo rígido normal: cae, rueda, vuelca y choca con lo demás.
#   - Los objetos "anclados" (farolas, bolardos, señales, bancos atornillados)
#     no se mueven con un disparo: solo con un golpe fuerte (coche o explosión).
#   - Tiene VIDA. Al llegar a cero se ROMPE en sus propias piezas (las mismas
#     cajas con las que está dibujado), que salen volando como escombros, con
#     chispas, astillas, polvo o cristales según el material.
#   - Algunos hacen algo especial al romperse: el bidón rojo explota y la boca
#     de riego suelta un chorro de agua.
#
# Se crean con ObjetoFisico.crear("farola"), desde_cajas(...) o desde_modelo(...).
# Los efectos (escombros, partículas, ondas expansivas) están en fisica_escenario.gd.
# El gestor que hace que coches y jugador los empujen es gestor_fisica.gd.
# -----------------------------------------------------------------------------
class_name ObjetoFisico
extends RigidBody3D

const CAPA: int = 4              # Capa 3 de choque: objetos sueltos del escenario.
const DIST_VISTA: float = 320.0  # A más distancia no se dibujan (son pequeños).

const POSTE: Color = Color(0.16, 0.16, 0.18)
const MADERA: Color = Color(0.42, 0.29, 0.18)
const MADERA_OSC: Color = Color(0.3, 0.2, 0.12)
const VERDE_MUNI: Color = Color(0.16, 0.32, 0.2)
const LUZ_CALIDA: Color = Color(1.0, 0.86, 0.55)

# Piezas: ["c", centro, tamaño, color] = caja.
#         ["k", base, Vector3(radio, alto, radio_arriba), color] = cilindro de 8 caras con tapa.
# masa en kg; vida en puntos; mat = metal | madera | piedra | plastico | ceramica.
# anclado: un disparo no lo mueve; hace falta un golpe que le dé "umbral" m/s.
# resistencia: por debajo de esa velocidad (m/s) un coche se para en seco contra él.
# empujable: el jugador lo arrastra al andar contra él.
const TIPOS: Dictionary = {
	"farola": {"masa": 180.0, "vida": 320.0, "mat": "metal", "anclado": true, "umbral": 4.0,
		"piezas": [
			["c", Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.36), Color(0.1, 0.1, 0.11)],
			["c", Vector3(0, 2.45, 0), Vector3(0.15, 4.3, 0.15), POSTE],
			["c", Vector3(0.36, 4.55, 0), Vector3(0.82, 0.1, 0.1), POSTE],
			["c", Vector3(0.72, 4.48, 0), Vector3(0.46, 0.18, 0.32), POSTE]],
		"lampara": [Vector3(0.72, 4.35, 0), Vector3(0.36, 0.08, 0.24)], "luz": Vector3(0.72, 4.1, 0)},
	"farol_casco": {"masa": 110.0, "vida": 220.0, "mat": "metal", "anclado": true, "umbral": 4.0,
		"piezas": [
			["c", Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), Color(0.08, 0.08, 0.09)],
			["c", Vector3(0, 1.8, 0), Vector3(0.12, 3.2, 0.12), POSTE],
			["c", Vector3(0, 3.5, 0), Vector3(0.36, 0.08, 0.36), POSTE],
			["c", Vector3(0, 3.82, 0), Vector3(0.26, 0.1, 0.26), POSTE]],
		"lampara": [Vector3(0, 3.66, 0), Vector3(0.28, 0.26, 0.28)], "luz": Vector3(0, 3.5, 0)},
	"farolillo": {"masa": 40.0, "vida": 90.0, "mat": "madera", "anclado": true, "umbral": 3.0,
		"piezas": [
			["c", Vector3(0, 1.6, 0), Vector3(0.14, 3.2, 0.14), MADERA],
			["c", Vector3(0, 3.55, 0), Vector3(0.46, 0.08, 0.46), MADERA_OSC]],
		"lampara": [Vector3(0, 3.3, 0), Vector3(0.36, 0.36, 0.36)], "luz": Vector3(0, 3.2, 0)},
	"banco": {"masa": 45.0, "vida": 70.0, "mat": "madera", "anclado": true, "umbral": 3.0,
		"piezas": [
			["c", Vector3(-0.75, 0.22, 0), Vector3(0.08, 0.44, 0.5), POSTE],
			["c", Vector3(0.75, 0.22, 0), Vector3(0.08, 0.44, 0.5), POSTE],
			["c", Vector3(0, 0.46, 0.02), Vector3(1.8, 0.05, 0.5), MADERA],
			["c", Vector3(0, 0.78, 0.25), Vector3(1.8, 0.28, 0.05), MADERA],
			["c", Vector3(-0.75, 0.66, 0.24), Vector3(0.06, 0.4, 0.06), POSTE],
			["c", Vector3(0.75, 0.66, 0.24), Vector3(0.06, 0.4, 0.06), POSTE]]},
	"banco_rustico": {"masa": 30.0, "vida": 50.0, "mat": "madera", "anclado": false, "umbral": 2.0,
		"piezas": [
			["c", Vector3(0, 0.2, -0.7), Vector3(0.5, 0.4, 0.3), MADERA_OSC],
			["c", Vector3(0, 0.2, 0.7), Vector3(0.5, 0.4, 0.3), MADERA_OSC],
			["c", Vector3(0, 0.45, 0), Vector3(0.6, 0.1, 2.0), MADERA]]},
	"papelera": {"masa": 12.0, "vida": 35.0, "mat": "metal", "empujable": true,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.24, 0.75, 0.27), VERDE_MUNI],
			["k", Vector3(0, 0.75, 0), Vector3(0.29, 0.05, 0.29), Color(0.1, 0.12, 0.1)]]},
	"bolardo": {"masa": 120.0, "vida": 260.0, "mat": "metal", "anclado": true, "umbral": 9.0, "resistencia": 9.0,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.11, 0.85, 0.09), Color(0.2, 0.2, 0.22)],
			["k", Vector3(0, 0.62, 0), Vector3(0.115, 0.06, 0.115), Color(0.85, 0.85, 0.85)]]},
	"buzon": {"masa": 35.0, "vida": 70.0, "mat": "metal", "anclado": true, "umbral": 3.0,
		"piezas": [
			["c", Vector3(0, 0.35, 0), Vector3(0.12, 0.7, 0.12), POSTE],
			["c", Vector3(0, 0.98, 0), Vector3(0.45, 0.58, 0.38), Color(0.95, 0.75, 0.1)],
			["c", Vector3(0, 1.08, 0.2), Vector3(0.3, 0.05, 0.02), Color(0.1, 0.1, 0.1)]]},
	"contenedor": {"masa": 140.0, "vida": 180.0, "mat": "plastico", "empujable": true,
		"piezas": [
			["c", Vector3(0, 0.66, 0), Vector3(1.4, 1.1, 1.0), Color(0.2, 0.38, 0.22)],
			["c", Vector3(0, 1.25, 0.05), Vector3(1.45, 0.08, 1.05), Color(0.15, 0.28, 0.17)],
			["c", Vector3(-0.55, 0.07, -0.35), Vector3(0.14, 0.14, 0.14), Color(0.05, 0.05, 0.05)],
			["c", Vector3(0.55, 0.07, -0.35), Vector3(0.14, 0.14, 0.14), Color(0.05, 0.05, 0.05)],
			["c", Vector3(-0.55, 0.07, 0.35), Vector3(0.14, 0.14, 0.14), Color(0.05, 0.05, 0.05)],
			["c", Vector3(0.55, 0.07, 0.35), Vector3(0.14, 0.14, 0.14), Color(0.05, 0.05, 0.05)]]},
	"boca_riego": {"masa": 60.0, "vida": 160.0, "mat": "metal", "anclado": true, "umbral": 3.0, "agua": true,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.13, 0.62, 0.12), Color(0.75, 0.12, 0.1)],
			["k", Vector3(0, 0.62, 0), Vector3(0.14, 0.12, 0.06), Color(0.6, 0.1, 0.08)],
			["c", Vector3(0, 0.42, 0), Vector3(0.42, 0.1, 0.1), Color(0.6, 0.1, 0.08)]]},
	"cono": {"masa": 3.0, "vida": 12.0, "mat": "plastico", "empujable": true,
		"piezas": [
			["c", Vector3(0, 0.02, 0), Vector3(0.4, 0.04, 0.4), Color(0.12, 0.12, 0.12)],
			["k", Vector3(0, 0.04, 0), Vector3(0.15, 0.62, 0.03), Color(1.0, 0.45, 0.08)],
			["k", Vector3(0, 0.3, 0), Vector3(0.1, 0.1, 0.085), Color(0.95, 0.95, 0.95)]]},
	"valla_obra": {"masa": 16.0, "vida": 40.0, "mat": "metal", "empujable": true,
		"piezas": [
			["c", Vector3(-0.9, 0.5, 0), Vector3(0.06, 1.0, 0.06), Color(0.8, 0.8, 0.82)],
			["c", Vector3(0.9, 0.5, 0), Vector3(0.06, 1.0, 0.06), Color(0.8, 0.8, 0.82)],
			["c", Vector3(0, 0.85, 0), Vector3(1.86, 0.22, 0.04), Color(0.95, 0.15, 0.1)],
			["c", Vector3(0, 0.45, 0), Vector3(1.86, 0.12, 0.04), Color(0.95, 0.95, 0.95)],
			["c", Vector3(-0.9, 0.03, 0), Vector3(0.12, 0.06, 0.7), Color(0.2, 0.2, 0.2)],
			["c", Vector3(0.9, 0.03, 0), Vector3(0.12, 0.06, 0.7), Color(0.2, 0.2, 0.2)]]},
	"barril": {"masa": 35.0, "vida": 50.0, "mat": "madera", "empujable": true,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.36, 0.45, 0.4), Color(0.42, 0.28, 0.15)],
			["k", Vector3(0, 0.45, 0), Vector3(0.4, 0.45, 0.36), Color(0.38, 0.25, 0.14)],
			["k", Vector3(0, 0.12, 0), Vector3(0.375, 0.05, 0.375), Color(0.25, 0.25, 0.27)],
			["k", Vector3(0, 0.75, 0), Vector3(0.385, 0.05, 0.385), Color(0.25, 0.25, 0.27)]]},
	"bidon_rojo": {"masa": 25.0, "vida": 30.0, "mat": "metal", "empujable": true, "explosivo": true,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.3, 0.9, 0.3), Color(0.75, 0.1, 0.08)],
			["k", Vector3(0, 0.2, 0), Vector3(0.31, 0.04, 0.31), Color(0.2, 0.2, 0.2)],
			["k", Vector3(0, 0.65, 0), Vector3(0.31, 0.04, 0.31), Color(0.2, 0.2, 0.2)],
			["c", Vector3(0, 0.6, 0.3), Vector3(0.22, 0.22, 0.02), Color(0.95, 0.8, 0.1)]]},
	"caja": {"masa": 12.0, "vida": 25.0, "mat": "madera", "empujable": true,
		"piezas": [
			["c", Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), Color(0.62, 0.48, 0.28)],
			["c", Vector3(0, 0.3, 0.305), Vector3(0.62, 0.08, 0.02), Color(0.45, 0.34, 0.2)],
			["c", Vector3(0, 0.3, -0.305), Vector3(0.62, 0.08, 0.02), Color(0.45, 0.34, 0.2)]]},
	"lena": {"masa": 70.0, "vida": 50.0, "mat": "madera",
		"piezas": [
			["c", Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 2.0), Color(0.5, 0.36, 0.2)],
			["c", Vector3(0, 0.6, 0), Vector3(0.7, 0.4, 1.7), Color(0.46, 0.33, 0.19)],
			["c", Vector3(0, 1.0, 0), Vector3(0.7, 0.4, 1.4), Color(0.52, 0.38, 0.22)]]},
	"senal_curva": {"masa": 18.0, "vida": 45.0, "mat": "metal", "anclado": true, "umbral": 3.0,
		"piezas": [
			["c", Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08), Color(0.35, 0.36, 0.38)],
			["c", Vector3(0, 2.4, 0), Vector3(0.9, 0.9, 0.04), Color(1.0, 0.8, 0.1)],
			["c", Vector3(0, 2.4, 0.025), Vector3(0.5, 0.5, 0.02), Color(0.1, 0.1, 0.1)]]},
	"senal_velocidad": {"masa": 18.0, "vida": 45.0, "mat": "metal", "anclado": true, "umbral": 3.0,
		"piezas": [
			["c", Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08), Color(0.35, 0.36, 0.38)],
			["c", Vector3(0, 2.4, 0), Vector3(0.85, 0.85, 0.04), Color(0.85, 0.1, 0.1)],
			["c", Vector3(0, 2.4, 0.025), Vector3(0.6, 0.6, 0.02), Color(0.95, 0.95, 0.95)]]},
	"silla": {"masa": 6.0, "vida": 18.0, "mat": "madera", "empujable": true,
		"piezas": [
			["c", Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42), MADERA],
			["c", Vector3(0, 0.75, 0.19), Vector3(0.42, 0.5, 0.04), MADERA],
			["c", Vector3(-0.18, 0.22, -0.18), Vector3(0.04, 0.44, 0.04), MADERA_OSC],
			["c", Vector3(0.18, 0.22, -0.18), Vector3(0.04, 0.44, 0.04), MADERA_OSC],
			["c", Vector3(-0.18, 0.22, 0.18), Vector3(0.04, 0.44, 0.04), MADERA_OSC],
			["c", Vector3(0.18, 0.22, 0.18), Vector3(0.04, 0.44, 0.04), MADERA_OSC]]},
	"maceta": {"masa": 25.0, "vida": 22.0, "mat": "ceramica", "empujable": true,
		"piezas": [
			["k", Vector3(0, 0, 0), Vector3(0.26, 0.5, 0.34), Color(0.68, 0.36, 0.22)],
			["k", Vector3(0, 0.5, 0), Vector3(0.3, 0.45, 0.05), Color(0.22, 0.48, 0.2)]]},
	"mesa_terraza": {"masa": 14.0, "vida": 30.0, "mat": "metal", "empujable": true,
		"piezas": [
			["k", Vector3(0, 0.72, 0), Vector3(0.4, 0.04, 0.4), Color(0.85, 0.85, 0.82)],
			["c", Vector3(0, 0.36, 0), Vector3(0.06, 0.72, 0.06), POSTE],
			["c", Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.5), POSTE]]},
}

static var _mallas: Dictionary = {}      # tipo -> ArrayMesh (compartida por todos los de ese tipo)
static var _formas: Dictionary = {}      # tipo -> [Shape3D, centro]
static var _mallas_lampara: Dictionary = {}
static var _mat_vertices: StandardMaterial3D = null

var tipo: String = ""
var vida: float = 50.0
var vida_max: float = 50.0
var material_fisico: String = "madera"
var anclado: bool = false
var umbral: float = 3.0
var resistencia: float = 0.0
var empujable: bool = false
var explosivo: bool = false
var agua: bool = false
var piezas: Array = []
var roto: bool = false
var alto: float = 1.0

var _luz: OmniLight3D = null
var _lampara: MeshInstance3D = null
var _vel_antes: Vector3 = Vector3.ZERO
var _t_despierto: float = 0.0
var _ms_golpe_coche: int = -100000
var _ms_sonido: int = -100000


# ------------------------------------------------------------------ crear ----

# Crea un objeto del catálogo. "con_luz": las farolas llevan una luz de verdad
# (solo en la ciudad principal; en el mundo grande brillan sin luz para no gastar).
static func crear(nombre: String, con_luz: bool = false) -> ObjetoFisico:
	var d: Dictionary = TIPOS.get(nombre, {})
	if d.is_empty():
		push_warning("ObjetoFisico: tipo desconocido '%s'" % nombre)
		nombre = "caja"
		d = TIPOS["caja"]
	var o: ObjetoFisico = ObjetoFisico.new()
	o.tipo = nombre
	o.piezas = d["piezas"]
	o._configurar(d)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _malla_de(nombre, o.piezas)
	mi.visibility_range_end = DIST_VISTA
	mi.visibility_range_end_margin = 20.0
	o.add_child(mi)
	var f: Array = _forma_de(nombre, o.piezas)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = f[0]
	cs.position = f[1]
	o.add_child(cs)
	o.alto = (f[0] as BoxShape3D).size.y
	if d.has("lampara"):
		o._poner_lampara(d["lampara"])
	if con_luz and d.has("luz"):
		o._luz = Construir.luz_noche(o, d["luz"], Color(1.0, 0.7, 0.4), 1.6, 11.0)
	return o


# Objeto hecho de cajas sueltas (muebles de los interiores). cajas: [[centro_local, tamaño, color], ...]
# con el suelo del objeto en y = 0.
static func desde_cajas(cajas: Array, mat: String = "madera") -> ObjetoFisico:
	var o: ObjetoFisico = ObjetoFisico.new()
	o.tipo = "mueble"
	var lista: Array = []
	var volumen: float = 0.0
	for cj in cajas:
		lista.append(["c", cj[0], cj[1], cj[2]])
		var t: Vector3 = cj[1]
		volumen += t.x * t.y * t.z
	o.piezas = lista
	var masa: float = clampf(volumen * (420.0 if mat == "madera" else 700.0), 3.0, 90.0)
	o._configurar({"masa": masa, "vida": 12.0 + masa * 1.2, "mat": mat, "empujable": masa < 50.0})
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _construir_malla(lista)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(mi)
	var caja: AABB = _caja_de_piezas(lista)
	var forma: BoxShape3D = BoxShape3D.new()
	forma.size = caja.size.max(Vector3.ONE * 0.05)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = forma
	cs.position = caja.get_center()
	o.add_child(cs)
	o.alto = forma.size.y
	return o


# Objeto con un modelo 3D descargado (kits de la ciudad principal). Para romperse se
# trocea su caja en pedazos del color medio indicado.
static func desde_modelo(modelo: Node3D, masa: float, mat: String, color: Color,
		anclado_: bool = false) -> ObjetoFisico:
	var o: ObjetoFisico = ObjetoFisico.new()
	o.tipo = "modelo"
	o._configurar({"masa": masa, "vida": 15.0 + masa * 1.1, "mat": mat, "anclado": anclado_,
			"umbral": 3.0, "empujable": masa <= 40.0 and not anclado_})
	o.add_child(modelo)
	var caja: AABB = modelo.transform * Assets.caja_de(modelo)   # (caja_de no cuenta la escala del propio modelo)
	if caja.size.length() < 0.01:
		caja = AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6))
	var forma: BoxShape3D = BoxShape3D.new()
	forma.size = caja.size.max(Vector3.ONE * 0.05)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = forma
	cs.position = caja.get_center()
	o.add_child(cs)
	o.alto = forma.size.y
	o.piezas = [["c", caja.get_center(), caja.size, color]]
	return o


func _configurar(d: Dictionary) -> void:
	mass = float(d.get("masa", 20.0))
	vida = float(d.get("vida", 40.0))
	vida_max = vida
	material_fisico = str(d.get("mat", "madera"))
	anclado = bool(d.get("anclado", false))
	umbral = float(d.get("umbral", 2.5))
	resistencia = float(d.get("resistencia", 0.0))
	empujable = bool(d.get("empujable", false))
	explosivo = bool(d.get("explosivo", false))
	agua = bool(d.get("agua", false))
	collision_layer = CAPA
	collision_mask = 1 | CAPA
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	angular_damp = 0.6
	add_to_group("objetos_fisicos")


func _ready() -> void:
	set_physics_process(false)


func _poner_lampara(datos: Array) -> void:
	var tam: Vector3 = datos[1]
	var clave: String = str(tam)
	if not _mallas_lampara.has(clave):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = tam
		bm.material = Construir.material(LUZ_CALIDA, 3.0)
		_mallas_lampara[clave] = bm
	# Base apagada (de día) + brillo que enciende ciclo_dia.gd de noche.
	var apagada: MeshInstance3D = MeshInstance3D.new()
	var bm2: BoxMesh = BoxMesh.new()
	bm2.size = tam * 0.98
	bm2.material = Construir.material(Color(0.85, 0.8, 0.62))
	apagada.mesh = bm2
	apagada.position = datos[0]
	add_child(apagada)
	_lampara = MeshInstance3D.new()
	_lampara.mesh = _mallas_lampara[clave]
	_lampara.position = datos[0]
	_lampara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lampara.add_to_group("ventanas_noche")
	_lampara.visible = Juego.es_de_noche()
	add_child(_lampara)


# ------------------------------------------------------------ mallas ---------

static func _material_vertices() -> StandardMaterial3D:
	if _mat_vertices == null:
		_mat_vertices = StandardMaterial3D.new()
		_mat_vertices.vertex_color_use_as_albedo = true
		_mat_vertices.roughness = 0.85
		_mat_vertices.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_vertices


static func _malla_de(nombre: String, lista: Array) -> ArrayMesh:
	if not _mallas.has(nombre):
		_mallas[nombre] = _construir_malla(lista)
	return _mallas[nombre]


static func _construir_malla(lista: Array) -> ArrayMesh:
	var mb: ConstructorMalla = ConstructorMalla.new()
	for p in lista:
		if p[0] == "c":
			mb.caja(p[1], p[2], p[3])
		else:
			var base: Vector3 = p[1]
			var dim: Vector3 = p[2]
			mb.cono(base, dim.x, dim.y, 8, p[3], dim.z)
			_tapa(mb, base + Vector3(0, dim.y, 0), dim.z, p[3].lightened(0.06))
			_tapa(mb, base, dim.x, p[3].darkened(0.2))
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.superficie())
	m.surface_set_material(0, _material_vertices())
	return m


static func _tapa(mb: ConstructorMalla, c: Vector3, radio: float, col: Color) -> void:
	if radio <= 0.001:
		return
	for i in 8:
		var a0: float = TAU * float(i) / 8.0
		var a1: float = TAU * float(i + 1) / 8.0
		mb._tri(c, c + Vector3(cos(a1) * radio, 0, sin(a1) * radio), c + Vector3(cos(a0) * radio, 0, sin(a0) * radio),
				Vector3.UP, col)


static func _caja_de_piezas(lista: Array) -> AABB:
	var caja: AABB = AABB()
	var primera: bool = true
	for p in lista:
		var b: AABB
		if p[0] == "c":
			b = AABB(p[1] - p[2] / 2.0, p[2])
		else:
			var dim: Vector3 = p[2]
			var r: float = maxf(dim.x, dim.z)
			b = AABB(p[1] - Vector3(r, 0, r), Vector3(r * 2.0, dim.y, r * 2.0))
		caja = b if primera else caja.merge(b)
		primera = false
	return caja


static func _forma_de(nombre: String, lista: Array) -> Array:
	if not _formas.has(nombre):
		var caja: AABB = _caja_de_piezas(lista)
		var forma: BoxShape3D = BoxShape3D.new()
		forma.size = caja.size.max(Vector3.ONE * 0.05)
		_formas[nombre] = [forma, caja.get_center()]
	return _formas[nombre]


# ------------------------------------------------------------ física ---------

# Lo pasa de "pared" a cuerpo rígido que cae y rueda.
func despertar() -> void:
	if roto:
		return
	if freeze:
		freeze = false
		_t_despierto = 0.0
		_vel_antes = Vector3.ZERO
	sleeping = false


func _integrate_forces(estado: PhysicsDirectBodyState3D) -> void:
	_t_despierto += estado.step
	var v: Vector3 = estado.linear_velocity
	var dv: float = (_vel_antes - v).length()
	_vel_antes = v
	if _t_despierto < 0.2:
		return
	# Golpe contra el suelo u otra cosa al caer o salir volando.
	if dv > 7.0:
		var dano: float = (dv - 7.0) * 7.0 * _fragilidad()
		_sonar(dv)
		if dano > 1.0:
			call_deferred("_dano_de_golpe", dano, estado.transform.origin, -v.normalized())
	# Una farola volcada se apaga.
	if _luz != null and estado.transform.basis.y.dot(Vector3.UP) < 0.75:
		_apagar_luz()


func _fragilidad() -> float:
	match material_fisico:
		"ceramica":
			return 3.0
		"plastico":
			return 0.6
		"metal":
			return 0.35
	return 1.0


func _dano_de_golpe(dano: float, punto: Vector3, normal: Vector3) -> void:
	if roto:
		return
	vida -= dano
	if dano > 8.0:
		FisicaEscenario.particulas(self, punto, normal, material_fisico, 0.5)
	if vida <= 0.0:
		romper(linear_velocity * mass * 0.3)


func _sonar(fuerza: float) -> void:
	var ahora: int = Time.get_ticks_msec()
	if ahora - _ms_sonido < 250:
		return
	_ms_sonido = ahora
	Sonido.tocar(self, "golpe", clampf(-20.0 + fuerza, -20.0, -4.0))


# Llamada genérica de "le han hecho daño" (puños, balas: jugador.gd la usa para todo lo
# que tiene recibir_dano). Busca el punto exacto repitiendo el rayo de la cámara del jugador.
func recibir_dano(cantidad: float) -> void:
	if roto:
		return
	var punto: Vector3 = global_position + Vector3.UP * alto * 0.6
	var dir: Vector3 = Vector3.FORWARD
	var normal: Vector3 = Vector3.UP
	var j: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if j != null:
		dir = (global_position + Vector3.UP * alto * 0.5 - j.global_position).normalized()
		if j.has_method("_origen") and j.has_method("_adelante"):
			var desde: Vector3 = j.call("_origen")
			var hacia: Vector3 = j.call("_adelante")
			var choque: Dictionary = Combate.rayo(get_world_3d(), desde, hacia, 200.0, [(j as CollisionObject3D).get_rid()])
			if not choque.is_empty() and choque["collider"] == self:
				punto = choque["position"]
				normal = choque["normal"]
				dir = hacia.normalized()
	impacto(punto, dir, cantidad, cantidad * 1.2, normal)


# Impacto con punto y dirección conocidos (balas, golpes). "impulso" en kg·m/s.
func impacto(punto: Vector3, dir: Vector3, dano: float, impulso: float, normal: Vector3 = Vector3.ZERO) -> void:
	if roto:
		return
	if normal == Vector3.ZERO:
		normal = -dir
	FisicaEscenario.particulas(self, punto, normal, material_fisico, clampf(dano / 30.0, 0.3, 1.2))
	_sonar(8.0 + dano * 0.2)
	# La lámpara de una farola se rompe de un tiro si le das arriba.
	if _lampara != null and is_instance_valid(_lampara) and punto.y > global_position.y + alto * 0.72:
		_romper_lampara()
	vida -= dano
	if vida <= 0.0:
		romper(dir * impulso)
		return
	if not anclado or impulso / mass >= umbral:
		despertar()
		apply_impulse(dir * impulso, punto - global_position)


# Una onda expansiva: "dv" es el cambio de velocidad en m/s que le da.
func onda_expansiva(dir: Vector3, dv: float, dano: float) -> void:
	if roto:
		return
	vida -= dano
	if dano > 20.0:
		_romper_lampara()
	if vida <= 0.0:
		romper(dir * dv * mass)
		return
	if not anclado or dv >= umbral:
		despertar()
		var giro: Vector3 = Vector3(randf_range(-0.3, 0.3), alto * randf_range(0.3, 0.8), randf_range(-0.3, 0.3))
		apply_impulse(dir * dv * mass, giro)


# Un vehículo le da a "vel" (m/s). Devuelve qué parte de su velocidad pierde el coche
# (1 = se para en seco, como contra un bolardo).
func golpe_vehiculo(vel: Vector3, masa_veh: float, vehiculo: Node = null) -> float:
	if roto:
		return 0.0
	var rapidez: float = vel.length()
	if rapidez < 2.0:
		return 0.0
	var ahora: int = Time.get_ticks_msec()
	if ahora - _ms_golpe_coche < 400:
		return 0.0
	_ms_golpe_coche = ahora
	var punto: Vector3 = global_position + Vector3.UP * minf(alto * 0.5, 0.7)
	FisicaEscenario.particulas(self, punto, -vel.normalized() + Vector3.UP * 0.5, material_fisico, 1.0)
	_sonar(rapidez)
	if vehiculo != null and vehiculo.has_method("recibir_dano") and mass > 50.0:
		vehiculo.recibir_dano(rapidez * mass / 500.0)
	# Bolardos y similares: si vienes despacio, te paras.
	if resistencia > 0.0 and rapidez < resistencia:
		vida -= rapidez * 3.0
		return 1.0
	var dano: float = rapidez * rapidez * 0.3 * clampf(masa_veh / 1200.0, 0.3, 4.0)
	_romper_lampara()
	vida -= dano
	var empuje: Vector3 = vel * minf(mass, masa_veh) * 1.15 + Vector3.UP * mass * rapidez * 0.22
	if vida <= 0.0:
		romper(empuje)
	else:
		despertar()
		# Se empuja un poco por arriba del centro: las cosas altas vuelcan en vez de deslizar.
		apply_impulse(empuje, Vector3.UP * alto * 0.25)
	return clampf(mass / (mass + masa_veh), 0.0, 0.6)


# El jugador anda contra él: lo arrastra (más despacio cuanto más pesa).
func empujar_andando(vel: Vector3, delta: float) -> void:
	if roto or anclado:
		return
	var h: Vector3 = Vector3(vel.x, 0.0, vel.z)
	var rapidez: float = h.length()
	if rapidez < 0.5:
		return
	var dir: Vector3 = h / rapidez
	var actual: float = linear_velocity.dot(dir)
	var objetivo: float = rapidez * clampf(45.0 / mass, 0.08, 1.1)
	if actual >= objetivo:
		return
	despertar()
	apply_central_impulse(dir * (objetivo - actual) * mass * minf(1.0, delta * 12.0))


# ----------------------------------------------------------- romperse --------

func romper(empuje: Vector3 = Vector3.ZERO) -> void:
	if roto:
		return
	roto = true
	var xf: Transform3D = global_transform
	var padre: Node = get_parent()
	FisicaEscenario.estallar(self, piezas, xf, linear_velocity, empuje / maxf(mass, 1.0), material_fisico)
	if _luz != null:
		_apagar_luz()
	if agua and padre is Node3D:
		FisicaEscenario.chorro(padre as Node3D, xf.origin + Vector3.UP * 0.3)
	if explosivo and padre is Node3D:
		# Diferido (lo hace GestorFisica en el siguiente fotograma de física): así una cadena
		# de bidones no se llama a sí misma dentro del mismo bucle de la onda expansiva.
		FisicaEscenario.pendientes.append([padre, xf.origin + Vector3.UP * 0.5])
	collision_layer = 0
	collision_mask = 0
	queue_free()


func _romper_lampara() -> void:
	if _lampara == null or not is_instance_valid(_lampara):
		return
	var pos: Vector3 = _lampara.global_position
	_lampara.queue_free()
	_lampara = null
	FisicaEscenario.particulas(self, pos, Vector3.DOWN, "cristal", 1.0)
	FisicaEscenario.particulas(self, pos, Vector3.DOWN, "chispas", 0.6)
	_apagar_luz()


func _apagar_luz() -> void:
	if _luz == null or not is_instance_valid(_luz):
		_luz = null
		return
	var l: OmniLight3D = _luz
	_luz = null
	l.remove_from_group("luces_noche")
	l.remove_from_group("luces_lod")
	# Parpadea un momento y se apaga.
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.2, 0.06)
	tw.tween_property(l, "light_energy", 1.4, 0.05)
	tw.tween_property(l, "light_energy", 0.0, 0.12)
	tw.tween_callback(l.queue_free)
