# gestor_trozos.gd
# -----------------------------------------------------------------------------
# Carga y descarga el mundo grande (10 km x 10 km) por trozos mientras el
# jugador se mueve. Dos capas:
#   - CERCA: trozos de 128 m con terreno de 4 m, choques, carreteras, casas,
#     huertos y árboles. Radio de unos 580 m alrededor del jugador.
#   - LEJOS: trozos de 512 m solo para verse (terreno de 16 m, carreteras y
#     casas en cajas). Radio de unos 2,3 km. Se esconden cuando los trozos
#     cercanos que tapan ya están cargados.
# La generación pesada (ruido, mallas) corre en hilos de WorkerThreadPool y
# el montaje de nodos se hace en el hilo principal, con un máximo por
# fotograma para que no haya tirones. Ver generador_mundo.gd.
#
# Seguridad: un muro invisible en el borde del mundo y, si el jugador cae bajo
# el terreno (el trozo aún no tenía choque), se le sube a la superficie.
# SIN PROBAR en Godot. Si algo falla con hilos, pon USAR_HILOS = false.
# -----------------------------------------------------------------------------
class_name GestorTrozos
extends Node3D

const SEMILLA: int = 1847
const RADIO_CERCA: float = 4.5      # En trozos de 128 m.
const RADIO_LEJOS: float = 4.5      # En trozos de 512 m.
const MAX_TAREAS: int = 4           # Trozos generándose a la vez.
const MAX_MONTAJES: int = 2         # Trozos montados por fotograma.
const USAR_HILOS: bool = true
const BAJAR_LEJOS: float = 2.0      # El terreno lejano va un poco por debajo del cercano.
const DIST_ARBOLES: float = 650.0

# Rectángulo de la ciudad original (lo pone mundo.gd antes de añadir el gestor).
var nucleo: Rect2 = Rect2(-110.0, -120.0, 440.0, 240.0)

var _jugador: Node3D
var _cerca: Dictionary = {}       # Vector2i -> Node3D
var _lejos: Dictionary = {}
var _en_trabajo: Dictionary = {}  # "n:x:z" o "l:x:z" -> true
var _listos: Array = []
var _mutex: Mutex = Mutex.new()
var _cola: Array = []
var _material: StandardMaterial3D
var _malla_arbol: ArrayMesh
var _mallas_veg: Array = []   # Roble, arbusto, roca y flores (ver GeneradorMundo._vegetacion).
var _forma_tronco: CylinderShape3D = _crear_forma_tronco()
var _t_busca: float = 0.0
var _t_suelo: float = 0.0


func _ready() -> void:
	GeneradorMundo.iniciar(SEMILLA, nucleo)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED   # (Seguro: si algún día se prueba el orden de caras, se puede cambiar.)
	_material.roughness = 1.0
	_malla_arbol = _crear_malla_arbol()
	_mallas_veg = _crear_mallas_vegetacion()
	_muros_del_borde()
	print("Mundo grande listo: semilla %d, %d asentamientos." % [SEMILLA, GeneradorMundo.todos_asentamientos().size()])


func _crear_forma_tronco() -> CylinderShape3D:
	var f: CylinderShape3D = CylinderShape3D.new()
	f.radius = 0.45
	f.height = 2.4
	return f


func _crear_malla_arbol() -> ArrayMesh:
	var mb: ConstructorMalla = ConstructorMalla.new()
	mb.caja(Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), Color(0.3, 0.2, 0.12))
	mb.cono(Vector3(0, 1.6, 0), 2.0, 3.2, 7, Color(0.1, 0.3, 0.12))
	mb.cono(Vector3(0, 3.6, 0), 1.5, 2.8, 7, Color(0.12, 0.35, 0.14))
	mb.cono(Vector3(0, 5.4, 0), 1.0, 2.4, 7, Color(0.14, 0.4, 0.16))
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.superficie())
	m.surface_set_material(0, _material)
	return m


func _malla_de(mb: ConstructorMalla) -> ArrayMesh:
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.superficie())
	m.surface_set_material(0, _material)
	return m


