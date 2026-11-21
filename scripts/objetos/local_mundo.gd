# local_mundo.gd
# -----------------------------------------------------------------------------
# El INTERIOR de un negocio en el que se puede entrar (restaurante, bar, cafetería,
# panadería, taberna, taller): decoración, mostrador, persona que atiende, luces y
# la zona de "estás dentro". Lo crea ServicioMundo cuando su servicio está en
# datos/locales.gd. El edificio (muros con puerta y ventanas, suelo y techo) lo
# hace GeneradorMundo igual que con las casas; esto pone lo de dentro.
#
# Todo sale de DATOS + una semilla (la posición del local): el mismo local siempre es
# igual, y dos locales del mismo tipo se distinguen en nombre, colores, disposición,
# precios y plato del día. Los muebles son cajas de colores fundidas en UNA malla.
#
# Coordenadas del plano: u a lo ancho (0 = centro), iv a lo hondo desde la puerta (0)
# hasta el muro del fondo (D). La puerta está en el lado +z del local.
#
# Se usa con E en el mostrador (MostradorLocal): abre VentanaLocal con la carta.
# -----------------------------------------------------------------------------
class_name LocalMundo
extends Node3D

const Locales = preload("res://scripts/datos/locales.gd")
const Economia = preload("res://scripts/datos/economia.gd")
const Casino = preload("res://scripts/datos/casino.gd")

const GROSOR: float = 0.3          # Igual que GeneradorMundo.GROSOR_MURO.
const SUELO: float = 0.1           # Altura del suelo sobre la base del edificio.
const MADERAS: Array = [Color(0.45, 0.3, 0.18), Color(0.55, 0.4, 0.25), Color(0.35, 0.25, 0.18), Color(0.6, 0.5, 0.35)]
const MANTELES: Array = [Color(0.75, 0.2, 0.2), Color(0.25, 0.4, 0.65), Color(0.85, 0.8, 0.7), Color(0.3, 0.55, 0.4), Color(0.7, 0.55, 0.2)]
const PERSONAJES: Array = ["Character_Hazmat", "Character_Enemy", "Character_Soldier"]
const VERDE_BRUMA: Color = Color(0.35, 0.95, 0.5)

static var _copas_dia: int = -1
static var _copas: int = 0

var local: String = "restaurante"
var semilla: int = 0
var nombre: String = ""
var ancho: float = 16.0            # Medidas exteriores del edificio.
var fondo: float = 11.0
var punto_vehiculo: Vector3 = Vector3.ZERO   # Dónde buscar el vehículo (taller).

var W: float = 0.0                 # Medidas interiores.
var D: float = 0.0
var madera: Color = MADERAS[0]
var tela: Color = MANTELES[0]
var panel: Color = Color(0.5, 0.35, 0.25)
var cajas: Array = []              # [pos, tam, color, solido]
var luces: Array = []              # Posiciones de las luces.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _npc: Node3D = null
var _luces_nodos: Array = []
var _mostrador: Node3D = null
var _abierto: bool = true
var _dentro: bool = false
var _t: float = 0.0
var _uc: float = 0.0               # Centro del mostrador (u).
var _largo_m: float = 5.0          # Largo del mostrador.
var _decor_vivo: Array = []        # Nodos que se animan (orbe de bruma...).
var _tiempo: float = 0.0


# Crea el interior dentro de un ServicioMundo (que está en la puerta, por fuera).
static func crear(servicio: Node3D, id_local: String) -> LocalMundo:
	var lm: LocalMundo = LocalMundo.new()
	lm.local = id_local
	var datos: Dictionary = Locales.LOCALES[id_local]
	lm.ancho = float(datos["ancho"])
	lm.fondo = float(datos["fondo"])
	lm.semilla = int(absf(servicio.position.x) * 7.0 + absf(servicio.position.z) * 13.0) + int(servicio.position.x < 0.0) * 31 + int(servicio.position.z < 0.0) * 57
	lm.punto_vehiculo = servicio.position
	# El centro del edificio está justo detrás del punto de uso (a medio fondo + 0,5 m), un metro más abajo.
	lm.position = Vector3(0.0, -1.0, -(lm.fondo / 2.0 + 0.5))
	servicio.add_child(lm)
	return lm


func _ready() -> void:
	nombre = Locales.nombre_local(local, semilla)
	W = ancho - 2.0 * GROSOR
	D = fondo - 2.0 * GROSOR
	_rng.seed = semilla * 7919 + 17
	madera = MADERAS[_rng.randi() % MADERAS.size()]
	tela = MANTELES[_rng.randi() % MANTELES.size()]
	panel = Locales.color_local(local, semilla).darkened(0.25)
	_planta()
	_construir_visual()
	_poner_luces()
	_poner_mostrador()
	_zona_interior()
	_actualizar_abierto(true)
	set_process(true)


# ---------------------------------------------------------------------------
# Ayudas para colocar cajas en el plano.
# ---------------------------------------------------------------------------

# Caja centrada en (u, iv), apoyada a "y0" sobre el suelo, de tamaño (su, sh, sv).
func c(u: float, iv: float, y0: float, su: float, sh: float, sv: float, col: Color, solido: bool = true) -> void:
	cajas.append([Vector3(u, SUELO + y0 + sh / 2.0, D / 2.0 - iv), Vector3(su, sh, sv), col, solido])


func luz(u: float, iv: float, h: float) -> void:
	luces.append(Vector3(u, SUELO + h, D / 2.0 - iv))


# Punto del plano en coordenadas locales (para nodos sueltos).
func p(u: float, iv: float, h: float) -> Vector3:
	return Vector3(u, SUELO + h, D / 2.0 - iv)


