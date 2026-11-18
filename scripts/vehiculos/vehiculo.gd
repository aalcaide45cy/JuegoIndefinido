# vehiculo.gd
# -----------------------------------------------------------------------------
# Coches, furgonetas, camiones y tractores que se pueden conducir (modelos CC0
# de Kenney, assets/kenney/car-kit). Conducción "arcade" (sin ruedas físicas):
# un CharacterBody3D que acelera, gira y choca con las paredes.
#
#   E junto al vehículo   subir (si no es tuyo, es un ROBO: sube la sospecha)
#   W/S  acelerar / marcha atrás      A/D  girar      Espacio  freno
#   E dentro              bajar       V    cambiar de cámara
#   Bidón de gasolina en la mano + E   echar gasolina (+40 %)
#   Kit de reparación en la mano + E   reparar
#
# El estado de los vehículos que son tuyos vive en Juego.vehiculos (se guarda).
# Si el coche sale girado 90 o 180 grados, cambia GIRO_MODELO.  SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Vehiculo
extends Interactuable

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const CARPETA: String = "kenney/car-kit/"
# Giro extra del modelo (radianes) por si el frente no coincide con -Z.
const GIRO_MODELO: float = 0.0

# cat = categoría en el concesionario (por defecto según la clase); clase: "suelo", "remolque" o "aire".
# largo (m), vmax (m/s), acel (m/s²), giro (rad/s), precio, gasto (relativo), color si falta el modelo
const TIPOS: Dictionary = {
	"hatchback": {"nombre": "Utilitario deportivo", "modelo": "hatchback-sports", "largo": 3.9, "vmax": 24.0,
			"acel": 9.0, "giro": 1.9, "precio": 2400, "gasto": 1.0, "color": Color(0.8, 0.2, 0.15)},
	"sedan": {"nombre": "Sedán", "modelo": "sedan", "largo": 4.4, "vmax": 22.0, "acel": 8.0, "giro": 1.7,
			"precio": 3000, "gasto": 1.0, "color": Color(0.2, 0.3, 0.5)},
	"taxi": {"nombre": "Taxi", "modelo": "taxi", "largo": 4.4, "vmax": 22.0, "acel": 8.0, "giro": 1.7,
			"precio": 3200, "gasto": 1.0, "color": Color(0.9, 0.75, 0.15)},
	"suv": {"nombre": "Todoterreno", "modelo": "suv", "largo": 4.6, "vmax": 21.0, "acel": 7.5, "giro": 1.6,
			"precio": 5200, "gasto": 1.3, "color": Color(0.25, 0.3, 0.25)},
	"furgoneta": {"nombre": "Furgoneta", "modelo": "van", "largo": 4.8, "vmax": 18.0, "acel": 6.0, "giro": 1.5,
			"precio": 4200, "gasto": 1.2, "color": Color(0.85, 0.85, 0.85), "cat": "Camiones"},
	"camion": {"nombre": "Camión", "modelo": "truck", "largo": 6.4, "vmax": 15.0, "acel": 4.5, "giro": 1.2,
			"precio": 7500, "gasto": 2.0, "color": Color(0.6, 0.3, 0.1), "cat": "Camiones"},
	"tractor": {"nombre": "Tractor", "modelo": "tractor", "largo": 3.6, "vmax": 9.0, "acel": 3.5, "giro": 1.5,
			"precio": 6000, "gasto": 0.8, "color": Color(0.2, 0.5, 0.2), "cat": "Maquinaria"},
	"excavadora": {"nombre": "Excavadora", "modelo": "tractor-shovel", "largo": 4.6, "vmax": 7.0, "acel": 3.0,
			"giro": 1.3, "precio": 9000, "gasto": 1.0, "color": Color(0.9, 0.6, 0.1), "cat": "Maquinaria"},
	"trailer": {"nombre": "Cabeza tractora (tráiler)", "modelo": "truck", "largo": 5.6, "vmax": 17.0, "acel": 5.0,
			"giro": 1.2, "precio": 12000, "gasto": 2.2, "color": Color(0.7, 0.1, 0.1), "cat": "Camiones"},
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
	"deportivo": {"nombre": "Deportivo de carreras", "modelo": "race", "largo": 4.2, "vmax": 34.0, "acel": 12.0,
			"giro": 2.0, "precio": 12000, "gasto": 1.8, "color": Color(0.1, 0.1, 0.6)},
}

