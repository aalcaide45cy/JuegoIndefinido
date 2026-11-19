# barrio_plaza.gd
# -----------------------------------------------------------------------------
# Primer barrio: la Plaza del Ahorcado. Una plaza cuadrada de 40 x 40 metros
# rodeada de casas, con una fuente seca en el centro y farolas.
#   - Norte: la herboristería, donde se compra todo (se entra andando).
#   - Este:  la casa con el cartel SE ALQUILA, que puede ser tu escondite.
#   - Oeste: la ferretería. Sur: la armería.
#   - Tres calles salen de la plaza: norte (Mercado), este (Barrio Residencial)
#     y sur (Zona Industrial).
#
# El centro de la plaza es el punto (0, 0, 0). El norte es -Z.
# -----------------------------------------------------------------------------
class_name BarrioPlaza
extends Barrio

const Propiedades = preload("res://scripts/datos/propiedades.gd")

const MITAD: float = 20.0   # La plaza va de -20 a 20 en X y en Z.
const FONDO_CASAS: float = 8.0
const ANCHO_HERBORISTERIA: float = 10.0
const ANCHO_VIVIENDA: float = 10.0
const ANCHO_TIENDA: float = 10.0


func construir() -> void:
	# Semilla fija: las casas salen siempre iguales (cámbiala para otra plaza).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1666

	_suelo()

	# Casas alrededor, con huecos para la herboristería (norte) y tu casa (este).
	var e: float = MITAD + FONDO_CASAS
	var h: float = ANCHO_HERBORISTERIA / 2.0
	var v: float = ANCHO_VIVIENDA / 2.0
	# Calles que salen de la plaza (de 8 m de ancho): al norte hacia el Mercado,
	# al este hacia el barrio residencial y al sur hacia la zona industrial.
	var calle_norte: Vector2 = Vector2(12.0, 20.0)      # En X (fila norte).
	var calle_sur: Vector2 = Vector2(12.0, 20.0)        # En -X (la fila sur está girada).
	var calle_este: Vector2 = Vector2(-20.0, -12.0)     # En Z (fila este).
	fila_con_huecos(Vector3(0, 0, -MITAD), 0.0, -e, e,
			[Vector2(-h, h), calle_norte], FONDO_CASAS, rng)
	var t: float = ANCHO_TIENDA / 2.0
	fila_con_huecos(Vector3(0, 0, MITAD), PI, -e, e,
			[Vector2(-t, t), calle_sur], FONDO_CASAS, rng)
	fila_con_huecos(Vector3(MITAD, 0, 0), -PI / 2.0, -MITAD, MITAD,
			[Vector2(-v, v), calle_este], FONDO_CASAS, rng)
	fila_con_huecos(Vector3(-MITAD, 0, 0), PI / 2.0, -MITAD, MITAD,
			[Vector2(-t, t)], FONDO_CASAS, rng)
	# Asfalto de las tres salidas.
	calle(Vector3(16, 0, -MITAD - 4), 8.0, 8.0, false)
	calle(Vector3(MITAD + 4, 0, -16), 8.0, 8.0, true)
	calle(Vector3(-16, 0, MITAD + 4), 8.0, 8.0, false)

	_herboristeria()
	vivienda("plaza", int(Propiedades.ficha("plaza")["alquiler"]), Vector3(MITAD, 0, 0), -PI / 2.0)
	tienda_con_interior(Vector3(-MITAD, 0, 0), PI / 2.0, "FERRETERÍA  Clavo y Martillo", "ferreteria",
			"Ferretería Clavo y Martillo", "Hablar con el ferretero (comprar)", Color(1.0, 0.8, 0.4))
	tienda_con_interior(Vector3(0, 0, MITAD), PI, "ARMERÍA  El Último Recurso", "armeria",
			"Armería El Último Recurso", "Hablar con el armero (comprar)", Color(1.0, 0.5, 0.4))
	_fuente()
	var inmo: InmobiliariaMostrador = InmobiliariaMostrador.new()
	inmo.position = Vector3(-7.5, 0, -9)   # (A (-10,-10) tapaba el camino de patrulla de los guardias por la plaza.)
	add_child(inmo)
	registrar_poi(inmo, "Inmobiliaria", Color(0.5, 0.75, 1.0))
	var bolsa: OficinaEmpleo = OficinaEmpleo.new()
	bolsa.position = Vector3(7.5, 0, -9)   # (A (-6.5,-12.5) tapaba el camino de patrulla de los guardias.)
	add_child(bolsa)
	registrar_poi(bolsa, "Bolsa de trabajo", Color(1.0, 0.9, 0.5))
	_decorar_plaza()
	_adornos()
	_guardia([Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)])

	farola(Vector3(-10, 0, -10))
	farola(Vector3(10, 0, -10))
	farola(Vector3(-10, 0, 10))
	farola(Vector3(10, 0, 12))

	# Cartel del Prefecto en la pared oeste: la magia está prohibida.
	var cartel: Label3D = Construir.texto(self, Vector3(-MITAD + 0.12, 2.2, 12),
			"POR DECRETO DEL PREFECTO\nQueda prohibida toda magia,\nalquimia y brebaje.\nSe pagan 50 $ por cada bruja.",
			80, Color(0.85, 0.8, 0.65))
	cartel.rotation.y = PI / 2.0