func mesa(u: float, iv: float, lado: float = 1.0, sillas: bool = true, vela: bool = true) -> void:
	c(u, iv, 0.0, 0.5, 0.72, 0.5, madera, true)
	c(u, iv, 0.72, lado, 0.08, lado, tela, true)
	if vela:
		c(u, iv, 0.8, 0.1, 0.16, 0.1, Color(1.0, 0.85, 0.5), false)
	if sillas:
		var s: float = lado / 2.0 + 0.32
		for d in [Vector2(s, 0), Vector2(-s, 0), Vector2(0, s), Vector2(0, -s)]:
			var v: Vector2 = d
			c(u + v.x, iv + v.y, 0.0, 0.4, 0.45, 0.4, madera.darkened(0.1), false)
			c(u + v.x * 1.28, iv + v.y * 1.28, 0.45, 0.4 if v.x == 0.0 else 0.06, 0.4, 0.06 if v.x == 0.0 else 0.4, madera.darkened(0.2), false)


# Estantería con botellas o cajas a lo largo del muro del fondo (u entre -a y a).
func estante_fondo(a: float, niveles: int, col_bot: Array) -> void:
	for n in niveles:
		var h: float = 1.15 + n * 0.5
		c(0.0, D - 0.22, h, a * 2.0, 0.06, 0.4, madera.darkened(0.15), false)
		var x: float = -a + 0.3
		while x < a - 0.2:
			var col: Color = col_bot[_rng.randi() % col_bot.size()]
			c(x, D - 0.22, h + 0.06, 0.16, 0.32, 0.16, col, false)
			x += 0.36
	c(0.0, D - 0.06, 0.0, a * 2.0 + 0.4, 2.6, 0.1, madera.darkened(0.35), false)


func mostrador(largo: float, uc: float, iv_c: float = -1.0, color: Color = Color.TRANSPARENT) -> void:
	_uc = uc
	_largo_m = largo
	var ivc: float = (D - 1.7) if iv_c < 0.0 else iv_c
	var col: Color = madera.darkened(0.1) if color == Color.TRANSPARENT else color
	c(uc, ivc, 0.0, largo, 1.0, 0.9, col, true)
	c(uc, ivc, 1.0, largo + 0.2, 0.08, 1.1, col.lightened(0.25), false)
	c(uc - largo * 0.3, ivc, 1.08, 0.4, 0.25, 0.35, Color(0.2, 0.2, 0.22), false)   # Caja registradora.


func plantas(lista: Array) -> void:
	for v in lista:
		var q: Vector2 = v
		c(q.x, q.y, 0.0, 0.5, 0.45, 0.5, Color(0.55, 0.3, 0.2), true)
		c(q.x, q.y, 0.45, 0.45, 0.7, 0.45, Color(0.25, 0.55, 0.3), false)
		c(q.x, q.y, 1.1, 0.3, 0.35, 0.3, Color(0.35, 0.65, 0.35), false)


func cuadro(u: float, iv: float, h: float, lado: String = "fondo") -> void:
	var col: Color = Color.from_hsv(_rng.randf(), 0.45, 0.8)
	match lado:
		"fondo":
			c(u, D - 0.06, h, 0.8, 0.6, 0.05, madera.darkened(0.3), false)
			c(u, D - 0.09, h + 0.06, 0.66, 0.48, 0.04, col, false)
		"izq":
			c(-W / 2.0 + 0.06, iv, h, 0.05, 0.6, 0.8, madera.darkened(0.3), false)
			c(-W / 2.0 + 0.09, iv, h + 0.06, 0.04, 0.48, 0.66, col, false)
		"der":
			c(W / 2.0 - 0.06, iv, h, 0.05, 0.6, 0.8, madera.darkened(0.3), false)
			c(W / 2.0 - 0.09, iv, h + 0.06, 0.04, 0.48, 0.66, col, false)


# Zócalo de color por las paredes: cada local tiene el suyo.
func zocalo() -> void:
	c(0.0, D - 0.04, 0.0, W, 1.0, 0.08, panel, false)
	c(-W / 2.0 + 0.04, D / 2.0, 0.0, 0.08, 1.0, D, panel, false)
	c(W / 2.0 - 0.04, D / 2.0, 0.0, 0.08, 1.0, D, panel, false)


# ---------------------------------------------------------------------------
# Los repartos por estilo.
# ---------------------------------------------------------------------------
func _planta() -> void:
	var estilo: String = str(Locales.LOCALES[local]["estilo"])
	# Felpudo y alfombra a la entrada.
	c(0.0, 0.7, 0.0, 1.6, 0.03, 1.0, Color(0.45, 0.15, 0.15), false)
	zocalo()
	match estilo:
		"comedor": _comedor()
		"barra": _barra()
		"cafe": _cafeteria()
		"panaderia": _panaderia()
		"taberna": _taberna()
		"taller": _taller()
		"salon", "barberia": _salon(estilo == "barberia")


# Posiciones de mesa libres de pasillos y mostrador.
func _mesas_en(columnas: Array, filas: Array, lado: float, sillas: bool = true) -> int:
	var n: int = 0
	for iv in filas:
		for u in columnas:
			if absf(float(u)) < 1.5 and float(iv) < 3.4:
				continue
			if float(iv) > D - 4.0 and absf(float(u) - _uc) < _largo_m / 2.0 + 1.0:
				continue
			mesa(float(u), float(iv), lado, sillas)
			n += 1
	return n


func _filas(desde: float, paso: float, hasta: float) -> Array:
	var r: Array = []
	var v: float = desde
	while v <= hasta:
		r.append(v)
		v += paso
	return r


func _orbe(u: float, iv: float, h: float, col: Color) -> void:
	var o: Node3D = Construir.esfera(self, p(u, iv, h), 0.18, col, Vector3.ONE, 2.5)
	_decor_vivo.append(o)
	var l: OmniLight3D = Construir.luz(self, p(u, iv, h), col, 0.9, 5.0)
	l.shadow_enabled = false
	_luces_nodos.append(l)


