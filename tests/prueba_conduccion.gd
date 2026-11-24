# Prueba de la física de los vehículos (FisicaCoche). Sin ventana:
#   godot --headless --path . res://tests/prueba_conduccion.tscn -- [tipo|todos]
# Pista plana de 1 km con una rampa y un muro. Mide: altura en reposo, 0-100 km/h, velocidad
# punta, frenada desde 100, curva (radio y balanceo), freno de mano (derrape) y choque contra el
# muro (daño y abolladura). Acaba con "RESUMEN" y la lista de fallos si los hay.
extends Node3D

var fallos: Array = []
var v: Vehiculo


func _suelo() -> void:
	var cuerpo: StaticBody3D = StaticBody3D.new()
	var forma: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(2000, 2, 2000)
	forma.shape = caja
	forma.position.y = -1.0
	cuerpo.add_child(forma)
	add_child(cuerpo)
	# Muro al final de la pista (z = -600).
	var muro: StaticBody3D = StaticBody3D.new()
	var fm: CollisionShape3D = CollisionShape3D.new()
	var cm: BoxShape3D = BoxShape3D.new()
	cm.size = Vector3(40, 4, 2)
	fm.shape = cm
	muro.add_child(fm)
	muro.position = Vector3(300, 2, -60)
	add_child(muro)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 50, 0)
	cam.current = true


func _esperar(seg: float) -> void:
	var t: float = 0.0
	while t < seg:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _crear(tipo: String, pos: Vector3, giro: float = 0.0) -> Vehiculo:
	if v != null and is_instance_valid(v):
		v.queue_free()
		await get_tree().physics_frame
	v = Vehiculo.new()
	v.tipo = tipo
	v.id = ""
	add_child(v)
	v.global_position = pos
	v.chasis.rotation.y = giro
	await get_tree().process_frame
	await get_tree().physics_frame
	v.fisica.conducido = true
	return v


func _kmh() -> float:
	return v.fisica.velocidad * 3.6