var tipo: String = "sedan"
var id: String = ""            # Vacío = no es tuyo todavía. "amb_..." aparcado, "mio_N" comprado.
var gasolina: float = 100.0
var salud: float = 100.0
var conductor: Node3D = null
var remolque = null            # Remolque enganchado (otro Vehiculo) o null.
var tractor = null             # Si esto es un remolque enganchado: quién lo arrastra.
var _vy: float = 0.0
var _rotor: Node3D = null
var _modelo_aire: Node3D = null

var chasis: CharacterBody3D
var _ancho: float = 2.0
var _largo: float = 4.0
var _v: float = 0.0
var _faros: SpotLight3D
var _t_guardado: float = 0.0
var _t_golpe: float = 0.0
var _ultimo_suelo: Vector3 = Vector3.ZERO


func _ready() -> void:
	ignora_vista = true
	add_to_group("vehiculos")
	var d: Dictionary = TIPOS[tipo]
	_largo = d["largo"]
	chasis = CharacterBody3D.new()
	chasis.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	add_child(chasis)
	var modelo: Node3D = _crear_modelo(d)
	chasis.add_child(modelo)
	var forma: BoxShape3D = BoxShape3D.new()
	forma.size = Vector3(_ancho, 1.2, _largo)
	var choque: CollisionShape3D = CollisionShape3D.new()
	choque.shape = forma
	choque.position.y = 0.7
	chasis.add_child(choque)
	_faros = SpotLight3D.new()
	_faros.position = Vector3(0, 0.8, -_largo / 2.0)
	_faros.spot_range = 40.0
	_faros.spot_angle = 35.0
	_faros.light_energy = 3.0
	_faros.visible = false
	chasis.add_child(_faros)
	distancia = _largo / 2.0 + 1.6
	set_physics_process(false)


# El modelo del coche, escalado al largo del tipo, centrado y con las ruedas en el suelo.
# Si no está el modelo, una caja de color.
func _crear_modelo(d: Dictionary) -> Node3D:
	var raiz: Node3D = Node3D.new()
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
		m.position = Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z)
		var envoltorio: Node3D = Node3D.new()
		envoltorio.scale = Vector3.ONE * esc
		envoltorio.rotation.y = (PI / 2.0 if largo_x else PI) + GIRO_MODELO
		envoltorio.add_child(m)
		raiz.add_child(envoltorio)
	else:
		_ancho = 1.9
		Construir.caja(raiz, Vector3(0, 0.6, 0), Vector3(_ancho, 0.8, _largo), d["color"], false)
		Construir.caja(raiz, Vector3(0, 1.2, 0.3), Vector3(_ancho - 0.2, 0.6, _largo * 0.5), d["color"].darkened(0.3), false)
	_ancho = clampf(_ancho, 1.4, 3.2)
	return raiz


# Helicóptero y avioneta hechos con cajas (no hay modelos de aire en los paquetes).
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
	if _es_mio():
		return "Conducir: %s  (gasolina %d %%, estado %d %%)" % [nombre, int(gasolina), int(salud)]
	return "ROBAR: %s (la policía te buscará)" % nombre


func _es_mio() -> bool:
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


func bajar() -> void:
	if conductor == null:
		return
	if clase() == "aire" and not chasis.is_on_floor():
		Juego.avisar("No puedes bajar en pleno vuelo. Aterriza primero.")
		return
	var j: Node3D = conductor
	conductor = null
	_v = 0.0
	chasis.velocity = Vector3.ZERO
	_faros.visible = false
	set_physics_process(false)
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
	if id == "":
		return
	var p: Vector3 = chasis.global_position
	Juego.vehiculos[id] = {"tipo": tipo, "pos": [p.x, p.y, p.z], "giro": chasis.rotation.y,
			"gas": gasolina, "salud": salud}


