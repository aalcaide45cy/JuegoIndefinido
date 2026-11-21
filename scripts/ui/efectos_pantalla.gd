# efectos_pantalla.gd
# -----------------------------------------------------------------------------
# Efectos que se ven en toda la pantalla mientras estás bajo los efectos de una
# poción: mundo ondulado (mareo, náuseas), bordes oscuros (somnolencia,
# paranoia) y un tinte de color (euforia, veneno, visión nocturna).
# Solo se dibuja si hay algún efecto con parte visual; si no, está oculto y no
# cuesta nada. Va detrás del resto de la interfaz (solo toca el mundo 3D).
# Los valores salen de "visual" en scripts/datos/efectos.gd.
# -----------------------------------------------------------------------------
class_name EfectosPantalla
extends ColorRect

const CODIGO: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float ondas = 0.0;
uniform float vineta = 0.0;
uniform vec4 tinte : source_color = vec4(0.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 14.0 + TIME * 2.2) * 0.006 * ondas;
	uv.y += cos(uv.x * 11.0 + TIME * 1.7) * 0.006 * ondas;
	vec3 c = texture(pantalla, uv).rgb;
	c = mix(c, tinte.rgb, tinte.a);
	float d = length(SCREEN_UV - vec2(0.5)) * 1.4;
	c *= 1.0 - smoothstep(0.35, 0.85, d) * vineta * 0.85;
	COLOR = vec4(c, 1.0);
}
"""

var _material: ShaderMaterial
var _ondas: float = 0.0
var _vineta: float = 0.0
var _tinte: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sombreado: Shader = Shader.new()
	sombreado.code = CODIGO
	_material = ShaderMaterial.new()
	_material.shader = sombreado
	material = _material
	color = Color.WHITE
	visible = false


func _process(delta: float) -> void:
	var paso: float = minf(1.0, delta * 2.5)   # Entra y sale suave.
	var objetivo_tinte: Color = Juego.tinte()
	_ondas = lerpf(_ondas, Juego.visual("ondas"), paso)
	_vineta = lerpf(_vineta, Juego.visual("vineta"), paso)
	_tinte = _tinte.lerp(objetivo_tinte if objetivo_tinte.a > 0.0 else Color(_tinte.r, _tinte.g, _tinte.b, 0.0), paso)
	var activo: bool = _ondas > 0.005 or _vineta > 0.005 or _tinte.a > 0.002
	if activo != visible:
		visible = activo
	if not activo:
		return
	_material.set_shader_parameter("ondas", _ondas)
	_material.set_shader_parameter("vineta", _vineta)
	_material.set_shader_parameter("tinte", _tinte)