func _comedor() -> void:
	mostrador(clampf(W * 0.45, 4.0, 7.0), 0.0)
	estante_fondo(minf(W * 0.3 - 0.9, 5.0), 3, [Color(0.5, 0.15, 0.2), Color(0.2, 0.45, 0.3), Color(0.85, 0.75, 0.4), Color(0.3, 0.3, 0.6)])
	var lat: float = W / 2.0 - 2.0
	_mesas_en([-lat, -lat * 0.5, lat * 0.5, lat], _filas(3.2, 2.9, D - 3.5), 1.0)
	plantas([Vector2(-W / 2.0 + 0.6, 1.0), Vector2(W / 2.0 - 0.6, 1.0)])
	cuadro(-W / 2.0, 4.0, 1.6, "izq")
	cuadro(W / 2.0, 6.0, 1.6, "der")
	cuadro(-W / 2.0, 8.0, 1.6, "izq")
	_pizarra(W / 2.0 - 0.08, 3.0, "der")
	luz(-W * 0.22, D * 0.35, 2.7)
	luz(W * 0.22, D * 0.35, 2.7)
	luz(0.0, D * 0.8, 2.7)
	_orbe(0.0, D * 0.5, 2.2, VERDE_BRUMA)   # Un duende de luz que flota por el comedor.


func _barra() -> void:
	mostrador(clampf(W * 0.62, 5.0, 9.0), 0.0)
	# Barra en L: un tramo corto hacia la puerta por la derecha.
	var x: float = _largo_m / 2.0 - 0.45
	c(x, D - 3.1, 0.0, 0.9, 1.0, 2.5, madera.darkened(0.1), true)
	c(x, D - 3.1, 1.0, 1.1, 0.08, 2.7, madera.darkened(0.1).lightened(0.25), false)
	estante_fondo(minf(W * 0.3 - 0.9, 5.0), 3, [Color(0.15, 0.5, 0.2), Color(0.55, 0.3, 0.1), Color(0.85, 0.85, 0.9), Color(0.5, 0.15, 0.4), VERDE_BRUMA])
	# Taburetes.
	var tx: float = -_largo_m / 2.0 + 0.7
	while tx < _largo_m / 2.0 - 1.3:
		c(tx, D - 2.75, 0.0, 0.14, 0.65, 0.14, Color(0.2, 0.2, 0.24), false)
		c(tx, D - 2.75, 0.65, 0.4, 0.09, 0.4, Color(0.7, 0.15, 0.2), false)
		tx += 0.95
	# Mesas altas con taburetes.
	for q in [Vector2(-W * 0.3, 3.4), Vector2(-W * 0.3, 6.2), Vector2(W * 0.3, 3.8)]:
		var v: Vector2 = q
		c(v.x, v.y, 0.0, 0.18, 1.05, 0.18, Color(0.2, 0.2, 0.24), true)
		c(v.x, v.y, 1.05, 0.8, 0.07, 0.8, tela, true)
		for d in [Vector2(0.7, 0), Vector2(-0.7, 0)]:
			var s: Vector2 = d
			c(v.x + s.x, v.y + s.y, 0.0, 0.12, 0.7, 0.12, Color(0.2, 0.2, 0.24), false)
			c(v.x + s.x, v.y + s.y, 0.7, 0.36, 0.08, 0.36, Color(0.2, 0.45, 0.6), false)
	# Máquina de música y diana.
	c(-W / 2.0 + 0.6, D * 0.6, 0.0, 0.9, 1.6, 0.6, Color(0.5, 0.15, 0.55), true)
	c(-W / 2.0 + 0.6, D * 0.6, 1.0, 0.7, 0.4, 0.62, Color(1.0, 0.8, 0.3), false)
	c(W / 2.0 - 0.08, D * 0.62, 1.4, 0.05, 0.7, 0.7, Color(0.8, 0.15, 0.15), false)
	c(W / 2.0 - 0.1, D * 0.62, 1.6, 0.04, 0.3, 0.3, Color(0.95, 0.9, 0.8), false)
	cuadro(-W * 0.38, 0.0, 1.9, "fondo")
	luz(-W * 0.2, D * 0.45, 2.7)
	luz(W * 0.2, D * 0.45, 2.7)
	luz(0.0, D * 0.85, 2.6)
	# Neón del bar (brilla de verdad) sobre la barra.
	var neon: Node3D = Construir.caja(self, p(0.0, D - 0.25, 2.55), Vector3(2.6, 0.14, 0.06), Color(0.2, 0.9, 1.0), false, 3.0)
	if neon != null:
		_decor_vivo.append(neon)