# El suelo va en baldosas de 20 x 20 m: así cada trozo solo recibe la luz de
# las farolas cercanas (el renderizador Compatibilidad limita las luces por objeto).
func _suelo() -> void:
	for ix in range(-2, 2):
		for iz in range(-2, 2):
			Construir.caja(self, Vector3(ix * 20 + 10, -0.1, iz * 20 + 10), Vector3(20, 0.2, 20),
					Color(0.27, 0.25, 0.24))
	# Un "camino" algo más claro que cruza la plaza.
	Construir.caja(self, Vector3(0, 0.005, 0), Vector3(4, 0.01, 2 * MITAD), Color(0.34, 0.31, 0.28), false)
	Construir.caja(self, Vector3(10, 0.006, 0), Vector3(20, 0.01, 4), Color(0.34, 0.31, 0.28), false)


# ------------------------------ La herboristería ------------------------------

func _herboristeria() -> void:
	# Fachada en z = -20 mirando al sur (ángulo 0). Puerta en medio y dos escaparates.
	var huecos: Array = [
		{"x": 0.0, "ancho": 1.6, "abajo": 0.0, "arriba": 2.5},
		{"x": -3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
		{"x": 3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
	]
	var tienda: Node3D = edificio_visitable(Vector3(0, 0, -MITAD), 0.0, ANCHO_HERBORISTERIA, FONDO_CASAS, 9.0,
			Color(0.2, 0.24, 0.2), Color(0.35, 0.3, 0.22), huecos)
	cartel_tienda(tienda, "HERBORISTERÍA  La Mandrágora Honrada", Color(0.6, 0.9, 0.6))
	registrar_poi(tienda, "Herboristería", Color(0.6, 0.9, 0.6))
	Construir.luz_noche(tienda, Vector3(0, 2.9, 1.2), Color(0.5, 1.0, 0.6), 1.0, 6.0)

	# Dentro: luz cálida, mostrador con el herbolario y estanterías de frascos.
	Construir.luz(tienda, Vector3(0, 3.0, -4.0), Color(1.0, 0.8, 0.5), 1.4, 8.0)
	Construir.caja(tienda, Vector3(0, 0.5, -5.2), Vector3(5.0, 1.0, 0.7), Color(0.3, 0.2, 0.13))
	var tendero: Tendero = Tendero.new()
	tendero.position = Vector3(0, 1.0, -5.2)
	tienda.add_child(tendero)
	Construir.texto(tienda, Vector3(0, 1.25, -4.78), "Pulsa E para comprar", 32, Color(1, 0.92, 0.6))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for fila in 4:
		var y: float = 0.6 + fila * 0.55
		Construir.caja(tienda, Vector3(0, y, -7.6), Vector3(8.0, 0.05, 0.45), Color(0.25, 0.17, 0.11), false)
		for i in 12:
			var color: Color = Color.from_hsv(rng.randf(), 0.5, 0.6)
			Construir.cilindro(tienda, Vector3(-3.6 + i * 0.65, y + 0.15, -7.6), 0.08, 0.25, color, false, 0.6)
	# Sacos de tierra y abono junto a la pared (decoración).
	for i in 3:
		Construir.caja(tienda, Vector3(-4.2, 0.3, -1.5 - i * 0.8), Vector3(0.7, 0.6, 0.5), Color(0.4, 0.32, 0.2))
		Construir.caja(tienda, Vector3(4.2, 0.3, -1.5 - i * 0.8), Vector3(0.7, 0.6, 0.5), Color(0.3, 0.25, 0.2))
	# Ramos de hierbas colgando del techo.
	for i in 5:
		Construir.cilindro(tienda, Vector3(-3 + i * 1.5, 2.9, -3.0), 0.12, 0.5,
				Color(0.3, 0.45, 0.25), false, 0.0, 0.02)
	decorar_tienda(tienda)


# Objetos sueltos por la plaza (del kit "Fantasy Props" y "Medieval Village"):
# bancos junto a la fuente, un carro, barriles, cajas y un puesto de mercado.
func _decorar_plaza() -> void:
	for p in [Vector3(5, 0, 5), Vector3(-5, 0, 5), Vector3(5, 0, -5), Vector3(-5, 0, -5)]:
		prop(self, "Bench", p, atan2(-p.x, -p.z), 1.0, true)
	Assets.colocar_solido(self, PUEBLO + "Prop_Wagon", Vector3(-14, 0, 13), 0.5)
	for i in 3:
		prop(self, "Barrel", Vector3(14 + i * 0.8, 0, 15), i, 1.0, true)
	prop(self, "Crate_Wooden", Vector3(-15, 0, -14), 0.2, 1.0, true)
	prop(self, "Crate_Wooden", Vector3(-15, 0, -12.7), 0.6, 1.0, true)
	prop(self, "Stall_Empty", Vector3(-14, 0, -3), PI / 2.0, 1.0, true)
	prop(self, "Stall_Empty", Vector3(14, 0, 4), -PI / 2.0, 1.0, true)
	prop(self, "Dummy", Vector3(10, 0, 8), -PI / 2.0, 1.0, true)


# Un guardia del Prefecto que patrulla la plaza de noche (puntos en coordenadas de la plaza).
func _guardia(puntos: Array) -> void:
	var guardia: Guardia = Guardia.new()
	var ruta: Array[Vector3] = []
	for p in puntos:
		ruta.append(to_global(p))
	guardia.ruta = ruta
	add_child(guardia)


func _fuente() -> void:
	# Fuente de tres pisos con agua que brilla un poco (el agua mágica está prohibida, pero ahí sigue).
	Construir.cilindro(self, Vector3(0, 0.11, 0), 4.0, 0.22, Color(0.36, 0.35, 0.37), false)       # Grada baja
	Construir.cilindro(self, Vector3(0, 0.55, 0), 3.4, 0.9, Color(0.5, 0.5, 0.53), true)          # Muro de la pila
	Construir.cilindro(self, Vector3(0, 1.05, 0), 3.65, 0.14, Color(0.62, 0.62, 0.65), false)      # Borde
	var agua: MeshInstance3D = _agua(3.3, 0.04, Vector3(0, 0.92, 0))
	Construir.cilindro(self, Vector3(0, 0.7, 0), 0.8, 0.8, Color(0.48, 0.48, 0.5), false)         # Pie 1
	Construir.cilindro(self, Vector3(0, 1.62, 0), 1.9, 0.14, Color(0.6, 0.6, 0.63), false, 0.0, 1.6)   # Plato 1
	Construir.cilindro(self, Vector3(0, 1.82, 0), 1.6, 0.26, Color(0.5, 0.5, 0.53), false, 0.0, 1.3)
	_agua(1.3, 0.03, Vector3(0, 1.98, 0))
	Construir.cilindro(self, Vector3(0, 2.5, 0), 0.32, 1.1, Color(0.46, 0.46, 0.5), false)         # Pie 2
	Construir.cilindro(self, Vector3(0, 3.15, 0), 1.0, 0.12, Color(0.6, 0.6, 0.63), false, 0.0, 0.85)   # Plato 2
	_agua(0.85, 0.03, Vector3(0, 3.22, 0))
	# Colisión de toda la fuente: un cilindro macizo.
	var cuerpo: StaticBody3D = StaticBody3D.new()
	var choque: CollisionShape3D = CollisionShape3D.new()
	var forma: CylinderShape3D = CylinderShape3D.new()
	forma.radius = 3.7
	forma.height = 1.2
	choque.shape = forma
	cuerpo.position = Vector3(0, 0.6, 0)
	cuerpo.add_child(choque)
	add_child(cuerpo)
	# Una estatua del último alquimista sobre el plato de arriba: capa, cabeza y sombrero de pico.
	Construir.cilindro(self, Vector3(0, 3.9, 0), 0.5, 1.3, Color(0.52, 0.52, 0.56), false, 0.0, 0.28)
	Construir.esfera(self, Vector3(0, 4.75, 0), 0.24, Color(0.58, 0.58, 0.62))
	Construir.cilindro(self, Vector3(0, 4.98, 0), 0.4, 0.06, Color(0.5, 0.5, 0.54), false)
	Construir.cilindro(self, Vector3(0, 5.27, 0), 0.25, 0.55, Color(0.46, 0.46, 0.5), false, 0.0, 0.0)
	Construir.cilindro(self, Vector3(0.45, 4.4, 0), 0.05, 0.9, Color(0.44, 0.44, 0.48), false, 0.0)  # Bastón
	Construir.esfera(self, Vector3(0.45, 4.9, 0), 0.12, Color(0.4, 0.8, 0.9), Vector3.ONE, 1.6)      # Cristal que brilla
	# Chorros de agua que caen de plato en plato.
	_chorro(Vector3(0, 3.4, 0), 0.0, Vector3(0, 2.6, 0))
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		_chorro(Vector3(cos(a) * 1.55, 2.0, sin(a) * 1.55), a, Vector3(cos(a), 0.9, sin(a)))
	# Luz azulada bajo el agua (solo de noche) y sonido de agua corriendo.
	Construir.luz_noche(self, Vector3(0, 1.4, 0), Color(0.4, 0.75, 1.0), 1.1, 8.0)
	var sonido: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sonido.stream = Sonido.fuente()
	sonido.unit_size = 5.0
	sonido.max_distance = 30.0
	sonido.volume_db = -4.0
	sonido.autoplay = true
	sonido.position = Vector3(0, 1.5, 0)
	add_child(sonido)
	Construir.texto(self, Vector3(0, 0.55, 3.72), "Aquí ardió el último alquimista. Dicen que el agua aún guarda su magia.",
			36, Color(0.8, 0.82, 0.85))


# Un disco de agua semitransparente que brilla suavemente.
func _agua(radio: float, alto: float, pos: Vector3) -> MeshInstance3D:
	var malla: CylinderMesh = CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = alto
	malla.radial_segments = 20
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.62, 0.8, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 0.55)
	mat.emission_energy_multiplier = 0.7
	malla.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = malla
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# Partículas de agua: salen en la dirección indicada y caen por la gravedad.
func _chorro(pos: Vector3, _giro: float, dir: Vector3) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = 0.9
	p.direction = dir.normalized()
	p.spread = 10.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0, -7.0, 0)
	p.local_coords = true
	var malla: SphereMesh = SphereMesh.new()
	malla.radius = 0.05
	malla.height = 0.1
	malla.radial_segments = 6
	malla.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 0.9)
	mat.emission_energy_multiplier = 0.8
	malla.material = mat
	p.mesh = malla
	add_child(p)


