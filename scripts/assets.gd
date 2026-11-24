# assets.gd
# -----------------------------------------------------------------------------
# Puente entre el juego y los modelos/texturas descargados (assets/).
# Si el archivo existe, se usa; si no, el juego sigue con sus cajas. Así se
# pueden ir sustituyendo cosas de una en una sin romper nada.
#
#   Assets.modelo("farola")  -> busca assets/modelos/farola.glb (o .gltf)
#   Assets.textura("suelo")  -> busca assets/texturas/suelo.png (o .jpg)
#
# Mira assets/LEEME.md para la lista de nombres que el juego reconoce.
# -----------------------------------------------------------------------------
class_name Assets
extends RefCounted

const CARPETA_MODELOS: String = "res://assets/modelos/"
const CARPETA_TEXTURAS: String = "res://assets/texturas/"

# Paquetes CC0 de Quaternius ya incluidos (ver CREDITS.md). Se usan así:
#   Assets.modelo(Assets.FANTASIA + "Barrel")
const FANTASIA: String = "quaternius/fantasy-props-megakit/"      # Barriles, mesas, pociones...
const MEDIEVAL: String = "quaternius/medieval-village-megakit/"   # Muros, tejados, carros...
const ARMAS: String = "quaternius/toon-shooter-game-kit/Guns/"    # Pistola, escopeta, AK...
const ENTORNO: String = "quaternius/toon-shooter-game-kit/Environment/"
const PERSONAJES: String = "quaternius/universal-base-characters/"
# Universal Animation Library (CC0): 43 animaciones para el esqueleto de PERSONAJES.
const UAL: String = "res://assets/quaternius/universal-animation-library/UAL1_Standard.glb"
const BASES_PERSONA: PackedStringArray = ["Superhero_Male_FullBody", "Superhero_Female_FullBody"]

# Nombres de animación que usa el juego -> nombres equivalentes en los otros paquetes.
# Así "Walk", "HitReact" o "Death" valen tanto para los muñecos del Toon Shooter como
# para las personas con la Universal Animation Library.
const ALIAS_ANIM: Dictionary = {
	"Idle": ["Idle"], "Walk": ["Walk"], "Run": ["Jog_Fwd", "Sprint"], "Sprint": ["Sprint", "Run"],
	"HitReact": ["Hit_Chest"], "HitHead": ["Hit_Head", "HitReact", "Hit_Chest"],
	"Death": ["Death01"], "Punch": ["Punch_Cross", "Punch_Jab"],
	"Duck": ["Crouch_Idle"], "Jump": ["Jump_Start", "Roll"], "Roll": ["Roll", "Jump"],
	"Wave": ["Interact", "Idle_Talking"], "Yes": ["Idle_Talking"], "No": ["Idle_Talking"],
	"Idle_Shoot": ["Pistol_Aim_Neutral", "Pistol_Idle"], "Walk_Shoot": ["Walk"],
	"Run_Shoot": ["Jog_Fwd"], "Run_Gun": ["Jog_Fwd"], "Shoot": ["Pistol_Shoot", "Idle_Shoot"],
	"Talk": ["Idle_Talking", "Idle"], "Sit": ["Sitting_Idle"],
}

static var _lib_ual: AnimationLibrary = null


# Candidatos para un nombre de animación (el propio, con prefijo de Quaternius y sus alias).
static func nombres_anim(nombre: String) -> Array:
	var r: Array = [nombre, "CharacterArmature|" + nombre]
	for a in ALIAS_ANIM.get(nombre, []):
		r.append(a)
		r.append("CharacterArmature|" + String(a))
	return r


