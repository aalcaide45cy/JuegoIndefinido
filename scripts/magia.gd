# magia.gd  (autocarga "Magia")
# -----------------------------------------------------------------------------
# El sistema de magia: maná, nivel de cada escuela, el hechizo preparado, lanzarlo y el riesgo
# de que te vean (la magia está prohibida). Los datos están en scripts/datos/magia.gd y el
# diseño en docs/MAGIA.md.
#
#   F  lanzar el hechizo preparado        Q  preparar el siguiente hechizo que sepas
#   K  grimorio (ver escuelas y elegir hechizo)
#
# Lo que se guarda en la partida: exportar() / importar() (ver guardado.gd).
# Barra de maná: abajo a la izquierda, solo cuando no está lleno o acabas de cambiar de hechizo.
# -----------------------------------------------------------------------------
extends Node

const DatosMagia = preload("res://scripts/datos/magia.gd")

signal lanzado(id: String)
signal cambio

var mana: float = DatosMagia.MANA_MAX
var xp: Dictionary = {}           # escuela -> experiencia
var preparado: String = "brote"   # Hechizo que lanza F.
var esperas: Dictionary = {}      # hechizo -> segundos que faltan para poder lanzarlo
var apagadas: Array = []          # [luz, segundos] de las luces apagadas por "Apagón"

var _capa: CanvasLayer = null
var _barra: ProgressBar = null
var _texto: Label = null
var _t_ver: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reiniciar()
	_accion("lanzar_hechizo", KEY_F)
	_accion("siguiente_hechizo", KEY_Q)
	_accion("grimorio", KEY_K)


func _accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)


func reiniciar() -> void:
	mana = DatosMagia.MANA_MAX
	xp = {}
	for e in DatosMagia.ESCUELAS:
		xp[e] = 0.0
	preparado = "brote"
	esperas = {}
	cambio.emit()


# ------------------------------- Consultas -------------------------------------

func nivel(escuela: String) -> int:
	return DatosMagia.nivel_por_xp(float(xp.get(escuela, 0.0)))


func nivel_total() -> int:
	var n: int = 0
	for e in DatosMagia.ESCUELAS:
		n += nivel(e)
	return n


func sabe(id: String) -> bool:
	return DatosMagia.HECHIZOS.has(id) and nivel(DatosMagia.escuela_de(id)) >= DatosMagia.nivel_requerido(id)


func coste(id: String) -> float:
	var n: int = nivel(DatosMagia.escuela_de(id))
	return float(DatosMagia.HECHIZOS[id]["coste"]) * (1.0 - DatosMagia.DESCUENTO_POR_NIVEL * (n - 1))


func potencia(id: String) -> float:
	return 1.0 + DatosMagia.POTENCIA_POR_NIVEL * (nivel(DatosMagia.escuela_de(id)) - 1)


func conocidos() -> Array:
	return DatosMagia.todos().filter(func(h: String) -> bool: return sabe(h))


func preparar(id: String) -> void:
	if sabe(id):
		preparado = id
		_mostrar()
		cambio.emit()


func siguiente() -> void:
	var lista: Array = conocidos()
	if lista.is_empty():
		return
	preparar(lista[(lista.find(preparado) + 1) % lista.size()])
	Juego.avisar("Hechizo preparado: %s (%d de maná)." % [DatosMagia.HECHIZOS[preparado]["nombre"], int(coste(preparado))])


# ------------------------------- Bucle -----------------------------------------

func _process(delta: float) -> void:
	var antes: float = mana
	mana = minf(DatosMagia.MANA_MAX, mana + (DatosMagia.MANA_REGEN + 0.5 * (nivel_total() - 4)) * delta)
	for h in esperas.keys():
		esperas[h] = float(esperas[h]) - delta
		if float(esperas[h]) <= 0.0:
			esperas.erase(h)
	for i in range(apagadas.size() - 1, -1, -1):
		apagadas[i][1] = float(apagadas[i][1]) - delta
		if float(apagadas[i][1]) <= 0.0:
			var luz = apagadas[i][0]
			if is_instance_valid(luz):
				luz.visible = true
			apagadas.remove_at(i)
	_t_ver -= delta
	_actualizar_barra(antes)


