# vehiculo.gd
# -----------------------------------------------------------------------------
# Coches, furgonetas, camiones, tractores, remolques y aparatos de aire.
#
# VEHÍCULOS DE SUELO (rediseño de noviembre de 2026): física real con FisicaCoche
# (RigidBody3D con suspensión por rueda, neumáticos que agarran o patinan, motor,
# marchas, frenos y freno de mano). Al chocar se abollan de verdad (Deformacion),
# saltan chispas y cristales, el motor pierde potencia y echa humo, y al final
# revientan. Luces de freno, marcha atrás, intermitentes y faros (EfectosVehiculo),
# humo y marcas de neumático (MarcasFrenada) y sonido de motor (SonidoMotor).
# Si chocas contra un coche del tráfico, ese coche pasa a tener física también.
#
# REMOLQUES: los arrastra un vehículo con un enganche que pivota (el remolque se
# cierra en las curvas como uno de verdad). AIRE: helicóptero y avioneta con el
# control de siempre.
#
#   E junto al vehículo   subir (si no es tuyo, es un ROBO: sube la sospecha)
#   W/S  acelerar / frenar y marcha atrás     A/D  girar
#   Espacio  freno de mano (derrapes)          Q  claxon
#   R  enderezar el coche si ha volcado        H  enganchar / soltar remolque
#   E dentro  bajar        V  cambiar de cámara
#   Bidón de gasolina en la mano + E   echar gasolina (+40 %)
#   Kit de reparación en la mano + E   reparar (también quita las abolladuras)
#
# El estado de los vehículos que son tuyos vive en Juego.vehiculos (se guarda).
# -----------------------------------------------------------------------------
class_name Vehiculo
extends Interactuable

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const CARPETA: String = "kenney/car-kit/"
# Giro extra del modelo (radianes) por si el frente no coincide con -Z.
const GIRO_MODELO: float = 0.0

# cat = categoría en el concesionario (por defecto según la clase); clase: "suelo", "remolque" o "aire".
# largo (m), vmax (m/s), acel (m/s²), giro (rad: ángulo máximo de las ruedas; en el aire, rad/s),
# precio, gasto (relativo), color si falta el modelo.
# (Velocidades nuevas: antes el sedán no pasaba de 79 km/h y el deportivo de 122.)
const TIPOS: Dictionary = {
	"hatchback": {"nombre": "Utilitario deportivo", "modelo": "hatchback-sports", "largo": 3.9, "vmax": 44.0,
			"acel": 8.5, "giro": 0.62, "precio": 2400, "gasto": 1.0, "color": Color(0.8, 0.2, 0.15)},
	"sedan": {"nombre": "Sedán", "modelo": "sedan", "largo": 4.4, "vmax": 46.0, "acel": 8.0, "giro": 0.58,
			"precio": 3000, "gasto": 1.0, "color": Color(0.2, 0.3, 0.5)},
	"taxi": {"nombre": "Taxi", "modelo": "taxi", "largo": 4.4, "vmax": 43.0, "acel": 7.5, "giro": 0.58,
			"precio": 3200, "gasto": 1.0, "color": Color(0.9, 0.75, 0.15)},
	"suv": {"nombre": "Todoterreno", "modelo": "suv", "largo": 4.6, "vmax": 42.0, "acel": 7.0, "giro": 0.56,
			"precio": 5200, "gasto": 1.3, "color": Color(0.25, 0.3, 0.25)},
	"furgoneta": {"nombre": "Furgoneta", "modelo": "van", "largo": 4.8, "vmax": 36.0, "acel": 5.5, "giro": 0.56,
			"precio": 4200, "gasto": 1.2, "color": Color(0.85, 0.85, 0.85), "cat": "Camiones"},
	"camion": {"nombre": "Camión", "modelo": "truck", "largo": 6.4, "vmax": 28.0, "acel": 3.8, "giro": 0.5,
			"precio": 7500, "gasto": 2.0, "color": Color(0.6, 0.3, 0.1), "cat": "Camiones"},
	"tractor": {"nombre": "Tractor", "modelo": "tractor", "largo": 3.6, "vmax": 12.0, "acel": 3.5, "giro": 0.62,
			"precio": 6000, "gasto": 0.8, "color": Color(0.2, 0.5, 0.2), "cat": "Maquinaria"},
	"excavadora": {"nombre": "Excavadora", "modelo": "tractor-shovel", "largo": 4.6, "vmax": 9.0, "acel": 2.8,
			"giro": 0.6, "precio": 9000, "gasto": 1.0, "color": Color(0.9, 0.6, 0.1), "cat": "Maquinaria"},
	"trailer": {"nombre": "Cabeza tractora (tráiler)", "modelo": "truck", "largo": 5.6, "vmax": 31.0, "acel": 4.2,
			"giro": 0.52, "precio": 12000, "gasto": 2.2, "color": Color(0.7, 0.1, 0.1), "cat": "Camiones"},
	"remolque_carga": {"nombre": "Remolque de carga", "modelo": "delivery-flat", "largo": 4.5, "precio": 1800,
			"clase": "remolque", "color": Color(0.5, 0.5, 0.55), "cat": "Remolques"},
	"remolque_grande": {"nombre": "Semirremolque (tráiler)", "modelo": "truck-flat", "largo": 9.0, "precio": 5500,
			"clase": "remolque", "color": Color(0.35, 0.35, 0.4), "cat": "Remolques"},
	"portacoches": {"nombre": "Portacoches", "modelo": "truck-flat", "largo": 10.5, "precio": 8500,
			"clase": "remolque", "color": Color(0.2, 0.3, 0.45), "cat": "Remolques"},
	"helicoptero": {"nombre": "Helicóptero", "modelo": "", "largo": 7.0, "vmax": 45.0, "acel": 10.0, "giro": 1.2,
			"precio": 90000, "gasto": 3.0, "clase": "aire", "modo": "helicoptero", "color": Color(0.15, 0.2, 0.3),
			"cat": "Aire"},
	"avion": {"nombre": "Avioneta", "modelo": "", "largo": 8.0, "vmax": 60.0, "acel": 9.0, "giro": 0.9,
			"precio": 150000, "gasto": 3.0, "clase": "aire", "modo": "avion", "color": Color(0.85, 0.85, 0.9),
			"cat": "Aire"},
	"deportivo": {"nombre": "Deportivo de carreras", "modelo": "race", "largo": 4.2, "vmax": 66.0, "acel": 11.0,
			"giro": 0.6, "precio": 12000, "gasto": 1.8, "color": Color(0.1, 0.1, 0.6)},
}
# Remolques que van ENCIMA de la cabeza tractora (quinta rueda), no detrás con lanza.
const SEMIRREMOLQUES: Array = ["remolque_grande", "portacoches"]

