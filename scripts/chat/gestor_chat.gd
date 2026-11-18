# gestor_chat.gd  (autoload "Chat")
# -----------------------------------------------------------------------------
# Une las tres piezas del chat:
#   1. LAS REGLAS (ServidorChat): quién oye qué, límites, moderación.
#   2. LA PUERTA DE RED: en un jugador todo es local; en multijugador el cliente
#      manda sus mensajes al servidor con @rpc y el servidor reparte las
#      respuestas (servidor autoritativo, ver docs/MULTIJUGADOR.md).
#   3. EL CLIENTE: guarda el historial y avisa a la pantalla (PanelChat).
#
# En un jugador además:
#   - los avisos del juego (cobros, encargos, policía, cosechas...) entran por
#     el canal Sistema,
#   - hay "vecinos" simulados que hablan por los distintos canales para que se
#     vea funcionar (cercano, gritar, grupo, privado y facción).
#
# Uso desde cualquier script:
#   Chat.enviar(Canales.Id.CERCANO, "Hola")
#   Chat.sistema("Cobras 50 $", "cobros")
# -----------------------------------------------------------------------------
extends Node

signal mensaje_nuevo(msg: Dictionary)      # Algo nuevo para pintar.
signal historial_cambiado                  # Se ha limpiado, etc.
signal ajustes_cambiados                   # Filtros, ignorados, grupo, facción.

const RUTA_AJUSTES: String = "user://chat.cfg"
const ID_LOCAL: int = 1

var servidor: ServidorChat = ServidorChat.new()
var mi_id: int = ID_LOCAL
var mi_nombre: String = "Forastero"
var historial: Array = []                  # Mensajes recibidos (los más nuevos al final).
var filtros: Dictionary = {}               # id de canal -> true si se ve en la pestaña "Todo".
var simulacion: bool = true                # Vecinos simulados (solo en un jugador).
var jugador: Node3D = null                 # Para saber dónde estás (lo pone el HUD).
var ultimo_canal: int = Canales.Id.CERCANO
var ultimo_destino: String = ""

var _ultimo_aviso: String = ""
var _t_ultimo_aviso: float = -10.0
var _bots: Dictionary = {}                 # id -> {"nombre","distancia","angulo","velocidad"}
var _t_siguiente_bot: float = 14.0
var _respuestas: Array = []                # [{"t": segundos, "bot": id, "texto": String}]
var _reloj: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in Canales.ORDEN:
		filtros[id] = true
	_cargar_ajustes()
	servidor.registrar(mi_id, mi_nombre, Vector3.ZERO, _grupo_guardado, _faccion_guardada)
	for n in _ignorados_guardados:
		servidor.ignorar(mi_id, n)
	if Juego != null:
		Juego.mensaje.connect(_aviso_del_juego)
		Juego.dia_nuevo.connect(func() -> void: sistema("Amanece el día %d." % Juego.dia, "otros"))
	if multiplayer != null:
		multiplayer.peer_disconnected.connect(func(id: int) -> void: servidor.quitar(id))
	if simulacion:
		_crear_vecinos()
	_dar_la_bienvenida()


func _dar_la_bienvenida() -> void:
	sistema("Chat listo. Enter para escribir, Tab cambia de canal, /ayuda para ver los comandos.", "otros")


func _process(delta: float) -> void:
	_reloj += delta
	if jugador != null and is_instance_valid(jugador):
		servidor.mover(mi_id, jugador.global_position)
	if simulacion and not _hay_red():
		_mover_vecinos(delta)
		_tic_vecinos(delta)


func _hay_red() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer() \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _es_servidor() -> bool:
	return not _hay_red() or multiplayer.is_server()


# ------------------------------- Enviar ---------------------------------------

# Escribe en un canal (o un comando si empieza por "/"). "destino" es el nombre
# de la persona en el canal Privado.
func enviar(canal: int, texto: String, destino: String = "") -> void:
	var t: String = texto.strip_edges()
	if t == "":
		return
	if t.begins_with("/"):
		_comando(t, canal, destino)
		return
	ultimo_canal = canal
	ultimo_destino = destino
	if _hay_red() and not multiplayer.is_server():
		rpc_id(1, "_rpc_enviar", canal, t, destino)
	else:
		_atender(mi_id, canal, t, destino)


# El servidor (o el juego en local) decide y reparte.
func _atender(emisor: int, canal: int, texto: String, destino: String) -> void:
	var r: Dictionary = servidor.procesar(emisor, canal, texto, destino, _reloj)
	if not bool(r["ok"]):
		_entregar_a(emisor, servidor.notificar(emisor, String(r["error"]), "otros")["msg"])
		return
	for e in r["entregas"]:
		_entregar_a(int(e["para"]), e["msg"])


