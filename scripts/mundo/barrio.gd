# barrio.gd
# -----------------------------------------------------------------------------
# Base para un "barrio": un trozo de ciudad que se construye en su propio
# script. La ciudad crece añadiendo barrios uno a uno en mundo.gd, en vez de
# hacer una ciudad enorme de golpe.
#
# Para crear un barrio nuevo:
#   1. Copia barrio_plaza.gd con otro nombre (p. ej. barrio_mercado.gd) y
#      cambia su class_name (p. ej. BarrioMercado).
#   2. Escribe lo que quieras dentro de construir().
#   3. En mundo.gd, añádelo con su posición, por ejemplo:
#        _anadir_barrio(BarrioMercado.new(), Vector3(0, 0, -60))
# -----------------------------------------------------------------------------
class_name Barrio
extends Node3D


func _ready() -> void:
	construir()


# Cada barrio escribe aquí sus edificios, farolas, puertas...
func construir() -> void:
	pass


# Altura de un piso con el kit "Medieval Village" (assets/modelos/pueblo/).
const ALTO_PISO: float = 3.12
const PUEBLO: String = "quaternius/medieval-village-megakit/"
const PROPS: String = "quaternius/fantasy-props-megakit/"


# true si el kit de edificios está descargado (si no, se usan las cajas de siempre).
func hay_kit_pueblo() -> bool:
	return Assets.existe(PUEBLO + "Wall_Plaster_Straight") and Assets.existe(PUEBLO + "Roof_RoundTiles_6x6")


# Elige qué pared modular va en una posición: planta baja de ladrillo, pisos
# de arriba de yeso; puertas solo en la fachada.
func _modulo_pared(piso: int, es_fachada: bool, i: int, puerta_i: int, rng: RandomNumberGenerator) -> String:
	var tipo: String = "UnevenBrick" if piso == 0 else "Plaster"
	if es_fachada and piso == 0 and i == puerta_i:
		return PUEBLO + "Wall_%s_%s" % [tipo, "Door_Round" if rng.randf() < 0.5 else "Door_Flat"]
	var r: float = rng.randf()
	if r < 0.5:
		return PUEBLO + "Wall_%s_Window_Wide_%s" % [tipo, "Round" if rng.randf() < 0.5 else "Flat"]
	if r < 0.75:
		return PUEBLO + "Wall_%s_Window_Thin_Round" % tipo
	return PUEBLO + "Wall_%s_Straight" % tipo


# Una pared hecha con módulos de 2 m. En el nodo "lado" el eje x va a lo largo
# de la pared y +z es hacia fuera. Los módulos se estiran un poco en x para
# cubrir justo "largo" metros.
func _pared_modular(lado: Node3D, largo: float, piso_desde: int, pisos: int,
		es_fachada: bool, puerta_i: int, rng: RandomNumberGenerator) -> void:
	var n: int = maxi(1, roundi(largo / 2.0))
	var estirar: float = largo / (2.0 * n)
	for piso in range(piso_desde, pisos):
		for i in n:
			var nombre: String = _modulo_pared(piso, es_fachada, i, puerta_i, rng)
			var x: float = -largo / 2.0 + (i + 0.5) * (largo / n)
			Assets.colocar_solido(lado, nombre, Vector3(x, piso * ALTO_PISO, 0.0), 0.0,
					Vector3(estirar, 1.0, 1.0), false)
			# Algunas ventanas tienen luz de noche: un cuadro cálido tras el hueco
			# (ciclo_dia.gd lo enciende al anochecer y lo apaga de día).
			if "Window" in nombre and rng.randf() < 0.3:
				var ancho_v: float = 0.45 if "Thin" in nombre else 0.9
				var vela: MeshInstance3D = Construir.caja(lado, Vector3(x, piso * ALTO_PISO + 1.5, -0.15),
						Vector3(ancho_v, 1.0, 0.03), Color(1.0, 0.72, 0.38), false, 1.4) as MeshInstance3D
				vela.visible = false
				vela.add_to_group("ventanas_noche")