var tipo: String = "sedan"
var id: String = ""            # Vacío = no es tuyo todavía. "amb_..." aparcado, "mio_N" comprado.
var temporal: bool = false     # Coche del tráfico que pasó a tener física tras un choque: se borra al alejarte.
var gasolina: float = 100.0
var salud: float = 100.0:
	set = _poner_salud
var conductor: Node3D = null
var remolque = null            # Remolque enganchado (otro Vehiculo) o null.
var tractor = null             # Si esto es un remolque enganchado: quién lo arrastra.
var destruido: bool = false     # Reventado por una explosión: quemado, sin motor, con fuego.
var _vy: float = 0.0
var _rotor: Node3D = null
var _modelo_aire: Node3D = null
# Ruedas y hélices del modelo nuevo (ModeloVehiculo).
var _giros: Array = []         # Nodos que ruedan (rotación en X).
var _radios: Array = []        # Radio de cada rueda (m).
var _pivotes: Array = []       # Ruedas delanteras: viran (rotación en Y).
var _rotores: Array = []       # [{"nodo": Node3D, "eje": Vector3}]
var _ruedas: Array = []        # [{pivote, giro, radio, del}] (para FisicaCoche)
var _viraje: float = 0.0       # Ángulo actual de las ruedas delanteras.
var _carroceria: Node3D = null # Lo que se abolla.

var chasis: PhysicsBody3D      # FisicaCoche (suelo) o CharacterBody3D (aire y remolques).
var fisica: FisicaCoche = null
var efectos: EfectosVehiculo = null
var sonido: SonidoMotor = null
var _ancho: float = 2.0
var _alto: float = 1.6
var _largo: float = 4.0
var _v: float = 0.0
var _t_guardado: float = 0.0
var _t_golpe: float = 0.0
var _t_sondeo: float = 0.0
var _ultimo_suelo: Vector3 = Vector3.ZERO
var _excepciones: Dictionary = {}   # Personas cercanas que el chasis atraviesa (las atropella a mano).
var _atropellados: Dictionary = {}  # instancia -> segundos hasta poder volver a golpearla
var sacudida: float = 0.0           # La lee la cámara del jugador (temblor tras un golpe).
var _t_fuego: float = -1.0          # Cuenta atrás para reventar cuando arde.


func _ready() -> void:
	ignora_vista = true
	add_to_group("vehiculos")
	add_to_group("danable")   # Las explosiones le hacen daño (ver recibir_dano).
	var d: Dictionary = TIPOS[tipo]
	_largo = d["largo"]
	var con_fisica: bool = clase() == "suelo" and FisicaCoche.PERFILES.has(tipo)
	if con_fisica:
		fisica = FisicaCoche.new()
		fisica.tipo = tipo
		fisica.vmax = float(d["vmax"])
		fisica.acel = float(d["acel"])
		fisica.giro_max = float(d["giro"])
		chasis = fisica
	else:
		var cb: CharacterBody3D = CharacterBody3D.new()
		cb.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		chasis = cb
	add_child(chasis)
	var modelo: Node3D = _crear_modelo(d)
	chasis.add_child(modelo)
	if fisica != null and _ruedas.size() >= 2:
		_formas_fisicas()
		fisica.preparar(_ruedas, _largo)
		fisica.golpe.connect(_al_golpear)
	else:
		if fisica != null:
			# Sin modelo con ruedas (falta el GLB): se queda con la física, con ruedas virtuales.
			_ruedas_virtuales()
			_formas_fisicas()
			fisica.preparar(_ruedas, _largo)
			fisica.golpe.connect(_al_golpear)
		else:
			var forma: BoxShape3D = BoxShape3D.new()
			forma.size = Vector3(_ancho, 1.2, _largo)
			var choque: CollisionShape3D = CollisionShape3D.new()
			choque.shape = forma
			choque.position.y = 0.7
			chasis.add_child(choque)
	if clase() != "remolque":
		efectos = EfectosVehiculo.new()
		efectos.con_luz_real = true
		chasis.add_child(efectos)
		var pos_ruedas: Array = []
		for r in _ruedas:
			pos_ruedas.append((r["pivote"] as Node3D).position)
		efectos.montar(_caja_carroceria(), pos_ruedas, tipo)
	distancia = _largo / 2.0 + 1.6
	# El chasis se mueve solo por el mundo (física); este nodo lo sigue. Se suelta al final del
	# fotograma para que el gestor ya lo haya colocado en su sitio.
	_soltar_chasis.call_deferred()


func _soltar_chasis() -> void:
	if not is_instance_valid(chasis):
		return
	chasis.top_level = true
	if fisica != null:
		fisica.sleeping = false


# Formas de choque para la física: la parte baja de la carrocería (por encima de las ruedas, que
# son rayos) y la cabina, algo más estrecha. Antes era una caja de 1,2 m que tocaba el suelo.
func _formas_fisicas() -> void:
	var radio: float = 0.35
	for r in _ruedas:
		radio = minf(radio, float(r["radio"]))
	var caja: AABB = _caja_carroceria()
	var bajo: float = clampf(radio * 0.8, 0.18, 0.45)
	var alto_bajo: float = maxf(0.4, caja.size.y * 0.55 - bajo)
	var f1: BoxShape3D = BoxShape3D.new()
	f1.size = Vector3(caja.size.x * 0.94, alto_bajo, caja.size.z * 0.97)
	var c1: CollisionShape3D = CollisionShape3D.new()
	c1.shape = f1
	c1.position = Vector3(caja.get_center().x, bajo + alto_bajo / 2.0, caja.get_center().z)
	chasis.add_child(c1)
	var alto_cab: float = caja.size.y * 0.42
	if alto_cab > 0.3:
		var f2: BoxShape3D = BoxShape3D.new()
		f2.size = Vector3(caja.size.x * 0.82, alto_cab, caja.size.z * 0.6)
		var c2: CollisionShape3D = CollisionShape3D.new()
		c2.shape = f2
		c2.position = Vector3(caja.get_center().x, bajo + alto_bajo + alto_cab / 2.0, caja.get_center().z + caja.size.z * 0.06)
		chasis.add_child(c2)


