# casa_asaltable.gd
# -----------------------------------------------------------------------------
# Convierte una casa con interior en un sitio que se puede asaltar:
#   - la puerta de entrada está cerrada con llave (EntradaForzable) y las ventanas se pueden
#     forzar o romper,
#   - dentro hay de 1 a 4 personas (Vecino): de noche duermen; al anochecer y por la mañana
#     están despiertas y atentas; de día la casa suele estar vacía,
#   - hay muebles con botín (BotinCasa) según el tipo de casa (humilde, normal o rica),
#   - el ruido, la linterna y tus pasos despiertan a la gente (Asaltos.alerta_por_ruido),
#   - hay consecuencias: testigos, denuncias, alarma, estrellas de policía.
# Todo es opcional: con Asaltos.activo = false (o puertas_cerradas = false) las casas se
# quedan como antes.
#
# Es independiente de cómo se dibuje la casa. Solo necesita un diccionario "espec":
#   id, distrito, perfil (opcional), ancho, fondo, cara (+1 / -1: hacia dónde da la puerta),
#   semilla, camas (lista de {"pos": Vector3 local, "yaw": giro}), muebles (lista de
#   {"tipo": cajon|joyero|armario, "pos": Vector3 local}), ventanas_x (x de las ventanas de
#   la fachada), habitaciones (Rect2 locales), puerta_mundo (la PuertaMundo que se abre).
# El nodo va en el centro del suelo de la casa y todo se coloca en coordenadas locales:
# la puerta está en z = cara * fondo / 2.
#   - En el juego lo crea GestorInteriores con CasaAsaltable.desde_interior() usando el
#     reparto de InteriorCasa (camas y muebles reales).
#   - Para pruebas: CasaAsaltable.casa_de_prueba() levanta una casa completa con paredes.
# -----------------------------------------------------------------------------
class_name CasaAsaltable
extends Node3D

const G: float = 0.3        # Grosor de los muros (igual que en generador_mundo.gd).
const HUECO: float = 1.3    # Ancho de la puerta.

var id: String = "prueba"
var perfil: String = "normal"
var distrito: String = ""
var ancho: float = 10.0
var fondo: float = 8.0
var cara: float = 1.0
var semilla: int = 1
var espec: Dictionary = {}

var propia: bool = false         # Es tuya (alquilada o comprada): no se asalta.
var desvalijada: bool = false    # La asaltaron hace poco: no queda botín.
var denunciada: bool = false
var violencia: bool = false
var tiene_alarma: bool = false
var vecinos: Array = []
var puerta: EntradaForzable = null
var ventanas: Array = []
var botines: Array = []
var jugador_dentro: bool = false
var puerta_mundo: PuertaMundo = null
var duermen: bool = true         # A esta hora la gente duerme (si no, está despierta y atenta).

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _jugador: Node3D = null
var _alarma_sonada: bool = false
var _primer_asalto_contado: bool = false
var _t_luz: float = 0.0


# espec: ver la cabecera del archivo.
func configurar(e: Dictionary) -> CasaAsaltable:
	espec = e
	id = str(e.get("id", id))
	distrito = str(e.get("distrito", distrito))
	ancho = float(e.get("ancho", ancho))
	fondo = float(e.get("fondo", fondo))
	cara = float(e.get("cara", cara))
	perfil = str(e.get("perfil", Asaltos.perfil_de(distrito, bool(e.get("pequena", false)))))
	semilla = int(e.get("semilla", hash(id)))
	puerta_mundo = e.get("puerta_mundo") as PuertaMundo
	return self