func _unhandled_input(evento: InputEvent) -> void:
	if Juego.menu_abierto or _jugador() == null:
		return
	if evento.is_action_pressed("lanzar_hechizo"):
		var texto: String = lanzar(preparado)
		if texto != "":
			Juego.avisar(texto)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("siguiente_hechizo"):
		siguiente()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("grimorio"):
		var hud = _jugador().get("hud")
		if hud != null and not hud.hay_menu():
			hud.abrir_ventana(VentanaGrimorio.new())
		get_viewport().set_input_as_handled()


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


# ------------------------------- Lanzar ----------------------------------------

# Lanza el hechizo. Devuelve el texto para el aviso ("" si no hace falta avisar).
func lanzar(id: String) -> String:
	var j: Node3D = _jugador()
	if j == null or not DatosMagia.HECHIZOS.has(id):
		return ""
	var h: Dictionary = DatosMagia.HECHIZOS[id]
	if not sabe(id):
		return "Aún no sabes %s: sube %s a nivel %d." % [h["nombre"], DatosMagia.ESCUELAS[h["escuela"]]["nombre"], DatosMagia.nivel_requerido(id)]
	if esperas.has(id):
		return "%s: espera %d s." % [h["nombre"], ceili(float(esperas[id]))]
	var c: float = coste(id)
	if mana < c:
		return "No tienes maná suficiente (%d de %d)." % [int(mana), int(c)]
	var resultado: String = _hacer(id, h, j)
	if resultado.begins_with("!"):
		return resultado.substr(1)   # No ha hecho nada: no gasta.
	mana -= c
	esperas[id] = float(h["espera"])
	var escuela: String = str(h["escuela"])
	var nivel_antes: int = nivel(escuela)
	xp[escuela] = float(xp.get(escuela, 0.0)) + c
	if nivel(escuela) > nivel_antes:
		var nuevos: Array = (DatosMagia.ORDEN[escuela] as Array).filter(func(x: String) -> bool:
			return DatosMagia.nivel_requerido(x) == nivel(escuela))
		var extra: String = "" if nuevos.is_empty() else "  Nuevo hechizo: %s." % DatosMagia.HECHIZOS[nuevos[0]]["nombre"]
		Juego.nuevo_aviso("%s sube a nivel %d.%s" % [DatosMagia.ESCUELAS[escuela]["nombre"], nivel(escuela), extra])
	_efecto_visual(j, DatosMagia.ESCUELAS[escuela]["color"])
	Sonido.tocar(j, "comprar", -10.0)
	_riesgo(j, float(h["riesgo"]))
	_t_ver = 3.0
	lanzado.emit(id)
	cambio.emit()
	return resultado