func _ruedas_virtuales() -> void:
	_ruedas.clear()
	var lat: float = _ancho * 0.4
	for z in [-_largo * 0.32, _largo * 0.32]:
		for lado in [-1.0, 1.0]:
			var piv: Node3D = Node3D.new()
			piv.position = Vector3(lado * lat, 0.35, z)
			var g: Node3D = Node3D.new()
			piv.add_child(g)
			chasis.add_child(piv)
			_ruedas.append({"pivote": piv, "giro": g, "radio": 0.35, "del": z < 0.0})


# Caja de la carrocería en coordenadas del chasis (para luces y formas de choque).
func _caja_carroceria() -> AABB:
	var raiz: Node3D = _carroceria
	if raiz == null:
		return AABB(Vector3(-_ancho / 2.0, 0.0, -_largo / 2.0), Vector3(_ancho, _alto, _largo))
	var total: AABB = AABB()
	var primero: bool = true
	var inv: Transform3D = Transform3D.IDENTITY
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var t: Transform3D = _transform_relativo(mi)
		var a: AABB = t * mi.get_aabb()
		total = a if primero else total.merge(a)
		primero = false
	if primero:
		return AABB(Vector3(-_ancho / 2.0, 0.0, -_largo / 2.0), Vector3(_ancho, _alto, _largo))
	return inv * total


# Transformación de un nodo respecto al chasis (sin depender de que ya esté en el árbol).
func _transform_relativo(n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var actual: Node = n
	while actual != null and actual != chasis:
		if actual is Node3D:
			t = (actual as Node3D).transform * t
		actual = actual.get_parent()
	return t


# El modelo del coche, escalado al largo del tipo, centrado y con las ruedas en el suelo.
# Si no está el modelo, una caja de color.
func _crear_modelo(d: Dictionary) -> Node3D:
	var raiz: Node3D = Node3D.new()
	var nuevo: Dictionary = ModeloVehiculo.crear(tipo, float(d["largo"]), d.get("clase", "suelo") == "suelo")
	if not nuevo.is_empty():
		_giros = nuevo["giros"]
		_radios = nuevo["radios"]
		_pivotes = nuevo["pivotes"]
		_rotores = nuevo["rotores"]
		_ruedas = nuevo.get("ruedas", [])
		_carroceria = nuevo.get("escala", null)
		_alto = float(nuevo.get("alto", 1.6))
		if d.get("clase", "suelo") == "aire":
			_ancho = 3.0
			_modelo_aire = nuevo["nodo"]
		else:
			_ancho = clampf(float(nuevo["ancho"]), 1.4, 3.2)
		raiz.add_child(nuevo["nodo"])
		return raiz
	if d.get("clase", "suelo") == "aire":
		_ancho = 3.0
		_modelo_aire = Node3D.new()
		raiz.add_child(_modelo_aire)
		if d["modo"] == "helicoptero":
			_helicoptero(_modelo_aire, d["color"])
		else:
			_avioneta(_modelo_aire, d["color"])
		return raiz
	var m: Node3D = Assets.modelo(CARPETA + str(d["modelo"])) if str(d["modelo"]) != "" else null
	if m != null:
		var caja: AABB = Assets.caja_de(m)
		var largo_x: bool = caja.size.x > caja.size.z
		var esc: float = _largo / maxf(0.01, maxf(caja.size.x, caja.size.z))
		_ancho = (caja.size.z if largo_x else caja.size.x) * esc
		_alto = caja.size.y * esc
		m.position = Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z)
		var envoltorio: Node3D = Node3D.new()
		envoltorio.scale = Vector3.ONE * esc
		envoltorio.rotation.y = (PI / 2.0 if largo_x else PI) + GIRO_MODELO
		envoltorio.add_child(m)
		raiz.add_child(envoltorio)
		_carroceria = envoltorio
	else:
		_ancho = 1.9
		_alto = 1.5
		Construir.caja(raiz, Vector3(0, 0.6, 0), Vector3(_ancho, 0.8, _largo), d["color"], false)
		Construir.caja(raiz, Vector3(0, 1.2, 0.3), Vector3(_ancho - 0.2, 0.6, _largo * 0.5), d["color"].darkened(0.3), false)
		_carroceria = raiz
	_ancho = clampf(_ancho, 1.4, 3.2)
	return raiz


# Helicóptero y avioneta hechos con cajas (si faltan los modelos).
func _helicoptero(raiz: Node3D, color: Color) -> void:
	Construir.caja(raiz, Vector3(0, 1.3, 0), Vector3(2.0, 1.7, 3.8), color, false)
	Construir.caja(raiz, Vector3(0, 1.55, -1.6), Vector3(1.8, 1.0, 0.9), Color(0.5, 0.75, 0.9), false)
	Construir.caja(raiz, Vector3(0, 1.6, 3.2), Vector3(0.4, 0.5, 3.4), color, false)
	Construir.caja(raiz, Vector3(0, 2.2, 4.8), Vector3(0.1, 1.3, 0.8), color.lightened(0.15), false)
	for lado in [-0.9, 0.9]:
		Construir.caja(raiz, Vector3(lado, 0.2, 0), Vector3(0.12, 0.12, 3.6), Color(0.1, 0.1, 0.1), false)
		Construir.caja(raiz, Vector3(lado, 0.55, -0.9), Vector3(0.1, 0.7, 0.1), Color(0.1, 0.1, 0.1), false)
		Construir.caja(raiz, Vector3(lado, 0.55, 0.9), Vector3(0.1, 0.7, 0.1), Color(0.1, 0.1, 0.1), false)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 2.3, 0)
	raiz.add_child(_rotor)
	Construir.caja(_rotor, Vector3.ZERO, Vector3(9.0, 0.05, 0.35), Color(0.08, 0.08, 0.08), false)
	Construir.caja(_rotor, Vector3.ZERO, Vector3(0.35, 0.05, 9.0), Color(0.08, 0.08, 0.08), false)


