# servidor_chat.gd
# -----------------------------------------------------------------------------
# Las REGLAS del chat. No tiene nodos, ni pantalla, ni red: solo datos y
# decisiones. Por eso sirve igual para:
#   - un jugador (lo usa el propio juego, en local),
#   - el servidor dedicado (headless), que es el único que manda (ver
#     docs/MULTIJUGADOR.md: servidor autoritativo),
#   - las pruebas automáticas.
#
# El cliente NUNCA decide a quién llega un mensaje: pide "quiero decir X en el
# canal Y" y el servidor comprueba y reparte. Aquí se aplican:
#   - alcance por distancia (cercano y gritar), grupos, privados y facciones,
#   - límites de tasa y de tamaño, anti-spam (texto repetido) y silencio temporal,
#   - limpieza del texto (sin símbolos de formato ni caracteres raros) y filtro
#     de palabras feas,
#   - lista de ignorados por jugador y comandos de moderación para admins.
# -----------------------------------------------------------------------------
class_name ServidorChat
extends RefCounted

# id (int) -> {"id","nombre","pos","grupo","faccion","admin","ignorados","silencio_hasta",
#              "marcas": [tiempos], "textos": [[texto, tiempo]], "infracciones": [tiempos],
#              "ultimo_gritar": float}
var jugadores: Dictionary = {}
var _siguiente_mensaje: int = 1

# Palabras que se tapan (lista corta y suave; el servidor puede ampliarla).
var palabras_feas: PackedStringArray = ["gilipollas", "imbecil", "imbécil", "puta", "puto", "mierda", "cabron", "cabrón"]


# ------------------------------- Jugadores ------------------------------------

func registrar(id: int, nombre: String, pos: Vector3 = Vector3.ZERO, grupo: String = "",
		faccion: String = "", admin: bool = false) -> void:
	jugadores[id] = {
		"id": id, "nombre": limpiar_nombre(nombre), "pos": pos, "grupo": grupo, "faccion": faccion,
		"admin": admin, "ignorados": [], "silencio_hasta": 0.0, "marcas": [], "textos": [],
		"infracciones": [], "ultimo_gritar": -1000.0,
	}


func quitar(id: int) -> void:
	jugadores.erase(id)


func mover(id: int, pos: Vector3) -> void:
	if jugadores.has(id):
		jugadores[id]["pos"] = pos


func buscar_por_nombre(nombre: String) -> int:
	var n: String = nombre.strip_edges().to_lower()
	for id in jugadores:
		if String(jugadores[id]["nombre"]).to_lower() == n:
			return int(id)
	return -1


func nombres() -> PackedStringArray:
	var l: PackedStringArray = PackedStringArray()
	for id in jugadores:
		l.append(String(jugadores[id]["nombre"]))
	return l


# --------------------------------- Limpieza -----------------------------------

# Solo letras, números, espacios y signos normales. Sin saltos de línea, sin
# corchetes (así nadie se cuela con formato) y con tamaño máximo.
func limpiar_nombre(nombre: String) -> String:
	var t: String = _limpiar_basico(nombre)
	if t.length() > Canales.MAX_LARGO_NOMBRE:
		t = t.substr(0, Canales.MAX_LARGO_NOMBRE)
	return t if t != "" else "Jugador"


func limpiar_texto(texto: String) -> String:
	var t: String = _limpiar_basico(texto)
	if t.length() > Canales.MAX_LARGO:
		t = t.substr(0, Canales.MAX_LARGO)
	return filtrar(t)


func _limpiar_basico(texto: String) -> String:
	var salida: String = ""
	for i in texto.length():
		var c: int = texto.unicode_at(i)
		if c < 32 or c == 127 or (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E):
			salida += " "
		elif c == 91 or c == 93:        # [ ]
			salida += "(" if c == 91 else ")"
		else:
			salida += String.chr(c)
	# Espacios repetidos fuera.
	var partes: PackedStringArray = salida.split(" ", false)
	return " ".join(partes).strip_edges()


func filtrar(texto: String) -> String:
	var t: String = texto
	var bajo: String = t.to_lower()
	for p in palabras_feas:
		var desde: int = 0
		while true:
			var i: int = bajo.find(p, desde)
			if i < 0:
				break
			t = t.substr(0, i) + "*".repeat(p.length()) + t.substr(i + p.length())
			desde = i + p.length()
	return t


