# medir_rendimiento.gd
# -----------------------------------------------------------------------------
# Mide lo que cuesta dibujar el mundo en varios sitios (plaza original, aldea, pueblo, ciudad,
# montaña y vista aérea), de día y de noche, y saca una captura de cada uno.
# Para cada sitio escribe: FPS, ms por fotograma, llamadas de dibujo, objetos y primitivas
# dibujadas, nodos en la escena, memoria de vídeo y de sistema, y peatones/coches cerca.
# Al final escribe "rendimiento.csv" en la carpeta de salida.
#
#   En el PC (ventana fuera de pantalla, sin robar el foco):
#     godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/medir_rendimiento.tscn -- C:/capturas
#   En la nube (sin tarjeta gráfica: los FPS no valen, las llamadas y los objetos sí):
#     xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/medir_rendimiento.tscn -- /carpeta
# -----------------------------------------------------------------------------
extends Node

const SEGUNDOS_POR_SITIO: float = 6.0   # Tiempo para que carguen los trozos antes de medir.
const SEGUNDOS_MEDIDA: float = 3.0

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var filas: Array = []


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _ir(pos: Vector3, giro: float, incl: float) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
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
	var vidas: Array = escena.find_children("*", "VidaUrbana", true, false)
	vida = vidas[0] if vidas.size() > 0 else null
	J.velocidad_tiempo = 0.0
	var sitios: Array = [["plaza_original", Vector3(2.0, 1.0, 22.0), 0.6, -0.1, false]]
	var vistos: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		var tipo: int = int(s["tipo"])
		var monte: bool = bool(s.get("montana", false))
		var etiqueta: String = "montana" if monte else ["aldea", "pueblo", "ciudad"][clampi(tipo, 0, 2)]
		if vistos.has(etiqueta):
			continue
		vistos[etiqueta] = true
		var p: Vector2 = s["pos"]
		var h: float = GeneradorMundo.altura(p.x, p.y)
		sitios.append(["%s_%s" % [etiqueta, str(s.get("nombre", ""))], Vector3(p.x + 2.0, h + 1.2, p.y + 24.0), 0.6, -0.08, false])
	sitios.append(["aerea_ciudad_300m", Vector3(0.0, 300.0, 300.0), 0.0, -0.7, true])
	for hora in [12.0, 23.0]:
		J.hora = hora
		for st in sitios:
			J.modo_volar = bool(st[4])
			_ir(st[1], st[2], st[3])
			await _esperar(SEGUNDOS_POR_SITIO)
			var fila: Dictionary = await _medir("%s_%s" % [st[0], "dia" if hora < 20.0 else "noche"], st)
			filas.append(fila)
			await _foto("rend_" + str(fila["sitio"]))
	_escribir_csv()
	print("RESULTADO: TODO BIEN (", filas.size(), " medidas)")
	get_tree().quit()


func _medir(nombre: String, st: Array) -> Dictionary:
	var fotogramas: int = 0
	var t0: int = Time.get_ticks_usec()
	var peor: float = 0.0
	var ultimo: int = t0
	var llamadas: int = 0
	var objetos: int = 0
	var primitivas: int = 0
	while Time.get_ticks_usec() - t0 < int(SEGUNDOS_MEDIDA * 1000000.0):
		_ir(st[1], st[2], st[3])
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		peor = maxf(peor, (ahora - ultimo) / 1000.0)
		ultimo = ahora
		fotogramas += 1
		llamadas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objetos += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		primitivas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var seg: float = (Time.get_ticks_usec() - t0) / 1000000.0
	var n: int = maxi(1, fotogramas)
	var fila: Dictionary = {
		"sitio": nombre,
		"fps": snappedf(fotogramas / seg, 0.1),
		"ms_medio": snappedf(seg * 1000.0 / n, 0.01),
		"ms_peor": snappedf(peor, 0.01),
		"llamadas": llamadas / n,
		"objetos": objetos / n,
		"primitivas": primitivas / n,
		"nodos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"mem_video_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"mem_sistema_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"peatones": vida._peatones.filter(func(q): return is_instance_valid(q)).size() if vida != null and "_peatones" in vida else -1,
		"fisica_activos": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
	}
	print("  ", fila)
	return fila


func _escribir_csv() -> void:
	var f: FileAccess = FileAccess.open("%s/rendimiento.csv" % carpeta, FileAccess.WRITE)
	if f == null or filas.is_empty():
		return
	var claves: Array = (filas[0] as Dictionary).keys()
	f.store_line(",".join(PackedStringArray(claves.map(func(k): return str(k)))))
	for fila in filas:
		f.store_line(",".join(PackedStringArray(claves.map(func(k): return str(fila[k])))))
	f.close()
