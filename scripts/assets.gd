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


# Devuelve una copia nueva del modelo, o null si no está descargado. Si el nombre
# lleva una carpeta (como "quaternius/..."), se busca dentro de assets/.
static func modelo(nombre: String) -> Node3D:
	var base: String = "res://assets/" if "/" in nombre else CARPETA_MODELOS
	for ext in ["glb", "gltf"]:
		var ruta: String = "%s%s.%s" % [base, nombre, ext]
		if ResourceLoader.exists(ruta):
			var escena = load(ruta)
			if escena is PackedScene:
				return (escena as PackedScene).instantiate() as Node3D
	return null


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


static func poner_animacion(personaje_nodo: Node3D, nombre: String) -> void:
	if personaje_nodo == null or not personaje_nodo.has_meta("animaciones"):
		return
	var r: AnimationPlayer = personaje_nodo.get_meta("animaciones") as AnimationPlayer
	if r == null or not is_instance_valid(r):
		return
	for candidato in [nombre, "CharacterArmature|" + nombre]:
		if r.has_animation(candidato):
			if r.current_animation != candidato:
				var anim: Animation = r.get_animation(candidato)
				if anim != null:
					anim.loop_mode = Animation.LOOP_LINEAR
				r.play(candidato)
			return


static func _filtrar_armas(nodo: Node, conservar: String) -> void:
	for h in nodo.get_children():
		if h is Node3D and ARMAS_PERSONAJE.has(String(h.name)):
			(h as Node3D).visible = (String(h.name) == conservar)
		_filtrar_armas(h, conservar)


static func _buscar_animaciones(nodo: Node) -> AnimationPlayer:
	if nodo is AnimationPlayer:
		return nodo as AnimationPlayer
	for h in nodo.get_children():
		var r: AnimationPlayer = _buscar_animaciones(h)
		if r != null:
			return r
	return null