func _avioneta(raiz: Node3D, color: Color) -> void:
	Construir.caja(raiz, Vector3(0, 1.1, 0), Vector3(1.3, 1.3, 7.0), color, false)
	Construir.caja(raiz, Vector3(0, 1.45, -1.2), Vector3(1.1, 0.6, 1.4), Color(0.5, 0.75, 0.9), false)
	Construir.caja(raiz, Vector3(0, 1.0, -0.4), Vector3(10.0, 0.15, 1.8), color.darkened(0.15), false)
	Construir.caja(raiz, Vector3(0, 1.1, 3.4), Vector3(3.6, 0.12, 1.0), color.darkened(0.15), false)
	Construir.caja(raiz, Vector3(0, 1.8, 3.4), Vector3(0.12, 1.4, 1.1), color.lightened(0.1), false)
	for lado in [-0.9, 0.9]:
		Construir.cilindro(raiz, Vector3(lado, 0.35, -0.6), 0.28, 0.14, Color(0.08, 0.08, 0.08), false)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.1, -3.6)
	raiz.add_child(_rotor)
	Construir.caja(_rotor, Vector3.ZERO, Vector3(0.12, 2.6, 0.2), Color(0.08, 0.08, 0.08), false)


func clase() -> String:
	return str(TIPOS[tipo].get("clase", "suelo"))


# Hace rodar las ruedas según la velocidad (m/s) y vira las delanteras. Para los vehículos sin
# FisicaCoche (aire, remolques); los de suelo las mueve su física.
func girar_ruedas(v: float, delta: float, direccion: float = 0.0) -> void:
	for i in _giros.size():
		(_giros[i] as Node3D).rotation.x -= v * delta / maxf(0.05, float(_radios[i]))
	if _pivotes.is_empty():
		return
	var objetivo: float = direccion * 0.5 if absf(v) > 0.3 else 0.0
	_viraje = lerpf(_viraje, objetivo, clampf(delta * 10.0, 0.0, 1.0))
	for p in _pivotes:
		(p as Node3D).rotation.y = _viraje


func _poner_salud(valor: float) -> void:
	var antes: float = salud
	salud = valor
	# Reparado (taller o kit): fuera abolladuras, quemado y humo.
	if valor >= 99.0 and antes < 99.0 and is_inside_tree():
		Deformacion.restaurar(_carroceria)
		destruido = false
		_t_fuego = -1.0
		if fisica != null:
			fisica.factor_motor = 1.0
			fisica.tiron = 0.0


# ------------------------------- Interacción ---------------------------------

func texto_accion() -> String:
	var mano: String = Juego.id_en_mano()
	if conductor != null:
		return "Bajar del vehículo"
	if mano == "bidon_gasolina":
		return "Echar gasolina (%d %%)" % int(gasolina)
	if mano == "kit_reparacion":
		return "Reparar (estado %d %%)" % int(salud)
	var nombre: String = str(TIPOS[tipo]["nombre"])
	if clase() == "remolque":
		return "%s (conduce un vehículo cerca y pulsa H para engancharlo)" % nombre
	if destruido:
		return "%s (destrozado: llévalo al taller o usa un kit de reparación)" % nombre
	if _es_mio():
		return "Conducir: %s  (gasolina %d %%, estado %d %%)" % [nombre, int(gasolina), int(salud)]
	return "ROBAR: %s (la policía te buscará)" % nombre


func _es_mio() -> bool:
	# Un coche aparcado ("amb_N") solo es tuyo si lo robaste (plazas_tomadas). Antes bastaba que
	# estuviera en Juego.vehiculos, y guardar la partida metía ahí TODOS los coches aparcados:
	# tras guardar, los 7 eran tuyos (sin robo ni sospecha) y se podían vender.
	if id.begins_with("amb_"):
		return Juego.plazas_tomadas.has(id)
	return id.begins_with("mio_") or (id != "" and Juego.vehiculos.has(id))


func usar(jugador: Node) -> void:
	if conductor != null:
		bajar()
		return
	var mano: String = Juego.id_en_mano()
	if mano == "bidon_gasolina":
		if gasolina >= 99.0:
			Juego.avisar("El depósito ya está lleno.")
			return
		Juego.quitar(mano, 1)
		gasolina = minf(100.0, gasolina + 40.0)
		Juego.avisar("Depósito al %d %%." % int(gasolina))
		return
	if mano == "kit_reparacion":
		if salud >= 99.0:
			Juego.avisar("No necesita reparación.")
			return
		Juego.quitar(mano, 1)
		salud = 100.0
		Juego.avisar("Vehículo reparado.")
		return
	if clase() == "remolque":
		Juego.avisar("Se engancha desde un vehículo: conduce uno hasta aquí y pulsa H.")
		return
	if not _es_mio():
		_robar()
	subir(jugador)


func _robar() -> void:
	Juego.sospecha = minf(100.0, Juego.sospecha + 30.0)
	Juego.delito_visto = 8.0
	Juego.avisar("¡Robas un vehículo! La policía empieza a sospechar.")
	if id == "":
		id = "robado_%d" % Juego.siguiente_vehiculo()
		temporal = false
	elif id.begins_with("amb_"):
		# Si luego lo vendes o lo aportas al negocio, su plaza no se repone sola: antes el
		# coche reaparecía, se robaba otra vez y se volvía a vender (dinero infinito).
		Juego.plazas_tomadas[id] = true
	guardar_estado()


func subir(jugador: Node) -> void:
	if conductor != null or not jugador.has_method("subir_a"):
		return
	conductor = jugador as Node3D
	_ultimo_suelo = global_position
	jugador.subir_a(self)
	set_physics_process(true)
	if fisica != null:
		fisica.conducido = true
		fisica.freeze = false
		fisica.sleeping = false
		if conductor is CollisionObject3D:
			fisica.excluir((conductor as CollisionObject3D).get_rid())
			fisica.add_collision_exception_with(conductor)
	if sonido == null and clase() != "remolque":
		sonido = SonidoMotor.new()
		var p: Dictionary = FisicaCoche.PERFILES.get(tipo, {})
		sonido.cilindros = 6.0 if tipo == "deportivo" else 4.0
		sonido.grave = 1.0 if float(p.get("rpm_max", 6000.0)) > 4000.0 else 0.55
		if clase() == "aire":
			sonido.grave = 0.7
		chasis.add_child(sonido)