func _entregar_a(para: int, msg: Dictionary) -> void:
	if para == mi_id:
		_recibir(msg)
	elif _bots.has(para):
		_bot_recibe(para, msg)
	elif _hay_red() and multiplayer.is_server():
		rpc_id(para, "_rpc_recibir", msg)


func _recibir(msg: Dictionary) -> void:
	var m: Dictionary = msg.duplicate()
	m["hora_juego"] = Juego.texto_hora() if Juego != null else ""
	historial.append(m)
	if historial.size() > Canales.MAX_HISTORIAL:
		historial = historial.slice(historial.size() - Canales.MAX_HISTORIAL)
	mensaje_nuevo.emit(m)


# Aviso del sistema para ti.
func sistema(texto: String, categoria: String = "otros") -> void:
	var n: Dictionary = servidor.notificar(mi_id, texto, categoria)
	_recibir(n["msg"])


func limpiar() -> void:
	historial.clear()
	historial_cambiado.emit()


# ------------------------------- Red (@rpc) -----------------------------------
# Solo se usan con una partida en red. El servidor es el único que reparte.

@rpc("any_peer", "call_remote", "reliable")
func _rpc_enviar(canal: int, texto: String, destino: String) -> void:
	if not _es_servidor():
		return
	var emisor: int = multiplayer.get_remote_sender_id()
	if not servidor.jugadores.has(emisor):
		servidor.registrar(emisor, "Jugador %d" % emisor)
	_atender(emisor, canal, texto, destino)


@rpc("authority", "call_remote", "reliable")
func _rpc_recibir(msg: Dictionary) -> void:
	_recibir(msg)


# El cliente se presenta al entrar (nombre y posición se vuelven a comprobar en el servidor).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_hola(nombre: String) -> void:
	if not _es_servidor():
		return
	var emisor: int = multiplayer.get_remote_sender_id()
	servidor.registrar(emisor, nombre)


# ------------------------------- Comandos -------------------------------------

func _comando(texto: String, canal_actual: int, destino_actual: String) -> void:
	var partes: PackedStringArray = texto.substr(1).split(" ", false)
	if partes.is_empty():
		return
	var cmd: String = partes[0].to_lower()
	var resto: String = " ".join(partes.slice(1))
	# "/grupo unir X", "/grupo salir", "/faccion unir X"... se miran antes que el canal.
	if (cmd == "grupo" or cmd == "faccion" or cmd == "facción") and partes.size() >= 2 			and ["unir", "crear", "salir"].has(partes[1].to_lower()):
		_unir_o_salir("grupo" if cmd == "grupo" else "faccion", partes)
		return
	var canal: int = Canales.desde_clave(cmd)
	if canal >= 0 and Canales.es_escribible(canal):
		if canal == Canales.Id.PRIVADO:
			if partes.size() < 3:
				_aviso_local("Uso: /p NOMBRE mensaje")
				return
			enviar(canal, " ".join(partes.slice(2)), partes[1])
		else:
			if resto == "":
				ultimo_canal = canal
				ajustes_cambiados.emit()
			else:
				enviar(canal, resto)
		return
	match cmd:
		"w", "msg", "susurro":
			if partes.size() < 3:
				_aviso_local("Uso: /w NOMBRE mensaje")
			else:
				enviar(Canales.Id.PRIVADO, " ".join(partes.slice(2)), partes[1])
		"r", "responder":
			if ultimo_destino == "":
				_aviso_local("Nadie a quien responder.")
			else:
				enviar(Canales.Id.PRIVADO, resto, ultimo_destino)
		"ayuda", "help", "?":
			_ayuda()
		"limpiar", "clear":
			limpiar()
		"silenciar", "ignorar", "mute":
			ignorar(resto)
		"desilenciar", "perdonar", "unmute":
			dejar_de_ignorar(resto)
		"grupo":
			_unir_o_salir("grupo", partes)
		"faccion", "facción":
			_unir_o_salir("faccion", partes)
		"jugadores", "quien":
			_aviso_local("Conectados: " + ", ".join(servidor.nombres()))
		_:
			_aviso_local("No conozco /%s. Escribe /ayuda." % cmd)


func _unir_o_salir(campo: String, partes: PackedStringArray) -> void:
	var etiqueta: String = "grupo" if campo == "grupo" else "facción"
	if partes.size() >= 2 and partes[1].to_lower() == "salir":
		servidor.salir(mi_id, campo)
		_guardar_ajustes()
		ajustes_cambiados.emit()
		_aviso_local("Has salido de tu %s." % etiqueta)
	elif partes.size() >= 3 and (partes[1].to_lower() == "unir" or partes[1].to_lower() == "crear"):
		var e: String = servidor.unir(mi_id, campo, " ".join(partes.slice(2)))
		if e != "":
			_aviso_local(e)
		else:
			_guardar_ajustes()
			ajustes_cambiados.emit()
			_aviso_local("Ahora estás en el %s «%s»." % [etiqueta, String(servidor.jugadores[mi_id][campo])])
	else:
		var actual: String = String(servidor.jugadores[mi_id][campo])
		_aviso_local("Tu %s: %s. Uso: /%s unir NOMBRE  ·  /%s salir" % [etiqueta, actual if actual != "" else "ninguno", partes[0], partes[0]])