# Reviste un edificio con paredes modulares por sus 4 lados. "salida" aleja las
# paredes hacia fuera (para no meterse en habitaciones que ya existen);
# "fachada_desde" es el primer piso con módulos en la fachada.
func revestir(casa: Node3D, ancho: float, fondo: float, pisos: int, rng: RandomNumberGenerator,
		salida: float = 0.0, fachada_desde: int = 0) -> void:
	var puerta_i: int = rng.randi_range(0, maxi(0, roundi(ancho / 2.0) - 1))
	var lados: Array = [
		# [posición, giro, largo, es_fachada]
		[Vector3(0, 0, salida), 0.0, ancho, true],
		[Vector3(0, 0, -fondo - salida), PI, ancho, false],
		[Vector3(ancho / 2.0 + salida, 0, -fondo / 2.0), PI / 2.0, fondo, false],
		[Vector3(-ancho / 2.0 - salida, 0, -fondo / 2.0), -PI / 2.0, fondo, false],
	]
	for l in lados:
		var lado: Node3D = Node3D.new()
		lado.position = l[0]
		lado.rotation.y = l[1]
		casa.add_child(lado)
		_pared_modular(lado, l[2], fachada_desde if l[3] else 0, pisos, l[3], puerta_i, rng)


# Tejado de tejas sobre un edificio (el modelo se estira para cubrir la planta).
func tejado(casa: Node3D, ancho: float, fondo: float, alto: float) -> void:
	var lado_mayor: float = maxf(ancho, fondo)
	var nombre: String = PUEBLO + "Roof_RoundTiles_4x4"
	if lado_mayor > 7.0:
		nombre = PUEBLO + "Roof_RoundTiles_8x8"
	elif lado_mayor > 5.0:
		nombre = PUEBLO + "Roof_RoundTiles_6x6"
	var modelo: Node3D = Assets.modelo(nombre)
	if modelo == null:
		return
	var caja: AABB = Assets.caja_de(modelo)
	var sx: float = (ancho + 0.9) / caja.size.x
	var sz: float = (fondo + 0.9) / caja.size.z
	var sy: float = clampf((sx + sz) / 2.0, 0.7, 1.2)
	modelo.position = Vector3(-caja.get_center().x, 0.0, -caja.get_center().z)
	var contenedor: Node3D = Node3D.new()
	contenedor.add_child(modelo)
	contenedor.scale = Vector3(sx, sy, sz)
	contenedor.position = Vector3(0, alto - caja.position.y * sy, -fondo / 2.0)
	casa.add_child(contenedor)
	# El tejado deja abiertos los triángulos de delante y detrás: los tapamos
	# con un prisma de yeso para que no se vea el cielo por dentro.
	var subida: float = caja.size.y * sy
	var yeso: StandardMaterial3D = Construir.material(Color(0.78, 0.72, 0.6))
	for z in [0.0, -fondo]:
		var prisma: PrismMesh = PrismMesh.new()
		prisma.size = Vector3(ancho + 0.7, subida * 0.93, 0.3)
		prisma.material = yeso
		var instancia: MeshInstance3D = MeshInstance3D.new()
		instancia.mesh = prisma
		instancia.position = Vector3(0, alto + subida * 0.93 / 2.0, z)
		casa.add_child(instancia)


# Pone un objeto del paquete "Fantasy Props" (barril, cofre, vela...). Si el
# modelo no está, no pasa nada. "solido" = el jugador choca con él.
func prop(padre: Node3D, nombre: String, pos: Vector3, giro: float = 0.0, escala: float = 1.0,
		solido: bool = false) -> Node3D:
	return Assets.colocar_solido(padre, PROPS + nombre, pos, giro, Vector3.ONE * escala, solido)


# Decora la herboristería de la plaza (las demás tiendas usan _decorar_tienda,
# que elige los muebles según el tipo de tienda). Pone muebles y objetos del kit de props:
# barriles, cajas, un cofre, una lámpara de araña y velas y pociones en el mostrador.
func decorar_tienda(tienda: Node3D) -> void:
	if not Assets.existe(PROPS + "Barrel"):
		return
	prop(tienda, "Barrel", Vector3(-4.2, 0, -4.3), 0.0, 1.0, true)
	prop(tienda, "Barrel", Vector3(-4.2, 0, -5.3), 0.4, 1.0, true)
	prop(tienda, "Barrel_Apples", Vector3(4.2, 0, -4.3), 0.0, 1.0, true)
	prop(tienda, "Crate_Wooden", Vector3(4.15, 0, -5.4), 0.3, 0.7, true)
	prop(tienda, "Chest_Wood", Vector3(-3.0, 0, -6.9), 0.0, 1.0, true)
	prop(tienda, "Chandelier", Vector3(0, ALTO_PLANTA_BAJA, -2.6), 0.0, 0.8)
	prop(tienda, "Candle_2", Vector3(-2.0, 1.0, -5.2))
	prop(tienda, "Potion_1", Vector3(2.0, 1.0, -5.1), 0.0, 2.0)
	prop(tienda, "Potion_2", Vector3(2.35, 1.0, -5.25), 0.0, 2.0)
	prop(tienda, "Potion_4", Vector3(1.7, 1.0, -5.3), 0.0, 2.0)


