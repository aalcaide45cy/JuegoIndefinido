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
			"precio": 4200, "gasto": 1.2, "color": Color(0.85, 0.85, 0.85)},
	"camion": {"nombre": "Camión", "modelo": "truck", "largo": 6.4, "vmax": 15.0, "acel": 4.5, "giro": 1.2,
			"precio": 7500, "gasto": 2.0, "color": Color(0.6, 0.3, 0.1)},
	"tractor": {"nombre": "Tractor", "modelo": "tractor", "largo": 3.6, "vmax": 9.0, "acel": 3.5, "giro": 1.5,
			"precio": 6000, "gasto": 0.8, "color": Color(0.2, 0.5, 0.2)},
	"deportivo": {"nombre": "Deportivo de carreras", "modelo": "race", "largo": 4.2, "vmax": 34.0, "acel": 12.0,
			"giro": 2.0, "precio": 12000, "gasto": 1.8, "color": Color(0.1, 0.1, 0.6)},
}

var tipo: String = "sedan"
var id: String = ""            # Vacío = no es tuyo todavía. "amb_..." aparcado, "mio_N" comprado.
var gasolina: float = 100.0
var salud: float = 100.0
var conductor: Node3D = null

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
	var m: Node3D = Assets.modelo(CARPETA + str(d["modelo"]))
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
	if not _es_mio():
		_robar()
	subir(jugador)


func _robar() -> void:
	Juego.sospecha = minf(100.0, Juego.sospecha + 30.0)
	Juego.delito_visto = 8.0
	Juego.avisar("¡Robas un vehículo! La policía empieza a sospechar.")
	if id == "":
		id = "robado_%d" % Juego.siguiente_vehiculo()
	guardar_estado()


func subir(jugador: Node) -> void:
	if conductor != null or not jugador.has_method("subir_a"):
		return
	conductor = jugador as Node3D
	# Que no desaparezca con el trozo de mapa donde estaba aparcado.
	var escena: Node = get_tree().current_scene
	if escena != null and get_parent() != escena:
		reparent(escena)
	_ultimo_suelo = global_position
	jugador.subir_a(self)
	set_physics_process(true)


func bajar() -> void:
	if conductor == null:
		return
	var j: Node3D = conductor
	conductor = null
	_v = 0.0
	chasis.velocity = Vector3.ZERO
	_faros.visible = false
	set_physics_process(false)
	var lado: Vector3 = chasis.global_transform.basis.x * -(_ancho / 2.0 + 0.9)
	var destino: Vector3 = chasis.global_position + lado + Vector3(0, 0.3, 0)
	if j.has_method("bajar_de"):
		j.bajar_de(self, destino)
	guardar_estado()


# Guarda posición y estado en Juego.vehiculos (solo si es tuyo).
func guardar_estado() -> void:
	if id == "":
		return
	var p: Vector3 = chasis.global_position
	Juego.vehiculos[id] = {"tipo": tipo, "pos": [p.x, p.y, p.z], "giro": chasis.rotation.y,
			"gas": gasolina, "salud": salud}


# ------------------------------- Conducción ----------------------------------

func _physics_process(delta: float) -> void:
	if conductor == null:
		return
	var d: Dictionary = TIPOS[tipo]
	var vmax: float = float(d["vmax"]) * (0.3 if salud <= 0.0 else 1.0)
	var entrada: float = 0.0
	var direccion: float = 0.0
	var freno: bool = false
	if not Juego.menu_abierto:
		entrada = Input.get_axis("atras", "adelante")
		direccion = Input.get_axis("derecha", "izquierda")
		freno = Input.is_action_pressed("saltar")
	if gasolina <= 0.0:
		entrada = 0.0
	var adelante: Vector3 = -chasis.global_transform.basis.z
	if entrada != 0.0:
		var frenando: bool = entrada * _v < 0.0
		_v += entrada * float(d["acel"]) * (2.2 if frenando else 1.0) * delta
	else:
		_v = move_toward(_v, 0.0, 4.0 * delta)
	if freno:
		_v = move_toward(_v, 0.0, 20.0 * delta)
	_v = clampf(_v, -vmax * 0.35, vmax)
	var giro: float = direccion * float(d["giro"]) * clampf(absf(_v) / 6.0, 0.0, 1.0) * signf(_v) * delta
	chasis.rotate_y(giro)
	adelante = -chasis.global_transform.basis.z
	chasis.velocity.x = adelante.x * _v
	chasis.velocity.z = adelante.z * _v
	if chasis.is_on_floor():
		chasis.velocity.y = -1.0
	else:
		chasis.velocity.y -= 20.0 * delta
	var v_antes: float = _v
	chasis.move_and_slide()
	_v = chasis.velocity.dot(adelante)
	_choques(v_antes, delta)
	# Gasolina: gasta según la velocidad.
	gasolina = maxf(0.0, gasolina - (0.02 + 0.25 * absf(_v) / vmax) * float(d["gasto"]) * delta)
	_faros.visible = Juego.es_de_noche()
	# El nodo principal sigue al chasis (así la distancia de "E" es correcta) y lleva al conductor.
	global_position = chasis.global_position
	chasis.position = Vector3.ZERO
	conductor.global_position = global_position + Vector3(0, 0.9, 0)
	if is_on_ground_safe():
		_ultimo_suelo = global_position
	elif global_position.y < -10.0:
		global_position = _ultimo_suelo + Vector3(0, 0.5, 0)
		chasis.position = Vector3.ZERO
		_v = 0.0
	_t_guardado -= delta
	if _t_guardado <= 0.0:
		_t_guardado = 3.0
		guardar_estado()


func is_on_ground_safe() -> bool:
	return chasis.is_on_floor()


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
