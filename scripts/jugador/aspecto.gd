# aspecto.gd
# -----------------------------------------------------------------------------
# El aspecto del jugador: qué cuerpo lleva (el alquimista de cajas o un traje
# con modelo de Quaternius), color de piel, abrigo, bufanda, pelo, peinado y
# sombrero. Todo son números en Juego.aspecto (se guarda con la partida), así
# que añadir colores u opciones es solo ampliar las listas de aquí.
#
# Sin class_name a propósito (como los datos de objetos): se usa con preload.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
extends RefCounted

const CUERPOS: Array = ["Alquimista", "Traje de protección", "Soldado", "Bandido"]
const MODELOS_CUERPO: Dictionary = {
	1: "quaternius/toon-shooter-game-kit/Characters/Character_Hazmat",
	2: "quaternius/toon-shooter-game-kit/Characters/Character_Soldier",
	3: "quaternius/toon-shooter-game-kit/Characters/Character_Enemy",
}
const PIELES: Array = [Color(0.96, 0.8, 0.69), Color(0.85, 0.67, 0.52), Color(0.7, 0.5, 0.36),
		Color(0.52, 0.36, 0.26), Color(0.33, 0.22, 0.16)]
const NOMBRES_PIEL: Array = ["Clara", "Trigueña", "Morena", "Oscura", "Muy oscura"]
const ABRIGOS: Array = [Color(0.16, 0.12, 0.2), Color(0.45, 0.12, 0.1), Color(0.12, 0.25, 0.4),
		Color(0.2, 0.3, 0.17), Color(0.35, 0.3, 0.25), Color(0.1, 0.1, 0.1), Color(0.55, 0.45, 0.15)]
const NOMBRES_ABRIGO: Array = ["Violeta oscuro", "Granate", "Azul noche", "Verde bosque", "Marrón",
		"Negro", "Mostaza"]
const BUFANDAS: Array = [Color(0.25, 0.5, 0.3), Color(0.75, 0.2, 0.15), Color(0.9, 0.9, 0.85),
		Color(0.2, 0.35, 0.65), Color(0.85, 0.7, 0.2), Color(0.12, 0.12, 0.12)]
const NOMBRES_BUFANDA: Array = ["Verde", "Roja", "Blanca", "Azul", "Amarilla", "Negra"]
# Los dos últimos tintes son MÁGICOS (Hoja de Bruma y luz de luna): solo los hace una peluquería.
const PELOS: Array = [Color(0.1, 0.07, 0.05), Color(0.35, 0.2, 0.1), Color(0.75, 0.55, 0.25),
		Color(0.7, 0.25, 0.1), Color(0.75, 0.75, 0.75), Color(0.25, 0.4, 0.75),
		Color(0.3, 0.85, 0.5), Color(0.7, 0.55, 1.0)]
const NOMBRES_PELO: Array = ["Negro", "Castaño", "Rubio", "Pelirrojo", "Canoso", "Azul",
		"Verde Hoja de Bruma", "Violeta de luna"]
const PEINADOS: Array = ["Corto", "Largo", "Rapado", "Mohicano", "Coleta", "Afro"]
const BARBAS: Array = ["Sin barba", "Bigote", "Perilla", "Barba corta", "Barba larga"]
const SOMBREROS: Array = ["Ala ancha", "Gorra", "Capucha", "Sin sombrero"]
const COMPLEXIONES: Array = ["Delgada", "Normal", "Robusta"]

# Las opciones que se pueden cambiar en la ventana: [clave, título, lista de nombres].
const OPCIONES: Array = [
	["cuerpo", "Cuerpo", CUERPOS],
	["complexion", "Complexión", COMPLEXIONES],
	["piel", "Piel", NOMBRES_PIEL],
	["peinado", "Peinado", PEINADOS],
	["pelo", "Color de pelo", NOMBRES_PELO],
	["barba", "Barba", BARBAS],
	["sombrero", "Sombrero", SOMBREROS],
	["abrigo", "Abrigo", NOMBRES_ABRIGO],
	["bufanda", "Bufanda", NOMBRES_BUFANDA],
]

const POR_DEFECTO: Dictionary = {"cuerpo": 0, "complexion": 1, "piel": 0, "peinado": 0, "pelo": 0, "barba": 0,
		"sombrero": 0, "abrigo": 0, "bufanda": 0}


# Cuántas opciones tiene cada clave (para pasar de una a otra dando la vuelta).
static func cantidad(clave: String) -> int:
	for o in OPCIONES:
		if o[0] == clave:
			return (o[2] as Array).size()
	return 1


# Devuelve un aspecto correcto (lo que falte o esté fuera de rango vuelve al de por defecto).
static func valido(a) -> Dictionary:
	var r: Dictionary = POR_DEFECTO.duplicate()
	if a is Dictionary:
		for clave in POR_DEFECTO:
			r[clave] = clampi(int(a.get(clave, POR_DEFECTO[clave])), 0, cantidad(clave) - 1)
	return r