func _hacer(id: String, h: Dictionary, j: Node3D) -> String:
	var p: float = potencia(id)
	match str(h["tipo"]):
		"efecto":
			Juego.aplicar_efecto(str(h["efecto"]), float(h["dur"]) * p, float(h["fuerza"]))
			if h.has("efecto2"):
				Juego.aplicar_efecto(str(h["efecto2"]), float(h["dur"]) * p, float(h["fuerza"]))
			return "%s." % h["nombre"]
		"curar":
			Juego.cambiar_vida(float(h["valor"]) * p)
			Juego.aplicar_efecto(str(h["efecto"]), float(h["dur"]), float(h["fuerza"]) * p)
			return "Sanar: recuperas vida."
		"crecer":
			var n: int = 0
			for m in get_tree().get_nodes_in_group("macetas"):
				if m is Node3D and (m as Node3D).global_position.distance_to(j.global_position) <= float(h["radio"]) and m.has_method("adelantar"):
					m.adelantar(float(h["valor"]) * p)
					n += 1
			if n == 0:
				return "!No hay plantas cerca."
			return "Brote: %d planta(s) crecen de golpe." % n
		"disfraz":
			if Juego.estrellas == 0 and Juego.alerta <= 0.0:
				return "!Nadie te busca: no hace falta cambiar de cara."
			Juego.estrellas = maxi(0, Juego.estrellas - int(h["valor"]))
			Juego.alerta = 0.0
			Juego.cambio.emit()
			return "Rostro ajeno: ya no se parecen a ti los carteles."
		"empujar":
			var golpeados: int = 0
			var frente: Vector3 = -j.global_transform.basis.z
			if j.get("_giro") != null:
				var giro: float = float(j.get("_giro"))
				frente = Vector3(-sin(giro), 0.0, -cos(giro))
			for n in _cercanos(j.global_position, float(h["radio"])):
				var dir: Vector3 = (n.global_position - j.global_position)
				dir.y = 0.0
				if dir.length() < 0.1 or dir.normalized().dot(frente) < 0.3:
					continue
				_empujar(n, dir.normalized() * 9.0 * p)
				if n.has_method("recibir_dano"):
					n.recibir_dano(float(h["valor"]) * p)
				golpeados += 1
			for c in get_tree().get_nodes_in_group("danable"):
				if c is RigidBody3D and (c as Node3D).global_position.distance_to(j.global_position) <= float(h["radio"]):
					(c as RigidBody3D).apply_central_impulse(((c as Node3D).global_position - j.global_position).normalized() * 6.0 * p)
			return "Empujón (%d)." % golpeados if golpeados > 0 else "Empujón."
		"abrir":
			var mejor = null
			var dist: float = float(h["radio"])
			for e in get_tree().get_nodes_in_group("entradas_forzables"):
				if not e is Node3D or bool(e.get("forzada")) or str(e.get("tipo")) != "puerta":
					continue
				var d: float = (e as Node3D).global_position.distance_to(j.global_position)
				if d <= dist:
					dist = d
					mejor = e
			if mejor == null:
				return "!No hay ninguna puerta cerrada al alcance."
			mejor.forzada = true
			mejor.remove_from_group("interactuable")
			if mejor.casa != null and mejor.casa.has_method("entrada_forzada"):
				mejor.casa.entrada_forzada(mejor, "puerta")
			mejor.abrir()
			return "Ganzúa sombría: la cerradura cede sin un ruido."
		"apagon":
			var n2: int = 0
			for grupo in ["luces_lod", "luces_noche"]:
				for l in get_tree().get_nodes_in_group(grupo):
					if l is Light3D and (l as Light3D).visible and (l as Node3D).global_position.distance_to(j.global_position) <= float(h["radio"]):
						(l as Light3D).visible = false
						apagadas.append([l, float(h["valor"])])
						n2 += 1
			Juego.aplicar_efecto(str(h["efecto"]), float(h["dur"]) * p, float(h["fuerza"]))
			return "Apagón: se apagan %d luces." % n2
		"pavor":
			var n3: int = 0
			for n in _cercanos(j.global_position, float(h["radio"]) * p):
				if "huyendo" in n:
					n.huyendo = true
				if n.has_method("asustar"):
					n.asustar(j.global_position)
				else:
					var dir2: Vector3 = n.global_position - j.global_position
					dir2.y = 0.0
					_empujar(n, dir2.normalized() * 4.0)
				n3 += 1
			if n3 == 0:
				return "!No hay nadie cerca a quien asustar."
			return "Pavor: %d persona(s) huyen aterradas." % n3
	return ""


# Personas cerca: peatones, guardias, vecinos y matones (no los aliados).
func _cercanos(centro: Vector3, radio: float) -> Array:
	var out: Array = []
	for grupo in ["peatones", "guardias", "vecinos", "matones"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if n is Node3D and is_instance_valid(n) and not n.has_meta("muerto") \
					and (n as Node3D).global_position.distance_to(centro) <= radio:
				out.append(n)
	return out


func _empujar(n: Node, impulso: Vector3) -> void:
	if n.has_method("empujar"):
		n.empujar(impulso)
	elif "_impulso" in n:
		n._impulso = impulso
	elif n is CharacterBody3D:
		(n as CharacterBody3D).velocity += impulso


# La magia es ilegal: los guardias que lo ven suben las estrellas, la gente sube la sospecha.
func _riesgo(j: Node3D, riesgo: float) -> void:
	if riesgo <= 0.0:
		return
	var factor: float = riesgo * (DatosMagia.NOCHE_RIESGO if Juego.es_de_noche() else 1.0) * (1.0 - clampf(Juego.mod("sigilo") * 0.5, 0.0, 0.8))
	var r_guardia: float = DatosMagia.RADIO_GUARDIAS * sqrt(factor)
	for g in get_tree().get_nodes_in_group("guardias"):
		if g is Node3D and not g.has_meta("muerto") and (g as Node3D).global_position.distance_to(j.global_position) <= r_guardia:
			Juego.subir_estrellas(1, "Magia prohibida a la vista de un guardia")
			return
	if Juego.interiores > 0:
		return   # Dentro de un edificio no te ve la gente de la calle.
	var testigos: int = 0
	for n in get_tree().get_nodes_in_group("peatones"):
		if n is Node3D and (n as Node3D).global_position.distance_to(j.global_position) <= DatosMagia.RADIO_GENTE * sqrt(factor):
			testigos += 1
	if testigos > 0:
		Juego.sospecha = clampf(Juego.sospecha + DatosMagia.SOSPECHA_POR_TESTIGO * factor * mini(testigos, 4), 0.0, 100.0)
		Juego.avisar("Alguien te ha visto hacer magia. Sube la sospecha.")


func _efecto_visual(j: Node3D, color: Color) -> void:
	var raiz: Node3D = Node3D.new()
	j.get_parent().add_child(raiz)
	# Delante del jugador, a la altura de las manos (en primera persona, pegado a la cara tapaba todo).
	var frente: Vector3 = Vector3.FORWARD
	if j.get("_giro") != null:
		frente = Vector3(-sin(float(j.get("_giro"))), 0.0, -cos(float(j.get("_giro"))))
	raiz.global_position = j.global_position + Vector3.UP * 1.0 + frente * 2.2
	var part: CPUParticles3D = CPUParticles3D.new()
	part.one_shot = true
	part.explosiveness = 0.9
	part.amount = 40
	part.lifetime = 0.8
	part.direction = (frente + Vector3.UP * 0.6).normalized()   # Hacia delante: no a la cara.
	part.spread = 50.0
	part.local_coords = false
	part.initial_velocity_min = 1.0
	part.initial_velocity_max = 3.0
	part.gravity = Vector3(0, 1.5, 0)
	part.scale_amount_min = 0.5
	part.scale_amount_max = 1.0
	var malla: BoxMesh = BoxMesh.new()   # Low poly: cubitos de luz.
	malla.size = Vector3.ONE * 0.05
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	part.mesh = malla
	raiz.add_child(part)
	part.emitting = true
	var luz: OmniLight3D = OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 3.0
	luz.omni_range = 7.0
	raiz.add_child(luz)
	var tw: Tween = raiz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.5)
	tw.tween_interval(0.5)
	tw.tween_callback(raiz.queue_free)


