# sonido.gd
# -----------------------------------------------------------------------------
# Efectos de sonido sencillos generados por código (sin archivos). Si más
# adelante se añaden .wav/.ogg CC0 en assets/sonidos/NOMBRE.wav (o .ogg), se usan
# en su lugar automáticamente.
#   Sonido.tocar(self, "disparo")   # nombres: disparo, golpe, compra, explosion, alerta
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Sonido
extends RefCounted

static var _cache: Dictionary = {}


static func tocar(origen: Node, nombre: String, volumen_db: float = -6.0) -> void:
	if origen == null or not origen.is_inside_tree():
		return
	var flujo: AudioStream = _flujo(nombre)
	if flujo == null:
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = flujo
	p.volume_db = volumen_db
	origen.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _flujo(nombre: String) -> AudioStream:
	if _cache.has(nombre):
		return _cache[nombre]
	var flujo: AudioStream = null
	for ext in ["ogg", "wav"]:
		var ruta: String = "res://assets/sonidos/%s.%s" % [nombre, ext]
		if ResourceLoader.exists(ruta):
			flujo = load(ruta) as AudioStream
			break
	if flujo == null:
		flujo = _generar(nombre)
	_cache[nombre] = flujo
	return flujo


# nombre -> [duración s, frecuencia Hz (0 = ruido), caída de volumen]
static func _generar(nombre: String) -> AudioStream:
	var tabla: Dictionary = {
		"disparo": [0.18, 0.0, 14.0], "explosion": [0.9, 0.0, 4.0],
		"golpe": [0.12, 140.0, 20.0], "compra": [0.25, 880.0, 9.0],
		"alerta": [0.5, 520.0, 3.0],
	}
	if nombre == "trueno":
		return _trueno()
	if not tabla.has(nombre):
		return null
	var d: Array = tabla[nombre]
	var tasa: int = 22050
	var n: int = int(float(d[0]) * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t: float = float(i) / tasa
		var env: float = exp(-float(d[2]) * t)
		var v: float = rng.randf_range(-1.0, 1.0) if float(d[1]) == 0.0 else sin(TAU * float(d[1]) * t)
		var m: int = int(clampf(v * env, -1.0, 1.0) * 32000.0)
		datos.encode_s16(i * 2, m)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = datos
	return w


# Un trueno: ruido grave que crece de golpe, retumba y se apaga despacio (3 s).
static func _trueno() -> AudioStream:
	var tasa: int = 11025
	var n: int = tasa * 3
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	var grave: float = 0.0
	var mas_grave: float = 0.0
	for i in n:
		var t: float = float(i) / tasa
		grave = lerpf(grave, rng.randf_range(-1.0, 1.0), 0.12)
		mas_grave = lerpf(mas_grave, grave, 0.1)
		# Ataque rápido, caída lenta y un par de "rebotes" del retumbo.
		var env: float = minf(t * 25.0, 1.0) * exp(-1.3 * t) * (0.75 + 0.25 * sin(TAU * 3.0 * t))
		var v: float = (grave * 1.2 + mas_grave * 5.0) * env
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = datos
	return w


# Viento suave de fondo en bucle. Si existe assets/sonidos/ambiente.ogg/.wav se usa ese.
static func ambiente(padre: Node, volumen_db: float = -22.0) -> void:
	var flujo: AudioStream = null
	for ext in ["ogg", "wav"]:
		var ruta: String = "res://assets/sonidos/ambiente.%s" % ext
		if ResourceLoader.exists(ruta):
			flujo = load(ruta) as AudioStream
			break
	if flujo == null:
		var tasa: int = 11025
		var n: int = tasa * 6
		var datos: PackedByteArray = PackedByteArray()
		datos.resize(n * 2)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 11
		var suave: float = 0.0
		for i in n:
			suave = lerpf(suave, rng.randf_range(-1.0, 1.0), 0.06)
			var oleaje: float = 0.6 + 0.4 * sin(TAU * float(i) / n * 2.0)
			datos.encode_s16(i * 2, int(clampf(suave * 3.0 * oleaje, -1.0, 1.0) * 20000.0))
		var w: AudioStreamWAV = AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = tasa
		w.data = datos
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
		flujo = w
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = flujo
	p.volume_db = volumen_db
	p.autoplay = true
	padre.add_child(p)
