# Capturas del comportamiento de los personajes (scripts/ia). Con ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1600x900 res://tests/captura_ia.tscn -- /carpeta
# 1) Acera con gente paseando, parejas y charlas.  2) Un valiente se lía a puñetazos contigo.
# 3) Uno armado saca la pistola y te dispara.  4) Disparo al aire: la gente huye o se cubre.
# 5) Le apuntas a uno: levanta las manos y suplica.  6) Un civil armado (Ocupante) te encañona.
extends Node

var carpeta: String = "."
var J: Node
var jugador: Node3D
var vida_u: Node
var cam: Camera3D
var h: float = 0.0
var centro: Vector2
var cam_jugador: Camera3D   # Hay que dejarla activa mientras se apunta: el peatón mira hacia dónde apunta la cámara.
var doble: Node3D   # Un muñeco donde está el jugador, para que se vea a quién atacan.


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _cam_en(pos: Vector3, objetivo: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 55.0
		add_child(cam)
	cam.current = true
	cam.global_position = pos
	cam.look_at(objetivo, Vector3.UP)


# Cámara que encuadra a dos personajes desde el lado que tenga vista despejada (sin paredes ni
# árboles entre la cámara y ellos), a "dist" metros.
func _encuadrar(a: Vector3, b: Vector3, dist: float, altura: float = 1.8) -> void:
	var medio: Vector3 = (a + b) * 0.5
	var eje: Vector3 = b - a
	eje.y = 0.0
	var base: float = atan2(eje.z, eje.x) + PI / 2.0 if eje.length() > 0.1 else 0.0
	var espacio: PhysicsDirectSpaceState3D = jugador.get_world_3d().direct_space_state
	var mejor: Vector3 = medio + Vector3(dist, altura, 0)
	var mejor_libre: float = -1.0
	for i in 16:
		var ang: float = base + (i / 2) * (PI / 8.0) * (1.0 if i % 2 == 0 else -1.0)
		for f in [1.0, 0.7]:
			var pos: Vector3 = medio + Vector3(cos(ang), 0, sin(ang)) * dist * f + Vector3(0, altura, 0)
			var libre: float = 0.0
			for objetivo in [a, b, medio]:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(objetivo + Vector3(0, 1.2, 0), pos)
				q.collide_with_areas = false
				var hit: Dictionary = espacio.intersect_ray(q)
				if hit.is_empty() or hit["collider"] is CharacterBody3D:
					libre += 1.0
			libre -= (1.0 - f) * 0.5 + absf(float(i / 2)) * 0.05
			if libre > mejor_libre:
				mejor_libre = libre
				mejor = pos
	_cam_en(mejor, medio + Vector3(0, 1.0, 0))


func _peatones() -> Array:
	return vida_u._peatones.filter(func(q): return is_instance_valid(q) and not q.has_meta("muerto"))


func _calmar_a_todos() -> void:
	J.estrellas = 0
	for q in _peatones():
		if q.cerebro != null:
			q.cerebro.miedo = 0.0
			q.cerebro.ira = 0.0
			q.cerebro.amenaza = null
			q.cerebro.t_incidente = -99.0
			q.cerebro.t_disparo = -99.0
			q.cerebro.amenaza_dispara = false


func _elegir_peaton(excluir: Array = []) -> Node3D:
	for q in _peatones():
		if q in excluir or q.estado != 0 or q.cerebro == null or q.cerebro.lider != null:
			continue
		return q
	return null


func _poner_jugador(p: Vector3) -> void:
	jugador.global_position = p
	jugador.velocity = Vector3.ZERO
	if doble != null:
		doble.global_position = p


func _doble_mira(punto: Vector3) -> void:
	if doble == null:
		return
	var d: Vector3 = punto - doble.global_position
	doble.rotation.y = atan2(-d.x, -d.z)
	var dj: Vector3 = punto - (jugador.global_position + Vector3(0, 1.6, 0))
	jugador._giro = atan2(-dj.x, -dj.z)
	jugador._inclinacion = clampf(atan2(dj.y, Vector2(dj.x, dj.z).length()), -1.2, 0.9)


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
	vida_u = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.modo_volar = true
	J.hora = 11.0
	J.velocidad_tiempo = 0.0
	J.policia_activa = false
	Graficos.v["peatones"] = 4
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			centro = s["pos"]
			break
	h = GeneradorMundo.altura(centro.x, centro.y)
	for i in 24:
		_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
		await esperar(0.5)
	cam_jugador = get_viewport().get_camera_3d()
	doble = Assets.persona("", "", "Idle")
	if doble != null:
		Ropa.vestir(doble, 3, {"camisa": Color(0.25, 0.25, 0.28), "pantalon": Color(0.12, 0.12, 0.14), "manga": 2, "pierna": 0})
		get_tree().current_scene.add_child(doble)
		doble.global_position = jugador.global_position
	await _acera()
	await _pelea()
	await _armado()
	await _apuntar()
	await _disparo()
	await _civil()
	await _agachado()
	await _empujones()
	get_tree().quit()


# 1) La acera con más gente junta.
func _acera() -> void:
	var mejor: Node3D = null
	var mejor_n: int = 0
	for t in 30:
		_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
		await esperar(0.3)
		for q in _peatones():
			var n: int = _peatones().filter(func(x): return x.global_position.distance_to(q.global_position) < 9.0).size()
			if n > mejor_n:
				mejor_n = n
				mejor = q
		if mejor_n >= 4:
			break
	if mejor == null:
		return
	var otro: Node3D = mejor
	for x in _peatones():
		if x != mejor and x.global_position.distance_to(mejor.global_position) < 9.0:
			otro = x
	_encuadrar(mejor.global_position, otro.global_position, 9.0, 3.0)
	await esperar(0.2)
	await _foto("ia_01_acera_con_gente")


# 2) Le pegas a un valiente: se encara contigo.
func _pelea() -> void:
	_calmar_a_todos()
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	q.cerebro.ajustar({"valentia": 0.95, "agresividad": 0.95, "armado": false, "agilidad": 0.6})
	J.vida = 100.0
	J.invulnerable = 999.0
	_poner_jugador(q.global_position + (-q.global_basis.z) * 1.4 + Vector3(0, 0.05, 0))
	q.recibir_dano(4.0)
	var hecha: bool = false
	for i in 40:
		await esperar(0.1)
		_poner_jugador(Vector3(jugador.global_position.x, q.global_position.y + 0.05, jugador.global_position.z))
		_doble_mira(q.global_position)
		if not hecha and q.cerebro.accion == "pelear" and q.cerebro.anim_fija == "Punch":
			_encuadrar(q.global_position, jugador.global_position, 4.0, 1.4)
			await _foto("ia_02_le_pegas_y_se_encara_a_punetazos")
			hecha = true
	if not hecha:
		_encuadrar(q.global_position, jugador.global_position, 4.0, 1.4)
		await _foto("ia_02_le_pegas_y_se_encara_a_punetazos")


# 3) Uno armado: saca la pistola y dispara.
func _armado() -> void:
	_calmar_a_todos()
	_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
	await esperar(1.0)
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	q.cerebro.ajustar({"valentia": 0.9, "agresividad": 0.8, "armado": true})
	J.invulnerable = 999.0
	_poner_jugador(q.global_position + (-q.global_basis.z) * 7.0 + Vector3(0, 0.05, 0))
	q.recibir_dano(4.0)
	for i in 25:
		await esperar(0.1)
		_doble_mira(q.global_position)
		_encuadrar(q.global_position, jugador.global_position, 5.5, 1.6)
	print("Armado: acción ", q.cerebro.accion, " arma fuera ", q.cerebro.arma_fuera)
	await _foto("ia_03_armado_saca_la_pistola_y_dispara")


# 4) Le apuntas a uno con una pistola.
func _apuntar() -> void:
	_calmar_a_todos()
	_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
	await esperar(1.0)
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	q.cerebro.ajustar({"valentia": 0.1, "agresividad": 0.1, "armado": false, "agilidad": 0.2})
	J.inventario[J.seleccion] = {"id": "pistola", "cantidad": 1, "balas": 8}
	_poner_jugador(q.global_position + (-q.global_basis.z) * 4.0 + Vector3(0, 0.05, 0))
	if cam_jugador != null:
		cam_jugador.current = true
	for i in 35:
		_doble_mira(q.global_position + Vector3(0, 1.1, 0))
		await esperar(0.1)
		if i > 12 and q.cerebro.accion == "suplicar":
			break
	print("Apuntado: acción ", q.cerebro.accion, " anim ", q.cerebro.anim_fija)
	_encuadrar(q.global_position, jugador.global_position, 3.5, 1.5)
	await _foto("ia_04_le_apuntas_y_reacciona")
	J.inventario[J.seleccion] = null


# 5) Disparo al aire en mitad de la acera.
func _disparo() -> void:
	_calmar_a_todos()
	if doble != null:
		doble.visible = false
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	_poner_jugador(q.global_position + Vector3(2.0, 0.2, 0.0))
	await esperar(0.3)
	Sonido.tocar(jugador, "disparo")
	await esperar(1.2)
	_encuadrar(q.global_position, jugador.global_position, 10.0, 5.0)
	await _foto("ia_05_disparo_al_aire_la_gente_reacciona")


# 6) Un civil armado (como el dueño de un local) al que hieres.
func _civil() -> void:
	_calmar_a_todos()
	if doble != null:
		doble.visible = true
	var base: Vector3 = Vector3(centro.x + 2.0, h + 0.4, centro.y + 2.0)
	var o: Ocupante = Ocupante.new()
	o.semilla = 7
	o.armado = true
	o.arma = "Shotgun"
	o.zona = Rect2(base.x - 6.0, base.z - 6.0, 12.0, 12.0)
	get_tree().current_scene.add_child(o)
	o.global_position = base
	o.cerebro.ajustar({"valentia": 0.9, "agresividad": 0.8})
	_poner_jugador(base + Vector3(0, 0, 8.0))
	await esperar(0.5)
	o.recibir_dano(5.0)
	for i in 20:
		await esperar(0.1)
		_doble_mira(o.global_position)
	print("Civil: acción ", o.cerebro.accion, " arma fuera ", o.cerebro.arma_fuera)
	_encuadrar(o.global_position, jugador.global_position, 5.0, 1.6)
	await _foto("ia_06_civil_armado_te_encanona")


# 7) Tiros muy cerca de un miedoso: se agacha tapándose.
func _agachado() -> void:
	_calmar_a_todos()
	if doble != null:
		doble.visible = true
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	q.cerebro.ajustar({"valentia": 0.05, "agresividad": 0.05, "armado": false, "agilidad": 0.3})
	_poner_jugador(q.global_position + Vector3(5.0, 0.2, 0.0))
	for i in 30:
		if i % 2 == 0:
			Sonido.tocar(jugador, "disparo")
		_doble_mira(q.global_position)
		await esperar(0.15)
		if q.cerebro.anim_fija == "Duck":
			await esperar(0.3)
			break
	_encuadrar(q.global_position, jugador.global_position, 4.5, 1.5)
	await _foto("ia_07_tiros_cerca_se_agacha_tapandose")


# 8) Le empujas dos veces: a la segunda se encara.
func _empujones() -> void:
	_calmar_a_todos()
	var q: Node3D = _elegir_peaton()
	if q == null:
		return
	q.cerebro.ajustar({"valentia": 0.8, "agresividad": 0.9, "armado": false})
	J.invulnerable = 999.0
	_poner_jugador(q.global_position + (-q.global_basis.z) * 1.0 + Vector3(0, 0.05, 0))
	for vez in 2:
		q.cerebro.percibir("empujon", jugador.global_position, 1.0, jugador)
		for i in 16:
			_doble_mira(q.global_position)
			await esperar(0.1)
	_encuadrar(q.global_position, jugador.global_position, 3.5, 1.4)
	await _foto("ia_08_segundo_empujon_se_encara")