func _cafeteria() -> void:
	mostrador(clampf(W * 0.5, 4.0, 6.5), 0.0)
	# Vitrina de pasteles sobre el mostrador (cristal claro y pasteles de colores).
	c(0.8, D - 1.7, 1.08, 2.0, 0.45, 0.7, Color(0.85, 0.92, 0.95), false)
	for i in 5:
		c(-0.0 + i * 0.34, D - 1.7, 1.12, 0.26, 0.2, 0.3, Color.from_hsv(_rng.randf(), 0.45, 0.95), false)
	# Máquina de café y estante con tazas.
	c(-1.4, D - 0.5, 0.0, 1.0, 1.5, 0.5, Color(0.7, 0.7, 0.74), false)
	c(-1.4, D - 0.5, 1.5, 0.8, 0.5, 0.45, Color(0.35, 0.35, 0.4), false)
	estante_fondo(minf(W * 0.3 - 0.9, 3.3), 2, [Color(0.95, 0.95, 0.9), Color(0.85, 0.6, 0.3), Color(0.5, 0.7, 0.85)])
	# Mesitas junto a las paredes y las ventanas.
	var lat: float = W / 2.0 - 1.4
	for iv in _filas(2.6, 2.3, D - 3.6):
		for u in [-lat, lat]:
			mesa(float(u), float(iv), 0.8, true, false)
	plantas([Vector2(-W / 2.0 + 0.6, 1.0), Vector2(W / 2.0 - 0.6, 1.0), Vector2(-W / 2.0 + 0.6, D - 0.8)])
	cuadro(-W / 2.0, 4.0, 1.7, "izq")
	cuadro(W / 2.0, 5.0, 1.7, "der")
	_pizarra(0.0, 6.5, "izq")
	luz(-W * 0.2, D * 0.4, 2.7)
	luz(W * 0.2, D * 0.4, 2.7)
	# Estrellas de papel colgando del techo (toque de fantasía): pequeñas y con brillo.
	for i in 7:
		var e: Node3D = Construir.caja(self, p(_rng.randf_range(-W * 0.4, W * 0.4), _rng.randf_range(2.0, D - 3.0), _rng.randf_range(2.3, 2.9)),
				Vector3(0.14, 0.14, 0.14), Color(1.0, 0.9, 0.4), false, 2.0)
		if e != null:
			e.rotation = Vector3(0.6, 0.6, 0.0)
			_decor_vivo.append(e)


func _panaderia() -> void:
	mostrador(clampf(W * 0.5, 4.0, 6.0), 0.0)
	# Vitrinas bajas con panes encima del mostrador.
	for i in 4:
		var x: float = -_largo_m * 0.3 + i * (_largo_m * 0.2)
		c(x, D - 1.7, 1.08, 0.7, 0.4, 0.7, Color(0.9, 0.92, 0.95), false)
		c(x, D - 1.7, 1.12, 0.55, 0.14, 0.4, Color(0.8, 0.55, 0.25).lerp(Color(0.9, 0.7, 0.35), _rng.randf()), false)
	# Estanterías con barras a los lados.
	for lado in [-1.0, 1.0]:
		for n in 3:
			c(float(lado) * (W / 2.0 - 0.3), D * 0.45, 0.45 + n * 0.5, 0.4, 0.06, D * 0.55, madera.darkened(0.15), false)
			var iv: float = 2.4
			while iv < D - 3.2:
				c(float(lado) * (W / 2.0 - 0.3), iv, 0.51 + n * 0.5, 0.32, 0.2, 0.5, Color(0.8, 0.55, 0.25).lerp(Color(0.95, 0.75, 0.4), _rng.randf()), false)
				iv += 0.7
	# Horno de piedra al fondo con la boca encendida, y sacos de harina.
	var hx: float = W / 2.0 - 1.4
	c(hx, D - 1.1, 0.0, 1.8, 1.7, 1.4, Color(0.5, 0.3, 0.25), true)
	var boca: Node3D = Construir.caja(self, p(hx, D - 1.8, 0.8), Vector3(0.9, 0.6, 0.08), Color(1.0, 0.5, 0.1), false, 2.5)
	if boca != null:
		_decor_vivo.append(boca)
	var lh: OmniLight3D = Construir.luz(self, p(hx, D - 2.6, 1.2), Color(1.0, 0.55, 0.2), 1.0, 5.0)
	lh.shadow_enabled = false
	_luces_nodos.append(lh)
	for i in 3:
		c(-W / 2.0 + 1.2 + i * 0.7, D - 0.7, 0.0, 0.6, 0.55, 0.45, Color(0.92, 0.9, 0.82), true)
	c(-W / 2.0 + 1.55, D - 0.7, 0.55, 0.6, 0.5, 0.45, Color(0.9, 0.88, 0.8), false)
	# Un pan de bruma que brilla en un pedestal junto a la puerta.
	c(-W / 2.0 + 1.0, 1.8, 0.0, 0.5, 0.9, 0.5, madera, true)
	var pan: Node3D = Construir.caja(self, p(-W / 2.0 + 1.0, 1.8, 1.05), Vector3(0.5, 0.18, 0.2), VERDE_BRUMA, false, 2.0)
	if pan != null:
		_decor_vivo.append(pan)
	plantas([Vector2(W / 2.0 - 0.6, 1.0)])
	_pizarra(0.0, D - 0.12, "fondo")
	luz(-W * 0.2, D * 0.45, 2.7)
	luz(W * 0.2, D * 0.45, 2.7)