# Casa del mundo grande: usa el reparto de InteriorCasa (datos["camas"] y datos["muebles"]) y la
# puerta que ya puso GestorInteriores. "c" es el diccionario de GeneradorMundo.casa().
static func desde_interior(c: Dictionary, datos: Dictionary, pu: PuertaMundo) -> CasaAsaltable:
	var centro: Vector3 = Vector3(float(c["x"]), float(c["y"]), float(c["z"]))
	var camas: Array = []
	for b in datos.get("camas", []):
		camas.append({"pos": (b["pos"] as Vector3) - centro, "yaw": float(b["yaw"])})
	var muebles: Array = []
	for m in datos.get("muebles", []):
		muebles.append({"tipo": str(m["tipo"]), "pos": (m["pos"] as Vector3) - centro})
	var habitaciones: Array = []
	for r in datos.get("habitaciones", []):
		var rr: Rect2 = r
		habitaciones.append(Rect2(rr.position.x - centro.x, rr.position.y - centro.z, rr.size.x, rr.size.y))
	var w: float = float(c["w"])
	var e: Dictionary = {"id": Asaltos.id_de_casa(c), "distrito": str(c.get("distrito", "")), "ancho": w, "fondo": float(c["d"]),
			"cara": float(c["puerta"]), "semilla": int(float(c["x"]) * 31.0 + float(c["z"]) * 17.0),
			"camas": camas, "muebles": muebles, "habitaciones": habitaciones, "ventanas_x": GeneradorMundo.ventanas_x(w),
			"puerta_mundo": pu, "pequena": w - 0.6 < 8.5 or float(c["d"]) - 0.6 < 7.5}
	var casa: CasaAsaltable = CasaAsaltable.new().configurar(e)
	casa.position = centro
	return casa


func _ready() -> void:
	Asaltos.asegurar_ajustes()
	add_to_group("casas_asaltables")
	_rng.seed = semilla
	tiene_alarma = _rng.randf() < float(Asaltos.PERFILES[perfil]["alarma"])
	var casas: Dictionary = Juego.asaltos_info.get("casas", {})
	desvalijada = casas.has(id) and Juego.dia - int(casas[id]) < Asaltos.DIAS_REPOSICION
	if not Asaltos.activo:
		return
	_construir_entradas()
	if desvalijada:
		for e in [puerta] + ventanas:
			(e as EntradaForzable).desbloquear()   # Ya la forzaste hace poco: la cerradura sigue rota.
	_construir_muebles_y_botin()
	_poblar()
	Juego.cambio.connect(_revisar_propiedad)
	_revisar_propiedad()


func _exit_tree() -> void:
	if jugador_dentro:
		Juego.interiores = maxi(0, Juego.interiores - 1)
		jugador_dentro = false


# ------------------------------- Coordenadas ---------------------------------

func a_mundo(local: Vector3) -> Vector3:
	return to_global(local)


func esta_fuera(pos_mundo: Vector3) -> bool:
	var l: Vector3 = to_local(pos_mundo)
	return absf(l.x) > ancho / 2.0 + 0.2 or absf(l.z) > fondo / 2.0 + 0.2


func esta_dentro(pos_mundo: Vector3) -> bool:
	var l: Vector3 = to_local(pos_mundo)
	return absf(l.x) < ancho / 2.0 - G and absf(l.z) < fondo / 2.0 - G and l.y > -0.5 and l.y < 3.2


# Camas por defecto (casa de prueba): contra las paredes del fondo.
func _camas_por_defecto() -> Array:
	var z_fondo: float = -cara * (fondo / 2.0 - G - 1.2)
	var z_medio: float = -cara * (fondo / 2.0 - G - 3.6)
	var x_izq: float = -ancho / 2.0 + G + 0.55
	var x_der: float = ancho / 2.0 - G - 0.55
	var yaw: float = 0.0 if cara > 0.0 else PI
	return [{"pos": Vector3(x_izq, 0.0, z_fondo), "yaw": yaw, "propia": true},
			{"pos": Vector3(x_der, 0.0, z_fondo), "yaw": yaw, "propia": true},
			{"pos": Vector3(x_izq, 0.0, z_medio), "yaw": yaw, "propia": true},
			{"pos": Vector3(x_der, 0.0, z_medio), "yaw": yaw, "propia": true}]


func _muebles_por_defecto() -> Array:
	var z: float = -cara * (fondo / 2.0 - G - 0.4)
	var xs: Array = [-ancho * 0.1, ancho * 0.12, ancho * 0.28, -ancho * 0.28]
	var lista: Array = []
	var tipos: Array = Asaltos.CONTENEDORES_POR_PERFIL[perfil]
	for i in tipos.size():
		lista.append({"tipo": tipos[i], "pos": Vector3(xs[i % 4], 0.45, z), "propio": true})
	return lista


# ------------------------------- Construcción --------------------------------