# Árboles, parterres y luces de fiesta: la plaza deja de estar pelada.
func _adornos() -> void:
	# Círculos de adoquín de distintos tonos alrededor de la fuente (cada uno un pelín más alto).
	var tonos: Array = [[12.5, Color(0.36, 0.33, 0.3)], [10.5, Color(0.5, 0.45, 0.38)],
			[8.2, Color(0.33, 0.3, 0.28)], [7.4, Color(0.55, 0.5, 0.42)], [5.3, Color(0.42, 0.38, 0.34)],
			[4.6, Color(0.6, 0.55, 0.47)]]
	for i in tonos.size():
		Construir.cilindro(self, Vector3(0, 0.02 + i * 0.014, 0), tonos[i][0], 0.012, tonos[i][1], false)
	# Árboles en alcorques de piedra (copas de colores: otoño y cerezo).
	var copas: Array = [Color(0.86, 0.5, 0.14), Color(0.28, 0.55, 0.22), Color(0.9, 0.55, 0.65),
			Color(0.82, 0.62, 0.15), Color(0.2, 0.48, 0.25), Color(0.9, 0.5, 0.58)]
	var sitios: Array = [Vector3(-9, 0, -16.5), Vector3(9, 0, -16.5), Vector3(-9, 0, 16.5), Vector3(9, 0, 16.5),
			Vector3(-16.5, 0, 7.5), Vector3(16.5, 0, -7.5)]
	for i in sitios.size():
		_arbol(sitios[i], copas[i], i)
	# Parterres de flores.
	for pos in [Vector3(-9, 0, 4.5), Vector3(-9, 0, -4.5), Vector3(9, 0, 5.5), Vector3(9, 0, -5.5)]:
		_parterre(pos)
	# Guirnaldas de bombillas de lado a lado de la plaza (de noche brillan).
	_guirnalda(-6.0)
	_guirnalda(6.5)