func _ayuda() -> void:
	for linea in [
		"Canales: /c cercano (25 m) · /gr gritar (120 m) · /g grupo · /f facción · /p NOMBRE privado",
		"Atajos: Enter escribe · Tab cambia de canal · ↑ ↓ recupera lo escrito · Esc cierra",
		"Otros: /r responder · /silenciar NOMBRE · /desilenciar NOMBRE · /grupo unir X · /faccion unir X · /jugadores · /limpiar",
	]:
		_aviso_local(linea)


# Un aviso solo para ti (no sale por la red).
func _aviso_local(texto: String) -> void:
	_recibir(servidor.notificar(mi_id, texto, "otros")["msg"])


func ignorar(nombre: String) -> void:
	var e: String = servidor.ignorar(mi_id, nombre)
	if e != "":
		_aviso_local(e)
		return
	_guardar_ajustes()
	ajustes_cambiados.emit()
	_aviso_local("Silenciado: %s (ya no verás lo que escriba)." % nombre.strip_edges())


func dejar_de_ignorar(nombre: String) -> void:
	servidor.dejar_de_ignorar(mi_id, nombre)
	_guardar_ajustes()
	ajustes_cambiados.emit()
	_aviso_local("Ya puedes leer a %s." % nombre.strip_edges())


func ignorados() -> Array:
	return (servidor.jugadores[mi_id]["ignorados"] as Array).duplicate()


func mi_grupo() -> String:
	return String(servidor.jugadores[mi_id]["grupo"])


func mi_faccion() -> String:
	return String(servidor.jugadores[mi_id]["faccion"])


func poner_filtro(canal: int, visible: bool) -> void:
	filtros[canal] = visible
	_guardar_ajustes()
	ajustes_cambiados.emit()


# ------------------------- Avisos del juego -> Sistema ------------------------

func _aviso_del_juego(texto: String) -> void:
	# Lo que repite el mismo texto en menos de 1,5 s se junta (por ejemplo, los
	# avisos de "Entras en..." al cruzar zonas).
	if texto == _ultimo_aviso and _reloj - _t_ultimo_aviso < 1.5:
		return
	_ultimo_aviso = texto
	_t_ultimo_aviso = _reloj
	sistema(texto, clasificar(texto))


# Decide a qué categoría pertenece un aviso del juego.
static func clasificar(texto: String) -> String:
	var t: String = texto.to_lower()
	for p in ["policía", "policia", "guardia", "patrulla", "multa", "¡alto", "registr", "cacheo", "búsqueda", "estrella", "perdido la pista", "carnet"]:
		if t.contains(p):
			return "policia"
	for p in ["encargo", "mensaje de", "pedido", "cliente", "móvil", "movil", "negociaci", "quiere alquilar", "ofrece"]:
		if t.contains(p):
			return "encargos"
	for p in ["cosech", "planta", "maceta", "crece", "lluvia", "huerto", "corral", "recoges", "riego", "regad", "manzan", "animal"]:
		if t.contains(p):
			return "cosechas"
	for p in ["cobr", "pagas", "pago", "alquiler", "$", "dinero", "meta cumplida", "sueldo", "compraste", "vendes", "vendiste", "gastos"]:
		if t.contains(p):
			return "cobros"
	return "otros"


# ------------------------------ Ajustes guardados -----------------------------

var _grupo_guardado: String = "Callejeros"
var _faccion_guardada: String = "Círculo de la Bruma"
var _ignorados_guardados: Array = []


func _cargar_ajustes() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) != OK:
		return
	for id in Canales.ORDEN:
		filtros[id] = bool(cfg.get_value("filtros", str(id), true))
	_grupo_guardado = String(cfg.get_value("chat", "grupo", _grupo_guardado))
	_faccion_guardada = String(cfg.get_value("chat", "faccion", _faccion_guardada))
	_ignorados_guardados = cfg.get_value("chat", "ignorados", []) as Array
	ultimo_canal = int(cfg.get_value("chat", "canal", ultimo_canal))


