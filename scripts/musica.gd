# musica.gd
# -----------------------------------------------------------------------------
# Música y sonido ambiente, todo generado por código (sin descargas ni licencias).
# Hay varias "capas" que suenan en bucle y se mezclan solas según dónde estás,
# la hora, el clima y lo buscado que estés:
#   musica_dia / musica_noche  acordes suaves; de noche más graves y oscuros.
#   tension                    sube cuando los guardias te buscan.
#   ciudad                     murmullo de gente (plaza, mercado, residencial).
#   industrial                 zumbido de máquinas y golpes lejanos.
#   campo_dia / campo_noche    pájaros de día, grillos de noche.
#   lluvia                     la lluvia del clima (sube con Clima.lluvia).
# Dentro de un edificio los sonidos de fuera se apagan (filtro paso bajo).
# Si más adelante pones archivos .ogg/.wav en assets/musica/NOMBRE.ogg (con el
# nombre de la capa), se usan en lugar de los generados.
# Los volúmenes se cambian en el panel de administrador (F1) y se recuerdan.
# -----------------------------------------------------------------------------
class_name Musica
extends Node

const RUTA_OPCIONES: String = "user://opciones.cfg"
const BUS_MUSICA: String = "Musica"
const BUS_AMBIENTE: String = "Ambiente"

# Centros de las zonas (x, z) y su tipo de sonido.
const ZONAS: Array = [
	["plaza", Vector2(0, 0)], ["mercado", Vector2(16, -64)], ["residencial", Vector2(64, -16)],
	["industrial", Vector2(-16, 64)], ["campo", Vector2(200, -16)],
]
# Cuánto suena cada capa de ambiente en cada zona (0-1): ciudad, industrial, campo.
const MEZCLA_ZONA: Dictionary = {
	"plaza": [0.8, 0.0, 0.0], "mercado": [1.0, 0.0, 0.0], "residencial": [0.5, 0.0, 0.25],
	"industrial": [0.2, 1.0, 0.0], "campo": [0.0, 0.0, 1.0],
}
const DISTANCIA_CAMPO: float = 100.0   # A más de esto de todos los barrios, es campo abierto.

static var volumen_musica: float = 0.7      # 0-1 (lo cambia el panel F1).
static var volumen_ambiente: float = 0.8

var _capas: Dictionary = {}                 # nombre -> AudioStreamPlayer
var _pendientes: Array = ["musica_dia", "musica_noche", "tension", "ciudad", "industrial",
		"campo_dia", "campo_noche", "lluvia"]
var _t: float = 0.0
var _zona_actual: String = "plaza"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # La música sigue sonando en los menús (que pausan el juego).
	cargar_opciones()
	_crear_buses()


static func guardar_opciones() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("sonido", "musica", volumen_musica)
	cfg.set_value("sonido", "ambiente", volumen_ambiente)
	cfg.save(RUTA_OPCIONES)


static func cargar_opciones() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA_OPCIONES) != OK:
		return
	volumen_musica = clampf(float(cfg.get_value("sonido", "musica", 0.7)), 0.0, 1.0)
	volumen_ambiente = clampf(float(cfg.get_value("sonido", "ambiente", 0.8)), 0.0, 1.0)


func _crear_buses() -> void:
	for nombre in [BUS_MUSICA, BUS_AMBIENTE]:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, nombre)
			AudioServer.set_bus_send(idx, "Master")
	# En el bus del ambiente, un filtro que se activa dentro de los edificios.
	var ambiente: int = AudioServer.get_bus_index(BUS_AMBIENTE)
	if AudioServer.get_bus_effect_count(ambiente) == 0:
		var filtro: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		filtro.cutoff_hz = 800.0
		AudioServer.add_bus_effect(ambiente, filtro)
		AudioServer.set_bus_effect_enabled(ambiente, 0, false)


func _process(delta: float) -> void:
	# Las capas se generan una por fotograma para no congelar el arranque.
	if not _pendientes.is_empty():
		_crear_capa(String(_pendientes.pop_front()))
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_mezclar(0.25)


