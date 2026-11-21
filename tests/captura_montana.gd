# Busca puentes, túneles y señales en las carreteras de montaña y los fotografía.
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_montana.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _ir(pos: Vector3, dir: Vector2) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(-dir.x, -dir.y)
	jugador._inclinacion = -0.12


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
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	# Genera los trozos a lo largo de cada carretera de montaña para listar las obras.
	for c in GeneradorMundo._caminos:
		var vistos: Dictionary = {}
		for q in c["pts"]:
			var ct: Vector2i = Vector2i(floori(q.x / GeneradorMundo.TROZO), floori(q.y / GeneradorMundo.TROZO))
			if not vistos.has(ct):
				vistos[ct] = true
				GeneradorMundo.generar_cercano(ct)
	var cuenta: Dictionary = {}
	var primero: Dictionary = {}
	for o in GeneradorMundo.obras_vistas:
		cuenta[o[0]] = int(cuenta.get(o[0], 0)) + 1
		if not primero.has(o[0]):
			primero[o[0]] = o
	print("OBRAS: ", cuenta, " en ", GeneradorMundo._caminos.size(), " carreteras de montaña")
	for tipo in primero:
		var o: Array = primero[tipo]
		var p: Vector3 = o[1]
		var d: Vector2 = o[2]
		var atras: Vector3 = p - Vector3(d.x, 0, d.y) * 22.0
		atras.y = GeneradorMundo.altura(atras.x, atras.z) + 1.0
		_ir(atras, d)
		await _esperar(9.0)
		_ir(atras, d)
		await _esperar(1.5)
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_jpg("%s/montana_%s.jpg" % [carpeta, tipo], 0.88)
	get_tree().quit()