func _taberna() -> void:
	mostrador(clampf(W * 0.5, 4.0, 7.0), 0.0, -1.0, Color(0.35, 0.22, 0.14))
	estante_fondo(minf(W * 0.3 - 0.9, 5.0), 2, [Color(0.5, 0.3, 0.15), Color(0.6, 0.45, 0.2), Color(0.4, 0.2, 0.15)])
	# Mesas largas con bancos.
	for iv in _filas(3.4, 3.0, D - 4.0):
		for u in [-W * 0.3, W * 0.3]:
			c(float(u), float(iv), 0.0, 0.6, 0.72, 2.2, madera, true)
			c(float(u), float(iv), 0.72, 1.0, 0.08, 2.8, madera.lightened(0.1), true)
			for lado in [-0.9, 0.9]:
				c(float(u) + float(lado), float(iv), 0.0, 0.4, 0.45, 2.6, madera.darkened(0.15), false)
	# Barriles junto a las paredes.
	for q in [Vector2(-W / 2.0 + 0.7, 1.8), Vector2(-W / 2.0 + 0.7, 2.8), Vector2(W / 2.0 - 0.7, D - 3.0), Vector2(-W / 2.0 + 0.7, D - 1.0)]:
		var v: Vector2 = q
		c(v.x, v.y, 0.0, 0.9, 1.1, 0.9, Color(0.5, 0.33, 0.18), true)
		c(v.x, v.y, 0.3, 0.96, 0.08, 0.96, Color(0.25, 0.2, 0.18), false)
		c(v.x, v.y, 0.75, 0.96, 0.08, 0.96, Color(0.25, 0.2, 0.18), false)
	# Chimenea con fuego.
	var fz: float = D * 0.5
	c(W / 2.0 - 0.6, fz, 0.0, 1.0, 1.9, 2.0, Color(0.45, 0.43, 0.42), true)
	var fuego: Node3D = Construir.caja(self, p(W / 2.0 - 1.05, fz, 0.5), Vector3(0.08, 0.6, 1.1), Color(1.0, 0.5, 0.1), false, 2.8)
	if fuego != null:
		_decor_vivo.append(fuego)
	var lf: OmniLight3D = Construir.luz(self, p(W / 2.0 - 1.8, fz, 1.0), Color(1.0, 0.55, 0.2), 1.1, 6.5)
	lf.shadow_enabled = false
	_luces_nodos.append(lf)
	# Vigas oscuras y faroles.
	for iv in _filas(2.0, 3.0, D - 1.0):
		c(0.0, float(iv), 2.95, W, 0.18, 0.22, Color(0.25, 0.16, 0.1), false)
	# Un caldero que borbotea con bruma en un rincón.
	c(-W / 2.0 + 1.0, D - 2.6, 0.0, 0.9, 0.7, 0.9, Color(0.12, 0.12, 0.14), true)
	var sopa: Node3D = Construir.caja(self, p(-W / 2.0 + 1.0, D - 2.6, 0.72), Vector3(0.7, 0.05, 0.7), VERDE_BRUMA, false, 2.5)
	if sopa != null:
		_decor_vivo.append(sopa)
	cuadro(-W * 0.36, 0.0, 1.9, "fondo")
	luz(-W * 0.2, D * 0.4, 2.6)
	luz(W * 0.1, D * 0.75, 2.6)


func _taller() -> void:
	# Mostrador pequeño en la esquina del fondo, a la derecha.
	_uc = W * 0.27
	mostrador(clampf(W * 0.3, 3.5, 5.0), W * 0.27)
	# Elevador con un coche encima.
	var cu: float = -W * 0.2
	var ci: float = D * 0.48
	for dx in [-1.8, 1.8]:
		c(cu + float(dx), ci, 0.0, 0.22, 2.4, 0.22, Color(0.9, 0.7, 0.1), true)
	c(cu, ci, 1.3, 4.2, 0.16, 1.9, Color(0.35, 0.36, 0.4), true)
	var carro: Color = Color.from_hsv(_rng.randf(), 0.6, 0.65)
	c(cu, ci, 1.46, 3.8, 0.55, 1.6, carro, true)
	c(cu - 0.2, ci, 2.0, 2.0, 0.5, 1.4, carro.lightened(0.15), true)
	c(cu - 0.2, ci, 2.1, 1.9, 0.3, 1.45, Color(0.35, 0.5, 0.65), false)
	for dx in [-1.2, 1.2]:
		for dz in [-0.8, 0.8]:
			c(cu + float(dx), ci + float(dz), 1.2, 0.7, 0.7, 0.2, Color(0.08, 0.08, 0.09), false)
	# Banco de trabajo con herramientas y panel de la pared.
	c(-W / 2.0 + 0.5, D * 0.45, 0.0, 0.9, 0.95, 3.5, Color(0.45, 0.45, 0.5), true)
	for i in 5:
		c(-W / 2.0 + 0.5, D * 0.45 - 1.4 + i * 0.7, 0.95, 0.3, 0.12, 0.3, Color.from_hsv(_rng.randf(), 0.7, 0.8), false)
	c(-W / 2.0 + 0.08, D * 0.45, 1.2, 0.05, 1.2, 3.4, Color(0.2, 0.22, 0.26), false)
	for i in 6:
		c(-W / 2.0 + 0.12, D * 0.45 - 1.4 + i * 0.55, 1.6, 0.05, 0.5, 0.1, Color(0.7, 0.7, 0.75), false)
	# Pila de neumáticos, bidones y caja de herramientas.
	for i in 4:
		c(W / 2.0 - 0.9, 2.0, i * 0.28, 0.95, 0.28, 0.95, Color(0.1, 0.1, 0.11), true)
	c(W / 2.0 - 0.9, 3.2, 0.0, 0.8, 0.7, 0.8, Color(0.85, 0.7, 0.1), true)
	c(W / 2.0 - 0.9, D * 0.5, 0.0, 0.8, 1.0, 0.8, Color(0.2, 0.3, 0.6), true)
	c(W / 2.0 - 1.9, D * 0.5, 0.0, 0.6, 0.6, 0.6, Color(0.8, 0.2, 0.15), true)
	# Bidón mágico de aceite de bruma: brilla.
	c(-W * 0.38, D - 1.1, 0.0, 0.7, 0.9, 0.7, Color(0.15, 0.3, 0.2), true)
	var aceite: Node3D = Construir.caja(self, p(-W * 0.38, D - 1.1, 0.92), Vector3(0.5, 0.05, 0.5), VERDE_BRUMA, false, 2.5)
	if aceite != null:
		_decor_vivo.append(aceite)
	c(0.0, D - 0.1, 1.1, W * 0.5, 0.9, 0.1, Color(0.95, 0.7, 0.1), false)   # Cartel amarillo del fondo.
	luz(-W * 0.2, D * 0.35, 2.8)
	luz(W * 0.2, D * 0.55, 2.8)
	luz(-W * 0.2, D * 0.8, 2.8)


