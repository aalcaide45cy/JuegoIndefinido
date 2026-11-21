# Capturas de los peatones: aceras con casas (ya no las atraviesan) y una tira de fotogramas de
# un peatón andando de lado para ver el ritmo de las piernas. Con ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_peatones.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


# Cámara a "dist" metros del punto, a "altura", mirándolo desde el ángulo "ang".
var cam: Camera3D


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	_cam_en(punto + Vector3(dir.x * dist, altura, dir.y * dist), punto + Vector3(0, 1.0, 0))


func _cam_en(pos: Vector3, objetivo: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 60.0
		add_child(cam)
		cam.current = true
	cam.global_position = pos
	cam.look_at(objetivo, Vector3.UP)
	jugador.global_position = Vector3(pos.x, pos.y + 15.0, pos.z)
	jugador.velocity = Vector3.ZERO


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
	J.hora = 12.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var p: Vector2 = elegido["pos"]
	var h: float = GeneradorMundo.altura(p.x, p.y)
	jugador.global_position = Vector3(p.x + 40.0, h + 20.0, p.y + 40.0)
	await get_tree().create_timer(10.0).timeout

	# 1) Un peatón por la acera, visto desde la calzada con las casas detrás.
	var elegido_p: Node3D = null
	var t: float = 0.0
	while elegido_p == null and t < 60.0:
		jugador.global_position = Vector3(p.x + 40.0, h + 20.0, p.y + 40.0)
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		for q in vida._peatones:
			if is_instance_valid(q) and q.estado == 0 and q.vel > 1.0 and not q.alegre \
					and Vector2(q.global_position.x, q.global_position.z).distance_to(p) < 70.0:
				elegido_p = q
				break
	if elegido_p == null:
		print("No hay peatón en la acera")
		get_tree().quit()
		return
	var pa: Vector2 = elegido_p.red["pos"][elegido_p.desde]
	var pb: Vector2 = elegido_p.red["pos"][elegido_p.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var der: Vector2 = Vector2(-dir.y, dir.x)
	var hacia_calle: Vector2 = -der * float(elegido_p.s)
	# Foto de conjunto: desde la calle, en diagonal.
	var ang: float = atan2(hacia_calle.y + dir.y * 0.5, hacia_calle.x + dir.x * 0.5)
	_mirar(elegido_p.global_position, 11.0, 3.2, ang)
	await get_tree().create_timer(0.2).timeout
	await _foto("01_peaton_por_la_acera_con_casas")
	# 2) Tira de fotogramas de lado: cámara fija pegada a la calle, el peatón pasa andando.
	var lado_pos: Vector3 = elegido_p.global_position + Vector3(hacia_calle.x * 3.4, 0.0, hacia_calle.y * 3.4)
	_cam_en(lado_pos + Vector3(0, 1.0, 0), elegido_p.global_position + Vector3(0, 0.9, 0) + Vector3(dir.x, 0.0, dir.y) * 0.9)
	print("Velocidad del peatón %.2f m/s, ritmo de la animación %.2f" % [elegido_p.vel, (elegido_p.modelo.get_meta("animaciones") as AnimationPlayer).speed_scale])
	for i in 8:
		await get_tree().create_timer(0.12).timeout
		await _foto("tira_%d" % i)
	get_tree().quit()


func _casa_cerca(s: Dictionary, q: Node3D) -> bool:
	var pos: Vector2 = Vector2(q.global_position.x, q.global_position.z)
	for c in GeneradorMundo._casas_en(s, Rect2(pos.x - 12.0, pos.y - 12.0, 24.0, 24.0)):
		var dx: float = maxf(absf(pos.x - c["x"]) - float(c["w"]) / 2.0, 0.0)
		var dz: float = maxf(absf(pos.y - c["z"]) - float(c["d"]) / 2.0, 0.0)
		if Vector2(dx, dz).length() < 4.5 and int(c["pisos"]) >= 2:
			return true
	return false