# ------------------------------- Conducción ----------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if conductor != null and evento.is_action_pressed("enganchar"):
		_enganchar()


# H: engancha el remolque más cercano (a menos de 9 m) o suelta el que llevas.
func _enganchar() -> void:
	if remolque != null:
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
	Juego.avisar("Remolque enganchado: %s." % TIPOS[mejor.tipo]["nombre"])


# El remolque sigue al vehículo (sin física propia): detrás, con un poco de retraso al girar.
func _arrastrar() -> void:
	var r = remolque
	var atras: Vector3 = chasis.global_transform.basis.z
	var pos: Vector3 = chasis.global_position + atras * (_largo / 2.0 + float(r._largo) / 2.0 + 0.5)
	r.global_position = Vector3(pos.x, chasis.global_position.y, pos.z)
	r.chasis.position = Vector3.ZERO
	r.chasis.rotation.y = lerp_angle(r.chasis.rotation.y, chasis.rotation.y, 0.15)


func _physics_process(delta: float) -> void:
	if conductor == null:
		return
	var d: Dictionary = TIPOS[tipo]
	var vmax: float = float(d["vmax"]) * (0.3 if salud <= 0.0 else 1.0)
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
	var adelante: Vector3 = -chasis.global_transform.basis.z
	if entrada != 0.0:
		var frenando: bool = entrada * _v < 0.0
		_v += entrada * float(d["acel"]) * (2.2 if frenando else 1.0) * delta
	else:
		_v = move_toward(_v, 0.0, (1.5 if aire else 4.0) * delta)
	if freno and not aire:
		_v = move_toward(_v, 0.0, 20.0 * delta)
	_v = clampf(_v, -vmax * 0.35 if not (aire and d["modo"] == "avion") else 0.0, vmax)
	var volando: bool = aire and (not chasis.is_on_floor() or _vy > 0.5)
	var giro: float = direccion * float(d["giro"]) * delta
	if aire and d["modo"] == "helicoptero":
		pass   # Gira parado, como un helicóptero.
	elif aire and d["modo"] == "avion":
		giro *= clampf(_v / 12.0, 0.0, 1.0)
	else:
		giro *= clampf(absf(_v) / 6.0, 0.0, 1.0) * signf(_v)
	chasis.rotate_y(giro)
	adelante = -chasis.global_transform.basis.z
	chasis.velocity.x = adelante.x * _v
	chasis.velocity.z = adelante.z * _v
	if aire:
		var objetivo_vy: float = 0.0
		if d["modo"] == "helicoptero":
			objetivo_vy = 8.0 if sube else (-8.0 if baja else 0.0)
			if gasolina <= 0.0:
				objetivo_vy = -6.0
		else:
			var sustenta: bool = _v >= 20.0 and gasolina > 0.0
			objetivo_vy = (10.0 if sube else (-10.0 if baja else 0.0)) if sustenta else -9.0
			if not sustenta and chasis.is_on_floor():
				objetivo_vy = 0.0
		_vy = move_toward(_vy, objetivo_vy, 7.0 * delta)
		if chasis.is_on_floor() and _vy < 0.0:
			_vy = 0.0
		chasis.velocity.y = _vy
		if _rotor != null:
			_rotor.rotation.y += delta * (30.0 if gasolina > 0.0 else 3.0) * (1.0 if d["modo"] == "helicoptero" else 1.0)
		if _modelo_aire != null:
			_modelo_aire.rotation.z = lerpf(_modelo_aire.rotation.z, direccion * 0.45 if volando else 0.0, delta * 3.0)
			_modelo_aire.rotation.x = lerpf(_modelo_aire.rotation.x, -entrada * 0.12 if volando else 0.0, delta * 3.0)
	elif chasis.is_on_floor():
		chasis.velocity.y = -1.0
	else:
		chasis.velocity.y -= 20.0 * delta
	var v_antes: float = _v
	var vy_antes: float = _vy
	chasis.move_and_slide()
	_contener_en_el_mundo()
	_v = chasis.velocity.dot(adelante)
	if aire and chasis.is_on_floor() and vy_antes < -7.0:
		salud = maxf(0.0, salud - absf(vy_antes) * 4.0)
		Juego.cambiar_vida(-absf(vy_antes) * 2.0)
		Juego.avisar("¡Aterrizaje duro!  Estado: %d %%" % int(salud))
	_choques(v_antes, delta)
	# Gasolina: gasta según la velocidad.
	gasolina = maxf(0.0, gasolina - (0.02 + 0.25 * absf(_v) / maxf(1.0, vmax)) * float(d["gasto"]) * delta)
	_faros.visible = Juego.es_de_noche()
	# El nodo principal sigue al chasis (así la distancia de "E" es correcta) y lleva al conductor.
	global_position = chasis.global_position
	chasis.position = Vector3.ZERO
	conductor.global_position = global_position + Vector3(0, 0.9, 0)
	if remolque != null:
		_arrastrar()
	if is_on_ground_safe():
		_ultimo_suelo = global_position
	elif global_position.y < -10.0:
		global_position = _ultimo_suelo + Vector3(0, 0.5, 0)
		chasis.position = Vector3.ZERO
		_v = 0.0
		_vy = 0.0
	_t_guardado -= delta
	if _t_guardado <= 0.0:
		_t_guardado = 3.0
		guardar_estado()
		if remolque != null:
			remolque.guardar_estado()


