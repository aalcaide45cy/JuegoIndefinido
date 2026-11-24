# Capturas del cuerpo: disparos por zonas, miembros arrancados, ragdoll, atropello y efectos de arma.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/captura_cuerpo.tscn -- carpeta
extends Node3D

var carpeta: String = "."
var cam: Camera3D


class Muneco extends CharacterBody3D:
	var modelo: Node3D
	var vida: float = 100.0
	var _muerto: bool = false
	var personaje: String = "Character_Soldier"
	var humano: bool = false
	func _ready() -> void:
		add_to_group("personas")
		var f: CollisionShape3D = CollisionShape3D.new()
		var c: CapsuleShape3D = CapsuleShape3D.new()
		c.radius = 0.35
		c.height = 1.7
		f.shape = c
		f.position.y = 0.85
		add_child(f)
		if humano:
			modelo = Assets.persona(personaje, "Pistol", "Idle")
		else:
			modelo = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/" + personaje, "", "Idle")
		add_child(modelo)
	func recibir_dano(c: float) -> void:
		if _muerto:
			return
		vida -= c
		if vida <= 0.0:
			_muerto = true
			collision_layer = 0
			Cuerpo.al_morir(self, modelo, Vector3.ZERO, 3.0)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _caja(pos: Vector3, tam: Vector3, color: Color, nombre: String = "Pared") -> StaticBody3D:
	var s: StaticBody3D = StaticBody3D.new()
	s.name = nombre
	var f: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = tam
	f.shape = b
	s.add_child(f)
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = tam
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	s.add_child(m)
	add_child(s)
	s.global_position = pos
	return s