# Pone el aspecto "a" dentro de "raiz". Devuelve el modelo animado (si el cuerpo
# es uno de los trajes con modelo) o null (muñeco de cajas, sin animación).
static func vestir(raiz: Node3D, a: Dictionary) -> Node3D:
	var d: Dictionary = valido(a)
	var tipo: int = d["cuerpo"]
	if tipo > 0 and MODELOS_CUERPO.has(tipo):
		var persona: Node3D = Assets.personaje(MODELOS_CUERPO[tipo], "", "Idle")
		if persona != null:
			raiz.add_child(persona)
			return persona
	_muneco(raiz, d)
	return null


static func _muneco(raiz: Node3D, d: Dictionary) -> void:
	var ancho: float = [0.88, 1.0, 1.18][d["complexion"]]
	var base: Node3D = Node3D.new()
	base.scale = Vector3(ancho, 1.0, ancho)
	raiz.add_child(base)
	var piel: Color = PIELES[d["piel"]]
	var abrigo: Color = ABRIGOS[d["abrigo"]]
	var pelo: Color = PELOS[d["pelo"]]
	# Abrigo largo, brazos, cabeza y bufanda.
	Construir.cilindro(base, Vector3(0, 0.6, 0), 0.34, 1.2, abrigo, false, 0.0, 0.26)
	for lado in [-1.0, 1.0]:
		Construir.cilindro(base, Vector3(lado * 0.36, 0.86, 0.0), 0.075, 0.6, abrigo.lightened(0.08))
		Construir.esfera(base, Vector3(lado * 0.36, 0.54, 0.0), 0.075, piel)
	Construir.esfera(base, Vector3(0, 1.42, 0), 0.2, piel)
	Construir.cilindro(base, Vector3(0, 1.2, 0), 0.24, 0.12, BUFANDAS[d["bufanda"]])
	# Nariz: para saber hacia dónde mira (en Godot "delante" es -Z).
	Construir.caja(base, Vector3(0, 1.42, -0.2), Vector3(0.06, 0.06, 0.1), piel.darkened(0.1), false)
	# Peinado.
	match int(d["peinado"]):
		0:
			Construir.esfera(base, Vector3(0, 1.47, 0.02), 0.215, pelo, Vector3(1.0, 0.72, 1.0))
		1:
			Construir.esfera(base, Vector3(0, 1.47, 0.02), 0.215, pelo, Vector3(1.0, 0.72, 1.0))
			Construir.caja(base, Vector3(0, 1.28, 0.16), Vector3(0.36, 0.45, 0.1), pelo, false)
		3:   # Mohicano: cresta de delante a atrás.
			Construir.caja(base, Vector3(0, 1.66, 0.0), Vector3(0.07, 0.24, 0.4), pelo, false)
		4:   # Coleta.
			Construir.esfera(base, Vector3(0, 1.47, 0.02), 0.215, pelo, Vector3(1.0, 0.72, 1.0))
			Construir.cilindro(base, Vector3(0, 1.4, 0.26), 0.06, 0.4, pelo)
		5:   # Afro.
			Construir.esfera(base, Vector3(0, 1.55, 0.02), 0.31, pelo)
	# Barba y bigote (del color del pelo).
	var barba: int = int(d["barba"])
	if barba >= 1:
		Construir.caja(base, Vector3(0, 1.36, -0.19), Vector3(0.2, 0.04, 0.05), pelo, false)   # Bigote.
	if barba == 2:
		Construir.caja(base, Vector3(0, 1.28, -0.17), Vector3(0.07, 0.1, 0.05), pelo, false)
	elif barba >= 3:
		var largo: float = 0.12 if barba == 3 else 0.3
		Construir.caja(base, Vector3(0, 1.3 - largo / 2.0 + 0.06, -0.15), Vector3(0.3, largo, 0.1), pelo, false)
	# Sombrero.
	var tela: Color = abrigo.darkened(0.45)
	match int(d["sombrero"]):
		0:
			Construir.cilindro(base, Vector3(0, 1.58, 0), 0.38, 0.04, tela)
			Construir.cilindro(base, Vector3(0, 1.72, 0), 0.18, 0.26, tela, false, 0.0, 0.14)
		1:
			Construir.cilindro(base, Vector3(0, 1.62, 0), 0.21, 0.12, tela)
			Construir.caja(base, Vector3(0, 1.57, -0.22), Vector3(0.28, 0.03, 0.18), tela, false)
		2:
			Construir.esfera(base, Vector3(0, 1.46, 0.07), 0.25, abrigo, Vector3(1.0, 1.05, 1.0))