func _construir_entradas() -> void:
	var yaw: float = 0.0 if cara > 0.0 else PI
	puerta = EntradaForzable.new()
	puerta.tipo = "puerta"
	puerta.casa = self
	puerta.puerta_mundo = puerta_mundo
	# Con la puerta del juego (PuertaMundo) la entrada va justo delante; en la casa de prueba lleva su propia hoja.
	puerta.position = Vector3(0, 1.05, cara * (fondo / 2.0 - G / 2.0 + (0.45 if puerta_mundo != null else 0.0)))
	puerta.rotation.y = yaw
	puerta.rng.seed = semilla + 7
	add_child(puerta)
	var xs: Array = espec.get("ventanas_x", [ancho * 0.36])
	for i in xs.size():
		var v: EntradaForzable = EntradaForzable.new()
		v.tipo = "ventana"
		v.casa = self
		v.position = Vector3(float(xs[i]), 1.55, cara * (fondo / 2.0 + 0.3))
		v.rotation.y = yaw
		v.destino_local = Vector3(float(xs[i]), 0.15, cara * (fondo / 2.0 - G - 0.9))
		v.rng.seed = semilla + 11 + i
		add_child(v)
		ventanas.append(v)


func _construir_muebles_y_botin() -> void:
	var muebles: Array = espec.get("muebles", [])
	if muebles.is_empty():
		muebles = _muebles_por_defecto()
	var cupo: int = int(Asaltos.PERFILES[perfil]["cajones"])
	var puso_fuerte: bool = false
	var n: int = 0
	for m in muebles:
		if n >= cupo:
			break
		var tipo: String = str(m["tipo"])
		# En casas ricas, el primer armario esconde una caja fuerte.
		if perfil == "rica" and tipo == "armario" and not puso_fuerte:
			tipo = "caja_fuerte"
			puso_fuerte = true
		var p: Vector3 = m["pos"]
		if bool(m.get("propio", false)):
			_dibujar_mueble(tipo, p)
		var b: BotinCasa = BotinCasa.new()
		b.contenedor = tipo
		b.casa = self
		b.vacio = desvalijada
		b.rng.seed = semilla + 100 + n + Juego.dia * 13
		# El punto de uso va en el mueble, a media altura (el jugador lo alcanza desde 1,9 m).
		b.position = Vector3(p.x, maxf(p.y, 0.9), p.z)
		add_child(b)
		botines.append(b)
		n += 1


# Mueble que dibujo yo (solo en la casa de prueba; en el juego ya lo dibuja InteriorCasa).
func _dibujar_mueble(tipo: String, p: Vector3) -> void:
	var color: Color = Color(0.33, 0.22, 0.14)
	match tipo:
		"cajon":
			Construir.caja(self, Vector3(p.x, 0.45, p.z), Vector3(0.9, 0.9, 0.5), color, true)
		"joyero":
			Construir.caja(self, Vector3(p.x, 0.4, p.z), Vector3(0.9, 0.8, 0.5), color.lightened(0.1), true)
			Construir.caja(self, Vector3(p.x, 0.88, p.z), Vector3(0.35, 0.16, 0.25), Color(0.6, 0.15, 0.2), false)
		"armario":
			Construir.caja(self, Vector3(p.x, 1.0, p.z), Vector3(0.95, 2.0, 0.6), color.darkened(0.1), true)
		"caja_fuerte":
			Construir.caja(self, Vector3(p.x, 0.4, p.z), Vector3(0.7, 0.8, 0.55), Color(0.28, 0.3, 0.33), true)
			Construir.caja(self, Vector3(p.x, 0.45, p.z + cara * 0.29), Vector3(0.3, 0.3, 0.04), Color(0.65, 0.55, 0.25), false)


func _poblar() -> void:
	var ocup: Dictionary = Asaltos.ocupacion_a_las(Juego.hora)
	duermen = bool(ocup["duermen"])
	var camas: Array = espec.get("camas", [])
	if camas.is_empty():
		camas = _camas_por_defecto()
	var habitaciones: Array = espec.get("habitaciones", [])
	var rango: Array = Asaltos.PERFILES[perfil]["ocupantes"]
	var n: int = mini(_rng.randi_range(int(rango[0]), int(rango[1])), camas.size())
	for i in n:
		var rol: Dictionary = Asaltos.rol_aleatorio(_rng)
		var armado: bool = Asaltos.va_armado(distrito, _rng)
		var sueno: float = float(Asaltos.PERFILES[perfil]["sueno"]) * _rng.randf_range(0.75, 1.3)
		var presente: bool = _rng.randf() < float(ocup["presentes"])
		var cama: Dictionary = camas[i]
		var p: Vector3 = cama["pos"]
		if bool(cama.get("propia", false)):
			_poner_cama(p)
		if not presente:
			continue   # De día suele no haber nadie.
		var v: Vecino = Vecino.new()
		v.casa = self
		v.rol = rol
		v.armado = armado
		v.sueno = sueno
		v.rng.seed = semilla + 500 + i
		if duermen:
			v.position = Vector3(p.x, 0.45 + 0.1, p.z)
			v.rotation.y = float(cama.get("yaw", 0.0))
		else:
			v.atento = true
			var sitio: Vector3 = Vector3(p.x * 0.5, 0.1, p.z * 0.5)
			if not habitaciones.is_empty():
				var r: Rect2 = habitaciones[_rng.randi() % habitaciones.size()]
				sitio = Vector3(r.position.x + r.size.x / 2.0, 0.1, r.position.y + r.size.y / 2.0)
			v.position = sitio
		v.cama = a_mundo(Vector3(p.x, 0.6, p.z))
		v.salida = a_mundo(Vector3(0, 0.1, cara * (fondo / 2.0 + 1.5)))
		add_child(v)
		vecinos.append(v)


