# botin_casa.gd
# -----------------------------------------------------------------------------
# Un mueble de una casa asaltada con cosas de valor: cajón, joyero, armario o caja fuerte.
# E lo registra (lleva unos segundos y hace algo de ruido). El dinero robado va al dinero
# negro (si existe esa cuenta) y los objetos (joyas, relojes...) a la mochila, para vender.
# La caja fuerte necesita ganzúa (E, silenciosa) o palanca (Mayús + E, con mucho ruido).
# Cuánto hay depende del tipo de casa (Asaltos.botin) y del barrio.
# -----------------------------------------------------------------------------
class_name BotinCasa
extends AccionLenta

var contenedor: String = "cajon"
var casa: Node = null          # CasaAsaltable.
var vacio: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _metodo: String = ""


func _ready() -> void:
	super._ready()
	distancia = 1.9
	add_to_group("botines_casa")


func _datos() -> Dictionary:
	return Asaltos.CONTENEDORES.get(contenedor, {})


func texto_accion() -> String:
	var d: Dictionary = _datos()
	if d.is_empty():
		return ""
	if vacio:
		return "%s vacío" % str(d["nombre"]).capitalize()
	if activa:
		return "Registrando… (E para dejarlo)"
	if d.has("herramienta"):
		if Juego.tiene(str(d["herramienta"])):
			return "Abrir la %s con ganzúa (%d s)  ·  Mayús+E: palanca (ruidoso)" % [d["nombre"], int(d["tiempo"])]
		return "La %s está cerrada: ganzúa (E) o palanca (Mayús+E)" % d["nombre"]
	return "Registrar el %s (%d s)" % [d["nombre"], int(d["tiempo"])]


func usar(jugador: Node) -> void:
	if vacio:
		Juego.avisar("No queda nada de valor.")
		return
	if activa:
		cancelar("Lo dejas.")
		return
	var d: Dictionary = _datos()
	_metodo = ""
	var t: float = float(d["tiempo"])
	if d.has("herramienta"):
		if Input.is_action_pressed("correr"):
			if not Juego.tiene("palanca"):
				Juego.avisar("Necesitas una palanca (Mayús+E) o una ganzúa (E).")
				return
			_metodo = "palanca"
			t *= 0.4
		elif Juego.tiene(str(d["herramienta"])):
			_metodo = "ganzua"
		else:
			Juego.avisar("La caja fuerte necesita ganzúa o palanca.")
			return
	empezar_registro(jugador as Node3D, t)


func empezar_registro(jugador: Node3D, segundos: float) -> void:
	empezar(jugador, segundos, "Registrando…")


func cada_segundo() -> void:
	if casa == null:
		return
	var r: float = float(_datos().get("ruido", 0.15))
	if _metodo == "palanca":
		r = 0.85
	r *= clampf(1.0 - Juego.mod("sigilo"), 0.3, 1.8)
	if Juego.habilidades.has("sigilo"):
		r *= 0.7
	casa.hacer_ruido(global_position, r, false)
	if _metodo == "palanca" and casa.has_method("sonar_alarma_si_hay"):
		casa.sonar_alarma_si_hay("palanca")


func terminar() -> void:
	vacio = true
	var perfil: String = str(casa.get("perfil")) if casa != null else "normal"
	var desvalijada: bool = casa != null and casa.get("desvalijada") == true
	var cosas: Dictionary = {"dinero": 0, "objetos": []} if desvalijada else Asaltos.botin(perfil, contenedor, rng)
	var partes: PackedStringArray = PackedStringArray()
	var dinero: int = int(cosas["dinero"])
	if dinero > 0:
		Asaltos.cobrar_botin(dinero)
		partes.append("%d $" % dinero)
		Juego.asaltos_info["robado"] = int(Juego.asaltos_info.get("robado", 0)) + dinero
	for o in cosas["objetos"]:
		var sobran: int = Juego.anadir(str(o[0]), int(o[1]))
		var cogidos: int = int(o[1]) - sobran
		if cogidos > 0:
			partes.append("%d %s" % [cogidos, Juego.DatosObjetos.datos(str(o[0]))["nombre"].to_lower()])
	if partes.is_empty():
		Juego.avisar("Rebuscas en el %s y no hay nada de valor." % _datos().get("nombre", "mueble"))
	else:
		Juego.avisar("Encuentras: %s." % ", ".join(partes))
		Juego.ganar_xp(4 + int(dinero / 40))
		Juego.sospecha = minf(100.0, Juego.sospecha + 3.0)
		Juego.cambiar_rep("hampa", 1)
	if casa != null and casa.has_method("botin_cogido"):
		casa.botin_cogido(self)
	Juego.cambio.emit()