func bajar() -> void:
	if conductor == null:
		return
	if clase() == "aire" and not (chasis as CharacterBody3D).is_on_floor():
		Juego.avisar("No puedes bajar en pleno vuelo. Aterriza primero.")
		return
	var j: Node3D = conductor
	conductor = null
	_v = 0.0
	if fisica != null:
		fisica.conducido = false
		fisica.entrada = 0.0
		fisica.freno_mano = true
		if j is CollisionObject3D:
			fisica.remove_collision_exception_with(j)
	else:
		(chasis as CharacterBody3D).velocity = Vector3.ZERO
	if sonido != null:
		sonido.queue_free()
		sonido = null
	var destino: Vector3 = _sitio_para_bajar()
	if j.has_method("bajar_de"):
		j.bajar_de(self, destino)
	guardar_estado()


# Dónde te bajas: primero a la izquierda y, si ahí hay una pared u otra cosa, a la
# derecha, detrás o delante (cada vez más lejos). Antes siempre era a la izquierda y
# en una calle de 8 m, junto a una fachada, aparecías dentro del muro.
func _sitio_para_bajar() -> Vector3:
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 1.7
	var consulta: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	consulta.shape = capsula
	consulta.exclude = [chasis.get_rid()]
	if conductor is CollisionObject3D:
		consulta.exclude.append((conductor as CollisionObject3D).get_rid())
	var b: Basis = chasis.global_transform.basis
	var dirs: Array = [-b.x, b.x, b.z, -b.z]
	var medios: Array = [_ancho / 2.0, _ancho / 2.0, _largo / 2.0, _largo / 2.0]
	for margen in [0.9, 1.6, 2.6]:
		for i in 4:
			var p: Vector3 = chasis.global_position + (dirs[i] as Vector3) * (float(medios[i]) + margen)
			p.y = chasis.global_position.y + 0.3
			consulta.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
			if espacio.intersect_shape(consulta, 1).is_empty():
				return p
	return chasis.global_position + Vector3(0, 2.5, 0)


# Lo que te pagan por un vehículo usado: 60 % del precio, menos según lo dañado que esté.
static func valor_venta(tipo_v: String, salud_v: float) -> int:
	return int(float(TIPOS[tipo_v]["precio"]) * 0.6 * (0.4 + 0.6 * clampf(salud_v, 0.0, 100.0) / 100.0))


# Guarda posición y estado en Juego.vehiculos (solo si es tuyo).
func guardar_estado() -> void:
	if id == "" or (id.begins_with("amb_") and not Juego.plazas_tomadas.has(id)):
		return   # Un coche aparcado sin robar no es de nadie: no se guarda.
	var p: Vector3 = chasis.global_position
	var adelante: Vector3 = -chasis.global_transform.basis.z
	var giro: float = atan2(-adelante.x, -adelante.z)
	Juego.vehiculos[id] = {"tipo": tipo, "pos": [p.x, p.y + 0.1, p.z], "giro": giro,
			"gas": gasolina, "salud": salud}


# Velocidad hacia delante (m/s), para el HUD, la policía y el tráfico.
func velocidad_actual() -> float:
	if fisica != null:
		return fisica.velocidad
	return _v


# Hacia dónde mira el vehículo (para que la cámara se ponga detrás al conducir).
func rumbo_camara() -> float:
	var adelante: Vector3 = -chasis.global_transform.basis.z
	if fisica != null and fisica.velocidad < -2.0:
		adelante = -adelante   # Marcha atrás: la cámara mira hacia atrás.
	return atan2(-adelante.x, -adelante.z)


# ------------------------------- Conducción ----------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if conductor == null:
		return
	if evento.is_action_pressed("enganchar"):
		_enganchar()
	elif evento.is_action_pressed("recargar") and fisica != null:
		if fisica.global_transform.basis.y.y < 0.6 and fisica.linear_velocity.length() < 4.0:
			fisica.enderezar()


# H: engancha el remolque más cercano (a menos de 9 m) o suelta el que llevas.
func _enganchar() -> void:
	if remolque != null:
		if fisica != null and is_instance_valid(remolque):
			fisica.remove_collision_exception_with(remolque.chasis)
		remolque.tractor = null
		remolque.guardar_estado()
		remolque = null
		Juego.avisar("Remolque soltado.")
		return
	if clase() != "suelo":
		return
	var mejor = null
	var d_mejor: float = 9.0
	for nodo in get_tree().get_nodes_in_group("vehiculos"):
		if nodo != self and nodo.has_method("clase") and nodo.clase() == "remolque" and nodo.tractor == null:
			var dist: float = nodo.global_position.distance_to(global_position)
			if dist < d_mejor:
				d_mejor = dist
				mejor = nodo
	if mejor == null:
		Juego.avisar("No hay ningún remolque cerca (a menos de 9 m).")
		return
	remolque = mejor
	mejor.tractor = self
	if mejor.get_parent() != get_parent():
		mejor.reparent(get_parent())
	if fisica != null:
		fisica.add_collision_exception_with(mejor.chasis)
		fisica.excluir(mejor.chasis.get_rid())
	Juego.avisar("Remolque enganchado: %s." % TIPOS[mejor.tipo]["nombre"])


# El remolque cuelga de un enganche que pivota. Su eje trasero "arrastra" (como un remolque de
# verdad), así que en las curvas se cierra hacia dentro y no copia el giro de golpe. Los
# semirremolques se apoyan encima de la cabeza tractora (quinta rueda).
func _arrastrar(delta: float) -> void:
	var r = remolque
	if not is_instance_valid(r):
		remolque = null
		return
	var b: Basis = chasis.global_transform.basis
	var atras: Vector3 = b.z
	var semi: bool = SEMIRREMOLQUES.has(r.tipo) and tipo == "trailer"
	var enganche: Vector3 = chasis.global_position + atras * (_largo * 0.22 if semi else _largo / 2.0 + 0.35)
	enganche += b.y * (1.1 if semi else 0.5)
	var largo_r: float = float(r._largo)
	var pivote_r: float = largo_r / 2.0 - (1.4 if semi else -0.7)   # Del centro del remolque al enganche.
	var rc: CharacterBody3D = r.chasis as CharacterBody3D
	var adelante_r: Vector3 = -rc.global_transform.basis.z
	var eje: Vector3 = rc.global_position - adelante_r * largo_r * 0.22   # Eje trasero aproximado.
	var hacia: Vector3 = enganche - eje
	hacia.y = 0.0
	if hacia.length() > 0.2:
		adelante_r = hacia.normalized()
	var centro: Vector3 = enganche - adelante_r * pivote_r
	centro.y = chasis.global_position.y
	var yaw: float = atan2(-adelante_r.x, -adelante_r.z)
	r.global_position = centro
	rc.global_transform = Transform3D(Basis(Vector3.UP, yaw), centro)
	r.girar_ruedas(velocidad_actual(), delta)