func _crear_mallas_vegetacion() -> Array:
	var out: Array = []
	# Roble: tronco grueso y copa redonda hecha de conos aplastados.
	var mb: ConstructorMalla = ConstructorMalla.new()
	mb.caja(Vector3(0, 1.3, 0), Vector3(0.7, 2.6, 0.7), Color(0.34, 0.24, 0.15))
	mb.cono(Vector3(0, 2.2, 0), 3.0, 1.8, 8, Color(0.26, 0.46, 0.16), 2.2)
	mb.cono(Vector3(0, 4.0, 0), 2.2, 1.8, 8, Color(0.3, 0.5, 0.18), 0.4)
	out.append(_malla_de(mb))
	# Arbusto: dos montículos verdes.
	mb = ConstructorMalla.new()
	mb.cono(Vector3(0, 0, 0), 0.9, 0.8, 7, Color(0.2, 0.4, 0.15), 0.3)
	mb.cono(Vector3(0.5, 0, 0.3), 0.6, 0.6, 6, Color(0.25, 0.45, 0.17), 0.2)
	out.append(_malla_de(mb))
	# Roca: piedra irregular.
	mb = ConstructorMalla.new()
	mb.cono(Vector3(0, 0, 0), 1.1, 0.9, 6, Color(0.45, 0.44, 0.42), 0.5)
	mb.cono(Vector3(0.6, 0, -0.3), 0.6, 0.5, 5, Color(0.38, 0.37, 0.36), 0.25)
	out.append(_malla_de(mb))
	# Flores: tallos con cabezas de colores.
	mb = ConstructorMalla.new()
	mb.caja(Vector3(0, 0.15, 0), Vector3(0.05, 0.3, 0.05), Color(0.2, 0.4, 0.15))
	mb.caja(Vector3(0, 0.33, 0), Vector3(0.22, 0.1, 0.22), Color(0.9, 0.8, 0.2))
	mb.caja(Vector3(0.3, 0.12, 0.2), Vector3(0.05, 0.24, 0.05), Color(0.2, 0.4, 0.15))
	mb.caja(Vector3(0.3, 0.27, 0.2), Vector3(0.2, 0.09, 0.2), Color(0.85, 0.35, 0.55))
	mb.caja(Vector3(-0.25, 0.1, 0.25), Vector3(0.05, 0.2, 0.05), Color(0.2, 0.4, 0.15))
	mb.caja(Vector3(-0.25, 0.23, 0.25), Vector3(0.2, 0.09, 0.2), Color(0.95, 0.95, 0.95))
	out.append(_malla_de(mb))
	return out


# Cuatro muros invisibles y altos en el borde del mundo.
func _muros_del_borde() -> void:
	var m: float = GeneradorMundo.MITAD
	var grueso: float = 40.0
	var largo: float = m * 2.0 + grueso * 2.0
	var alto: float = 600.0
	var piezas: Array = [
		[Vector3(0, 0, -m - grueso / 2.0), Vector3(largo, alto, grueso)],
		[Vector3(0, 0, m + grueso / 2.0), Vector3(largo, alto, grueso)],
		[Vector3(-m - grueso / 2.0, 0, 0), Vector3(grueso, alto, largo)],
		[Vector3(m + grueso / 2.0, 0, 0), Vector3(grueso, alto, largo)],
	]
	for pz in piezas:
		var cuerpo: StaticBody3D = StaticBody3D.new()
		cuerpo.position = pz[0]
		var forma: BoxShape3D = BoxShape3D.new()
		forma.size = pz[1]
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = forma
		cuerpo.add_child(cs)
		add_child(cuerpo)


func _process(delta: float) -> void:
	# Los cultivos crecen aunque el huerto esté lejos y su trozo descargado.
	for id in Juego.parcelas:
		var e: Dictionary = Juego.parcelas[id]
		e["t"] = maxf(0.0, float(e["t"]) - delta * Clima.crecimiento())   # La lluvia acelera los cultivos.
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return
	_t_busca -= delta
	if _t_busca <= 0.0:
		_t_busca = 0.3
		_planificar()
	_lanzar_trabajos()
	_montar_listos()
	_t_suelo -= delta
	if _t_suelo <= 0.0:
		_t_suelo = 0.5
		_vigilar_suelo()


# ------------------------------ qué hay que cargar ------------------------------

func _clave(lejos: bool, c: Vector2i) -> String:
	return "%s:%d:%d" % ["l" if lejos else "n", c.x, c.y]


func _planificar() -> void:
	var p: Vector3 = _jugador.global_position
	_cola.clear()
	_pedir(false, GeneradorMundo.TROZO, RADIO_CERCA, p, _cerca)
	_pedir(true, GeneradorMundo.TROZO_LEJOS, RADIO_LEJOS, p, _lejos)
	_cola.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# Descarga lo que quedó atrás.
	var cambiado: bool = false
	cambiado = _descargar(_cerca, GeneradorMundo.TROZO, RADIO_CERCA + 1.5, p) or cambiado
	_descargar(_lejos, GeneradorMundo.TROZO_LEJOS, RADIO_LEJOS + 1.5, p)
	if cambiado:
		_actualizar_lejos_visibles()


