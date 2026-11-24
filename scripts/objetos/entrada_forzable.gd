# entrada_forzable.gd
# -----------------------------------------------------------------------------
# Una puerta o una ventana cerrada de una casa que se puede asaltar (ver casa_asaltable.gd).
#   E          -> forzar en silencio con ganzúa (lento, poco ruido; la ganzúa puede romperse).
#   Mayús + E  -> forzar a lo bruto: palanca si la tienes, y si no a patadas (puerta) o
#                 rompiendo el cristal (ventana). Rápido, pero hace mucho ruido y duele un poco.
# Mientras fuerzas, cada segundo se oye un ruido dentro (ver Asaltos.alerta_por_ruido).
# Al terminar, la puerta se abre; por la ventana entras trepando.
# -----------------------------------------------------------------------------
class_name EntradaForzable
extends AccionLenta

var tipo: String = "puerta"           # "puerta" o "ventana".
var casa: Node = null                 # CasaAsaltable.
var destino_local: Vector3 = Vector3.ZERO   # Por la ventana: dónde apareces dentro (coordenadas de la casa).
var forzada: bool = false
var puerta_mundo: PuertaMundo = null  # La puerta real del juego (GestorInteriores); si es null, esta entrada lleva su propia hoja.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _metodo: String = ""
var _losa: Node3D = null              # La hoja de la puerta (cuerpo sólido que gira).
var _cuerpo_losa: StaticBody3D = null


func _ready() -> void:
	super._ready()
	distancia = 2.2
	add_to_group("entradas_forzables")
	if tipo == "puerta" and puerta_mundo != null:
		puerta_mundo.bloquear_asalto(true)   # Mientras está cerrada con llave, solo se usa esta entrada.
	elif tipo == "puerta":
		_losa = Node3D.new()
		_losa.position = Vector3(-0.65, 0, 0)   # Bisagra a la izquierda del hueco de 1,3 m.
		add_child(_losa)
		_cuerpo_losa = StaticBody3D.new()
		_cuerpo_losa.position = Vector3(0.65, 0, 0)
		_losa.add_child(_cuerpo_losa)
		var forma: CollisionShape3D = CollisionShape3D.new()
		var caja: BoxShape3D = BoxShape3D.new()
		caja.size = Vector3(1.3, 2.1, 0.12)
		forma.shape = caja
		_cuerpo_losa.add_child(forma)
		Construir.caja(_cuerpo_losa, Vector3.ZERO, Vector3(1.3, 2.1, 0.1), Color(0.3, 0.18, 0.1), false)
		Construir.esfera(_cuerpo_losa, Vector3(0.5, 0, -0.08), 0.05, Color(0.75, 0.65, 0.3))
	elif casa != null and casa.get("puerta_mundo") == null:
		# Casa de prueba: un marco de ventana con cristal que se ve desde la calle.
		Construir.caja(self, Vector3(0, 0, 0.02), Vector3(1.1, 1.3, 0.05), Color(0.2, 0.17, 0.12), false)
		Construir.cristal(self, Vector3(0, 0, 0.05), Vector3(0.9, 1.1, 0.03))


func texto_accion() -> String:
	if forzada:
		return ""
	var nombre: String = "Puerta" if tipo == "puerta" else "Ventana"
	if activa:
		return "%s: forzando… (E para dejarlo)" % nombre
	var perfil: String = str(casa.get("perfil")) if casa != null else "normal"
	var sil: String = Asaltos.metodo_silencioso(tipo)
	var bruto: String = Asaltos.metodo_bruto(tipo)
	var t_sil: String = "ganzúa %d s" % int(round(Asaltos.tiempo_forzar(tipo, "ganzua", perfil))) if sil != "" else "necesitas ganzúa"
	var t_bru: String = "%s %d s, ruidoso" % [Asaltos.metodo(tipo, bruto)["nombre"], int(round(Asaltos.tiempo_forzar(tipo, bruto, perfil)))]
	return "%s cerrada con llave  ·  E: %s  ·  Mayús+E: %s" % [nombre, t_sil, t_bru]