func _physics_process(delta: float) -> void:
	if fisica != null:
		_fisica_suelo(delta)
		return
	if conductor == null:
		return
	_conducir_aire_o_arcade(delta)


func _fisica_suelo(delta: float) -> void:
	if not chasis.top_level:
		return
	# El nodo sigue al chasis (la "E" se mide desde aquí).
	global_position = fisica.global_position
	_t_golpe = maxf(0.0, _t_golpe - delta)
	sacudida = maxf(0.0, sacudida - delta * 2.5)
	for k in _atropellados.keys():
		_atropellados[k] = float(_atropellados[k]) - delta
		if float(_atropellados[k]) <= 0.0:
			_atropellados.erase(k)
	_arder(delta)
	var noche: bool = Juego.es_de_noche()
	if conductor == null:
		if efectos != null and not fisica.sleeping:
			efectos.actualizar(delta, false, false, false, [], salud)
		if temporal:
			_vigilar_temporal()
		return
	var d: Dictionary = TIPOS[tipo]
	var entrada: float = 0.0
	var direccion: float = 0.0
	var mano: bool = false
	var bocina: bool = false
	if not Juego.menu_abierto:
		entrada = Input.get_axis("atras", "adelante")
		direccion = Input.get_axis("derecha", "izquierda")
		mano = Input.is_action_pressed("saltar")
		bocina = Input.is_physical_key_pressed(KEY_Q)
	fisica.entrada = entrada
	fisica.direccion = direccion
	fisica.freno_mano = mano
	fisica.sin_gasolina = gasolina <= 0.0 or destruido
	if salud < 50.0:
		fisica.factor_motor = clampf(0.35 + salud / 50.0 * 0.65, 0.35, 1.0)
	if destruido:
		fisica.factor_motor = 0.0
	var rapidez: float = fisica.linear_velocity.length()
	gasolina = maxf(0.0, gasolina - (0.02 + 0.25 * fisica.acelerador * clampf(rapidez / float(d["vmax"]), 0.2, 1.0)) \
			* float(d["gasto"]) * delta)
	conductor.global_position = fisica.global_position + fisica.global_transform.basis.y * 0.9
	if efectos != null:
		var deslices: Array = []
		for r in fisica.ruedas:
			deslices.append(float(r["desliz"]))
		efectos.actualizar(delta, fisica.frenando or (mano and rapidez > 1.0), fisica.marcha == 0 and fisica.acelerador > 0.0,
				noche, deslices, salud)
	_marcas()
	if sonido != null:
		sonido.rpm = fisica.rpm
		sonido.carga = fisica.acelerador
		sonido.chirrido = clampf((fisica.deslizamiento - 3.0) / 10.0, 0.0, 1.0)
		sonido.claxon = bocina
		sonido.encendido = not destruido and gasolina > 0.0
	_sondear_alrededor(delta)
	if remolque != null:
		_arrastrar(delta)
	_contener_en_el_mundo()
	if fisica.global_position.y < -40.0:
		fisica.global_position = _ultimo_suelo + Vector3(0, 2.0, 0)
		fisica.linear_velocity = Vector3.ZERO
		fisica.angular_velocity = Vector3.ZERO
	elif fisica.ruedas_en_suelo >= 3:
		_ultimo_suelo = fisica.global_position
	_t_guardado -= delta
	if _t_guardado <= 0.0:
		_t_guardado = 3.0
		guardar_estado()
		if remolque != null:
			remolque.guardar_estado()


# Marcas negras en el suelo de las ruedas que patinan.
func _marcas() -> void:
	for i in fisica.ruedas.size():
		var r: Dictionary = fisica.ruedas[i]
		var clave: int = get_instance_id() * 16 + i
		if r["suelo"] and float(r["desliz"]) > 5.0:
			MarcasFrenada.poner(get_tree(), clave, r["punto"], r["normal"], float(r["radio"]) * 0.7,
					float(r["desliz"]))
		else:
			MarcasFrenada.cortar(clave)


# Mira lo que hay justo alrededor del coche cuando vas rápido:
#   - personas: el chasis no choca con ellas como si fueran un muro; se las atropella.
#   - coches del tráfico: pasan a tener física ANTES del golpe, para que el choque sea entre dos
#     coches de verdad (se empujan, giran y se abollan).
func _sondear_alrededor(delta: float) -> void:
	_t_sondeo -= delta
	var rapidez: float = fisica.linear_velocity.length()
	if _t_sondeo > 0.0:
		return
	_t_sondeo = 0.05
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var forma: BoxShape3D = BoxShape3D.new()
	var extra: float = clampf(rapidez * 0.12, 0.3, 3.0)
	forma.size = Vector3(_ancho + 0.6, _alto + 0.4, _largo + extra * 2.0)
	var consulta: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	var adelante: Vector3 = -fisica.global_transform.basis.z
	var centro: Vector3 = fisica.global_position + fisica.global_transform.basis.y * (_alto * 0.5) \
			+ adelante * (extra * 0.5 * signf(fisica.velocidad))
	consulta.transform = Transform3D(fisica.global_transform.basis, centro)
	consulta.exclude = [fisica.get_rid()]
	consulta.collide_with_areas = false
	var vistos: Dictionary = {}
	for res in espacio.intersect_shape(consulta, 16):
		var otro: Object = res["collider"]
		if otro == null or otro == conductor:
			continue
		if otro is RigidBody3D or otro is StaticBody3D:
			continue
		var es_coche_trafico: bool = otro.get("es_coche") == true
		if es_coche_trafico:
			if rapidez > 2.5:
				var vu: Node = get_tree().get_first_node_in_group("vida_urbana")
				if vu != null and vu.has_method("convertir_en_fisico"):
					vu.convertir_en_fisico(otro)
			continue
		if not (otro is Node3D):
			continue
		var persona: Node3D = otro as Node3D
		vistos[persona.get_instance_id()] = true
		if not _excepciones.has(persona.get_instance_id()):
			_excepciones[persona.get_instance_id()] = persona
			fisica.add_collision_exception_with(persona)
		if rapidez > 3.0 and not _atropellados.has(persona.get_instance_id()):
			_atropellar(persona, rapidez)
	# Las personas que ya no están cerca vuelven a chocar con el coche.
	for k in _excepciones.keys():
		if not vistos.has(k):
			var p = _excepciones[k]
			if is_instance_valid(p):
				fisica.remove_collision_exception_with(p)
			_excepciones.erase(k)


