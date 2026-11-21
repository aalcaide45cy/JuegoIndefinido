# Recorre sitios representativos del mundo (ciudad, un pueblo de cada estilo, montaña, vuelo),
# mide fotogramas y saca capturas. Se ejecuta con ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_pr12.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var filas: Array = []


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _ir(pos: Vector3, giro: float = 0.0, incl: float = -0.1) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _medir(nombre: String, frames: int = 240) -> void:
	var t0: int = Time.get_ticks_usec()
	var peor: int = 0
	var ult: int = t0
	for i in frames:
		await get_tree().process_frame
		var t: int = Time.get_ticks_usec()
		peor = maxi(peor, t - ult)
		ult = t
	var medio_ms: float = float(ult - t0) / 1000.0 / frames
	var fila: String = "%s | %.2f ms (%d FPS) | peor %.1f ms | peatones %d coches %d | dibujos %d" % [nombre, medio_ms, int(1000.0 / medio_ms),
			peor / 1000.0, vida._peatones.size(), vida._coches.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
	filas.append(fila)
	print("FPS ", fila)


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)


func _sitio(nombre: String, pos: Vector3, giro: float, incl: float, espera: float = 6.0) -> void:
	_ir(pos, giro, incl)
	await _esperar(espera)
	_ir(pos, giro, incl)
	await _esperar(1.0)
	await _medir(nombre)
	await _foto(nombre)


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
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.hora = 12.0
	J.velocidad_tiempo = 0.0 if "velocidad_tiempo" in J else 1.0
	print("Asentamientos: ", GeneradorMundo._asentamientos.size(), " caminos de montaña: ", GeneradorMundo._caminos.size())

	await _sitio("01_ciudad_original", Vector3(0, 0.5, 8), 0.0, -0.15, 5.0)
	jugador._giro = 1.57
	await _foto("02_ciudad_original_avenida")

	# Un asentamiento de cada estilo (no de montaña) y de cada tipo.
	var vistos_estilo: Dictionary = {}
	var vistos_tipo: Dictionary = {}
	var elegidos: Array = []
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if bool(s.get("montana", false)):
			continue
		var est: String = str(GeneradorMundo.estilo_de(int(s["ci"]) * 1009 + int(s["cj"]))["nombre"])
		if not vistos_estilo.has(est):
			vistos_estilo[est] = true
			elegidos.append([s, est])
	print("Estilos de casa encontrados: ", vistos_estilo.keys())
	var n: int = 3
	for par in elegidos:
		var s: Dictionary = par[0]
		var p: Vector2 = s["pos"]
		var nombre: String = "%02d_%s_%s_%s" % [n, GeneradorMundo.nombre_tipo(int(s["tipo"])).to_lower(), str(par[1]).replace(" ", "_"), str(s["nombre"]).replace(" ", "")]
		var h: float = GeneradorMundo.altura(p.x, p.y)
		await _sitio(nombre, Vector3(p.x + 2.0, h + 1.0, p.y + 18.0), 0.6, -0.12)
		n += 1
	# Una ciudad grande.
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			var h: float = GeneradorMundo.altura(p.x, p.y)
			await _sitio("%02d_ciudad_%s" % [n, str(s["nombre"]).replace(" ", "")], Vector3(p.x + 4.0, h + 1.0, p.y + 40.0), 0.3, -0.1, 7.0)
			n += 1
			break
	# Montaña: pueblo de montaña y su carretera.
	for c in GeneradorMundo._caminos:
		var pts: Array = c.get("pts", [])
		print("Camino: claves=", c.keys(), " puntos=", pts.size())
		if pts.size() > 4:
			var a: Vector2 = pts[pts.size() / 2]
			var b: Vector2 = pts[pts.size() / 2 + 1]
			var h: float = GeneradorMundo.altura(a.x, a.y)
			var dir: Vector2 = (b - a).normalized()
			await _sitio("%02d_carretera_montana" % n, Vector3(a.x, h + 1.0, a.y), atan2(-dir.x, -dir.y), -0.12, 8.0)
			n += 1
			var q: Vector2 = pts[pts.size() * 3 / 4]
			var h2: float = GeneradorMundo.altura(q.x, q.y)
			await _sitio("%02d_carretera_montana_curva" % n, Vector3(q.x, h2 + 25.0, q.y), 0.0, -0.45, 8.0)
			n += 1
			break
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			var h: float = GeneradorMundo.altura(p.x, p.y)
			await _sitio("%02d_pueblo_de_montana" % n, Vector3(p.x + 2.0, h + 1.0, p.y + 18.0), 0.6, -0.12, 8.0)
			n += 1
			break

	# Modo volar: velocidad normal y rueda.
	J.modo_volar = true
	J.velocidad_vuelo = J.VELOCIDAD_VUELO_NORMAL
	_ir(Vector3(0, 80, 8), 0.0, -0.3)
	await _esperar(3.0)
	var antes: Vector3 = jugador.global_position
	Input.action_press("adelante")
	await _esperar(3.0)
	Input.action_release("adelante")
	var recorrido: float = jugador.global_position.distance_to(antes)
	print("VUELO: velocidad normal ", J.velocidad_vuelo, " m/s; en 3 s recorrió ", recorrido, " m (≈ ", recorrido / 3.0, " m/s)")
	await _foto("%02d_volando_alto" % n)
	n += 1
	var v0: float = J.velocidad_vuelo
	for i in 5:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
	print("VUELO: rueda x5: ", v0, " -> ", J.velocidad_vuelo, " (con ratón capturado debería ser x2)")
	J.velocidad_vuelo = 600.0
	_ir(Vector3(0, 400, 8), 0.0, -0.5)
	Input.action_press("adelante")
	await _medir("vuelo_rapido_600ms", 120)
	await _foto("%02d_volando_rapido" % n)
	Input.action_release("adelante")
	J.modo_volar = false
	print("RESUMEN FPS:")
	for f in filas:
		print("  ", f)
	get_tree().quit()