# Peluquería y barbería: sillones frente a espejos, lavacabezas y sala de espera.
func _salon(barberia: bool) -> void:
	mostrador(clampf(W * 0.3, 3.5, 5.0), W * 0.2)
	var cuero: Color = Color(0.55, 0.12, 0.15) if barberia else Color(0.85, 0.45, 0.65)
	# Tres puestos en la pared izquierda: sillón giratorio y espejo con balda.
	for iv in [2.6, 5.0, 7.4]:
		var ivf: float = float(iv)
		if ivf > D - 2.0:
			continue
		var u: float = -W / 2.0 + 1.4
		c(u, ivf, 0.0, 0.25, 0.5, 0.25, Color(0.7, 0.7, 0.75), true)
		c(u, ivf, 0.5, 0.9, 0.2, 0.9, cuero, true)
		c(u - 0.4, ivf, 0.7, 0.15, 0.9, 0.9, cuero, false)
		c(u + 0.0, ivf + 0.0, 0.0, 0.9, 0.12, 0.9, Color(0.75, 0.75, 0.78), false)
		c(-W / 2.0 + 0.08, ivf, 1.0, 0.06, 1.2, 1.1, Color(0.7, 0.85, 0.95), false)
		c(-W / 2.0 + 0.1, ivf, 0.85, 0.2, 0.06, 1.2, Color(0.35, 0.35, 0.38), false)
		for k in 3:
			c(-W / 2.0 + 0.14, ivf - 0.4 + k * 0.4, 0.91, 0.1, 0.18, 0.1, Color.from_hsv(_rng.randf(), 0.6, 0.9), false)
	# Lavacabezas y sala de espera.
	c(W / 2.0 - 1.0, 2.8, 0.0, 0.9, 1.0, 0.9, Color(0.9, 0.9, 0.92), true)
	c(W / 2.0 - 1.0, 2.8, 1.0, 0.6, 0.2, 0.6, Color(0.5, 0.6, 0.75), false)
	c(W / 2.0 - 1.0, 5.2, 0.0, 0.9, 0.45, 2.4, tela, true)
	c(W / 2.0 - 0.45, 5.2, 0.45, 0.2, 0.5, 2.4, tela, false)
	c(W / 2.0 - 1.9, 5.2, 0.0, 0.7, 0.4, 0.7, madera, true)
	plantas([Vector2(W / 2.0 - 0.6, D - 1.0)])
	if barberia:
		# Poste de barbero con rayas rojas y blancas junto a la puerta: brilla.
		for i in 6:
			var col: Color = Color(0.85, 0.12, 0.12) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
			c(W / 2.0 - 0.7, 1.2, 0.2 + i * 0.35, 0.3, 0.35, 0.3, col, i == 0)
		c(W / 2.0 - 0.7, 1.2, 2.3, 0.36, 0.1, 0.36, Color(0.9, 0.8, 0.3), false)
		var navaja: Node3D = Construir.caja(self, p(0.0, D - 0.3, 2.1), Vector3(1.4, 0.08, 0.06), Color(0.8, 0.9, 1.0), false, 2.5)
		if navaja != null:
			_decor_vivo.append(navaja)
	else:
		var tinte: Node3D = Construir.caja(self, p(W / 2.0 - 0.5, D - 0.6, 1.5), Vector3(0.3, 0.5, 0.3), VERDE_BRUMA, false, 2.0)
		if tinte != null:
			_decor_vivo.append(tinte)
	cuadro(0.0, 0.0, 1.7, "fondo")
	luz(-W * 0.2, D * 0.35, 2.7)
	luz(W * 0.15, D * 0.6, 2.7)


# Una pizarra con el menú (negra con letras claras en un Label3D).
func _pizarra(u: float, iv: float, lado: String) -> void:
	var texto: String = "MENÚ DEL DÍA\n"
	var carta: Array = Locales.carta(local, semilla)
	for it in carta:
		var d: Dictionary = it
		if bool(d.get("dia", false)):
			texto += "★ %s  %d $\n" % [str(d["nombre"]), int(d["precio"])]
	if not texto.contains("★"):
		texto += "Pregunta en el mostrador"
	match lado:
		"der":
			c(W / 2.0 - 0.08, iv, 1.1, 0.06, 1.1, 1.5, Color(0.1, 0.12, 0.1), false)
			var l: Label3D = Construir.texto(self, p(W / 2.0 - 0.14, iv, 1.65), texto, 18, Color(0.95, 0.95, 0.85))
			l.rotation.y = -PI / 2.0
		"izq":
			c(-W / 2.0 + 0.08, iv, 1.1, 0.06, 1.1, 1.5, Color(0.1, 0.12, 0.1), false)
			var l2: Label3D = Construir.texto(self, p(-W / 2.0 + 0.14, iv, 1.65), texto, 18, Color(0.95, 0.95, 0.85))
			l2.rotation.y = PI / 2.0
		_:
			c(u, D - 0.1, 1.2, 1.8, 1.0, 0.06, Color(0.1, 0.12, 0.1), false)
			var l3: Label3D = Construir.texto(self, p(u, D - 0.16, 1.7), texto, 18, Color(0.95, 0.95, 0.85))
			l3.rotation.y = PI


# ---------------------------------------------------------------------------
# De los datos a nodos.
# ---------------------------------------------------------------------------
func _construir_visual() -> void:
	var mb: ConstructorMalla = ConstructorMalla.new()
	var cuerpo: StaticBody3D = StaticBody3D.new()
	add_child(cuerpo)
	for cj in cajas:
		var pos: Vector3 = cj[0]
		var tam: Vector3 = cj[1]
		mb.caja(pos, tam, cj[2])
		if bool(cj[3]):
			var cs: CollisionShape3D = CollisionShape3D.new()
			var f: BoxShape3D = BoxShape3D.new()
			f.size = tam
			cs.shape = f
			cs.position = pos
			cuerpo.add_child(cs)
	if mb.esta_vacio():
		return
	var malla: ArrayMesh = ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.superficie())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = malla
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _poner_luces() -> void:
	for lp in luces:
		var l: OmniLight3D = Construir.luz(self, lp, Color(1.0, 0.86, 0.6), 0.9, 7.5)
		l.shadow_enabled = false
		_luces_nodos.append(l)
		# Pantalla de la lámpara.
		Construir.caja(self, (lp as Vector3) + Vector3(0, 0.25, 0), Vector3(0.5, 0.12, 0.5), Color(1.0, 0.9, 0.6), false, 1.5)


