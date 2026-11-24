# Capturas de los vehículos nuevos en el mundo real: cámara de persecución, derrape con humo y
# marcas, choque con abolladura, ruedas pinchadas, luces de noche, tráfico con intermitentes y
# explosión. Con ventana (o xvfb):
#   godot --path . --resolution 1920x1080 res://tests/captura_conduccion.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var gestor: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	var al: Vector2 = -dir
	jugador._giro = atan2(-al.x, -al.y)
	jugador._inclinacion = -atan2(altura - 1.0, dist)


var _cam: Camera3D = null


# Cámara propia para los primeros planos (la del jugador va detrás de su cabeza).
func _ver(desde: Vector3, hacia: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		get_tree().current_scene.add_child(_cam)
	_cam.global_position = desde
	_cam.look_at(hacia)
	_cam.current = true


func _volver_camara() -> void:
	if _cam != null:
		_cam.current = false
	jugador._camara.current = true


func _poner(tipo: String, pos: Vector3, giro: float) -> Vehiculo:
	var v: Vehiculo = Vehiculo.new()
	v.tipo = tipo
	v.id = ""
	gestor.add_child(v)
	v.global_position = pos
	v.chasis.rotation.y = giro
	return v


func _vehiculo(id_v: String) -> Vehiculo:
	for n in get_tree().get_nodes_in_group("vehiculos"):
		if n is Vehiculo and (n as Vehiculo).id == id_v:
			return n
	return null


func _soltar_todo() -> void:
	for a in ["adelante", "atras", "izquierda", "derecha", "saltar"]:
		Input.action_release(a)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	gestor = get_tree().get_first_node_in_group("gestor_vehiculos")
	J.hora = 12.0
	if "velocidad_tiempo" in J:
		J.velocidad_tiempo = 0.0
	J.modo_volar = true
	jugador.global_position = Vector3(80, 3, -10)
	await _esperar(6.0)
	J.modo_volar = false
	# --- Coche en la avenida (z = -16, hacia +x) ---
	var id_v: String = gestor.entregar("sedan", Vector3(45, 0.4, -18.0), -PI / 2.0)
	await _esperar(0.5)
	var v: Vehiculo = _vehiculo(id_v)
	v.subir(jugador)
	await _esperar(1.0)
	Input.action_press("adelante")
	await _esperar(3.0)
	await _foto("veh_01_conduciendo_camara_persecucion")
	print("velocidad: %.0f km/h, marcha %d" % [v.velocidad_actual() * 3.6, v.fisica.marcha])
	# --- Derrape con freno de mano ---
	Input.action_release("adelante")
	Input.action_press("izquierda")
	Input.action_press("saltar")
	await _esperar(0.7)
	await _foto("veh_02_derrape_humo")
	await _esperar(0.8)
	_soltar_todo()
	Input.action_press("atras")
	await _esperar(2.0)
	_soltar_todo()
	await _esperar(1.0)
	# Vista de las marcas desde arriba.
	v.bajar()
	J.modo_volar = true
	_ver(v.global_position + Vector3(-9, 7, 4), v.global_position + Vector3(-3, 0, 0))
	await _esperar(0.5)
	await _foto("veh_03_marcas_de_frenada")
	_volver_camara()
	# --- Choque contra un todoterreno cruzado en la calle ---
	J.modo_volar = false
	var o: Vehiculo = _poner("suv", Vector3(335, 0.4, -18.0), PI * 0.5 + 0.2)
	var c: Vehiculo = _poner("hatchback", Vector3(255, 0.4, -18.0), -PI / 2.0)
	await _esperar(0.8)
	jugador.global_position = c.global_position + Vector3(0, 2, 0)
	await _esperar(0.5)
	c.subir(jugador)
	await _esperar(0.5)
	Input.action_press("adelante")
	var t: float = 0.0
	var v_max: float = 0.0
	while t < 10.0 and c.global_position.x < 331.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		v_max = maxf(v_max, c.velocidad_actual() * 3.6)
		if Engine.get_physics_frames() % 30 == 0:
			print("  t %.1f x %.1f y %.1f v %.0f marcha %d" % [t, c.global_position.x, c.global_position.y, c.velocidad_actual() * 3.6, c.fisica.marcha])
	print("velocidad al chocar: %.0f km/h" % v_max)
	await _esperar(0.06)
	await _foto("veh_04_choque_instante")
	_soltar_todo()
	await _esperar(2.5)
	print("choque: salud coche %.0f, salud suv %.0f" % [c.salud, o.salud])
	c.bajar()
	J.modo_volar = true
	var frente: Vector3 = c.fisica.global_transform * Vector3(2.2, 1.3, -3.6)
	_ver(frente, c.global_position + Vector3(0, 0.6, 0))
	await _esperar(0.4)
	await _foto("veh_05_abolladura_morro")
	var lado_o: Vector3 = o.global_position + (o.global_position - c.global_position).normalized() * -1.0
	_ver(o.global_position + Vector3(-4.0, 1.8, 2.2), o.global_position + Vector3(0, 0.6, 0))
	await _esperar(0.4)
	await _foto("veh_06_abolladura_suv")
	# --- Tiros a las ruedas del todoterreno ---
	for i in [0, 2]:
		var piv: Node3D = o.fisica.ruedas[i]["pivote"]
		o.recibir_impacto(piv.global_position, o.fisica.global_transform.basis.x, 20.0)
	await _esperar(3.0)
	var lado: Vector3 = o.fisica.global_transform.basis.x * -1.0
	_ver(o.global_position + lado * 4.2 + Vector3(0, 0.7, 0), o.fisica.global_transform * Vector3(0, 0.3, 0))
	await _esperar(0.4)
	await _foto("veh_07_ruedas_pinchadas")
	_volver_camara()
	# --- Noche: faros, luces de freno ---
	J.hora = 22.5
	J.modo_volar = false
	var id_n: String = gestor.entregar("deportivo", Vector3(420, 0.4, -18.0), -PI / 2.0)
	await _esperar(1.0)
	var n: Vehiculo = _vehiculo(id_n)
	n.subir(jugador)
	await _esperar(0.5)
	Input.action_press("adelante")
	await _esperar(2.0)
	Input.action_release("adelante")
	Input.action_press("atras")
	await _esperar(0.3)
	await _foto("veh_08_noche_luces_de_freno")
	_soltar_todo()
	await _esperar(2.0)
	_ver(n.fisica.global_transform * Vector3(2.5, 1.6, -12.0), n.global_position + Vector3(0, 0.8, 0))
	await _esperar(0.3)
	await _foto("veh_09_noche_faros")
	_volver_camara()
	n.bajar()
	# --- Tráfico: intermitentes y luces de freno ---
	J.hora = 18.5
	J.modo_volar = true
	var hecho: int = 0
	t = 0.0
	jugador.global_position = Vector3(80, 3, -10)
	print("coches de trafico: %d" % vida._coches.size())
	while t < 90.0 and hecho < 2:
		await _esperar(0.25)
		t += 0.25
		for a in vida._coches:
			if not is_instance_valid(a) or a.efectos == null:
				continue
			var interesante: bool = (hecho == 0 and a.efectos.intermitente != 0 and a.vel > 1.0) \
					or (hecho == 1 and a.acc < -1.5)
			if interesante:
				var detras: Vector3 = a.global_position - Vector3(a.dir2.x, 0, a.dir2.y) * 9.0
				jugador.global_position = detras + Vector3(0, 2.5, 0)
				jugador._giro = atan2(-a.dir2.x, -a.dir2.y)
				jugador._inclinacion = -0.18
				await _esperar(0.12)
				await _foto("veh_1%d_trafico_%s" % [hecho, "intermitente" if hecho == 0 else "frenando"])
				hecho += 1
				break
	# --- Explosión ---
	J.hora = 12.0
	_ver(o.global_position + Vector3(-11, 4, 6), o.global_position + Vector3(0, 1, 0))
	o.recibir_dano(300.0)
	await _esperar(0.35)
	await _foto("veh_12_explosion")
	await _esperar(2.5)
	await _foto("veh_13_coche_quemado")
	get_tree().quit()