func _arbol(pos: Vector3, copa: Color, n: int) -> void:
	Construir.cilindro(self, pos + Vector3(0, 0.2, 0), 1.0, 0.4, Color(0.45, 0.44, 0.46), true)
	Construir.cilindro(self, pos + Vector3(0, 0.42, 0), 0.85, 0.05, Color(0.28, 0.2, 0.14), false)
	Construir.cilindro(self, pos + Vector3(0, 1.4, 0), 0.22, 2.0, Color(0.38, 0.25, 0.15), false, 0.0, 0.14)
	var y: float = 2.2
	Construir.cilindro(self, pos + Vector3(0, y + 0.4, 0), 1.6, 0.8, copa.darkened(0.08), false, 0.0, 1.95)
	Construir.cilindro(self, pos + Vector3(0, y + 1.2, 0), 1.95, 0.8, copa.lightened(0.06), false, 0.0, 1.25)
	Construir.cilindro(self, pos + Vector3(0, y + 1.95, 0), 1.25, 0.8, copa.lightened(0.14), false, 0.0, 0.0)
	# Pétalos / hojas caídas alrededor.
	for i in 6:
		var a: float = float(n * 7 + i) * 1.1
		Construir.caja(self, pos + Vector3(cos(a) * (1.3 + 0.3 * i), 0.03, sin(a) * (1.3 + 0.3 * i)),
				Vector3(0.18, 0.01, 0.18), copa.lightened(0.1), false)