# Material con una textura del paquete Medieval Village, que se repite por el
# espacio (triplanar) sin necesidad de coordenadas UV. "escala" = repeticiones por metro.
var _materiales_textura: Dictionary = {}

func material_textura(nombre: String, escala: float) -> StandardMaterial3D:
	if _materiales_textura.has(nombre):
		return _materiales_textura[nombre]
	var ruta: String = "res://assets/%sT%s.png" % [PUEBLO, nombre.trim_prefix("T")]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(ruta):
		mat.albedo_texture = load(ruta) as Texture2D
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * escala
	mat.roughness = 0.9
	_materiales_textura[nombre] = mat
	return mat


# Marcos de madera alrededor de cada hueco (puerta y escaparates) de una fachada.
func marcos_de_huecos(casa: Node3D, huecos: Array) -> void:
	var madera: Material = material_textura("T_WoodTrim_BaseColor", 0.7)
	var f: float = 0.14   # Grosor del marco.
	for h in huecos:
		var x: float = h["x"]
		var ancho: float = h["ancho"]
		var abajo: float = h["abajo"]
		var arriba: float = h["arriba"]
		var alto_h: float = arriba - abajo
		var cy: float = (abajo + arriba) / 2.0
		Construir.caja(casa, Vector3(x - ancho / 2.0 - f / 2.0, cy, 0.08), Vector3(f, alto_h + f, 0.2), Color.WHITE, false, 0.0, madera)
		Construir.caja(casa, Vector3(x + ancho / 2.0 + f / 2.0, cy, 0.08), Vector3(f, alto_h + f, 0.2), Color.WHITE, false, 0.0, madera)
		Construir.caja(casa, Vector3(x, arriba + f / 2.0, 0.08), Vector3(ancho + 2.0 * f, f, 0.22), Color.WHITE, false, 0.0, madera)
		if abajo > 0.05:   # Los escaparates tienen alféizar; la puerta no.
			Construir.caja(casa, Vector3(x, abajo - f / 2.0, 0.1), Vector3(ancho + 2.0 * f, f, 0.26), Color.WHITE, false, 0.0, madera)


# Marca un edificio como "punto de interés": sale en la brújula y el minimapa
# (scripts/ui/brujula.gd y minimapa.gd) con su nombre y su color.
func registrar_poi(nodo: Node3D, nombre: String, color: Color) -> void:
	nodo.add_to_group("poi")
	nodo.set_meta("poi_nombre", nombre)
	nodo.set_meta("poi_color", color)


# Un tablón de madera con el nombre de la tienda, entre los escaparates y la viga de arriba.
func cartel_tienda(tienda: Node3D, titulo: String, color_texto: Color) -> void:
	if hay_kit_pueblo():
		Construir.caja(tienda, Vector3(0, 2.88, 0.1), Vector3(7.0, 0.46, 0.12), Color.WHITE, false, 0.0,
				material_textura("T_WoodTrim_BaseColor", 0.7))
	Construir.texto(tienda, Vector3(0, 2.88, 0.18), titulo, 80, color_texto)