# ------------------------------- Enviar mensajes ------------------------------

# Resultado: {"ok": bool, "error": String, "entregas": [{"para": id, "msg": {...}}]}
# "ahora" son segundos (reloj del servidor).
func procesar(emisor: int, canal: int, texto: String, destino: String, ahora: float) -> Dictionary:
	var fallo: Dictionary = {"ok": false, "error": "", "entregas": []}
	if not jugadores.has(emisor):
		fallo["error"] = "No estás conectado."
		return fallo
	var j: Dictionary = jugadores[emisor]
	if not Canales.es_escribible(canal):
		fallo["error"] = "Ahí no se puede escribir."
		return fallo
	if ahora < float(j["silencio_hasta"]):
		fallo["error"] = "Estás silenciado %d s más." % int(ceil(float(j["silencio_hasta"]) - ahora))
		return fallo
	var limpio: String = limpiar_texto(texto)
	if limpio == "":
		fallo["error"] = "Escribe algo."
		return fallo
	var motivo: String = _comprobar_tasa(j, canal, limpio, ahora)
	if motivo != "":
		_infraccion(j, ahora)
		fallo["error"] = motivo
		return fallo
	# Destinatarios.
	var para: Array = []
	var etiqueta_destino: String = ""
	match canal:
		Canales.Id.CERCANO:
			para = _en_alcance(j, Canales.ALCANCE_CERCANO)
		Canales.Id.GRITAR:
			para = _en_alcance(j, Canales.ALCANCE_GRITAR)
			limpio = limpio.to_upper()
		Canales.Id.GRUPO:
			if String(j["grupo"]) == "":
				fallo["error"] = "No estás en ningún grupo (/grupo unir NOMBRE)."
				return fallo
			para = _miembros("grupo", String(j["grupo"]))
		Canales.Id.FACCION:
			if String(j["faccion"]) == "":
				fallo["error"] = "No tienes facción (/faccion unir NOMBRE)."
				return fallo
			para = _miembros("faccion", String(j["faccion"]))
		Canales.Id.PRIVADO:
			var otro: int = buscar_por_nombre(destino)
			if otro < 0:
				fallo["error"] = "No hay nadie llamado «%s»." % destino
				return fallo
			if otro == emisor:
				fallo["error"] = "No puedes escribirte a ti mismo."
				return fallo
			etiqueta_destino = String(jugadores[otro]["nombre"])
			para = [emisor, otro]
	# Anotar el mensaje para los límites.
	_anotar(j, canal, limpio, ahora)
	var msg: Dictionary = _crear_mensaje(canal, emisor, String(j["nombre"]), limpio, etiqueta_destino)
	var entregas: Array = []
	for id in para:
		var r: Dictionary = jugadores[id]
		# Quien ignora al emisor no lo recibe (pero el emisor siempre ve lo suyo).
		if id != emisor and (r["ignorados"] as Array).has(String(j["nombre"]).to_lower()):
			continue
		entregas.append({"para": int(id), "msg": msg})
	return {"ok": true, "error": "", "entregas": entregas}


func _crear_mensaje(canal: int, de_id: int, de: String, texto: String, para: String = "", cat: String = "") -> Dictionary:
	var m: Dictionary = {"id": _siguiente_mensaje, "canal": canal, "de_id": de_id, "de": de, "texto": texto,
			"t": Time.get_unix_time_from_system()}
	if para != "":
		m["para"] = para
	if cat != "":
		m["cat"] = cat
	_siguiente_mensaje += 1
	return m


func _en_alcance(j: Dictionary, radio: float) -> Array:
	var l: Array = []
	for id in jugadores:
		var o: Dictionary = jugadores[id]
		if (o["pos"] as Vector3).distance_to(j["pos"]) <= radio:
			l.append(int(id))
	return l


func _miembros(campo: String, valor: String) -> Array:
	var l: Array = []
	for id in jugadores:
		if String(jugadores[id][campo]).to_lower() == valor.to_lower():
			l.append(int(id))
	return l


