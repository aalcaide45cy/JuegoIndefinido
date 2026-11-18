# Sonda: va a un punto, camina en una dirección y cuenta con qué choca. Args: x= z= dx= dz= s=
extends Node
func _a(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(k + "="): return str(a).substr(k.length() + 1)
	return d
func _ready() -> void:
	await get_tree().process_frame
	var escena = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child(escena)
	for i in 3: await get_tree().physics_frame
	var J = get_tree().root.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	var jug = hud.jugador
	if hud._menu != null: hud._menu.cerrar()
	J.reiniciar(); J.policia_activa = false
	var x: float = float(_a("x", "0")); var z: float = float(_a("z", "0"))
	var dir: Vector2 = Vector2(float(_a("dx", "0")), float(_a("dz", "1"))).normalized()
	jug.global_position = Vector3(x, GeneradorMundo.altura(x, z) + 2.0, z)
	jug._suelo_pendiente = true
	for i in 600:
		await get_tree().physics_frame
		if not jug._suelo_pendiente and jug.is_on_floor(): break
	jug._giro = atan2(-dir.x, -dir.y)
	Input.action_press("adelante"); Input.action_press("correr")
	var s: float = float(_a("s", "13"))
	var visto: Dictionary = {}
	for i in int(s * 60):
		await get_tree().physics_frame
		for k in jug.get_slide_collision_count():
			var c = jug.get_slide_collision(k)
			var o = c.get_collider()
			var nombre: String = "%s (%s) padre=%s" % [o.name, o.get_class(), o.get_parent().name if o.get_parent() else "-"]
			if not visto.has(nombre):
				visto[nombre] = c.get_position()
	Input.action_release("adelante")
	print("Posición final: ", jug.global_position)
	for ob in GeneradorMundo.obras_vistas:
		var q3: Vector3 = ob[1]
		if Vector2(q3.x - jug.global_position.x, q3.z - jug.global_position.z).length() < 40.0:
			print("  obra cercana: ", ob[0], " en ", q3, " dir ", ob[2])
	var esp = jug.get_world_3d().direct_space_state
	var pj: Vector3 = jug.global_position
	print("  altura teórica en el jugador %.2f, jugador y %.2f" % [GeneradorMundo.altura(pj.x, pj.z), pj.y])
	for r in [1.0, 2.0, 3.0, 5.0]:
		var linea: String = "  r=%.0f:" % r
		for ang in 8:
			linea += " %.2f" % GeneradorMundo.altura(pj.x + cos(ang * TAU / 8.0) * r, pj.z + sin(ang * TAU / 8.0) * r)
		print(linea)
	for ang in 8:
		var dd: Vector3 = Vector3(cos(ang * TAU / 8.0), 0, sin(ang * TAU / 8.0))
		for alt in [0.3, 1.2]:
			var o4: Vector3 = jug.global_position + Vector3(0, alt, 0)
			var r4 = esp.intersect_ray(PhysicsRayQueryParameters3D.create(o4, o4 + dd * 5.0))
			print("  ang %d alt %.1f: %s" % [ang * 45, alt, str(r4.get("position", "libre"))])
	for alt in [0.2, 0.8, 1.5, 2.5, 4.0]:
		var o3: Vector3 = jug.global_position + Vector3(0, alt, 0)
		var rr = esp.intersect_ray(PhysicsRayQueryParameters3D.create(o3, o3 + Vector3(dir.x, 0, dir.y) * 6.0))
		print("  rayo a altura %.1f: %s" % [alt, str(rr.get("position", "libre"))])
	for k in visto: print("  choca con ", k, " en ", visto[k])
	get_tree().quit(0)