func _poner_cama(p: Vector3) -> void:
	Construir.caja(self, Vector3(p.x, 0.35, p.z), Vector3(1.0, 0.5, 2.0), Color(0.5, 0.15, 0.15), false)
	Construir.caja(self, Vector3(p.x, 0.2, p.z), Vector3(1.1, 0.2, 2.1), Color(0.3, 0.2, 0.12), true)


# Una casa completa con paredes, suelo, techo, luz y puerta, para probar sin depender del mundo.
static func casa_de_prueba(padre: Node3D, pos: Vector3, e: Dictionary) -> CasaAsaltable:
	var w: float = float(e.get("ancho", 10.0))
	var d: float = float(e.get("fondo", 8.0))
	var cara_c: float = float(e.get("cara", 1.0))
	var col: Color = e.get("color", Color(0.55, 0.5, 0.42))
	var raiz: Node3D = Node3D.new()
	raiz.position = pos
	padre.add_child(raiz)
	var alto: float = 3.2
	Construir.caja(raiz, Vector3(0, alto / 2.0, -cara_c * (d / 2.0 - G / 2.0)), Vector3(w, alto, G), col)
	for lado in [-1.0, 1.0]:
		Construir.caja(raiz, Vector3(lado * (w / 2.0 - G / 2.0), alto / 2.0, 0), Vector3(G, alto, d), col)
	var lado_w: float = (w - 2.0 * G - HUECO) / 2.0
	var zf: float = cara_c * (d / 2.0 - G / 2.0)
	for lado in [-1.0, 1.0]:
		Construir.caja(raiz, Vector3(lado * (HUECO / 2.0 + lado_w / 2.0 + G), alto / 2.0, zf), Vector3(lado_w + 2.0 * G, alto, G), col)
	Construir.caja(raiz, Vector3(0, 2.1 + (alto - 2.1) / 2.0, zf), Vector3(HUECO, alto - 2.1, G), col)
	Construir.caja(raiz, Vector3(0, -0.05, 0), Vector3(w, 0.1, d), Color(0.38, 0.26, 0.16))
	Construir.caja(raiz, Vector3(0, alto + 0.1, 0), Vector3(w, 0.2, d), col.darkened(0.3))
	Construir.luz(raiz, Vector3(0, 2.6, 0), Color(1.0, 0.8, 0.5), 0.8, 9.0)
	Construir.caja(raiz, Vector3(1.0, 0.42, 0.0), Vector3(1.4, 0.84, 0.8), Color(0.35, 0.24, 0.14))   # Mesa.
	var casa: CasaAsaltable = CasaAsaltable.new().configurar(e.duplicate())
	raiz.add_child(casa)
	return casa


# ------------------------------- Ruido y vida --------------------------------

func hacer_ruido(origen: Vector3, intensidad: float, desde_fuera: bool) -> void:
	if intensidad <= 0.0:
		return
	for v in vecinos:
		if is_instance_valid(v):
			(v as Vecino).oir(intensidad, origen, desde_fuera and not esta_dentro(origen))