func _crear_capa(nombre: String) -> void:
	var flujo: AudioStream = _flujo_de_archivo(nombre)
	if flujo == null:
		flujo = _generar(nombre)
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = flujo
	p.volume_db = -80.0
	p.bus = BUS_MUSICA if nombre.begins_with("musica") or nombre == "tension" else BUS_AMBIENTE
	add_child(p)
	p.play()
	_capas[nombre] = p


func _flujo_de_archivo(nombre: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var ruta: String = "res://assets/musica/%s.%s" % [nombre, ext]
		if ResourceLoader.exists(ruta):
			var f: AudioStream = load(ruta) as AudioStream
			if f is AudioStreamOggVorbis:
				(f as AudioStreamOggVorbis).loop = true
			return f
	return null


# -------------------------------- Mezcla según el momento --------------------------------

func _zona_de(pos: Vector3) -> String:
	var p: Vector2 = Vector2(pos.x, pos.z)
	var mejor: String = "campo"
	var d_min: float = INF
	for z in ZONAS:
		var d: float = p.distance_to(z[1])
		if d < d_min:
			d_min = d
			mejor = z[0]
	return "campo" if d_min > DISTANCIA_CAMPO else mejor


func _mezclar(paso: float) -> void:
	var jugador: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador != null:
		_zona_actual = _zona_de(jugador.global_position)
	var mezcla: Array = MEZCLA_ZONA[_zona_actual]
	var h: float = Juego.hora
	var dia: float = smoothstep(5.5, 7.5, h) * (1.0 - smoothstep(19.0, 21.0, h))
	var dentro: bool = Juego.interiores > 0
	var tormenta: float = Clima.lluvia
	# Si llueve, la música baja un poco; dentro de un edificio, un poco más.
	var calma: float = (1.0 - 0.35 * tormenta) * (0.7 if dentro else 1.0)
	var m: float = volumen_musica * calma
	var a: float = volumen_ambiente
	var objetivos: Dictionary = {
		"musica_dia": m * dia * 0.5,
		"musica_noche": m * (1.0 - dia) * 0.55,
		"tension": m * clampf((Juego.alerta - 25.0) / 75.0, 0.0, 1.0) * 0.6 if Juego.policia_activa else 0.0,
		"ciudad": a * float(mezcla[0]) * (0.5 + 0.5 * dia) * 0.6,
		"industrial": a * float(mezcla[1]) * 0.5,
		"campo_dia": a * float(mezcla[2]) * dia * 0.6,
		"campo_noche": a * float(mezcla[2]) * (1.0 - dia) * 0.5,
		"lluvia": a * clampf(Clima.lluvia, 0.0, 1.0) * (0.55 + 0.45 * Clima.viento) * (0.5 if dentro else 1.0),
	}
	# La lluvia y el clima feo tapan un poco los pájaros y el murmullo.
	var tapa: float = 1.0 - 0.6 * clampf(Clima.lluvia, 0.0, 1.0)
	for k in ["ciudad", "campo_dia", "campo_noche"]:
		objetivos[k] = float(objetivos[k]) * tapa
	for nombre in objetivos:
		var p: AudioStreamPlayer = _capas.get(nombre) as AudioStreamPlayer
		if p == null:
			continue
		var db: float = linear_to_db(maxf(float(objetivos[nombre]), 0.0001))
		p.volume_db = move_toward(p.volume_db, maxf(db, -80.0), 60.0 * paso)   # Cambios suaves (60 dB/s).
	# Filtro del ambiente: dentro de edificios se apagan los sonidos de fuera.
	var bus: int = AudioServer.get_bus_index(BUS_AMBIENTE)
	if bus != -1 and AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.set_bus_effect_enabled(bus, 0, dentro)


# ------------------------------------- Generación -------------------------------------
# Cada generador devuelve un AudioStreamWAV en bucle (sin cortes al volver al principio).

static func _generar(nombre: String) -> AudioStream:
	match nombre:
		"musica_dia":
			return _pad([[130.81, 164.81, 196.0, 246.94], [110.0, 164.81, 196.0, 261.63],
					[87.31, 110.0, 130.81, 164.81], [98.0, 146.83, 164.81, 196.0]], 4.0, 0.0, 41)
		"musica_noche":
			return _pad([[55.0, 82.41, 110.0, 130.81], [43.65, 65.41, 87.31, 130.81],
					[51.91, 77.78, 103.83, 123.47], [55.0, 82.41, 98.0, 130.81]], 5.0, 0.35, 42)
		"tension":
			return _tension()
		"ciudad":
			return _ciudad()
		"industrial":
			return _industrial()
		"campo_dia":
			return _pajaros()
		"campo_noche":
			return _grillos()
		"lluvia":
			return _lluvia()
	return null


static func _wav(datos: PackedFloat32Array, tasa: int) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(datos.size() * 2)
	for i in datos.size():
		bytes.encode_s16(i * 2, int(clampf(datos[i], -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = datos.size()
	return w


# Hace que el final de un ruido se funda con su principio (bucle sin "clic").
static func _cerrar_bucle(d: PackedFloat32Array, fundido: int) -> void:
	var n: int = d.size()
	for i in fundido:
		var k: float = float(i) / fundido
		d[n - fundido + i] = d[n - fundido + i] * (1.0 - k) + d[i] * k
	# Lo que se fundió al final ya suena al principio: se recorta el solape.
	d.resize(n - fundido)


# Pads de acordes: cada acorde dura "duracion" segundos y se solapa con el siguiente.
# "oscuridad" (0-1) añade un temblor lento y baja el brillo.
static func _pad(acordes: Array, duracion: float, oscuridad: float, semilla: int) -> AudioStreamWAV:
	var tasa: int = 8000
	var total: float = duracion * acordes.size()
	var n: int = int(total * tasa)
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = semilla
	for k in acordes.size():
		var notas: Array = acordes[k]
		var inicio: float = k * duracion
		var largo: float = duracion + 1.0   # Se solapa 1 s con el siguiente acorde.
		var muestras: int = int(largo * tasa)
		for nota in notas:
			var f: float = float(nota)
			var fase0: float = rng.randf() * TAU
			var desafino: float = 1.0 + rng.randf_range(-0.002, 0.002)
			for i in muestras:
				var tl: float = float(i) / tasa
				var ventana: float = sin(PI * tl / largo)
				ventana *= ventana
				var v: float = sin(TAU * f * desafino * tl + fase0)
				v += (0.35 - 0.25 * oscuridad) * sin(TAU * f * 2.0 * tl + fase0)
				var tremolo: float = 1.0 - oscuridad * 0.3 * (0.5 + 0.5 * sin(TAU * 0.4 * tl + fase0))
				var idx: int = (int(inicio * tasa) + i) % n
				d[idx] += v * ventana * tremolo * 0.1
	# Un "pluck" suave de la nota más aguda de cada acorde, para que no sea solo un colchón.
	if oscuridad < 0.2:
		for k in acordes.size():
			var notas2: Array = acordes[k]
			for j in 4:
				var f2: float = float(notas2[j % notas2.size()]) * 4.0
				var t0: int = int((k * duracion + j * duracion / 4.0) * tasa)
				for i in int(1.4 * tasa):
					var tl2: float = float(i) / tasa
					d[(t0 + i) % n] += sin(TAU * f2 * tl2) * exp(-3.2 * tl2) * 0.05
	return _wav(d, tasa)


static func _tension() -> AudioStreamWAV:
	var tasa: int = 8000
	var n: int = tasa * 4
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t: float = float(i) / tasa
		# Tritono grave (A1 y Eb2) con un latido de 2 pulsos por segundo.
		var pulso: float = 0.55 + 0.45 * pow(maxf(0.0, sin(TAU * 2.0 * t)), 3.0)
		var v: float = sin(TAU * 55.0 * t) + sin(TAU * 77.78 * t) * 0.9 + sin(TAU * 311.0 * t) * 0.06
		d[i] = v * pulso * 0.22
	return _wav(d, tasa)


static func _ciudad() -> AudioStreamWAV:
	# Murmullo: ruido suavizado cuyo volumen sube y baja como voces lejanas.
	var tasa: int = 8000
	var n: int = tasa * 10
	var fundido: int = tasa
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n + fundido)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 51
	var a: float = 0.0
	var b: float = 0.0
	for i in n + fundido:
		a = lerpf(a, rng.randf_range(-1.0, 1.0), 0.22)
		b = lerpf(b, a, 0.3)
		var t: float = float(i) / tasa
		var voces: float = 0.45 + 0.3 * sin(TAU * 0.3 * t + 1.0) + 0.25 * sin(TAU * 0.7 * t + 2.0)
		d[i] = b * 1.5 * voces
	_cerrar_bucle(d, fundido)
	return _wav(d, tasa)


static func _industrial() -> AudioStreamWAV:
	var tasa: int = 8000
	var n: int = tasa * 8
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 61
	var ruido: float = 0.0
	for i in n:
		var t: float = float(i) / tasa
		# Zumbido de motor (50 y 100 Hz) y un golpe metálico lejano cada 2 s.
		var v: float = 0.5 * sin(TAU * 50.0 * t) + 0.25 * sin(TAU * 100.0 * t + 1.0) + 0.1 * sin(TAU * 150.0 * t)
		v *= 0.75 + 0.25 * sin(TAU * 0.5 * t)
		var tg: float = fposmod(t, 2.0)
		ruido = lerpf(ruido, rng.randf_range(-1.0, 1.0), 0.5)
		v += (sin(TAU * 420.0 * tg) * 0.6 + ruido * 0.4) * exp(-14.0 * tg) * 0.5
		d[i] = v * 0.35
	return _wav(d, tasa)


static func _pajaros() -> AudioStreamWAV:
	var tasa: int = 11025
	var n: int = tasa * 12
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 71
	var brisa: float = 0.0
	for i in n:
		brisa = lerpf(brisa, rng.randf_range(-1.0, 1.0), 0.04)
		d[i] = brisa * 0.12
	# Unos 14 gorjeos: barridos rápidos de tono con caída de volumen.
	for k in 14:
		var inicio: int = int(rng.randf() * (n - tasa))
		var f0: float = rng.randf_range(2200.0, 3600.0)
		var subida: float = rng.randf_range(-1200.0, 1500.0)
		var notas: int = rng.randi_range(1, 4)
		for q in notas:
			var t0: int = inicio + q * int(0.12 * tasa)
			var fase: float = 0.0
			for i in int(0.09 * tasa):
				var tl: float = float(i) / (0.09 * tasa)
				var f: float = f0 + subida * tl + 300.0 * sin(TAU * 25.0 * tl)
				fase += TAU * f / tasa
				d[(t0 + i) % n] += sin(fase) * sin(PI * tl) * 0.18
	return _wav(d, tasa)


static func _grillos() -> AudioStreamWAV:
	var tasa: int = 11025
	var n: int = tasa * 8
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t: float = float(i) / tasa
		# Dos grillos con trinos de ~24 Hz que suenan en tandas.
		var tanda1: float = smoothstep(0.2, 0.5, sin(TAU * t / 4.0))
		var tanda2: float = smoothstep(0.2, 0.5, sin(TAU * t / 8.0 + 2.0))
		var tr1: float = maxf(0.0, sin(TAU * 24.0 * t))
		var tr2: float = maxf(0.0, sin(TAU * 19.0 * t))
		var v: float = sin(TAU * 3800.0 * t) * tr1 * tanda1 + sin(TAU * 3300.0 * t) * tr2 * tanda2 * 0.8
		d[i] = v * 0.14
	return _wav(d, tasa)


static func _lluvia() -> AudioStreamWAV:
	var tasa: int = 11025
	var n: int = tasa * 6
	var fundido: int = tasa
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n + fundido)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 81
	var lento: float = 0.0
	for i in n + fundido:
		var r: float = rng.randf_range(-1.0, 1.0)
		lento = lerpf(lento, r, 0.15)
		# Ruido blanco quitándole los graves (suena a gotas) más un fondo sordo.
		d[i] = (r - lento) * 0.32 + lento * 0.12
	_cerrar_bucle(d, fundido)
	return _wav(d, tasa)