# Persona de proporciones humanas (Universal Base Characters) con las 43 animaciones de
# la Universal Animation Library. Mismo uso que personaje(): mira a -Z, pies en el suelo,
# meta "animaciones" con su AnimationPlayer. "arma": "Pistol", "Revolver", "Knife"... (en la mano derecha).
static func persona(base: String = "", arma: String = "", animacion: String = "Idle") -> Node3D:
	if base == "":
		base = BASES_PERSONA[randi() % BASES_PERSONA.size()]
	var m: Node3D = modelo(PERSONAJES + "base-characters/" + base)
	if m == null:
		return null
	if _lib_ual == null and ResourceLoader.exists(UAL):
		var fuente: Node = (load(UAL) as PackedScene).instantiate()
		var ap: AnimationPlayer = _buscar_animaciones(fuente)
		if ap != null and ap.has_animation_library(""):
			_lib_ual = ap.get_animation_library("")
		fuente.free()
	var envoltorio: Node3D = Node3D.new()
	m.rotation.y = PI
	envoltorio.add_child(m)
	if _lib_ual != null:
		var reproductor: AnimationPlayer = AnimationPlayer.new()
		reproductor.name = "AnimationPlayer"
		m.add_child(reproductor)
		reproductor.add_animation_library("", _lib_ual)
		envoltorio.set_meta("animaciones", reproductor)
		poner_animacion(envoltorio, animacion)
	if arma != "":
		var esq_l: Array = m.find_children("*", "Skeleton3D", true, false)
		var pieza: Node3D = modelo(ARMAS + arma)
		if not esq_l.is_empty() and pieza != null:
			var mano: BoneAttachment3D = BoneAttachment3D.new()
			mano.bone_name = "hand_r"
			(esq_l[0] as Skeleton3D).add_child(mano)
			pieza.name = arma
			# Las armas del kit vienen muy grandes (la pistola mide ~0,8 m): se dejan
			# a tamaño real. El cañón del modelo mira a -X y la culata está en el
			# origen; la mano tiene los dedos en +Y y el dorso hacia +Z.
			var largo: float = _largo_modelo(pieza)
			var tam: float = 0.55 if arma in ["Shotgun", "AK", "SMG", "Sniper", "Sniper_2", "GrenadeLauncher", "RocketLauncher", "ShortCannon"] else 0.24
			var esc: float = tam / largo if largo > 0.01 else 0.3
			pieza.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)).scaled(Vector3.ONE * esc), Vector3(0, 0.085, 0.0))
			mano.add_child(pieza)
	return envoltorio


# Lado más largo de las mallas de un modelo (en sus propias unidades).
static func _largo_modelo(n: Node, t: Transform3D = Transform3D.IDENTITY) -> float:
	var tt: Transform3D = t * (n as Node3D).transform if n is Node3D else t
	var largo: float = 0.0
	if n is MeshInstance3D:
		var a: AABB = tt * (n as MeshInstance3D).get_aabb()
		largo = a.get_longest_axis_size()
	for c in n.get_children():
		largo = maxf(largo, _largo_modelo(c, tt))
	return largo


# Ruta de un modelo. Si el nombre lleva una carpeta (como "quaternius/..."), se
# busca dentro de assets/; si no, en assets/modelos/.
static func _ruta(nombre: String, ext: String) -> String:
	var base: String = "res://assets/" if "/" in nombre else CARPETA_MODELOS
	return "%s%s.%s" % [base, nombre, ext]


# Devuelve una copia nueva del modelo, o null si no está descargado.
static func modelo(nombre: String) -> Node3D:
	for ext in ["glb", "gltf"]:
		var ruta: String = _ruta(nombre, ext)
		if ResourceLoader.exists(ruta):
			var escena = load(ruta)
			if escena is PackedScene:
				return (escena as PackedScene).instantiate() as Node3D
	return null


# true si el modelo existe (sin cargarlo).
static func existe(nombre: String) -> bool:
	for ext in ["glb", "gltf"]:
		if ResourceLoader.exists(_ruta(nombre, ext)):
			return true
	return false


# Devuelve la textura, o null si no está.
static func textura(nombre: String) -> Texture2D:
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var ruta: String = "%s%s.%s" % [CARPETA_TEXTURAS, nombre, ext]
		if ResourceLoader.exists(ruta):
			return load(ruta) as Texture2D
	return null


# Pone el modelo "nombre" dentro de "padre" en "pos" y devuelve true si existía.
static func colocar(padre: Node3D, nombre: String, pos: Vector3, escala: float = 1.0,
		giro: float = 0.0) -> bool:
	var m: Node3D = modelo(nombre)
	if m == null:
		return false
	m.position = pos
	m.scale = Vector3.ONE * escala
	m.rotation.y = giro
	padre.add_child(m)
	return true


const ARMAS_PERSONAJE: PackedStringArray = ["AK", "GrenadeLauncher", "Pistol", "Revolver",
		"Revolver_Small", "RocketLauncher", "ShortCannon", "Shotgun", "Shovel", "SMG", "Sniper", "Knife"]


# Personaje de Quaternius listo para poner: mide ~1,8 m con los pies en el suelo y
# mira hacia -Z. "arma" es el arma que se deja visible (las demás se ocultan).
# Devuelve null si el modelo no está. SIN PROBAR en Godot: revisar altura/giro.
static func personaje(nombre: String, arma: String = "", animacion: String = "Idle") -> Node3D:
	var m: Node3D = modelo(nombre)
	if m == null:
		return null
	var envoltorio: Node3D = Node3D.new()
	m.rotation.y = PI
	envoltorio.add_child(m)
	_filtrar_armas(m, arma)
	var reproductor: AnimationPlayer = _buscar_animaciones(m)
	if reproductor != null:
		envoltorio.set_meta("animaciones", reproductor)
		poner_animacion(envoltorio, animacion)
	return envoltorio


