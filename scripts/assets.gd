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


# Devuelve una copia nueva del modelo, o null si no está descargado.
static func modelo(nombre: String) -> Node3D:
	for ext in ["glb", "gltf"]:
		var ruta: String = "%s%s.%s" % [CARPETA_MODELOS, nombre, ext]
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