func is_on_ground_safe() -> bool:
	return chasis.is_on_floor()


# Techo de vuelo y muros invisibles: los vehículos (sobre todo los de aire, que pasan
# por encima de los muros de la ciudad) no pueden salir del rectángulo del mundo.
const ALTURA_MAXIMA: float = 45.0

func _contener_en_el_mundo() -> void:
	var lim: Rect2 = Juego.limites_mundo.grow(-2.0)
	var p: Vector3 = chasis.global_position
	var q: Vector3 = Vector3(clampf(p.x, lim.position.x, lim.end.x), minf(p.y, ALTURA_MAXIMA), clampf(p.z, lim.position.y, lim.end.y))
	if q != p:
		chasis.global_position = q
		if q.y < p.y:
			_vy = minf(_vy, 0.0)
		if q.x != p.x or q.z != p.z:
			_v *= 0.5


# Golpes: si frenas de golpe contra algo te haces daño y dañas el coche; si es
# algo que recibe daño (guardias, dianas), lo atropellas.
func _choques(v_antes: float, delta: float) -> void:
	_t_golpe -= delta
	var perdida: float = absf(v_antes) - absf(_v)
	for i in chasis.get_slide_collision_count():
		var otro = chasis.get_slide_collision(i).get_collider()
		if otro != null and otro.has_method("recibir_dano") and absf(v_antes) > 5.0 and _t_golpe <= 0.0:
			otro.recibir_dano(absf(v_antes) * 4.0)
			Juego.delito_visto = 6.0
			Juego.sospecha = minf(100.0, Juego.sospecha + 10.0)
			_t_golpe = 0.5
	if perdida > 6.0 and _t_golpe <= 0.0:
		_t_golpe = 0.5
		salud = maxf(0.0, salud - perdida * 1.5)
		Juego.cambiar_vida(-perdida * 0.8)
		Juego.avisar("¡Choque!  Estado del vehículo: %d %%" % int(salud))


# Texto para el HUD mientras conduces.
func texto_conduccion() -> String:
	return "[E] Bajar · %s · %d km/h · gasolina %d %% · estado %d %%" % [TIPOS[tipo]["nombre"],
			int(absf(_v) * 3.6), int(gasolina), int(salud)]