# Velocidad a la que "avanza" el cuerpo de las animaciones Walk y Run de Quaternius (medida con
# los pies en el suelo: ~1,08 m por paso en 0,5 s al andar y ~0,7 m en 0,13 s al correr).
# Si el personaje va a otra velocidad, hay que acelerar o frenar la animación o "patina".
const VEL_ANIM_ANDAR: float = 2.1
const VEL_ANIM_CORRER: float = 4.5
const VEL_CAMBIO_CARRERA: float = 3.3   # Por encima de esto se usa la animación de correr.
const VEL_QUIETO: float = 0.2


# Elige Idle / Walk / Run según la velocidad real (m/s) y ajusta el ritmo de la animación
# para que los pies no patinen: a la mitad de velocidad, las piernas van a la mitad.
static func animar_por_velocidad(personaje_nodo: Node3D, velocidad: float) -> void:
	if velocidad < VEL_QUIETO:
		poner_animacion(personaje_nodo, "Idle")
	elif velocidad > VEL_CAMBIO_CARRERA:
		poner_animacion(personaje_nodo, "Run", clampf(velocidad / VEL_ANIM_CORRER, 0.5, 2.0))
	else:
		poner_animacion(personaje_nodo, "Walk", clampf(velocidad / VEL_ANIM_ANDAR, 0.25, 2.0))


static func poner_animacion(personaje_nodo: Node3D, nombre: String, ritmo: float = 1.0) -> void:
	if personaje_nodo == null or not personaje_nodo.has_meta("animaciones"):
		return
	var r: AnimationPlayer = personaje_nodo.get_meta("animaciones") as AnimationPlayer
	if r == null or not is_instance_valid(r):
		return
	r.speed_scale = ritmo
	for candidato in nombres_anim(nombre):
		if r.has_animation(candidato):
			if r.current_animation != candidato:
				var anim: Animation = r.get_animation(candidato)
				if anim != null:
					anim.loop_mode = Animation.LOOP_LINEAR
				r.play(candidato, 0.2)   # Mezcla suave en vez de saltar de golpe.
			return


static func _filtrar_armas(nodo: Node, conservar: String) -> void:
	for h in nodo.get_children():
		# Algunos modelos traen el arma numerada ("Knife_1", "Knife_2"): se quita el
		# número para reconocerla (si no, el tendero salía con dos cuchillos en la mano).
		var nombre: String = String(h.name)
		var base: String = nombre.rsplit("_", true, 1)[0] if nombre.get_slice_count("_") > 1 \
				and nombre.rsplit("_", true, 1)[1].is_valid_int() else nombre
		if h is Node3D and (ARMAS_PERSONAJE.has(nombre) or ARMAS_PERSONAJE.has(base)):
			(h as Node3D).visible = (nombre == conservar)
		_filtrar_armas(h, conservar)


static func _buscar_animaciones(nodo: Node) -> AnimationPlayer:
	if nodo is AnimationPlayer:
		return nodo as AnimationPlayer
	for h in nodo.get_children():
		var r: AnimationPlayer = _buscar_animaciones(h)
		if r != null:
			return r
	return null


# ------------------------- Modelos con colisión y medidas ---------------------

# Caja que envuelve todas las mallas de un modelo (en coordenadas del propio modelo).
static func caja_de(nodo: Node3D) -> AABB:
	var caja: AABB = AABB()
	var primera: bool = true
	for hijo in nodo.find_children("*", "MeshInstance3D", true, false):
		var malla: MeshInstance3D = hijo as MeshInstance3D
		var local: Transform3D = Transform3D.IDENTITY
		var actual: Node = malla
		while actual != null and actual != nodo:
			local = (actual as Node3D).transform * local
			actual = actual.get_parent()
		var caja_malla: AABB = local * malla.get_aabb()
		caja = caja_malla if primera else caja.merge(caja_malla)
		primera = false
	return caja


# Como colocar(), pero además el jugador choca con el modelo (una caja que lo
# envuelve). "escala_vec" permite estirarlo distinto en cada eje. Devuelve el
# nodo del modelo, o null si no existe.
static func colocar_solido(padre: Node3D, nombre: String, pos: Vector3, giro: float = 0.0,
		escala_vec: Vector3 = Vector3.ONE, solido: bool = true) -> Node3D:
	var m: Node3D = modelo(nombre)
	if m == null:
		return null
	var cuerpo: Node3D
	if solido:
		var fisico: StaticBody3D = StaticBody3D.new()
		var caja: AABB = caja_de(m)
		var choque: CollisionShape3D = CollisionShape3D.new()
		var forma: BoxShape3D = BoxShape3D.new()
		forma.size = caja.size
		choque.shape = forma
		choque.position = caja.get_center()
		fisico.add_child(choque)
		cuerpo = fisico
	else:
		cuerpo = Node3D.new()
	cuerpo.add_child(m)
	cuerpo.position = pos
	cuerpo.rotation.y = giro
	cuerpo.scale = escala_vec
	padre.add_child(cuerpo)
	return cuerpo