func _probar(tipo: String) -> void:
	print("---- ", tipo, " ----")
	await _crear(tipo, Vector3(0, 0.6, 0))
	var f: FisicaCoche = v.fisica
	await _esperar(2.0)
	var y0: float = f.global_position.y
	print("reposo: y=%.3f ruedas_suelo=%d inclinacion=%.3f vel=%.3f" % [y0, f.ruedas_en_suelo, f.global_transform.basis.y.y, f.linear_velocity.length()])
	if f.ruedas_en_suelo < 2 or absf(y0) > 0.3:
		fallos.append("%s: no se apoya bien en reposo (y=%.2f)" % [tipo, y0])
	await _esperar(1.0)
	var y1: float = f.global_position.y
	if absf(y1 - y0) > 0.02:
		fallos.append("%s: sigue botando en reposo (%.3f)" % [tipo, y1 - y0])
	# 0-100 y punta
	f.entrada = 1.0
	var t: float = 0.0
	var t100: float = -1.0
	var max_cab: float = 0.0
	while t < 25.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t100 < 0.0 and _kmh() >= 100.0:
			t100 = t
		max_cab = maxf(max_cab, rad_to_deg(acos(clampf(f.global_transform.basis.y.y, -1, 1))))
	var punta: float = _kmh()
	var vmax: float = float(Vehiculo.TIPOS[tipo]["vmax"]) * 3.6
	print("0-100: %s s · punta %.0f km/h (objetivo %.0f) · marcha %d rpm %.0f · cabeceo max %.1f°" % [
			("%.1f" % t100) if t100 > 0 else "no llega", punta, vmax, f.marcha, f.rpm, max_cab])
	if punta < vmax * 0.85 or punta > vmax * 1.08:
		fallos.append("%s: punta %.0f km/h, objetivo %.0f" % [tipo, punta, vmax])
	if absf(f.global_transform.basis.x.dot(Vector3.UP)) > 0.05:
		fallos.append("%s: se tuerce en recta" % tipo)
	# Frenada desde la velocidad actual (o 100)
	var p0: Vector3 = f.global_position
	var v0: float = _kmh()
	f.entrada = -1.0
	t = 0.0
	while _kmh() > 1.0 and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	f.entrada = 0.0
	var dist: float = f.global_position.distance_to(p0)
	print("frenada desde %.0f km/h: %.1f m en %.1f s" % [v0, dist, t])
	await _esperar(1.0)
	# Curva a ~40 km/h
	await _crear(tipo, Vector3(0, 0.6, 200))
	f = v.fisica
	await _esperar(1.0)
	f.entrada = 1.0
	t = 0.0
	while _kmh() < minf(40.0, vmax * 0.8) and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	f.entrada = 0.3
	f.direccion = 1.0
	var giro_total: float = 0.0
	var yaw_ant: float = f.rotation.y
	var balanceo: float = 0.0
	t = 0.0
	while t < 4.0:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		giro_total += wrapf(f.rotation.y - yaw_ant, -PI, PI)
		yaw_ant = f.rotation.y
		balanceo = maxf(balanceo, rad_to_deg(asin(clampf(f.global_transform.basis.x.y, -1, 1))))
	var w: float = giro_total / 4.0
	var radio: float = absf(f.linear_velocity.length() / maxf(absf(w), 0.001))
	print("curva a %.0f km/h: giro %.0f°/s, radio %.1f m, balanceo max %.1f°, volcado=%s" % [
			_kmh(), rad_to_deg(w), radio, balanceo, str(f.global_transform.basis.y.y < 0.5)])
	if f.global_transform.basis.y.y < 0.5:
		fallos.append("%s: vuelca en una curva normal" % tipo)
	f.direccion = 0.0
	f.entrada = 0.0
	# Freno de mano a ~55 km/h: debe cruzarse (ángulo entre morro y velocidad)
	await _crear(tipo, Vector3(0, 0.6, 400))
	f = v.fisica
	await _esperar(1.0)
	f.entrada = 1.0
	t = 0.0
	while _kmh() < minf(55.0, vmax * 0.8) and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	f.entrada = 0.0
	f.direccion = 1.0
	f.freno_mano = true
	var cruce: float = 0.0
	var desliz: float = 0.0
	t = 0.0
	while t < 1.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var vel: Vector3 = f.linear_velocity
		vel.y = 0.0
		if vel.length() > 3.0:
			var morro: Vector3 = -f.global_transform.basis.z
			cruce = maxf(cruce, rad_to_deg(morro.angle_to(vel)))
		desliz = maxf(desliz, f.deslizamiento)
	print("freno de mano: cruce max %.0f°, deslizamiento max %.1f m/s, volcado=%s" % [cruce, desliz, str(f.global_transform.basis.y.y < 0.5)])
	if tipo in ["sedan", "deportivo", "hatchback"] and cruce < 15.0:
		fallos.append("%s: el freno de mano no hace derrapar (%.0f°)" % [tipo, cruce])
	f.freno_mano = false
	f.direccion = 0.0
	# Choque contra el muro a ~50 km/h
	await _crear(tipo, Vector3(300, 0.6, 0))
	f = v.fisica
	await _esperar(1.0)
	var golpes: Array = []
	f.golpe.connect(func(p, n, fz, o): golpes.append(fz))
	f.entrada = 1.0
	t = 0.0
	while t < 12.0 and f.global_position.z > -56.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _kmh() > 50.0:
			f.entrada = 0.0
	await _esperar(1.5)
	print("choque: golpes=%s salud=%.0f abollado=%s" % [str(golpes), v.salud, str(Deformacion.abollado(v._carroceria))])
	if golpes.is_empty():
		fallos.append("%s: no detecta el choque" % tipo)


func _ready() -> void:
	_suelo()
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cual: String = args[0] if args.size() > 0 else "sedan"
	var tipos: Array = [cual]
	if cual == "todos":
		tipos = FisicaCoche.PERFILES.keys()
	for tp in tipos:
		await _probar(tp)
	print("RESUMEN: ", "TODO BIEN" if fallos.is_empty() else "")
	for fl in fallos:
		print("FALLO: ", fl)
	get_tree().quit()