func usar(jugador: Node) -> void:
	if forzada:
		return
	if activa:
		cancelar("Lo dejas.")
		return
	if casa != null and casa.get("propia") == true:
		return
	var perfil: String = str(casa.get("perfil")) if casa != null else "normal"
	var mayus: bool = Input.is_action_pressed("correr")
	var id_metodo: String = Asaltos.metodo_bruto(tipo) if mayus else Asaltos.metodo_silencioso(tipo)
	if id_metodo == "":
		Juego.avisar("Necesitas una ganzúa (se compra en el mercado negro y la ferretería). Mayús+E: forzar a lo bruto.")
		return
	forzar_con(jugador as Node3D, id_metodo, perfil)


# Empieza a forzar con un método concreto (también lo usan las pruebas).
func forzar_con(jugador: Node3D, id_metodo: String, perfil: String) -> void:
	_metodo = id_metodo
	var m: Dictionary = Asaltos.metodo(tipo, id_metodo)
	var t: float = Asaltos.tiempo_forzar(tipo, id_metodo, perfil)
	empezar(jugador, t, "Forzando con %s…" % m["nombre"])


func cada_segundo() -> void:
	if casa == null or _metodo == "":
		return
	var r: float = Asaltos.ruido_forzar(tipo, _metodo)
	casa.hacer_ruido(global_position, r, true)
	if r >= 0.5 and casa.has_method("sonar_alarma_si_hay"):
		casa.sonar_alarma_si_hay("ruido")


func terminar() -> void:
	var m: Dictionary = Asaltos.metodo(tipo, _metodo)
	# Gasto de herramienta y daño.
	if float(m["rotura"]) > 0.0 and rng.randf() < float(m["rotura"]):
		if Juego.quitar(str(m["herramienta"]), 1):
			Juego.avisar("Se te ha roto la ganzúa, pero la cerradura cede.")
	if float(m["dano"]) > 0.0:
		Juego.cambiar_vida(-float(m["dano"]))
		Juego.avisar("Te haces daño al forzar a lo bruto.")
	if casa != null:
		casa.hacer_ruido(global_position, minf(1.0, Asaltos.ruido_forzar(tipo, _metodo) * 1.2), true)
		casa.entrada_forzada(self, tipo)
	forzada = true
	remove_from_group("interactuable")
	if tipo == "puerta":
		abrir()
	else:
		entrar_por_ventana()


func abrir() -> void:
	if puerta_mundo != null and is_instance_valid(puerta_mundo):
		puerta_mundo.bloquear_asalto(false)
		puerta_mundo.poner_abierta(true)
		Juego.avisar("La puerta cede.")
		return
	if _cuerpo_losa != null:
		_cuerpo_losa.collision_layer = 0
		_cuerpo_losa.collision_mask = 0
	if _losa != null:
		var anim: Tween = create_tween()
		anim.tween_property(_losa, "rotation:y", deg_to_rad(100.0), 0.5)
	Juego.avisar("La puerta cede.")


# Desbloquea la entrada (la casa pasa a ser tuya o se apagan los asaltos).
func desbloquear() -> void:
	forzada = true
	remove_from_group("interactuable")
	if tipo == "puerta" and puerta_mundo != null and is_instance_valid(puerta_mundo):
		puerta_mundo.bloquear_asalto(false)
	elif tipo == "puerta":
		if _cuerpo_losa != null:
			_cuerpo_losa.collision_layer = 0
			_cuerpo_losa.collision_mask = 0
		if _losa != null:
			_losa.rotation.y = deg_to_rad(100.0)
	visible = false


func entrar_por_ventana() -> void:
	Juego.avisar("La ventana cede. Trepas dentro.")
	if _jugador != null and casa != null:
		_jugador.global_position = casa.a_mundo(destino_local)
		if _jugador is CharacterBody3D:
			(_jugador as CharacterBody3D).velocity = Vector3.ZERO
	visible = false
