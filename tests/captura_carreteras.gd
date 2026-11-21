# Fotos de las carreteras en varios puntos (llanas, de montaña, uniones con pueblos, cambio cerca/lejos).
# Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_carreteras.tscn -- /carpeta prefijo
extends Node

var carpeta: String = "."
var prefijo: String = "x"
var jugador: Node3D
var camara: Camera3D


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


# Pone al jugador en "pos" (para que se carguen los trozos) y la cámara de la foto
# "atras" metros detrás de "pos" mirando hacia "dir", a "alto" metros del suelo.
func _foto(nombre: String, pos: Vector2, dir: Vector2, atras: float, alto: float, cabeceo: float, espera: float = 8.0) -> void:
	var y: float = GeneradorMundo.altura(pos.x, pos.y)
	jugador.global_position = Vector3(pos.x, y + 1.0, pos.y)
	jugador.velocity = Vector3.ZERO
	await _esperar(espera)
	jugador.global_position = Vector3(pos.x, GeneradorMundo.altura(pos.x, pos.y) + 1.0, pos.y)
	jugador.velocity = Vector3.ZERO
	await _esperar(1.0)
	var d: Vector2 = dir.normalized()
	var c: Vector2 = pos - d * atras
	var yc: float = GeneradorMundo.altura(c.x, c.y) + alto
	camara.global_position = Vector3(c.x, yc, c.y)
	camara.look_at(Vector3(pos.x, y, pos.y) + Vector3(0, -alto * (1.0 - cabeceo), 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s_%s.jpg" % [carpeta, prefijo, nombre], 0.9)
	print("FOTO ", nombre, " en ", pos)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	if args.size() > 1:
		prefijo = args[1]
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
	camara = Camera3D.new()
	camara.fov = 65.0
	camara.far = 4000.0
	escena.add_child(camara)
	camara.current = true

	# 1) Carretera llana entre dos pueblos: cruce de un borde de trozo (múltiplo de 128 m).
	var plana: Array = []
	for sg in GeneradorMundo.todas_las_carreteras():
		if int(sg[3]) == 1 and (sg[0] as Vector2).distance_to(sg[1]) > 500.0:
			plana.append(sg)
	var sg1: Array = plana[plana.size() / 3]
	var d1: Vector2 = ((sg1[1] as Vector2) - (sg1[0] as Vector2)).normalized()
	var medio: Vector2 = (sg1[0] as Vector2).lerp(sg1[1], 0.5)
	# Punto del tramo más cercano a un borde de trozo cualquiera.
	var borde: Vector2 = medio
	if absf(d1.x) > 0.3:
		borde.x = round(medio.x / 128.0) * 128.0
		borde.y = (sg1[0] as Vector2).y + (borde.x - (sg1[0] as Vector2).x) * d1.y / d1.x
	else:
		borde.y = round(medio.y / 128.0) * 128.0
		borde.x = (sg1[0] as Vector2).x + (borde.y - (sg1[0] as Vector2).y) * d1.x / d1.y
	print("RUTA llana: ", sg1[0], " -> ", sg1[1], " borde ", borde)
	await _foto("a1_llana_suelo", borde, d1, 22.0, 2.2, 0.0)
	await _foto("a2_llana_aerea", borde, d1, 30.0, 40.0, 0.35, 1.0)
	await _foto("a3_llana_cerca", borde, d1, 9.0, 1.6, 0.0, 1.0)

	# 2) Unión con un pueblo: final de una carretera en la puerta del asentamiento.
	var sg2: Array = plana[plana.size() * 2 / 3]
	var fin: Vector2 = sg2[1]
	var d2: Vector2 = ((sg2[1] as Vector2) - (sg2[0] as Vector2)).normalized()
	await _foto("b1_puerta_pueblo_aerea", fin - d2 * 40.0, d2, 45.0, 55.0, 0.3)
	await _foto("b2_puerta_pueblo_suelo", fin - d2 * 25.0, d2, 18.0, 2.2, 0.0, 1.0)

	# 3) Salidas de la ciudad original.
	for k in GeneradorMundo.conectores.size():
		var seg: Array = GeneradorMundo.conectores[k]["segs"][0]
		var dd: Vector2 = ((seg[1] as Vector2) - (seg[0] as Vector2)).normalized()
		await _foto("c%d_salida_ciudad" % (k + 1), (seg[0] as Vector2) + dd * 12.0, dd, 24.0, 20.0, 0.25, 7.0)

	# 4) Montaña: curva cerrada, puente y túnel.
	var cam0: Dictionary = GeneradorMundo._caminos[0]
	var pts: PackedVector2Array = cam0["pts"]
	var mejor_i: int = 2
	var mejor_a: float = 0.0
	for i in range(2, pts.size() - 2):
		var u: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var v: Vector2 = (pts[i + 1] - pts[i]).normalized()
		var ang: float = absf(u.angle_to(v))
		if ang > mejor_a:
			mejor_a = ang
			mejor_i = i
	var du: Vector2 = (pts[mejor_i + 1] - pts[mejor_i - 1]).normalized()
	print("CURVA: punto ", pts[mejor_i], " ángulo ", rad_to_deg(mejor_a))
	await _foto("d1_montana_curva_suelo", pts[mejor_i], du, 30.0, 3.0, 0.0)
	await _foto("d2_montana_curva_aerea", pts[mejor_i], du, 35.0, 45.0, 0.4, 1.0)
	await _foto("d3_montana_cuesta", pts[pts.size() / 2], (pts[pts.size() / 2 + 1] - pts[pts.size() / 2 - 1]).normalized(), 26.0, 2.6, 0.0)
	# Obras vistas (puente / túnel): hay que generar los trozos antes.
	for c in GeneradorMundo._caminos:
		var vistos: Dictionary = {}
		for q in c["pts"]:
			var ct: Vector2i = Vector2i(floori(q.x / GeneradorMundo.TROZO), floori(q.y / GeneradorMundo.TROZO))
			if not vistos.has(ct):
				vistos[ct] = true
				GeneradorMundo.generar_cercano(ct)
	var primero: Dictionary = {}
	for o in GeneradorMundo.obras_vistas:
		if not primero.has(o[0]):
			primero[o[0]] = o
	for tipo in ["puente", "tunel"]:
		if primero.has(tipo):
			var o: Array = primero[tipo]
			var p: Vector3 = o[1]
			var d: Vector2 = o[2]
			await _foto("e_%s" % tipo, Vector2(p.x, p.z), d, 24.0, 3.0, 0.0)
			await _foto("e_%s_aerea" % tipo, Vector2(p.x, p.z), d, 30.0, 35.0, 0.4, 1.0)

	# 5) Cambio cerca/lejos: vista alta de una carretera larga.
	await _foto("f1_lejos_aerea", medio, d1, 160.0, 260.0, 0.45, 9.0)
	get_tree().quit()