# Mensaje del sistema para un jugador (solo lo puede crear el servidor).
func notificar(para: int, texto: String, categoria: String = "otros") -> Dictionary:
	var cat: String = categoria if Canales.CATEGORIAS.has(categoria) else "otros"
	var msg: Dictionary = _crear_mensaje(Canales.Id.SISTEMA, 0, "Sistema", limpiar_texto(texto), "", cat)
	return {"para": para, "msg": msg}


# Mensaje del sistema para todos (anuncio del servidor).
func anunciar(texto: String, categoria: String = "otros") -> Array:
	var l: Array = []
	for id in jugadores:
		l.append(notificar(int(id), texto, categoria))
	return l


# ------------------------------- Límites y spam -------------------------------

func _comprobar_tasa(j: Dictionary, canal: int, texto: String, ahora: float) -> String:
	var marcas: Array = j["marcas"]
	while not marcas.is_empty() and ahora - float(marcas[0]) > Canales.VENTANA_SEG:
		marcas.pop_front()
	if not marcas.is_empty() and ahora - float(marcas.back()) < Canales.ESPERA_MIN:
		return "Más despacio."
	if marcas.size() >= Canales.LIMITE_MENSAJES:
		return "Demasiados mensajes seguidos. Espera un momento."
	if canal == Canales.Id.GRITAR and ahora - float(j["ultimo_gritar"]) < Canales.ESPERA_GRITAR:
		return "Tienes la garganta cansada: espera %d s para gritar." % int(ceil(Canales.ESPERA_GRITAR - (ahora - float(j["ultimo_gritar"]))))
	var textos: Array = j["textos"]
	while not textos.is_empty() and ahora - float(textos[0][1]) > Canales.SEG_REPETIDOS:
		textos.pop_front()
	var repes: int = 0
	for t in textos:
		if String(t[0]) == texto.to_lower():
			repes += 1
	if repes >= Canales.MAX_REPETIDOS - 1:
		return "Eso ya lo has dicho (anti-spam)."
	return ""


func _anotar(j: Dictionary, canal: int, texto: String, ahora: float) -> void:
	(j["marcas"] as Array).append(ahora)
	(j["textos"] as Array).append([texto.to_lower(), ahora])
	if canal == Canales.Id.GRITAR:
		j["ultimo_gritar"] = ahora


func _infraccion(j: Dictionary, ahora: float) -> void:
	var inf: Array = j["infracciones"]
	inf.append(ahora)
	while not inf.is_empty() and ahora - float(inf[0]) > 60.0:
		inf.pop_front()
	if inf.size() >= Canales.INFRACCIONES_PARA_SILENCIO:
		j["silencio_hasta"] = ahora + Canales.SEG_SILENCIO
		inf.clear()


# --------------------------- Grupos, facciones, ignorar -----------------------

func unir(id: int, campo: String, nombre: String) -> String:
	if not jugadores.has(id) or (campo != "grupo" and campo != "faccion"):
		return "No se puede."
	var n: String = limpiar_nombre(nombre)
	if n == "Jugador" and nombre.strip_edges() == "":
		return "Pon un nombre."
	jugadores[id][campo] = n
	return ""


func salir(id: int, campo: String) -> void:
	if jugadores.has(id) and (campo == "grupo" or campo == "faccion"):
		jugadores[id][campo] = ""


func ignorar(id: int, nombre: String) -> String:
	if not jugadores.has(id):
		return "No se puede."
	var n: String = nombre.strip_edges().to_lower()
	if n == "" or n == String(jugadores[id]["nombre"]).to_lower():
		return "Elige a otra persona."
	var l: Array = jugadores[id]["ignorados"]
	if not l.has(n):
		l.append(n)
	return ""


func dejar_de_ignorar(id: int, nombre: String) -> void:
	if jugadores.has(id):
		(jugadores[id]["ignorados"] as Array).erase(nombre.strip_edges().to_lower())


# Moderación: solo admins.
func silenciar_jugador(admin: int, nombre: String, segundos: float, ahora: float) -> String:
	if not jugadores.has(admin) or not bool(jugadores[admin]["admin"]):
		return "No tienes permiso."
	var otro: int = buscar_por_nombre(nombre)
	if otro < 0:
		return "No hay nadie llamado «%s»." % nombre
	jugadores[otro]["silencio_hasta"] = ahora + clampf(segundos, 0.0, 86400.0)
	return ""