# ------------------------------- Barra de maná ---------------------------------

func _mostrar() -> void:
	_t_ver = 3.0


func _actualizar_barra(_antes: float) -> void:
	var j: Node3D = _jugador()
	var ver: bool = j != null and get_tree().current_scene != null and (mana < DatosMagia.MANA_MAX - 0.5 or _t_ver > 0.0) and not Juego.menu_abierto
	if not ver:
		if _capa != null:
			_capa.visible = false
		return
	if _capa == null:
		_crear_barra()
	_capa.visible = true
	_barra.value = mana
	var h: Dictionary = DatosMagia.HECHIZOS[preparado]
	var esp: String = "  ·  espera %d s" % ceili(float(esperas[preparado])) if esperas.has(preparado) else ""
	_texto.text = "%s (%d)  [F]%s  ·  Q cambiar · K grimorio" % [h["nombre"], int(coste(preparado)), esp]
	_texto.modulate = DatosMagia.ESCUELAS[h["escuela"]]["color"]


func _crear_barra() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 5
	add_child(_capa)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.anchor_left = 0.0
	caja.anchor_top = 1.0
	caja.anchor_bottom = 1.0
	# La interfaz se dibuja sobre una base de 3840x2160 (project.godot): por eso los tamaños son grandes.
	caja.offset_left = 48.0
	caja.offset_top = -330.0
	caja.offset_bottom = -240.0
	caja.offset_right = 1300.0
	_capa.add_child(caja)
	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 34)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 10)
	caja.add_child(_texto)
	_barra = ProgressBar.new()
	_barra.max_value = DatosMagia.MANA_MAX
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(620, 26)
	var fondo: StyleBoxFlat = StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.05, 0.12, 0.8)
	var relleno: StyleBoxFlat = StyleBoxFlat.new()
	relleno.bg_color = Color(0.35, 0.55, 1.0)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", relleno)
	caja.add_child(_barra)


# ------------------------------- Guardar ---------------------------------------

func exportar() -> Dictionary:
	return {"mana": mana, "xp": xp.duplicate(), "preparado": preparado}


func importar(d: Dictionary) -> void:
	reiniciar()
	mana = clampf(float(d.get("mana", DatosMagia.MANA_MAX)), 0.0, DatosMagia.MANA_MAX)
	var x = d.get("xp", {})
	if x is Dictionary:
		for e in DatosMagia.ESCUELAS:
			xp[e] = maxf(0.0, float(x.get(e, 0.0)))
	var p: String = str(d.get("preparado", "brote"))
	preparado = p if sabe(p) else "brote"
	cambio.emit()