func _pedir(lejos: bool, tam: float, radio: float, p: Vector3, cargados: Dictionary) -> void:
	var cx: int = floori(p.x / tam)
	var cz: int = floori(p.z / tam)
	var r: int = ceili(radio)
	var limite: int = ceili(GeneradorMundo.MITAD / tam)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = Vector2i(cx + dx, cz + dz)
			if c.x < -limite or c.x >= limite or c.y < -limite or c.y >= limite:
				continue
			var d2: float = float(dx * dx + dz * dz)
			if d2 > radio * radio:
				continue
			if cargados.has(c) or _en_trabajo.has(_clave(lejos, c)):
				continue
			# Los cercanos pasan por delante de los lejanos (se les resta distancia).
			_cola.append([d2 * (1.0 if not lejos else 16.0) + (0.0 if not lejos else 400.0), lejos, c])


func _descargar(cargados: Dictionary, tam: float, radio: float, p: Vector3) -> bool:
	var quitar: Array = []
	for c in cargados:
		var cc: Vector2i = c
		var dx: float = (cc.x + 0.5) - p.x / tam
		var dz: float = (cc.y + 0.5) - p.z / tam
		if dx * dx + dz * dz > radio * radio:
			quitar.append(cc)
	for cc in quitar:
		var nodo: Node = cargados[cc]
		if is_instance_valid(nodo):
			nodo.queue_free()
		cargados.erase(cc)
	return not quitar.is_empty()


func _lanzar_trabajos() -> void:
	while _en_trabajo.size() < MAX_TAREAS and not _cola.is_empty():
		var item: Array = _cola.pop_front()
		var lejos: bool = item[1]
		var c: Vector2i = item[2]
		_en_trabajo[_clave(lejos, c)] = true
		if USAR_HILOS:
			WorkerThreadPool.add_task(_trabajo.bind(lejos, c))
		else:
			_trabajo(lejos, c)
			return   # Sin hilos: uno por fotograma.


# Esto corre en un hilo: solo toca datos, nunca nodos.
func _trabajo(lejos: bool, c: Vector2i) -> void:
	var datos: Dictionary = GeneradorMundo.generar_lejano(c) if lejos else GeneradorMundo.generar_cercano(c)
	_mutex.lock()
	_listos.append({"lejos": lejos, "c": c, "d": datos})
	_mutex.unlock()


func _montar_listos() -> void:
	for i in MAX_MONTAJES:
		_mutex.lock()
		var item: Variant = _listos.pop_front() if not _listos.is_empty() else null
		_mutex.unlock()
		if item == null:
			return
		var lejos: bool = item["lejos"]
		var c: Vector2i = item["c"]
		_en_trabajo.erase(_clave(lejos, c))
		if not _sigue_haciendo_falta(lejos, c):
			continue
		if lejos:
			_montar_lejos(c, item["d"])
			_actualizar_lejos_visibles()
		else:
			_montar_cerca(c, item["d"])
			_actualizar_lejos_visibles()


func _sigue_haciendo_falta(lejos: bool, c: Vector2i) -> bool:
	var tam: float = GeneradorMundo.TROZO_LEJOS if lejos else GeneradorMundo.TROZO
	var radio: float = (RADIO_LEJOS if lejos else RADIO_CERCA) + 1.0
	var p: Vector3 = _jugador.global_position
	var dx: float = (c.x + 0.5) - p.x / tam
	var dz: float = (c.y + 0.5) - p.z / tam
	return dx * dx + dz * dz <= radio * radio


# --------------------------------- montar nodos ---------------------------------

func _malla_desde(superficies: Array) -> ArrayMesh:
	var m: ArrayMesh = ArrayMesh.new()
	for a in superficies:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(m.get_surface_count() - 1, _material)
	return m


