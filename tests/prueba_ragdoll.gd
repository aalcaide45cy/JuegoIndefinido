extends Node3D
# Prueba del ragdoll "trapo": tira 5 cuerpos (dos esqueletos distintos, golpes en varias
# direcciones) y comprueba que rodillas y codos doblan hacia el lado natural y dentro de
# su límite, que el cuerpo acaba en el suelo y que se congela al quedarse quieto.
# Entre corchetes: doblez de cada bisagra medido sobre su eje (positivo = sentido natural).
#   godot --headless --path . res://tests/prueba_ragdoll.tscn
var fallos: int = 0

func _p(esq: Skeleton3D, n: String) -> Vector3:
	var i: int = Cuerpo.hueso(esq, n)
	return esq.global_transform * (Cuerpo._poses_reales(esq)[i] as Transform3D).origin

func _ok(sentido: bool, ang: float, limite: float, etiqueta: String) -> String:
	if not etiqueta.ends_with("t=3.5"):
		return "ok" if sentido else "al revés (cayendo)"
	if ang > limite:
		fallos += 1
		return "PASADO"
	return "ok"

func _medir(esq: Skeleton3D, etiqueta: String) -> void:
	var R: Vector3 = (_p(esq, "UpperLeg.R") - _p(esq, "UpperLeg.L")).normalized()
	var up: Vector3 = (_p(esq, "Neck") - _p(esq, "Body")).normalized()
	var F: Vector3 = up.cross(R).normalized()
	var out: String = etiqueta
	for lado in ["L", "R"]:
		var t: Vector3 = (_p(esq, "LowerLeg." + lado) - _p(esq, "UpperLeg." + lado)).normalized()
		var s: Vector3 = (_p(esq, "Foot." + lado) - _p(esq, "LowerLeg." + lado)).normalized()
		var ang: float = rad_to_deg(t.angle_to(s))
		var signo: float = (s - t * s.dot(t)).dot(F)
		out += "  rodilla%s %.0f° %s" % [lado, ang, _ok(signo <= 0.05 or ang < 10, ang, 150.0, etiqueta)]
		var a: Vector3 = (_p(esq, "LowerArm." + lado) - _p(esq, "UpperArm." + lado)).normalized()
		var b: Vector3 = (_p(esq, "Middle1." + lado) - _p(esq, "LowerArm." + lado)).normalized()
		var ang2: float = rad_to_deg(a.angle_to(b))
		out += "  codo%s %.0f° %s" % [lado, ang2, _ok((b - a * b.dot(a)).dot(F) >= -0.05 or ang2 < 10, ang2, 160.0, etiqueta)]
	for pb in esq.find_children("*", "PhysicalBone3D", true, false):
		var b: PhysicalBone3D = pb
		if b.joint_type != PhysicalBone3D.JOINT_TYPE_HINGE:
			continue
		var i: int = esq.find_bone(b.bone_name)
		var poses: Array = Cuerpo._poses_reales(esq)
		var gi: Transform3D = esq.global_transform * (poses[i] as Transform3D)
		var gp: Transform3D = esq.global_transform * (poses[esq.get_bone_parent(i)] as Transform3D)
		var eje: Vector3 = (b.global_basis * b.joint_offset.basis.z).normalized()
		var arr: Vector3 = gi.origin - gp.origin
		var abj: Vector3 = b.global_position - gi.origin
		var fl: float = rad_to_deg((arr - eje * arr.dot(eje)).signed_angle_to(abj - eje * abj.dot(eje), eje))
		var mal: bool = not etiqueta.ends_with("t=0.5") and (fl < -15.0 or fl > 160.0)
		if mal:
			fallos += 1
		out += "  [%s %.0f%s]" % [b.bone_name, fl, " AL REVES" if mal else ""]
	var sp: Vector3 = (_p(esq, "Torso") - _p(esq, "Body")).normalized()
	var cu: Vector3 = (_p(esq, "Head") - _p(esq, "Neck")).normalized()
	out += "  cuello-torso %.0f°  cabeza_y %.2f" % [rad_to_deg(sp.angle_to(cu)), _p(esq, "Head").y]
	if etiqueta.ends_with("t=3.5") and _p(esq, "Head").y > 0.45:
		fallos += 1
		out += " CABEZA EN EL AIRE"
	print(out)

func _ready() -> void:
	var suelo: StaticBody3D = StaticBody3D.new()
	var f: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	f.shape = bx
	suelo.add_child(f)
	add_child(suelo)
	suelo.position.y = -0.5
	var casos: Array = [["toon", Vector3(0, 0, 3)], ["toon", Vector3(0, 0, -3)], ["persona", Vector3(0, 0, 3)], ["persona", Vector3(0, 0, -3)], ["persona", Vector3(5, 1, 0)]]
	var k: int = 0
	for c in casos:
		var q: Node3D = Node3D.new()
		add_child(q)
		q.position = Vector3(k * 4.0, 0, 0)
		var m: Node3D = Assets.persona("Superhero_Male_FullBody", "", "Idle") if c[0] == "persona" else Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Soldier", "", "Idle")
		q.add_child(m)
		c.append(m)
		k += 1
	await get_tree().create_timer(0.3).timeout
	for c in casos:
		Cuerpo.ragdoll(c[2].get_parent(), c[2], c[1], true)
	for t in [0.5, 1.5, 3.5]:
		await get_tree().create_timer(t - (0.0 if t == 0.5 else (1.5 if t == 3.5 else 0.5))).timeout
		for c in casos:
			_medir(Cuerpo.esqueleto(c[2]), "%s %s t=%.1f" % [c[0], str(c[1]), t])
	await get_tree().create_timer(9.0).timeout
	for c in casos:
		if Cuerpo._simulador(Cuerpo.esqueleto(c[2])) != null and not Cuerpo._simulador(Cuerpo.esqueleto(c[2])).is_queued_for_deletion():
			fallos += 1
			print("NO SE CONGELÓ ", c[0])
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "FALLOS %d" % fallos)
	get_tree().quit()
