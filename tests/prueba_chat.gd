# Pruebas del chat: reglas del servidor (alcance, grupos, privados, límites,
# spam, moderación), avisos del sistema y comandos. Sin ventana:
#   godot --headless --path . res://tests/prueba_chat.tscn
extends Node

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func _para(r: Dictionary) -> Array:
	var l: Array = []
	for e in r["entregas"]:
		l.append(int(e["para"]))
	l.sort()
	return l


func _ready() -> void:
	await get_tree().process_frame
	_reglas()
	await _integracion()
	print("RESULTADO CHAT: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _reglas() -> void:
	var s: ServidorChat = ServidorChat.new()
	s.registrar(1, "Ana", Vector3(0, 0, 0), "Callejeros", "Bruma")
	s.registrar(2, "Beto", Vector3(20, 0, 0), "Callejeros", "")
	s.registrar(3, "Cleo", Vector3(30, 0, 0), "", "Bruma")
	s.registrar(4, "Dani", Vector3(100, 0, 0), "", "")
	s.registrar(5, "Eli", Vector3(500, 0, 0), "Otros", "")
	var t: float = 100.0

	# Cercano: 25 m.
	var r: Dictionary = s.procesar(1, Canales.Id.CERCANO, "hola", "", t)
	_ok(r["ok"] and _para(r) == [1, 2], "cercano llega a 20 m y no a 30 m: %s" % str(_para(r)))
	# Gritar: 120 m y en mayúsculas, con espera.
	t += 1.0
	r = s.procesar(1, Canales.Id.GRITAR, "socorro", "", t)
	_ok(r["ok"] and _para(r) == [1, 2, 3, 4], "gritar llega a 100 m y no a 500 m: %s" % str(_para(r)))
	_ok(r["ok"] and String(r["entregas"][0]["msg"]["texto"]) == "SOCORRO", "gritar sale en mayúsculas")
	t += 1.0
	r = s.procesar(1, Canales.Id.GRITAR, "otra", "", t)
	_ok(not r["ok"], "gritar tiene espera")
	t += 10.0
	# Grupo y facción.
	r = s.procesar(1, Canales.Id.GRUPO, "grupo", "", t)
	_ok(r["ok"] and _para(r) == [1, 2], "grupo solo llega a su grupo: %s" % str(_para(r)))
	t += 1.0
	r = s.procesar(1, Canales.Id.FACCION, "facción", "", t)
	_ok(r["ok"] and _para(r) == [1, 3], "facción solo llega a su facción: %s" % str(_para(r)))
	t += 1.0
	r = s.procesar(4, Canales.Id.GRUPO, "yo sin grupo", "", t)
	_ok(not r["ok"] and String(r["error"]) != "", "sin grupo no se puede escribir en grupo")
	# Privado.
	t += 1.0
	r = s.procesar(1, Canales.Id.PRIVADO, "secreto", "eli", t)
	_ok(r["ok"] and _para(r) == [1, 5], "privado llega a quien toca (aunque esté lejos): %s" % str(_para(r)))
	_ok(String(r["entregas"][0]["msg"]["para"]) == "Eli", "el privado lleva el nombre del destino")
	t += 1.0
	r = s.procesar(1, Canales.Id.PRIVADO, "x", "Nadie", t)
	_ok(not r["ok"], "privado a alguien que no existe falla")
	r = s.procesar(1, Canales.Id.SISTEMA, "x", "", t + 1.0)
	_ok(not r["ok"], "nadie escribe en Sistema")

	# Ignorados: Beto ignora a Ana y no la oye; ella sí se ve.
	s.ignorar(2, "ana")
	t += 5.0
	r = s.procesar(1, Canales.Id.CERCANO, "me oyes?", "", t)
	_ok(_para(r) == [1], "quien ignora no recibe: %s" % str(_para(r)))
	s.dejar_de_ignorar(2, "ana")

	# Limpieza.
	var sucio: String = s.limpiar_texto("[b]hola[/b]\n\tque   tal [url]")
	_ok(not sucio.contains("[") and not sucio.contains("\n") and not sucio.contains("  "), "texto limpio: «%s»" % sucio)
	_ok(s.limpiar_texto("a".repeat(500)).length() == Canales.MAX_LARGO, "tamaño máximo")
	_ok(s.limpiar_texto("eres un Gilipollas").contains("**********"), "filtro de palabras")
	_ok(s.limpiar_nombre("[Pepe]\n" + "x".repeat(60)).length() <= Canales.MAX_LARGO_NOMBRE, "nombre limitado")
	_ok(s.limpiar_nombre("   ") == "Jugador", "nombre vacío")

	# Límites de tasa: 5 mensajes en 8 s; el sexto se rechaza; 3 rechazos = silencio.
	var s2: ServidorChat = ServidorChat.new()
	s2.registrar(1, "Rafa", Vector3.ZERO)
	t = 1000.0
	var vistos: int = 0
	for i in 5:
		if s2.procesar(1, Canales.Id.CERCANO, "msg %d" % i, "", t)["ok"]:
			vistos += 1
		t += 1.0
	_ok(vistos == 5, "5 mensajes seguidos pasan (pasaron %d)" % vistos)
	r = s2.procesar(1, Canales.Id.CERCANO, "msg 6", "", t)
	_ok(not r["ok"], "el sexto en la ventana se rechaza")
	r = s2.procesar(1, Canales.Id.CERCANO, "msg 7", "", t + 0.1)
	_ok(not r["ok"], "demasiado rápido se rechaza")
	r = s2.procesar(1, Canales.Id.CERCANO, "msg 8", "", t + 0.2)
	_ok(not r["ok"] and s2.jugadores[1]["silencio_hasta"] > t, "tras 3 infracciones se silencia")
	r = s2.procesar(1, Canales.Id.CERCANO, "ya?", "", t + 5.0)
	_ok(not r["ok"] and String(r["error"]).contains("silenciado"), "silenciado no escribe")
	r = s2.procesar(1, Canales.Id.CERCANO, "ahora sí", "", t + 100.0)
	_ok(r["ok"], "el silencio termina")
	# Mensajes de usuarios distintos no se mezclan en la tasa.
	s2.registrar(2, "Sara", Vector3.ZERO)
	_ok(s2.procesar(2, Canales.Id.CERCANO, "hola", "", t + 100.0)["ok"], "cada jugador tiene su propio contador")

	# Spam: el mismo texto 3 veces seguidas.
	var s3: ServidorChat = ServidorChat.new()
	s3.registrar(1, "Spam", Vector3.ZERO)
	t = 5000.0
	var a: bool = s3.procesar(1, Canales.Id.CERCANO, "COMPRA YA", "", t)["ok"]
	var b: bool = s3.procesar(1, Canales.Id.CERCANO, "compra ya", "", t + 1.0)["ok"]
	var c: bool = s3.procesar(1, Canales.Id.CERCANO, "compra ya", "", t + 2.0)["ok"]
	_ok(a and b and not c, "repetir el mismo texto 3 veces es spam (%s %s %s)" % [a, b, c])

	# Moderación de admin.
	var s4: ServidorChat = ServidorChat.new()
	s4.registrar(1, "Jefe", Vector3.ZERO, "", "", true)
	s4.registrar(2, "Pepe", Vector3.ZERO)
	_ok(s4.silenciar_jugador(2, "jefe", 60.0, 0.0) != "", "un jugador normal no modera")
	_ok(s4.silenciar_jugador(1, "pepe", 60.0, 0.0) == "", "el admin silencia")
	_ok(not s4.procesar(2, Canales.Id.CERCANO, "hola", "", 10.0)["ok"], "el silenciado no escribe")

	# Anuncios del sistema.
	var n: Dictionary = s4.notificar(2, "Cobras 50 $", "cobros")
	_ok(int(n["msg"]["canal"]) == Canales.Id.SISTEMA and String(n["msg"]["cat"]) == "cobros", "notificar crea mensajes de sistema")
	_ok(s4.anunciar("Reinicio en 5 min").size() == 2, "anunciar llega a todos")

	# Clasificación de avisos del juego.
	var casos: Dictionary = {
		"¡Alto! Un guardia quiere registrarte.": "policia",
		"Búsqueda policial: ★★": "policia",
		"Mensaje de Marta (Ciudad): quiere 2 x Tónico": "encargos",
		"Alquileres del día: -120 $.": "cobros",
		"La lluvia va llenando tus recipientes de agua.": "cosechas",
		"Entras en: Ciudad original": "otros",
	}
	for texto in casos:
		_ok(GestorChat_clasificar(texto) == casos[texto], "clasificar «%s» = %s (da %s)" % [texto, casos[texto], GestorChat_clasificar(texto)])


func GestorChat_clasificar(texto: String) -> String:
	return (load("res://scripts/chat/gestor_chat.gd") as GDScript).clasificar(texto)


func _integracion() -> void:
	# El autoload Chat (un jugador) con los vecinos quietos.
	Chat.simulacion = false
	Chat.historial.clear()
	Chat.servidor.mover(Chat.mi_id, Vector3.ZERO)
	Chat.servidor.mover(101, Vector3(10, 0, 0))     # Marta, cerca
	Chat.servidor.mover(104, Vector3(300, 0, 0))    # Lucía, muy lejos
	Chat._reloj = 500.0
	Chat.enviar(Canales.Id.CERCANO, "Buenas")
	_ok(not Chat.historial.is_empty() and String(Chat.historial.back()["texto"]) == "Buenas", "enviar cercano llega a tu historial")
	Chat._reloj += 2.0
	Chat.enviar(Canales.Id.CERCANO, "/p Marta hola Marta")
	_ok(String(Chat.historial.back()["para"]) == "Marta", "/p NOMBRE manda un privado")
	Chat._reloj += 2.0
	Chat.enviar(Canales.Id.CERCANO, "/p Nadie hola")
	_ok(int(Chat.historial.back()["canal"]) == Canales.Id.SISTEMA, "el error sale como aviso del sistema")
	Chat._reloj += 2.0
	Chat.enviar(Canales.Id.CERCANO, "/grupo unir Tormenta")
	_ok(Chat.mi_grupo() == "Tormenta", "/grupo unir cambia de grupo")
	Chat._reloj += 2.0
	Chat.enviar(Canales.Id.CERCANO, "/silenciar Lucía")
	_ok(Chat.ignorados().has("lucía"), "/silenciar añade a la lista")
	Chat.enviar(Canales.Id.CERCANO, "/desilenciar Lucía")
	_ok(not Chat.ignorados().has("lucía"), "/desilenciar la quita")
	Chat.enviar(Canales.Id.CERCANO, "/limpiar")
	_ok(Chat.historial.is_empty(), "/limpiar vacía el historial")
	Chat.sistema("Cobras 30 $", "cobros")
	_ok(String(Chat.historial.back()["cat"]) == "cobros", "los avisos entran por Sistema con su categoría")
	Juego.avisar("¡Un guardia te golpea!")
	_ok(String(Chat.historial.back()["cat"]) == "policia", "Juego.avisar llega al chat y se clasifica")
	var n: int = Chat.historial.size()
	Juego.avisar("¡Un guardia te golpea!")
	_ok(Chat.historial.size() == n, "un aviso repetido en menos de 1,5 s no se duplica")