func _muneco(pos: Vector3, mira_y: float = 0.0, p: String = "Character_Soldier") -> Muneco:
	var m: Muneco = Muneco.new()
	m.personaje = p
	add_child(m)
	m.global_position = pos
	m.rotation.y = mira_y
	return m


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	carpeta = args[0] if args.size() > 0 else "."
	Graficos.v["gore"] = 2
	var entorno: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 0.7
	entorno.environment = env
	add_child(entorno)
	var sol: DirectionalLight3D = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.shadow_enabled = true
	add_child(sol)
	_caja(Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.42, 0.42, 0.4), "Suelo")
	_caja(Vector3(0, 1.5, 2.2), Vector3(8, 3, 0.3), Color(0.78, 0.75, 0.68), "Pared")
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 60.0
	cam.look_at_from_position(Vector3(1.8, 1.7, -3.2), Vector3(0, 1.0, 0.5))

	# 0) Personas nuevas: reacción a un tiro en el pecho, en la cabeza y muerte con ragdoll.
	var hs: Array = []
	for k in 3:
		var hm: Muneco = Muneco.new()
		hm.humano = true
		hm.personaje = "Superhero_Male_FullBody" if k != 1 else "Superhero_Female_FullBody"
		add_child(hm)
		hm.global_position = Vector3(-1.6 + k * 1.6, 0, 0.6)
		hs.append(hm)
	cam.look_at_from_position(Vector3(0, 1.6, -3.6), Vector3(0, 1.0, 0.6))
	await _esperar(0.8)
	await _foto("persona_0_de_pie")
	AnimCombate.una_vez(hs[0].modelo, "HitReact", "Idle")
	AnimCombate.una_vez(hs[1].modelo, "HitHead", "Idle")
	var pecho: Vector3 = hs[2].global_position + Vector3(0, 1.3, 0)
	Cuerpo.impactar(hs[2], pecho + Vector3(0, 0.1, -4), Vector3(0, -0.02, 1).normalized(), 200.0, "bala", {"punto": pecho, "distancia": 4.0})
	Gore.herida(hs[0], hs[0].global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1), "bala", 1.0)
	await _esperar(0.25)
	await _foto("persona_1_reaccion_pecho_cabeza_y_muerte")
	await _esperar(2.5)
	await _foto("persona_2_ragdoll")
	for hm2 in hs:
		hm2.queue_free()

	# 0b) "Trapo": alguien que corre recibe un tiro en el pecho; secuencia de la caída
	# vista de lado (sigue con su inercia, se le doblan las rodillas y se desploma).
	var corredor: Muneco = Muneco.new()
	corredor.humano = true
	corredor.personaje = "Superhero_Male_FullBody"
	add_child(corredor)
	corredor.global_position = Vector3(0, 0, 1.5)
	await _esperar(0.4)
	corredor.velocity = Vector3(0, 0, -4.5)   # Corriendo hacia -Z.
	cam.look_at_from_position(Vector3(5.5, 1.5, -0.5), Vector3(0, 0.8, -0.5))
	var pecho2: Vector3 = corredor.global_position + Vector3(0, 1.3, 0)
	Cuerpo.impactar(corredor, pecho2 + Vector3(-4, 0, 0), Vector3(1, 0, 0), 200.0, "bala", {"punto": pecho2, "distancia": 4.0})
	var tiempos: Array = [0.12, 0.3, 0.55, 2.2]
	var antes: float = 0.0
	for k2 in tiempos.size():
		await _esperar(float(tiempos[k2]) - antes)
		antes = float(tiempos[k2])
		await _foto("trapo_%d_caida_%.2fs" % [k2 + 1, antes])
	corredor.queue_free()
	cam.look_at_from_position(Vector3(1.8, 1.7, -3.2), Vector3(0, 1.0, 0.5))

	# 1) Tiro en el brazo con rifle: el brazo sale volando, el resto sigue en pie.
	var a: Muneco = _muneco(Vector3(0, 0, 0), PI)   # Mirando a la cámara (-Z).
	await _esperar(0.5)
	var esq: Skeleton3D = Cuerpo.esqueleto(a.modelo)
	var hombro: Vector3 = esq.global_transform * esq.get_bone_global_pose(Cuerpo.hueso(esq, "UpperArm.R")).origin
	var codo: Vector3 = esq.global_transform * esq.get_bone_global_pose(Cuerpo.hueso(esq, "LowerArm.R")).origin
	var blanco: Vector3 = (hombro + codo) * 0.5
	var desde: Vector3 = blanco + Vector3(0.6, 0.1, -4.0)
	for i in 2:
		var dir: Vector3 = (blanco - desde).normalized()
		EfectosArma.boca(self, desde, dir, "rifle")
		EfectosArma.trazadora(self, desde, blanco)
		var r: Dictionary = Cuerpo.impactar(a, desde, dir, 30.0, "bala", {"punto": blanco, "distancia": 4.0})
		print("tiro brazo: ", r)
		await _esperar(0.05)
	await _esperar(0.12)
	await _foto("cuerpo_1_brazo_arrancado")
	await _esperar(1.5)
	await _foto("cuerpo_2_brazo_en_el_suelo")
	if not Cuerpo._miembros.is_empty() and is_instance_valid(Cuerpo._miembros.back()):
		var brazo: Node3D = Cuerpo._miembros.back()
		print("brazo suelto en ", brazo.global_position)
		cam.look_at_from_position(brazo.global_position + Vector3(0.8, 1.0, -1.2), brazo.global_position)
		await _foto("cuerpo_2b_brazo_suelto")
		cam.look_at_from_position(Vector3(1.8, 1.7, -3.2), Vector3(0, 1.0, 0.5))

	# 2) Francotirador en la cabeza: revienta y cae con ragdoll.
	a.queue_free()
	for m in Cuerpo._miembros:
		if is_instance_valid(m):
			m.queue_free()
	var b: Muneco = _muneco(Vector3(0, 0, 0), PI, "Character_Enemy")
	await _esperar(0.5)
	var eb: Skeleton3D = Cuerpo.esqueleto(b.modelo)
	var cabeza: Vector3 = eb.global_transform * eb.get_bone_global_pose(Cuerpo.hueso(eb, "Head")).origin + Vector3.UP * 0.15
	var d2: Vector3 = (cabeza - Vector3(0.3, 1.6, -6)).normalized()
	var r2: Dictionary = Cuerpo.impactar(b, Vector3(0.3, 1.6, -6), d2, 90.0, "bala", {"punto": cabeza, "distancia": 6.0})
	print("francotirador: ", r2)
	await _esperar(0.08)
	await _foto("cuerpo_3_cabeza_revienta")
	await _esperar(2.5)
	cam.look_at_from_position(Vector3(2.2, 2.2, -2.0), Vector3(0, 0.2, 0.8))
	await _foto("cuerpo_4_cadaver_ragdoll_y_pared")

	# 3) Atropello: sale despedido con física y queda tendido; el charco, debajo.
	b.queue_free()
	var c: Muneco = _muneco(Vector3(-4, 0, -6), PI / 2.0, "Character_Hazmat")
	await _esperar(0.5)
	cam.look_at_from_position(Vector3(4, 2.0, -11), Vector3(0, 0.6, -6))
	c.collision_layer = 0
	c.vida = 0.0
	c._muerto = true
	c.set_meta("ult_impacto", {"dir": Vector3(1, 0.3, 0).normalized(), "fuerza": 13.0, "ms": Time.get_ticks_msec(), "tipo": "atropello", "zona": "torso", "punto": c.global_position})
	Cuerpo.al_morir(c, c.modelo, Vector3.RIGHT, 13.0)
	Gore.salpicar(c, c.global_position + Vector3.UP, Vector3.RIGHT, 2.0)
	await _esperar(0.3)
	var p5: Vector3 = Cuerpo.centro(c, c.modelo)
	cam.look_at_from_position(p5 + Vector3(1.5, 1.2, -5.0), p5)
	await _foto("cuerpo_5_atropello_en_el_aire")
	await _esperar(3.5)
	var p6: Vector3 = Cuerpo.centro(c, c.modelo)
	cam.look_at_from_position(p6 + Vector3(2.0, 2.2, -3.0), p6)
	await _foto("cuerpo_6_atropello_tendido_charco")

	# 4) Efectos de arma: fogonazo de escopeta, chispas en metal, polvo en piedra.
	var coche: StaticBody3D = _caja(Vector3(-1.5, 0.7, -12), Vector3(2, 1.4, 4), Color(0.6, 0.1, 0.1), "Coche")
	coche.set_meta("superficie", "metal")
	cam.look_at_from_position(Vector3(4.5, 1.7, -15.0), Vector3(-0.3, 1.0, -13.8))
	var boca: Vector3 = Vector3(1.2, 1.35, -15.6)
	var objetivo: Vector3 = Vector3(-0.5, 0.9, -13.0)
	var dir4: Vector3 = (objetivo - boca).normalized()
	EfectosArma.boca(self, boca, dir4, "escopeta")
	for i in 6:
		var dd: Vector3 = (dir4 + Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0)).normalized()
		var ch: Dictionary = Combate.rayo(get_world_3d(), boca, dd, 30.0, [])
		if not ch.is_empty():
			EfectosArma.impacto(self, ch, dd)
			EfectosArma.trazadora(self, boca, ch["position"])
	EfectosArma.casquillo(self, boca, Vector3.RIGHT, Vector3.UP, "escopeta")
	await get_tree().process_frame
	await _foto("cuerpo_7_escopeta_fogonazo_chispas")
	await _esperar(0.6)
	print("RESULTADO: TODO BIEN")
	get_tree().quit()