# Golpe a una persona: daño según la velocidad y un empujón (meta "impulso") que los personajes
# pueden usar para salir despedidos o caer como un muñeco.
func _atropellar(persona: Node3D, rapidez: float) -> void:
	_atropellados[persona.get_instance_id()] = 1.2
	var v: Vector3 = fisica.linear_velocity
	var impulso: Vector3 = v * 0.85 + Vector3.UP * clampf(rapidez * 0.35, 2.0, 9.0)
	persona.set_meta("impulso", impulso)
	persona.set_meta("atropellado_por", self)
	if persona.has_method("derribar"):
		# Peatones de la calle: salen despedidos (vida_urbana.gd, Agente.derribar).
		var dir3: Vector3 = v
		dir3.y = 0.0
		persona.call("derribar", dir3.normalized() if dir3.length() > 0.1 else Vector3.FORWARD, rapidez, true)
	elif persona.has_method("recibir_dano"):
		persona.call("recibir_dano", rapidez * 4.0)
	elif "velocity" in persona:
		persona.set("velocity", impulso)
	Juego.atropello_visto = 10.0   # Los guardias que lo vean te multarán y te perseguirán.
	Juego.delito_visto = 6.0
	Juego.sospecha = minf(100.0, Juego.sospecha + 10.0)
	# El coche nota el golpe (poco: una persona pesa mucho menos que un coche).
	fisica.apply_central_impulse(-v.normalized() * minf(rapidez, 15.0) * 70.0)
	sacudida = maxf(sacudida, 0.35)
	Sonido.tocar(self, "golpe", -4.0)


# Un choque de verdad (lo detecta FisicaCoche): daño, abolladura, chispas, cristales y sonido.
func _al_golpear(punto: Vector3, normal: Vector3, fuerza: float, otro: Object) -> void:
	if fuerza < 2.5:
		return
	var dano: float = (fuerza - 2.0) * 2.4
	salud = maxf(0.0, salud - dano)
	Deformacion.abollar(_carroceria, punto, normal, fuerza)
	EfectosVehiculo.estallido(self, punto, -normal + Vector3.UP * 0.4, "chispas", fuerza)
	if fuerza > 9.0:
		EfectosVehiculo.estallido(self, punto + Vector3.UP * 0.5, -normal + Vector3.UP * 0.6, "cristal", fuerza)
	Sonido.tocar(self, "golpe", clampf(-14.0 + fuerza * 0.8, -14.0, 2.0))
	if fuerza > 12.0 and fisica != null:
		fisica.tiron = clampf(fisica.tiron + randf_range(-0.6, 0.6), -1.0, 1.0)   # Dirección tocada.
	if otro != null and otro.has_method("recibir_dano") and otro is Vehiculo:
		pass   # El otro coche ya recibe su propio golpe en su física.
	if conductor != null:
		sacudida = maxf(sacudida, clampf(fuerza / 15.0, 0.2, 1.0))
		if fuerza > 6.0:
			Juego.cambiar_vida(-(fuerza - 6.0) * 1.3)
			Juego.avisar("¡Choque!  Estado del vehículo: %d %%" % int(salud))
	if salud <= 0.0 and not destruido and _t_fuego < 0.0:
		_t_fuego = 6.0   # Arde unos segundos y luego revienta.
		if conductor != null:
			Juego.avisar("¡El motor arde! Sal del coche (E).")


func _arder(delta: float) -> void:
	if _t_fuego < 0.0 or destruido:
		return
	_t_fuego -= delta
	if _t_fuego <= 0.0:
		_t_fuego = -1.0
		reventar()


# Coche del tráfico abandonado tras un choque: desaparece al alejarte.
func _vigilar_temporal() -> void:
	var j: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if j != null and j.global_position.distance_to(global_position) > 160.0:
		queue_free()


# --------------------- Aire y vehículos sin física de ruedas ---------------------