func _guardar_ajustes() -> void:
	if not servidor.jugadores.has(mi_id):
		return
	var cfg: ConfigFile = ConfigFile.new()
	for id in filtros:
		cfg.set_value("filtros", str(id), bool(filtros[id]))
	cfg.set_value("chat", "grupo", mi_grupo())
	cfg.set_value("chat", "faccion", mi_faccion())
	cfg.set_value("chat", "ignorados", ignorados())
	cfg.set_value("chat", "canal", ultimo_canal)
	cfg.save(RUTA_AJUSTES)


# --------------------------- Vecinos simulados (1 jugador) --------------------
# Cuatro personajes inventados que se mueven alrededor de ti a distintas
# distancias: así el canal Cercano (25 m) y Gritar (120 m) se comportan como
# en un servidor de verdad. El resto es texto de ambiente.

const VECINOS: Array = [
	{"id": 101, "nombre": "Marta", "dist": 9.0, "vel": 0.05, "grupo": "Callejeros", "faccion": "Círculo de la Bruma"},
	{"id": 102, "nombre": "Dani", "dist": 18.0, "vel": -0.04, "grupo": "Callejeros", "faccion": ""},
	{"id": 103, "nombre": "Iván", "dist": 70.0, "vel": 0.03, "grupo": "", "faccion": "Círculo de la Bruma"},
	{"id": 104, "nombre": "Lucía", "dist": 200.0, "vel": -0.02, "grupo": "", "faccion": ""},
]

const FRASES: Dictionary = {
	"cercano": ["¿Alguien sabe dónde compran hoja de bruma hoy?", "Cuidado, hay guardias en la plaza.", "Menuda noche, ¿verdad?", "Yo vendo barato en el mercado.", "¿Has visto el coche nuevo del concesionario?"],
	"gritar": ["¡¡SE VENDE CASA CERCA DE LA PLAZA!!", "¡Redada en el mercado!", "¡Quién quiere un tónico fresquito!"],
	"grupo": ["¿Quedamos en la herboristería?", "Tengo dos tónicos para el encargo de Marta.", "Os espero en la plaza.", "Hoy la poli está tranquila."],
	"faccion": ["La Bruma pide silencio esta noche.", "Quien tenga hojas de sobra, que las traiga al círculo.", "Cuidado con los chivatos."],
	"privado": ["Oye, ¿tienes un momento? Quiero hacerte un encargo.", "¿Sigues vendiendo? Te pago bien.", "Psst, luego te cuento algo."],
}

const RESPUESTAS: Array = ["Vale, entendido.", "Jajaja, buena.", "Ahora no puedo, luego hablamos.", "Perfecto, me parece bien.", "Mmm, déjame pensarlo.", "¡Hecho!"]


func _crear_vecinos() -> void:
	for v in VECINOS:
		var id: int = int(v["id"])
		servidor.registrar(id, String(v["nombre"]), Vector3(1000, 0, 1000), String(v["grupo"]), String(v["faccion"]))
		_bots[id] = {"nombre": v["nombre"], "dist": float(v["dist"]), "ang": randf() * TAU, "vel": float(v["vel"])}


func _mover_vecinos(delta: float) -> void:
	var centro: Vector3 = servidor.jugadores[mi_id]["pos"]
	for id in _bots:
		var b: Dictionary = _bots[id]
		b["ang"] = float(b["ang"]) + float(b["vel"]) * delta
		var p: Vector3 = centro + Vector3(cos(b["ang"]), 0.0, sin(b["ang"])) * float(b["dist"])
		servidor.mover(id, p)


func _tic_vecinos(delta: float) -> void:
	_t_siguiente_bot -= delta
	if _t_siguiente_bot <= 0.0:
		_t_siguiente_bot = randf_range(14.0, 30.0)
		_hablar_un_vecino()
	var i: int = 0
	while i < _respuestas.size():
		_respuestas[i]["t"] = float(_respuestas[i]["t"]) - delta
		if float(_respuestas[i]["t"]) <= 0.0:
			var r: Dictionary = _respuestas[i]
			_respuestas.remove_at(i)
			_atender(int(r["bot"]), Canales.Id.PRIVADO, String(r["texto"]), mi_nombre)
		else:
			i += 1


func _hablar_un_vecino() -> void:
	var id: int = _bots.keys().pick_random()
	var canales: Array = ["cercano", "cercano", "gritar", "grupo", "faccion", "privado"]
	var clave: String = canales.pick_random()
	var canal: int = Canales.desde_clave(clave)
	var texto: String = String(FRASES[clave].pick_random())
	_atender(id, canal, texto, mi_nombre)


# Un vecino recibe un mensaje: si es privado para él, contesta al rato.
func _bot_recibe(bot: int, msg: Dictionary) -> void:
	if int(msg["canal"]) == Canales.Id.PRIVADO and int(msg["de_id"]) == mi_id:
		_respuestas.append({"t": randf_range(1.2, 3.0), "bot": bot, "texto": String(RESPUESTAS.pick_random())})