func _montar_cerca(c: Vector2i, d: Dictionary) -> void:
	var raiz: Node3D = Node3D.new()
	raiz.name = "Trozo_%d_%d" % [c.x, c.y]
	add_child(raiz)
	_cerca[c] = raiz
	if bool(d.get("vacio", false)):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _malla_desde(d["superficies"])
	raiz.add_child(mi)
	var cuerpo: StaticBody3D = StaticBody3D.new()
	var forma: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(d["caras"])
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	raiz.add_child(cuerpo)
	var buf: PackedFloat32Array = d["arboles"]
	if buf.size() >= 12:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _malla_arbol
		mm.instance_count = buf.size() / 12
		mm.buffer = buf
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = DIST_ARBOLES
		raiz.add_child(mmi)
		# Choque de los troncos: un solo cuerpo por trozo con un cilindro por árbol (se comparte la forma).
		var troncos: StaticBody3D = StaticBody3D.new()
		for i in buf.size() / 12:
			var cs_t: CollisionShape3D = CollisionShape3D.new()
			cs_t.shape = _forma_tronco
			cs_t.position = Vector3(buf[i * 12 + 3], buf[i * 12 + 7] + 1.2, buf[i * 12 + 11])
			troncos.add_child(cs_t)
		raiz.add_child(troncos)
	var veg: Array = d.get("veg", [])
	for t in veg.size():
		var b2: PackedFloat32Array = veg[t]
		if b2.size() < 12:
			continue
		var mm2: MultiMesh = MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.mesh = _mallas_veg[t]
		mm2.instance_count = b2.size() / 12
		mm2.buffer = b2
		var mmi2: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi2.multimesh = mm2
		mmi2.visibility_range_end = DIST_ARBOLES if t == 0 else (260.0 if t == 2 else 150.0)
		raiz.add_child(mmi2)
		if t == 0:   # Los robles tienen tronco con choque (como los pinos).
			var troncos2: StaticBody3D = StaticBody3D.new()
			for i in b2.size() / 12:
				var cs2: CollisionShape3D = CollisionShape3D.new()
				cs2.shape = _forma_tronco
				cs2.position = Vector3(b2[i * 12 + 3], b2[i * 12 + 7] + 1.2, b2[i * 12 + 11])
				troncos2.add_child(cs2)
			raiz.add_child(troncos2)
	for pr in d["props"]:
		if pr["tipo"] == "servicio":
			var serv: ServicioMundo = ServicioMundo.new()
			serv.servicio = pr["serv"]
			serv.position = pr["pos"]
			raiz.add_child(serv)
		elif pr["tipo"] == "casa":
			var puerta: PropiedadMundo = PropiedadMundo.new()
			puerta.id_prop = pr["id"]
			puerta.position = pr["pos"]
			raiz.add_child(puerta)
		else:
			var parcela: Parcela = Parcela.new()
			parcela.id_huerto = pr["id"]
			parcela.m2 = int(pr["m2"])
			parcela.centro_cultivo = pr["centro"]
			parcela.tam_cultivo = pr["tam"]
			parcela.position = pr["pos"]
			raiz.add_child(parcela)


func _montar_lejos(c: Vector2i, d: Dictionary) -> void:
	var raiz: Node3D = Node3D.new()
	raiz.name = "Lejos_%d_%d" % [c.x, c.y]
	raiz.position.y = -BAJAR_LEJOS
	add_child(raiz)
	_lejos[c] = raiz
	if bool(d.get("vacio", false)):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _malla_desde(d["superficies"])
	raiz.add_child(mi)


# Un trozo lejano se esconde si los 16 trozos cercanos que cubre ya están cargados.
func _actualizar_lejos_visibles() -> void:
	var razon: int = int(GeneradorMundo.TROZO_LEJOS / GeneradorMundo.TROZO)
	var limite: int = ceili(GeneradorMundo.MITAD / GeneradorMundo.TROZO)
	for f in _lejos:
		var fc: Vector2i = f
		var todos: bool = true
		for j in razon:
			for i in razon:
				var c: Vector2i = Vector2i(fc.x * razon + i, fc.y * razon + j)
				if c.x < -limite or c.x >= limite or c.y < -limite or c.y >= limite:
					continue
				if not _cerca.has(c):
					todos = false
					break
			if not todos:
				break
		var nodo: Node3D = _lejos[f] as Node3D
		if is_instance_valid(nodo):
			nodo.visible = not todos


# ----------------------------------- seguridad -----------------------------------

# Si el jugador cae por debajo del terreno (su trozo aún no tenía choque), lo sube.
func _vigilar_suelo() -> void:
	var p: Vector3 = _jugador.global_position
	if nucleo.has_point(Vector2(p.x, p.z)):
		return
	if absf(p.x) > GeneradorMundo.MITAD or absf(p.z) > GeneradorMundo.MITAD:
		return
	var h: float = GeneradorMundo.altura(p.x, p.z)
	if p.y < h - 3.0 and p.y > h - 400.0:
		_jugador.global_position = Vector3(p.x, h + 1.5, p.z)
		if "velocity" in _jugador:
			_jugador.set("velocity", Vector3.ZERO)