func _conducir_aire_o_arcade(delta: float) -> void:
	var cb: CharacterBody3D = chasis as CharacterBody3D
	var d: Dictionary = TIPOS[tipo]
	var vmax: float = float(d.get("vmax", 20.0)) * (0.0 if destruido else (0.3 if salud <= 0.0 else 1.0))
	var entrada: float = 0.0
	var direccion: float = 0.0
	var freno: bool = false
	var sube: bool = false
	var baja: bool = false
	if not Juego.menu_abierto:
		entrada = Input.get_axis("atras", "adelante")
		direccion = Input.get_axis("derecha", "izquierda")
		freno = Input.is_action_pressed("saltar")
		sube = freno
		baja = Input.is_action_pressed("agacharse")
	if gasolina <= 0.0:
		entrada = 0.0
		sube = false
	var aire: bool = clase() == "aire"
	var adelante: Vector3 = -cb.global_transform.basis.z
	if entrada != 0.0:
		var frenando: bool = entrada * _v < 0.0
		_v += entrada * float(d.get("acel", 5.0)) * (2.2 if frenando else 1.0) * delta
	else:
		_v = move_toward(_v, 0.0, (1.5 if aire else 4.0) * delta)
	if freno and not aire:
		_v = move_toward(_v, 0.0, 20.0 * delta)
	_v = clampf(_v, -vmax * 0.35 if not (aire and d.get("modo", "") == "avion") else 0.0, vmax)
	var volando: bool = aire and (not cb.is_on_floor() or _vy > 0.5)
	var giro: float = direccion * float(d.get("giro", 1.5)) * delta
	if aire and d["modo"] == "helicoptero":
		pass   # Gira parado, como un helicóptero.
	elif aire and d["modo"] == "avion":
		giro *= clampf(_v / 12.0, 0.0, 1.0)
	else:
		giro *= clampf(absf(_v) / 6.0, 0.0, 1.0) * signf(_v) * 3.0
	cb.rotate_y(giro)
	adelante = -cb.global_transform.basis.z
	cb.velocity.x = adelante.x * _v
	cb.velocity.z = adelante.z * _v
	if aire:
		var objetivo_vy: float = 0.0
		if d["modo"] == "helicoptero":
			objetivo_vy = 8.0 if sube else (-8.0 if baja else 0.0)
			if gasolina <= 0.0:
				objetivo_vy = -6.0
		else:
			var sustenta: bool = _v >= 20.0 and gasolina > 0.0
			objetivo_vy = (10.0 if sube else (-10.0 if baja else 0.0)) if sustenta else -9.0
			if not sustenta and cb.is_on_floor():
				objetivo_vy = 0.0
		_vy = move_toward(_vy, objetivo_vy, 7.0 * delta)
		if cb.is_on_floor() and _vy < 0.0:
			_vy = 0.0
		cb.velocity.y = _vy
		var vel_rotor: float = delta * (30.0 if gasolina > 0.0 else 3.0)
		if _rotor != null:
			_rotor.rotation.y += vel_rotor
		for r in _rotores:
			((r["nodo"]) as Node3D).rotate((r["eje"]) as Vector3, vel_rotor)
		if _modelo_aire != null:
			_modelo_aire.rotation.z = lerpf(_modelo_aire.rotation.z, direccion * 0.45 if volando else 0.0, delta * 3.0)
			_modelo_aire.rotation.x = lerpf(_modelo_aire.rotation.x, -entrada * 0.12 if volando else 0.0, delta * 3.0)
	elif cb.is_on_floor():
		cb.velocity.y = -1.0
	else:
		cb.velocity.y -= 20.0 * delta
	var vy_antes: float = _vy
	cb.move_and_slide()
	_contener_en_el_mundo()
	_v = cb.velocity.dot(adelante)
	if not aire:
		girar_ruedas(_v, delta, direccion)
	if aire and cb.is_on_floor() and vy_antes < -7.0:
		salud = maxf(0.0, salud - absf(vy_antes) * 4.0)
		Juego.cambiar_vida(-absf(vy_antes) * 2.0)
		Juego.avisar("¡Aterrizaje duro!  Estado: %d %%" % int(salud))
	gasolina = maxf(0.0, gasolina - (0.02 + 0.25 * absf(_v) / maxf(1.0, vmax)) * float(d.get("gasto", 1.0)) * delta)
	if efectos != null:
		efectos.actualizar(delta, false, false, Juego.es_de_noche(), [], salud)
	if sonido != null:
		sonido.rpm = 1800.0 + absf(_v) * 60.0 + absf(_vy) * 80.0
		sonido.carga = absf(entrada)
	# El nodo principal sigue al chasis (así la distancia de "E" es correcta) y lleva al conductor.
	global_position = cb.global_position
	conductor.global_position = global_position + Vector3(0, 0.9, 0)
	if cb.is_on_floor():
		_ultimo_suelo = global_position
	elif global_position.y < -10.0:
		cb.global_position = _ultimo_suelo + Vector3(0, 0.5, 0)
		_v = 0.0
		_vy = 0.0
	_t_guardado -= delta
	if _t_guardado <= 0.0:
		_t_guardado = 3.0
		guardar_estado()


func is_on_ground_safe() -> bool:
	if fisica != null:
		return fisica.ruedas_en_suelo > 0
	return (chasis as CharacterBody3D).is_on_floor()


# Techo de vuelo y muros invisibles: los vehículos (sobre todo los de aire, que pasan
# por encima de los muros de la ciudad) no pueden salir del rectángulo del mundo.
const ALTURA_MAXIMA: float = 45.0

func _contener_en_el_mundo() -> void:
	var lim: Rect2 = Juego.limites_mundo.grow(-2.0)
	var p: Vector3 = chasis.global_position
	var q: Vector3 = Vector3(clampf(p.x, lim.position.x, lim.end.x), minf(p.y, ALTURA_MAXIMA if clase() == "aire" else 99999.0),
			clampf(p.z, lim.position.y, lim.end.y))
	if q != p:
		chasis.global_position = q
		if q.y < p.y:
			_vy = minf(_vy, 0.0)
		if q.x != p.x or q.z != p.z:
			_v *= 0.5
			if fisica != null:
				fisica.linear_velocity *= 0.3


# Texto para el HUD mientras conduces.
func texto_conduccion() -> String:
	var v: float = velocidad_actual()
	var marcha: String = ""
	if fisica != null:
		marcha = " · %s · %d rpm" % ["R" if fisica.marcha == 0 else str(fisica.marcha), int(fisica.rpm)]
	return "[E] Bajar · %s · %d km/h%s · gasolina %d %% · estado %d %%" % [TIPOS[tipo]["nombre"],
			int(absf(v) * 3.6), marcha, int(gasolina), int(salud)]


# Daño de una explosión, de balas o de un golpe fuerte. Con la salud a cero el coche revienta:
# queda quemado y en llamas, sin poder moverse.
func recibir_dano(cantidad: float) -> void:
	if destruido:
		return
	salud = maxf(0.0, salud - cantidad)
	if salud <= 0.0:
		reventar()


# Impacto con punto y dirección (balas, golpes): pequeña abolladura, chispas y, si es fuerte,
# cristales. Las armas pueden llamar a esto en lugar de recibir_dano.
func recibir_impacto(punto: Vector3, direccion: Vector3, dano: float) -> void:
	if destruido:
		return
	Deformacion.abollar(_carroceria, punto, direccion.normalized(), clampf(dano * 0.4, 3.0, 8.0))
	EfectosVehiculo.estallido(self, punto, -direccion.normalized(), "chispas", 3.0)
	if dano > 15.0:
		EfectosVehiculo.estallido(self, punto, -direccion.normalized(), "cristal", 6.0)
	recibir_dano(dano)


func reventar() -> void:
	if destruido:
		return
	destruido = true
	salud = 0.0
	Destruccion.quemar_modelo(chasis)
	Destruccion.fuego_en(self, global_position + Vector3.UP * 0.8)
	_v = 0.0
	if fisica != null:
		# La explosión levanta el coche y lo hace girar.
		fisica.freeze = false
		fisica.sleeping = false
		fisica.apply_central_impulse(Vector3.UP * fisica.mass * 6.5 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * fisica.mass * 2.0)
		fisica.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * fisica.mass * 1.5)
		fisica.factor_motor = 0.0
	else:
		(chasis as CharacterBody3D).velocity = Vector3.ZERO
	if efectos != null:
		efectos.intermitente = 0
	Sonido.tocar(self, "explosion", 0.0)
	if conductor != null:
		Juego.cambiar_vida(-40.0)
		Juego.avisar("¡El vehículo ha reventado!")