# Un edificio genérico de cajas: fachada con ventanas, puerta y cornisa.
# Se coloca con la fachada en "pos" mirando hacia "angulo"
# (0 = la fachada mira al sur, +Z; PI = mira al norte; PI/2 = al este; -PI/2 = al oeste).
func edificio(pos: Vector3, angulo: float, ancho: float, fondo: float, alto: float,
		color: Color, rng: RandomNumberGenerator) -> Node3D:
	var casa: Node3D = Node3D.new()
	casa.position = pos
	casa.rotation.y = angulo
	add_child(casa)
	if hay_kit_pueblo():
		# Con el kit descargado: el bloque solo sirve de choque (invisible) y de
		# fondo oscuro tras las ventanas; las paredes y el tejado son modelos.
		var pisos_kit: int = int(alto / 3.0)
		var alto_kit: float = pisos_kit * ALTO_PISO
		var choque: Node3D = Construir.caja(casa, Vector3(0, alto_kit / 2.0, -fondo / 2.0),
				Vector3(ancho, alto_kit, fondo), color)
		Construir.ocultar_mallas(choque)
		Construir.caja(casa, Vector3(0, alto_kit / 2.0, -fondo / 2.0),
				Vector3(ancho - 0.4, alto_kit, fondo - 0.4), color.darkened(0.55), false)
		revestir(casa, ancho, fondo, pisos_kit, rng)
		tejado(casa, ancho, fondo, alto_kit)
		return casa
	# El bloque principal ocupa de z = -fondo a z = 0 (la fachada está en z = 0).
	Construir.caja(casa, Vector3(0, alto / 2.0, -fondo / 2.0), Vector3(ancho, alto, fondo), color)
	# Cornisa (borde del tejado) un poco más oscura y saliente.
	Construir.caja(casa, Vector3(0, alto + 0.15, -fondo / 2.0 + 0.15),
			Vector3(ancho + 0.3, 0.3, fondo + 0.3), color.darkened(0.4), false)
	# Ventanas: una fila por piso; algunas encendidas (luz cálida), otras a oscuras.
	var pisos: int = int(alto / 3.0)
	var columnas: int = maxi(1, int(ancho / 2.2))
	for piso in range(1, pisos):
		for col in columnas:
			var x: float = (col - (columnas - 1) / 2.0) * (ancho / columnas)
			var encendida: bool = rng.randf() < 0.3
			Construir.caja(casa, Vector3(x, piso * 3.0 + 1.2, 0.05), Vector3(0.9, 1.3, 0.1),
					Color(0.05, 0.06, 0.09), false)
			if encendida:
				# Cuadro de luz: solo de noche (lo controla CicloDia).
				var brillo_v: Node3D = Construir.caja(casa, Vector3(x, piso * 3.0 + 1.2, 0.12),
						Vector3(0.8, 1.2, 0.03), Color(1.0, 0.7, 0.35), false, 1.2)
				brillo_v.visible = false
				brillo_v.add_to_group("ventanas_noche")
	# Puerta de madera en la planta baja.
	Construir.caja(casa, Vector3(rng.randf_range(-ancho / 4.0, ancho / 4.0), 1.1, 0.05),
			Vector3(1.1, 2.2, 0.1), Color(0.2, 0.13, 0.09), false)
	return casa


# Un edificio en el que se puede entrar: la planta baja es una habitación de
# verdad (suelo, paredes, techo) y la fachada tiene huecos para la puerta y
# los escaparates. Los pisos de arriba son un bloque macizo.
# Devuelve el nodo del edificio: lo que pongas dentro va en sus coordenadas
# locales (la fachada está en z = 0 y el interior va de z = -fondo a z = 0;
# x va de -ancho/2 a ancho/2).
const ALTO_PLANTA_BAJA: float = 3.12