func _process(delta: float) -> void:
	if not Asaltos.activo:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	var dentro: bool = esta_dentro(_jugador.global_position)
	if dentro != jugador_dentro:
		jugador_dentro = dentro
		Juego.interiores = maxi(0, Juego.interiores + (1 if dentro else -1))
	if not dentro or propia:
		return
	# Tus pasos hacen ruido (poco si vas agachado, mucho si corres).
	var vel: float = (_jugador as CharacterBody3D).velocity.length() if _jugador is CharacterBody3D else 0.0
	var corriendo: bool = Input.is_action_pressed("correr")
	var r: float = Asaltos.ruido_pasos(vel, _jugador.get("agachado") == true, corriendo)
	if r > 0.0:
		hacer_ruido(_jugador.global_position, r * delta * 3.0, false)
	# La linterna apuntando a la cara de alguien que duerme le despierta poco a poco.
	_t_luz -= delta
	if _t_luz <= 0.0:
		_t_luz = 0.2
		if _linterna_encendida():
			var cam: Camera3D = get_viewport().get_camera_3d()
			var adelante: Vector3 = -cam.global_basis.z if cam != null else Vector3.FORWARD
			for v in vecinos:
				if not is_instance_valid(v) or not (v as Vecino).esta_durmiendo():
					continue
				var al: Vector3 = v.global_position - _jugador.global_position
				if al.length() < 7.0 and al.normalized().dot(adelante) > 0.75:
					(v as Vecino).iluminar(0.2)


func _linterna_encendida() -> bool:
	if _jugador != null and _jugador.has_method("linterna_encendida"):
		return bool(_jugador.call("linterna_encendida"))
	return false


# ------------------------------- Consecuencias -------------------------------

func vecino_desperto(v: Vecino, motivo: String) -> void:
	var nombre: String = str(v.rol.get("nombre", "Alguien"))
	match motivo:
		"vista":
			testigo_te_vio(v)
		"ruido":
			Juego.avisar("¡%s ha oído algo!" % nombre if v.atento else "¡%s se despierta por el ruido!" % nombre)
		"luz":
			Juego.avisar("¡%s se despierta por la luz!" % nombre)
		"golpe":
			Juego.avisar("¡%s se despierta de golpe!" % nombre)
		_:
			Juego.avisar("¡%s se despierta!" % nombre)


func testigo_te_vio(v: Vecino) -> void:
	Juego.avisar("¡%s te ha visto!" % v.rol.get("nombre", "Alguien"))
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_ALLANAMIENTO, "Allanamiento de morada")


func denunciar(v: Vecino) -> void:
	if denunciada:
		return
	denunciada = true
	Juego.avisar("¡%s llama a la policía!" % v.rol.get("nombre", "Alguien"))
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_DENUNCIA, "Allanamiento denunciado")
	Juego.cambiar_rep("ley", -2)
	Juego.asaltos_info["buscado_hasta"] = Juego.dia + Asaltos.DIAS_BUSCADO
	Juego.cambio.emit()


func hubo_violencia() -> void:
	violencia = true


func sonar_alarma_si_hay(_motivo: String) -> void:
	if not tiene_alarma or _alarma_sonada or propia:
		return
	_alarma_sonada = true
	Juego.avisar("¡Salta la alarma antirrobo!")
	for v in vecinos:
		if is_instance_valid(v):
			(v as Vecino).oir(1.0, global_position, false)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(self) and not propia:
			Juego.exigir_estrellas(2, "Alarma antirrobo")
			Juego.avisar("La policía ha recibido el aviso de la alarma."))


func entrada_forzada(_e: EntradaForzable, _tipo: String) -> void:
	if _primer_asalto_contado:
		return
	_primer_asalto_contado = true
	Juego.asaltos_info["asaltos"] = int(Juego.asaltos_info.get("asaltos", 0)) + 1
	Juego.asaltos_info["casas"][id] = Juego.dia
	Juego.sospecha = minf(100.0, Juego.sospecha + 6.0)
	Juego.cambiar_rep("hampa", 1)


func botin_cogido(_b: BotinCasa) -> void:
	for b in botines:
		if is_instance_valid(b) and not (b as BotinCasa).vacio:
			return
	Juego.avisar("Has vaciado la casa. Mejor largarse antes de que despierten.")


# Si la casa pasa a ser tuya, deja de ser un blanco: puertas abiertas y nadie dentro.
func _revisar_propiedad() -> void:
	var ahora: bool = Juego.viviendas.has(id) or Juego.en_propiedad.has(id)
	if ahora == propia:
		return
	propia = ahora
	if propia:
		for e in [puerta] + ventanas:
			if e != null and is_instance_valid(e):
				(e as EntradaForzable).desbloquear()
		for v in vecinos:
			if is_instance_valid(v):
				(v as Node).queue_free()
		vecinos.clear()