func _parterre(pos: Vector3) -> void:
	Construir.caja(self, pos + Vector3(0, 0.25, 0), Vector3(3.2, 0.5, 1.2), Color(0.5, 0.48, 0.46), true)
	Construir.caja(self, pos + Vector3(0, 0.52, 0), Vector3(2.9, 0.06, 0.9), Color(0.2, 0.14, 0.1), false)
	var cols: Array = [Color(0.9, 0.25, 0.3), Color(0.95, 0.8, 0.25), Color(0.75, 0.4, 0.9), Color(0.95, 0.95, 0.9)]
	for i in 7:
		var x: float = -1.2 + i * 0.4
		for dz in [-0.25, 0.25]:
			Construir.caja(self, pos + Vector3(x, 0.7, dz + 0.04 * (i % 2)), Vector3(0.24, 0.24, 0.24), cols[(i + int(dz * 8)) % 4], false)
			Construir.caja(self, pos + Vector3(x, 0.58, dz + 0.04 * (i % 2)), Vector3(0.04, 0.2, 0.04), Color(0.2, 0.5, 0.22), false)


func _guirnalda(z: float) -> void:
	var colores: Array = [Color(1.0, 0.8, 0.4), Color(1.0, 0.5, 0.4), Color(0.6, 0.85, 1.0), Color(0.7, 1.0, 0.6)]
	var n: int = 24
	var alto_extremo: float = 6.4
	var caida: float = 1.6
	var anterior: Vector3 = Vector3(-19.7, alto_extremo, z)
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var x: float = lerpf(-19.7, 19.7, t)
		var y: float = alto_extremo - caida * 4.0 * t * (1.0 - t)
		var actual: Vector3 = Vector3(x, y, z)
		# Tramo de cable: una caja fina orientada entre los dos puntos.
		var medio: Vector3 = (anterior + actual) / 2.0
		var cable: Node3D = Construir.caja(self, medio, Vector3(anterior.distance_to(actual), 0.02, 0.02), Color(0.1, 0.1, 0.1), false)
		cable.rotation.z = atan2(actual.y - anterior.y, actual.x - anterior.x)
		if i % 2 == 0 and i < n:
			var b: Node3D = Construir.esfera(self, actual + Vector3(0, -0.12, 0), 0.1, colores[(i / 2) % 4],
					Vector3.ONE, 3.0)
			b.visible = false
			b.add_to_group("ventanas_noche")
			Construir.esfera(self, actual + Vector3(0, -0.12, 0), 0.08, Color(0.3, 0.3, 0.3))
		anterior = actual