func edificio_visitable(pos: Vector3, angulo: float, ancho: float, fondo: float, alto: float,
		color: Color, color_interior: Color, huecos: Array) -> Node3D:
	var casa: Node3D = Node3D.new()
	casa.position = pos
	casa.rotation.y = angulo
	add_child(casa)
	var kit: bool = hay_kit_pueblo()
	var pisos_kit: int = maxi(2, roundi(alto / ALTO_PISO))
	if kit:
		alto = pisos_kit * ALTO_PISO
	var g: float = 0.2   # Grosor de las paredes.
	var h: float = ALTO_PLANTA_BAJA
	# Suelo de madera (un pelín por encima de la calle para que no parpadee).
	# (Los bloques de dentro se encogen para no compartir plano con la fachada
	# ni con las paredes: si dos caras están en el mismo sitio, parpadean.)
	Construir.caja(casa, Vector3(0, 0.015, -fondo / 2.0), Vector3(ancho - 2.0 * g, 0.03, fondo - 2.0 * g), Color(0.24, 0.17, 0.11))
	# Paredes de dentro: fondo y laterales.
	Construir.caja(casa, Vector3(0, h / 2.0, -fondo + g / 2.0), Vector3(ancho, h, g), color_interior)
	Construir.caja(casa, Vector3(-ancho / 2.0 + g / 2.0, h / 2.0, -fondo / 2.0), Vector3(g, h, fondo - 2.0 * g), color_interior)
	Construir.caja(casa, Vector3(ancho / 2.0 - g / 2.0, h / 2.0, -fondo / 2.0), Vector3(g, h, fondo - 2.0 * g), color_interior)
	# Fachada con huecos.
	var piedra: Material = material_textura("T_UnevenBrick_BaseColor", 0.5) if kit else null
	Construir.pared_con_huecos(casa, -g / 2.0, ancho, h, g, huecos, color, piedra)
	if kit:
		marcos_de_huecos(casa, huecos)
	# Techo de la planta baja y pisos de arriba (macizos).
	Construir.caja(casa, Vector3(0, h + (alto - h) / 2.0, -fondo / 2.0), Vector3(ancho, alto - h, fondo), color)
	Construir.caja(casa, Vector3(0, h - 0.06, -fondo / 2.0), Vector3(ancho - 2.0 * g, 0.1, fondo - 2.0 * g), color_interior.darkened(0.5), false)
	Construir.caja(casa, Vector3(0, alto + 0.15, -fondo / 2.0 + 0.15),
			Vector3(ancho + 0.3, 0.3, fondo + 0.3), color.darkened(0.4), false)
	# Zona de interior: mientras estás dentro, los guardias pierden tu rastro antes.
	var zona: Area3D = Area3D.new()
	var forma_zona: CollisionShape3D = CollisionShape3D.new()
	var caja_zona: BoxShape3D = BoxShape3D.new()
	caja_zona.size = Vector3(ancho - 2.0 * g, h, fondo - 2.0 * g)
	forma_zona.shape = caja_zona
	zona.position = Vector3(0, h / 2.0, -fondo / 2.0)
	zona.add_child(forma_zona)
	casa.add_child(zona)
	zona.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo.is_in_group("jugador"):
			Juego.interiores += 1)
	zona.body_exited.connect(func(cuerpo: Node3D) -> void:
		if cuerpo.is_in_group("jugador"):
			Juego.interiores = maxi(0, Juego.interiores - 1))
	if kit:
		# Paredes y tejado modulares por fuera: costados y fondo enteros, y la
		# fachada solo de los pisos de arriba (la planta baja tiene la puerta y
		# los escaparates hechos a medida).
		revestir(casa, ancho, fondo, pisos_kit, RandomNumberGenerator.new(), 0.21, 1)
		tejado(casa, ancho, fondo, alto)
		return casa
	# Ventanas de los pisos de arriba, a oscuras.
	var pisos: int = int(alto / 3.0)
	var columnas: int = maxi(1, int(ancho / 2.2))
	for piso in range(1, pisos):
		for col in columnas:
			var x: float = (col - (columnas - 1) / 2.0) * (ancho / columnas)
			Construir.caja(casa, Vector3(x, piso * 3.0 + 1.5, 0.05), Vector3(0.9, 1.3, 0.1),
					Color(0.05, 0.06, 0.09), false)
	return casa


# Una fila de edificios de "desde" a "hasta" (en el eje local X de la fila).
func fila_edificios(origen: Vector3, angulo: float, desde: float, hasta: float,
		fondo: float, rng: RandomNumberGenerator) -> void:
	var colores: Array[Color] = [Color(0.33, 0.29, 0.26), Color(0.24, 0.26, 0.29),
			Color(0.29, 0.24, 0.24), Color(0.22, 0.22, 0.24), Color(0.27, 0.27, 0.22)]
	var x: float = desde
	var direccion: Vector3 = Basis(Vector3.UP, angulo) * Vector3.RIGHT
	while x < hasta - 0.01:
		var ancho: float = minf(rng.randf_range(5.0, 8.0), hasta - x)
		if hasta - x - ancho < 3.0:
			ancho = hasta - x  # Evita un edificio final demasiado estrecho.
		var alto: float = 3.0 * rng.randi_range(2, 4) + rng.randf_range(0.0, 1.0)
		var centro: Vector3 = origen + direccion * (x + ancho / 2.0)
		edificio(centro, angulo, ancho, fondo, alto, colores[rng.randi() % colores.size()], rng)
		x += ancho


# Una farola: poste, farol que brilla y luz cálida.
func farola(pos: Vector3) -> void:
	# Si hay un modelo descargado (assets/modelos/farola.glb), se usa ese.
	var modelo_farola: bool = Assets.colocar(self, "farola", pos)
	if not modelo_farola:
		Construir.cilindro(self, pos + Vector3(0, 1.6, 0), 0.08, 3.2, Color(0.1, 0.1, 0.1), true)
		Construir.caja(self, pos + Vector3(0, 3.3, 0), Vector3(0.35, 0.45, 0.35), Color(0.12, 0.1, 0.08), false)
		var brillo_f: Node3D = Construir.caja(self, pos + Vector3(0, 3.3, 0), Vector3(0.28, 0.38, 0.28), Color(1.0, 0.75, 0.4), false, 3.0)
		brillo_f.visible = false
		brillo_f.add_to_group("ventanas_noche")
	Construir.luz_noche(self, pos + Vector3(0, 3.2, 0), Color(1.0, 0.7, 0.4), 1.6, 11.0)


