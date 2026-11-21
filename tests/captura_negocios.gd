# Capturas de los negocios con interior: fachada, interior desde la puerta y desde el fondo y la
# ventana de pedidos de cada uno. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_negocios.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var escena: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)
	print("FOTO ", nombre)


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(dir.x, dir.y)
	jugador._inclinacion = -atan2(altura - 1.5, dist)


func _servicio(nombre: String):
	for n in get_tree().get_nodes_in_group("interactuable"):
		if n is ServicioMundo and n.servicio == nombre:
			return n
	return null


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	escena = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	J.hora = 14.0
	J.velocidad_tiempo = 0.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var p: Vector2 = elegido["pos"]
	var h: float = GeneradorMundo.altura(p.x, p.y)
	jugador.global_position = Vector3(p.x, h + 20.0, p.y)
	await get_tree().create_timer(6.0).timeout
	var n: int = 1
	for nombre in ["posada", "gimnasio"]:
		var sv = _servicio(nombre)
		if sv == null:
			print("No encontrado: ", nombre)
			continue
		var lm: LocalMundo = null
		for hijo in sv.get_children():
			if hijo is LocalMundo:
				lm = hijo
		var centro: Vector3 = lm.global_position + Vector3(0, 0, 0)
		# Fachada.
		_mirar(sv.global_position, 13.0, 3.0, PI / 2.0 + 0.5)
		await get_tree().create_timer(1.5).timeout
		await _foto("%02d_%s_fachada" % [n, nombre])
		# Desde la puerta hacia el fondo.
		_mirar(centro + Vector3(0, 0, 0), lm.D / 2.0 - 0.7, 0.25, PI / 2.0)
		await get_tree().create_timer(1.0).timeout
		await _foto("%02d_%s_interior_puerta" % [n, nombre])
		# Desde el fondo (rincón) hacia la puerta.
		jugador.global_position = centro + Vector3(-lm.W / 2.0 + 1.0, 0.4, -lm.D / 2.0 + 1.0)
		jugador.velocity = Vector3.ZERO
		jugador._giro = -2.4
		jugador._inclinacion = 0.0
		await get_tree().create_timer(1.0).timeout
		await _foto("%02d_%s_interior_fondo" % [n, nombre])
		# Mostrador y persona que atiende.
		jugador.global_position = lm.global_position + Vector3(lm._uc, 0.25, lm.D / 2.0 - (lm.D - 3.3))
		jugador._giro = 0.0
		jugador._inclinacion = 0.0
		await get_tree().create_timer(1.0).timeout
		await _foto("%02d_%s_mostrador" % [n, nombre])
		# La ventana de pedidos.
		J.dinero = 400
		J.anadir("hierba_bruma", 2)
		var v: VentanaLocal = VentanaLocal.new()
		v.local_mundo = lm
		hud.abrir_ventana(v)
		await get_tree().create_timer(0.6).timeout
		await _foto("%02d_%s_ventana" % [n, nombre])
		v.cerrar()
		await get_tree().process_frame
		n += 1
	print("FIN")
	get_tree().quit()