func _poner_mostrador() -> void:
	var datos: Dictionary = Locales.LOCALES[local]
	var ivm: float = D - 1.7
	_mostrador = Node3D.new()
	_mostrador.position = p(_uc, ivm - 1.1, 0.0)
	add_child(_mostrador)
	# Quien atiende: detrás del mostrador, mirando a la puerta.
	var ruta: String = "quaternius/toon-shooter-game-kit/Characters/" + str(PERSONAJES[semilla % PERSONAJES.size()])
	_npc = Assets.personaje(ruta, "", "Idle")
	if _npc != null:
		_npc.position = p(_uc, D - 0.85, 0.0)
		_npc.rotation.y = 0.0
		add_child(_npc)
	var cartel: Label3D = Construir.texto(self, p(_uc, D - 0.85, 2.35), "%s" % str(datos["npc"]), 22, Color(1, 0.95, 0.75))
	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.name = "CartelPersonal"
	var m: MostradorLocal = MostradorLocal.new()
	m.local_mundo = self
	m.position = p(_uc, ivm - 1.0, 1.0)
	add_child(m)


# Mientras estás dentro, los guardias pierden tu rastro antes, el clima suena apagado, etc.
func _zona_interior() -> void:
	var zona: Area3D = Area3D.new()
	var forma: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(W, 2.8, D)
	forma.shape = caja
	zona.position = p(0.0, D / 2.0, 1.5)
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo.is_in_group("jugador") and not _dentro:
			_dentro = true
			Juego.interiores += 1)
	zona.body_exited.connect(func(cuerpo: Node3D) -> void:
		if cuerpo.is_in_group("jugador") and _dentro:
			_dentro = false
			Juego.interiores = maxi(0, Juego.interiores - 1))


func _exit_tree() -> void:
	if _dentro:
		_dentro = false
		Juego.interiores = maxi(0, Juego.interiores - 1)


func _process(delta: float) -> void:
	_tiempo += delta
	_t += delta
	for i in _decor_vivo.size():
		var n: Node3D = _decor_vivo[i]
		if is_instance_valid(n) and n is MeshInstance3D and (n as MeshInstance3D).mesh is SphereMesh:
			n.position.y += sin(_tiempo * 1.6) * delta * 0.12
	if _t < 1.0:
		return
	_t = 0.0
	_actualizar_abierto(false)


func _actualizar_abierto(forzar: bool) -> void:
	var abierto: bool = Locales.abierto(local, Juego.hora)
	if abierto == _abierto and not forzar:
		return
	_abierto = abierto
	if _npc != null:
		_npc.visible = abierto
	var cartel: Node = get_node_or_null("CartelPersonal")
	if cartel is Node3D:
		(cartel as Node3D).visible = abierto
	for l in _luces_nodos:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = 0.9 if abierto else 0.0


func esta_abierto() -> bool:
	return _abierto


func carta() -> Array:
	return Locales.carta(local, semilla)


# ---------------------------------------------------------------------------
# Pedir y pagar. Todo estático para poder probarlo sin escena.
# ---------------------------------------------------------------------------

# El vehículo del taller (el más cercano a "pos"), o null.
static func vehiculo_taller(arbol: SceneTree, pos: Vector3):
	return ServicioMundo.vehiculo_cercano(arbol, pos, 18.0)


# Precio de un servicio del taller para un vehículo (-1 si no se puede: sin vehículo o no hace falta).
static func precio_taller(item: Dictionary, v) -> int:
	var clase: String = str(item.get("vehiculo", ""))
	if clase == "bidon":
		return int(item["precio"])
	if clase == "bruma":
		return int(item["precio"]) if v != null else -1
	if v == null:
		return -1
	var desc: float = Juego.descuento_servicio("taller")
	match clase:
		"reparar":
			var falta: float = 100.0 - float(v.get("salud"))
			if falta < 0.5:
				return -1
			return maxi(1, int(round(maxi(1, int(ceil(falta * Economia.REPARACION_POR_PORCENTAJE))) * (1.0 - desc))))
		"revision":
			var s: float = float(v.get("salud"))
			var mejora: float = minf(40.0, 100.0 - s)
			if mejora < 0.5:
				return -1
			return maxi(1, int(round(maxi(1, int(ceil(mejora * Economia.REPARACION_POR_PORCENTAJE * 0.75))) * (1.0 - desc))))
		"repostar":
			var gas: float = 100.0 - float(v.get("gasolina"))
			if gas < 0.5:
				return -1
			var gasto: float = float(Vehiculo.TIPOS[v.tipo].get("gasto", 1.0))
			return maxi(1, int(ceil(gas * Economia.GASOLINA_POR_PORCENTAJE * gasto * 1.1)))
	return -1