# ------------------------------ Suelo y calles --------------------------------

const ASFALTO: Color = Color(0.13, 0.13, 0.15)

# Suelo en baldosas de 20 x 20 m, de (x0, z0) a (x1, z1) (múltiplos de 20 de
# ancho). Van en baldosas para que cada trozo reciba pocas luces a la vez (el
# renderizador Compatibilidad limita las luces por objeto).
func suelo(x0: float, x1: float, z0: float, z1: float, color: Color = Color(0.17, 0.17, 0.19)) -> void:
	var x: float = x0
	while x < x1 - 0.01:
		var z: float = z0
		while z < z1 - 0.01:
			Construir.caja(self, Vector3(x + 10.0, -0.1, z + 10.0), Vector3(20, 0.2, 20), color)
			z += 20.0
		x += 20.0


# Una calle de asfalto: franja fina y oscura sobre el suelo.
func calle(centro: Vector3, ancho: float, largo: float, a_lo_largo_de_x: bool) -> void:
	var tam: Vector3 = Vector3(largo, 0.01, ancho) if a_lo_largo_de_x else Vector3(ancho, 0.01, largo)
	Construir.caja(self, Vector3(centro.x, 0.006, centro.z), tam, ASFALTO, false)


# Una fila de edificios con huecos: "huecos" es una lista de Vector2(desde, hasta)
# en la coordenada local de la fila (donde van tiendas, casas o calles).
func fila_con_huecos(origen: Vector3, angulo: float, desde: float, hasta: float,
		huecos: Array, fondo: float, rng: RandomNumberGenerator) -> void:
	var ordenados: Array = huecos.duplicate()
	ordenados.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = desde
	for hueco in ordenados:
		if hueco.x > cursor + 0.5:
			fila_edificios(origen, angulo, cursor, hueco.x, fondo, rng)
		cursor = maxf(cursor, hueco.y)
	if hasta > cursor + 0.5:
		fila_edificios(origen, angulo, cursor, hasta, fondo, rng)


# Un edificio grande que cierra el final de una calle.
func tapon_de_calle(centro: Vector3, ancho: float, color: Color = Color(0.2, 0.2, 0.23)) -> void:
	Construir.caja(self, Vector3(centro.x, 5.0, centro.z), Vector3(ancho, 10.0, 4.0), color)


