# sonido_motor.gd
# -----------------------------------------------------------------------------
# Sonido del vehículo que conduces, generado en directo (sin archivos):
#   - MOTOR: el tono sube y baja con las revoluciones (y cae al cambiar de marcha);
#     acelerando suena más fuerte y más "rasposo". Los camiones y tractores suenan
#     más graves (diésel); el deportivo, más agudo.
#   - NEUMÁTICOS: chirrido cuando patinan o derrapan.
#   - CLAXON: Q.
# Si hay un archivo assets/sonidos/motor.ogg no se usa: este sonido sigue las
# revoluciones, cosa que un archivo fijo no puede hacer.
# -----------------------------------------------------------------------------
class_name SonidoMotor
extends AudioStreamPlayer3D

const TASA: float = 22050.0

var rpm: float = 900.0
var carga: float = 0.0          # 0..1 cuánto se pisa el acelerador
var chirrido: float = 0.0       # 0..1 cuánto patinan las ruedas
var claxon: bool = false
var cilindros: float = 4.0
var grave: float = 1.0          # >1 más grave (diésel), <1 más agudo
var encendido: bool = true

var _gen: AudioStreamGeneratorPlayback = null
var _fase: float = 0.0
var _fase_c1: float = 0.0
var _fase_c2: float = 0.0
var _rpm_suave: float = 900.0
var _carga_suave: float = 0.0
var _chirr_suave: float = 0.0
var _f1: float = 0.0            # Filtro del chirrido (dos polos).
var _f2: float = 0.0
var _ruido_lp: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var s: AudioStreamGenerator = AudioStreamGenerator.new()
	s.mix_rate = TASA
	s.buffer_length = 0.12
	stream = s
	unit_size = 8.0
	max_distance = 120.0
	volume_db = -4.0
	play()
	_gen = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _gen == null:
		return
	var n: int = _gen.get_frames_available()
	if n <= 0:
		return
	var buffer: PackedVector2Array = PackedVector2Array()
	buffer.resize(n)
	var objetivo_rpm: float = rpm if encendido else 0.0
	for i in n:
		_rpm_suave += (objetivo_rpm - _rpm_suave) * 0.0016
		_carga_suave += (carga - _carga_suave) * 0.0008
		_chirr_suave += (chirrido - _chirr_suave) * 0.001
		var muestra: float = 0.0
		if _rpm_suave > 120.0:
			# Frecuencia de encendido: un pistón explota cada dos vueltas.
			var f0: float = _rpm_suave / 60.0 * cilindros * 0.5 / grave
			_fase = fmod(_fase + f0 / TASA, 1.0)
			var t: float = _fase * TAU
			var brillo: float = 0.35 + 0.65 * _carga_suave
			var onda: float = sin(t) + 0.55 * brillo * sin(2.0 * t + 0.3) + 0.3 * brillo * sin(3.0 * t + 1.1) \
					+ 0.18 * brillo * sin(5.0 * t)
			# Golpe de cada explosión: un pulso de ruido al principio de cada ciclo.
			var golpe: float = exp(-_fase * 9.0) * (_rng.randf() * 2.0 - 1.0) * (0.25 + 0.5 * _carga_suave)
			# "Retumbe" grave a media frecuencia.
			_ruido_lp += ((_rng.randf() * 2.0 - 1.0) - _ruido_lp) * 0.05
			var vol: float = 0.18 + 0.22 * _carga_suave + 0.12 * clampf(_rpm_suave / 6000.0, 0.0, 1.0)
			muestra += (onda * 0.5 + golpe + _ruido_lp * 0.6) * vol
		if _chirr_suave > 0.02:
			# Ruido filtrado alrededor de 1 kHz que tiembla: el chirrido de la goma.
			var x: float = _rng.randf() * 2.0 - 1.0
			var fc: float = 0.28 + 0.04 * sin(float(i) * 0.002)
			_f1 += fc * (x - _f1 - 0.6 * _f2)
			_f2 += fc * _f1
			muestra += _f2 * 0.55 * _chirr_suave
		if claxon:
			_fase_c1 = fmod(_fase_c1 + 415.0 / TASA, 1.0)
			_fase_c2 = fmod(_fase_c2 + 523.0 / TASA, 1.0)
			muestra += (signf(sin(_fase_c1 * TAU)) + signf(sin(_fase_c2 * TAU))) * 0.09
		muestra = clampf(muestra, -1.0, 1.0)
		buffer[i] = Vector2(muestra, muestra)
	_gen.push_buffer(buffer)