# Pide un producto. Devuelve {"ok": bool, "msg": String}. "precio" es el que se enseña en la carta
# (en el taller se calcula aquí con el vehículo).
static func pedir(item: Dictionary, v = null, id_local: String = "") -> Dictionary:
	var precio: int = precio_final(item, id_local)
	var clase: String = str(item.get("vehiculo", ""))
	if clase != "":
		precio = precio_taller(item, v)
		if precio < 0:
			if clase == "bidon":
				return {"ok": false, "msg": "No se puede."}
			if v == null:
				return {"ok": false, "msg": "Acerca un vehículo al taller (a menos de 18 m)."}
			return {"ok": false, "msg": "Eso no hace falta ahora."}
	var magico: String = str(item.get("magico", ""))
	if magico != "" and not Juego.tiene(magico, 1):
		return {"ok": false, "msg": "Para eso necesitas una %s." % str(Juego.DatosObjetos.datos(magico)["nombre"])}
	if clase == "bidon" and not Juego.cabe("bidon_gasolina", 1):
		return {"ok": false, "msg": "No te cabe el bidón."}
	var objeto: String = str(item.get("objeto", ""))
	if objeto != "" and not Juego.cabe(objeto, 1):
		return {"ok": false, "msg": "No te cabe en la mochila."}
	if not Juego.gastar(precio):
		return {"ok": false, "msg": "Cuesta %d $ y no te llega." % precio}
	if magico != "":
		Juego.quitar(magico, 1)
	if clase != "":
		return {"ok": true, "msg": _aplicar_taller(clase, v, precio)}
	if objeto != "":
		Juego.anadir(objeto, 1)
		return {"ok": true, "msg": "Te llevas %s (%d $)." % [str(item["nombre"]).to_lower(), precio]}
	return {"ok": true, "msg": _aplicar_consumo(item, precio)}


# Precio de un producto de comida o bebida con el descuento de hostelería (el que trabaja ahí paga la mitad).
static func precio_final(item: Dictionary, id_local: String) -> int:
	var p: int = int(item["precio"])
	if id_local != "" and not item.has("vehiculo"):
		p = maxi(1, int(round(p * (1.0 - Juego.descuento_servicio(id_local)))))
	return p


static func _aplicar_taller(clase: String, v, precio: int) -> String:
	match clase:
		"reparar":
			v.set("salud", 100.0)
			v.guardar_estado()
			return "Vehículo reparado por %d $." % precio
		"revision":
			v.set("salud", minf(100.0, float(v.get("salud")) + 40.0))
			v.guardar_estado()
			return "Revisión hecha: más salud para el vehículo (%d $)." % precio
		"repostar":
			v.set("gasolina", 100.0)
			v.guardar_estado()
			return "Depósito lleno por %d $." % precio
		"bidon":
			Juego.anadir("bidon_gasolina", 1)
			return "Compras un bidón de gasolina (%d $)." % precio
		"bruma":
			v.set("salud", 100.0)
			v.set("gasolina", 100.0)
			v.guardar_estado()
			return "El aceite de bruma brilla un momento: vehículo como nuevo y depósito lleno (%d $)." % precio
	return ""


static func _aplicar_consumo(item: Dictionary, precio: int) -> String:
	if item.has("hambre"):
		Juego.comer(float(item["hambre"]))
	if item.has("sed"):
		Juego.beber(float(item["sed"]))
	if item.has("vida"):
		Juego.cambiar_vida(float(item["vida"]))
	if item.has("energia"):
		Juego.resistencia = minf(Juego.resistencia_max(), Juego.resistencia + float(item["energia"]))
		if Juego.agotado and Juego.resistencia > 30.0:
			Juego.agotado = false
		Juego.cambio.emit()
	for e in item.get("efectos", []):
		var ef: Dictionary = e
		Juego.aplicar_efecto(str(ef["id"]), float(ef["dur"]), float(ef.get("f", 1.0)))
	var extra: String = ""
	if int(item.get("alcohol", 0)) > 0:
		if _copas_dia != Juego.dia:
			_copas_dia = Juego.dia
			_copas = 0
		_copas += int(item["alcohol"])
		if _copas >= Locales.COPAS_PARA_MAREARSE:
			Juego.aplicar_efecto("mareo", 45.0, 0.6)
			extra = " Te has pasado con las copas: el mundo da vueltas."
	if bool(item.get("rumor", false)):
		Juego.cambiar_rep("hampa", 1)
		extra += " " + str(Casino.RUMORES[randi() % Casino.RUMORES.size()])
	return "Pides %s (%d $).%s" % [str(item["nombre"]).to_lower(), precio, extra]


# Cuántas copas llevas hoy (para la ventana).
static func copas_hoy() -> int:
	return _copas if _copas_dia == Juego.dia else 0


static func reiniciar_copas() -> void:
	_copas_dia = -1
	_copas = 0


# ---------------------------------------------------------------------------
# El mostrador (lo que se usa con E).
# ---------------------------------------------------------------------------
class MostradorLocal extends Interactuable:
	var local_mundo: LocalMundo = null

	func _ready() -> void:
		distancia = 2.6

	func texto_accion() -> String:
		if local_mundo == null:
			return ""
		var nom: String = local_mundo.nombre
		if not local_mundo.esta_abierto():
			return "%s: cerrado (abre %s)" % [nom, Locales.texto_horario(local_mundo.local)]
		if Locales.es_taller(local_mundo.local):
			return "%s: servicios del taller" % nom
		if Locales.es_aspecto(local_mundo.local):
			return "%s: cambiar de aspecto" % nom
		return "%s: ver la carta y pedir" % nom

	func usar(jugador: Node) -> void:
		if local_mundo == null:
			return
		if not local_mundo.esta_abierto():
			Juego.avisar("%s está cerrado. Abre de %s." % [local_mundo.nombre, Locales.texto_horario(local_mundo.local)])
			return
		if Locales.es_aspecto(local_mundo.local):
			if jugador != null and "hud" in jugador and jugador.hud != null:
				var vp: VentanaPeluqueria = VentanaPeluqueria.new()
				vp.local = local_mundo.local
				jugador.hud.abrir_ventana(vp)
			return
		if jugador != null and "hud" in jugador and jugador.hud != null:
			var v: VentanaLocal = VentanaLocal.new()
			v.local_mundo = local_mundo
			jugador.hud.abrir_ventana(v)