# ---------------------------------- Tiendas -----------------------------------
# Una tienda con interior: mostrador con vendedor al fondo y estantes con
# género. "id_tienda" es el campo "tienda" de scripts/datos/objetos.gd, así
# que lo que se vende sale de ese archivo. La fachada va en "pos" mirando
# hacia "angulo" (igual que edificio_visitable).
func tienda_con_interior(pos: Vector3, angulo: float, titulo: String, id_tienda: String,
		nombre: String, texto_hablar: String, color_cartel: Color,
		color: Color = Color(0.24, 0.22, 0.2), color_interior: Color = Color(0.36, 0.3, 0.26),
		es_instructor: bool = false) -> void:
	var huecos: Array = [
		{"x": 0.0, "ancho": 1.6, "abajo": 0.0, "arriba": 2.5},
		{"x": -3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
		{"x": 3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
	]
	var tienda: Node3D = edificio_visitable(pos, angulo, 10.0, 8.0, 9.0, color, color_interior, huecos)
	cartel_tienda(tienda, titulo, color_cartel)
	registrar_poi(tienda, nombre, color_cartel)
	Construir.luz_noche(tienda, Vector3(0, 2.9, 1.2), color_cartel, 1.0, 6.0)
	# Una sola lámpara en el centro (antes eran dos: cada luz encarece el dibujo).
	Construir.luz(tienda, Vector3(0, 3.0, -3.0), Color(1.0, 0.85, 0.6), 2.0, 9.0)
	Construir.caja(tienda, Vector3(0, 0.5, -5.2), Vector3(5.0, 1.0, 0.7), Color(0.3, 0.2, 0.13))
	var vendedor: Tendero = Tendero.new()
	vendedor.tienda = id_tienda
	vendedor.nombre_tienda = nombre
	vendedor.texto_hablar = texto_hablar
	vendedor.es_instructor = es_instructor
	vendedor.position = Vector3(0, 1.0, -5.2)
	tienda.add_child(vendedor)
	Construir.texto(tienda, Vector3(0, 1.25, -4.78), "Pulsa E para comprar", 32, Color(1, 0.92, 0.6))
	_decorar_tienda(tienda, id_tienda)
	# Estantes con el género: una cajita de color por cada objeto que vende.
	var ids: Array = Juego.DatosObjetos.de_tienda(id_tienda)
	for fila in 3:
		var y: float = 0.6 + fila * 0.65
		Construir.caja(tienda, Vector3(0, y, -7.6), Vector3(8.0, 0.05, 0.45), Color(0.25, 0.17, 0.11), false)
		for i in 10:
			var color_obj: Color = Color(0.4, 0.4, 0.4)
			if not ids.is_empty():
				color_obj = Juego.DatosObjetos.datos(ids[(fila * 10 + i) % ids.size()])["color"]
			Construir.caja(tienda, Vector3(-3.6 + i * 0.8, y + 0.15, -7.6), Vector3(0.3, 0.25, 0.25), color_obj, false)


# Muebles y objetos de verdad (paquete Fantasy Props) para que cada tienda tenga
# su ambiente. Si el paquete no está, no se pone nada y la tienda sigue igual.
func _decorar_tienda(tienda: Node3D, id_tienda: String) -> void:
	var f: String = Assets.FANTASIA
	Assets.colocar_solido(tienda, f + "Barrel", Vector3(-4.2, 0, -1.0))
	Assets.colocar_solido(tienda, f + "Crate_Wooden", Vector3(4.0, 0, -1.1), 0.3)
	match id_tienda:
		"ferreteria":
			Assets.colocar_solido(tienda, f + "Anvil", Vector3(-3.6, 0, -3.0))
			Assets.colocar_solido(tienda, f + "Workbench", Vector3(3.3, 0, -2.8))
			Assets.colocar_solido(tienda, f + "Bucket_Metal", Vector3(-3.4, 0, -1.8))
		"armeria":
			Assets.colocar_solido(tienda, f + "WeaponStand", Vector3(-3.6, 0, -3.0))
			Assets.colocar_solido(tienda, f + "WeaponStand", Vector3(3.6, 0, -3.0))
			Assets.colocar_solido(tienda, f + "Dummy", Vector3(3.6, 0, -1.0))
		"botica", "herbolario":
			Assets.colocar(tienda, f + "Potion_1", Vector3(-1.6, 1.0, -5.2))
			Assets.colocar(tienda, f + "Potion_2", Vector3(-0.4, 1.0, -5.2))
			Assets.colocar(tienda, f + "Potion_4", Vector3(1.4, 1.0, -5.2))
			Assets.colocar(tienda, f + "Candle_1", Vector3(2.2, 1.0, -5.2))
			Assets.colocar_solido(tienda, f + "Cauldron", Vector3(3.6, 0, -3.2))
			Assets.colocar_solido(tienda, f + "Bookcase_2", Vector3(-3.8, 0, -3.4), PI / 2.0)
		"panaderia":
			Assets.colocar_solido(tienda, f + "Barrel_Apples", Vector3(-3.6, 0, -2.4))
			Assets.colocar_solido(tienda, f + "Bench", Vector3(3.0, 0, -3.0))
			Assets.colocar(tienda, f + "Mug", Vector3(-1.0, 1.0, -5.2))
		"":
			# La academia: maniquíes de entrenamiento.
			Assets.colocar_solido(tienda, f + "Dummy", Vector3(-3.4, 0, -3.0))
			Assets.colocar_solido(tienda, f + "Dummy", Vector3(3.4, 0, -3.0))


# --------------------------- Viviendas en alquiler ----------------------------
# Una casa con puerta, cartel de alquiler, cama, cocina con grifo, estantería,
# caldero, ventanilla de venta y huecos para macetas. Cada casa tiene su
# "id_casa" (para saber si la tienes alquilada) y su precio.
func vivienda(id_casa: String, precio: int, pos: Vector3, angulo: float,
		color: Color = Color(0.3, 0.26, 0.24), color_interior: Color = Color(0.42, 0.36, 0.3)) -> void:
	# En coordenadas de la casa: x va de -5 a 5 a lo largo de la fachada, y el
	# interior va de z = 0 (fachada) a z = -8 (pared del fondo).
	var huecos: Array = [
		{"x": -3.0, "ancho": PuertaCasa.ANCHO, "abajo": 0.0, "arriba": PuertaCasa.ALTO},
		{"x": 1.5, "ancho": 2.0, "abajo": 1.0, "arriba": 2.3, "cristal": true},
	]
	var casa: Node3D = edificio_visitable(pos, angulo, 10.0, 8.0, 7.0, color, color_interior, huecos)
	registrar_poi(casa, "Casa en alquiler", Color(1.0, 0.85, 0.5))

	# Cartel de alquiler encima de la puerta.
	if hay_kit_pueblo():
		Construir.caja(casa, Vector3(-3.0, 2.78, 0.1), Vector3(2.7, 0.42, 0.1), Color.WHITE, false, 0.0,
				material_textura("T_WoodTrim_BaseColor", 0.7))
	var cartel: Label3D = Construir.texto(casa, Vector3(-3.0, 2.78, 0.17),
			"SE ALQUILA  %d $" % precio, 56, Color(1.0, 0.85, 0.5))
	# Farolillo junto a la puerta.
	Construir.caja(casa, Vector3(-4.0, 2.4, 0.15), Vector3(0.2, 0.3, 0.2), Color(0.12, 0.1, 0.08), false)
	var brillo_l: Node3D = Construir.caja(casa, Vector3(-4.0, 2.4, 0.15), Vector3(0.15, 0.24, 0.15), Color(1.0, 0.75, 0.4), false, 3.0)
	brillo_l.visible = false
	brillo_l.add_to_group("ventanas_noche")
	Construir.luz_noche(casa, Vector3(-4.0, 2.4, 0.6), Color(1.0, 0.7, 0.4), 0.9, 5.0)
	var puerta: PuertaCasa = PuertaCasa.new()
	puerta.id_casa = id_casa
	puerta.precio = precio
	puerta.position = Vector3(-3.0, 1.0, -0.1)
	puerta.cartel = cartel
	casa.add_child(puerta)

	# Luz de dentro (una lámpara de aceite) y una alfombra.
	Construir.luz(casa, Vector3(0, 3.0, -3.0), Color(1.0, 0.75, 0.45), 1.8, 9.0)
	Construir.caja(casa, Vector3(0, 0.035, -4.0), Vector3(3.0, 0.01, 2.0), Color(0.35, 0.12, 0.12), false)

	# Ventanilla de venta: el mostrador está detrás del cristal y el cliente fuera.
	Construir.caja(casa, Vector3(1.5, 0.5, -0.55), Vector3(2.0, 1.0, 0.6), Color(0.3, 0.2, 0.13))
	var mostrador: Mostrador = Mostrador.new()
	mostrador.id_casa = id_casa
	mostrador.position = Vector3(1.5, 1.0, -0.55)
	mostrador.posicion_cliente = Vector3(0, -1.0, 1.5)
	mostrador.giro_cliente = 0.0   # Mira hacia dentro de la casa.
	casa.add_child(mostrador)

	var cocina: Muebles.Grifo = Muebles.Grifo.new()
	cocina.position = Vector3(3.2, 0, -7.45)
	casa.add_child(cocina)

	var estanteria: Muebles.Estanteria = Muebles.Estanteria.new()
	estanteria.position = Vector3(0.2, 0, -7.6)
	casa.add_child(estanteria)

	var cama: Muebles.Cama = Muebles.Cama.new()
	cama.position = Vector3(-4.1, 0, -6.6)
	casa.add_child(cama)

	# Caldero y recetario en la pared.
	var caldero: Caldero3D = Caldero3D.new()
	caldero.position = Vector3(3.3, 0, -4.2)
	casa.add_child(caldero)
	var recetas: PackedStringArray = ["RECETARIO (no enseñar a la guardia)"]
	for id_pocion in GameData.POCIONES:
		recetas.append("%s = %s" % [GameData.POCIONES[id_pocion]["nombre"], GameData.texto_receta(id_pocion)])
	var recetario: Label3D = Construir.texto(casa, Vector3(4.88, 1.9, -4.2), "\n".join(recetas), 40,
			Color(0.75, 0.9, 0.7))
	recetario.rotation.y = -PI / 2.0

	# Un poco de mobiliario de verdad: mesa con vela y un baúl.
	Assets.colocar_solido(casa, Assets.FANTASIA + "Table_Large", Vector3(-1.6, 0, -3.0))
	Assets.colocar(casa, Assets.FANTASIA + "Candle_2", Vector3(-1.6, 0.81, -3.0))
	Assets.colocar_solido(casa, Assets.FANTASIA + "Chest_Wood", Vector3(-2.6, 0, -7.3))

	# Cinco huecos para macetas junto a la pared izquierda; las dos primeras ya vienen puestas.
	for i in 5:
		var hueco: Muebles.HuecoMaceta = Muebles.HuecoMaceta.new()
		hueco.position = Vector3(-4.4, 0.03, -1.9 - i * 0.8)
		casa.add_child(hueco)
		if i < 2:
			hueco.poner_maceta()
