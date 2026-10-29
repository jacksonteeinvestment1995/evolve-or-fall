extends Node2D
## The trees, swaying in the wind. Each tree is drawn in 4-pixel strips: the crown leans a pixel or two while the
## trunk stays put (the idea from the HD-2D preview). Only trees near the camera are drawn.

const TILE := 32
const Biomes := preload("res://biomes.gd")
const STRIP := 4

var cells := {}      # Vector2i -> true (also holds pond tiles, which are skipped)
var water := {}
var skip := {}       # town tiles: solid, but not trees
var cam: Camera2D
var biome := {}      # tile -> biome id: the trees of a biome are tinted (frosty, dry, sickly, autumn)
var _t := 0.0

## Recolours only the leaves of a tree for its biome (snow-laden, dry, sickly, dead, autumn ember), keeping the
## trunk. The biome id rides in the modulate alpha (1.0 - id * 0.01), the per-tree variation in its red channel.
const LEAF_SHADER := """
shader_type canvas_item;
varying vec4 vcol;
void vertex() {
	vcol = COLOR;
}
vec3 ramp(vec3 lo, vec3 mid, vec3 hi, float t) {
	return t < 0.5 ? mix(lo, mid, t * 2.0) : mix(mid, hi, t * 2.0 - 1.0);
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	int id = int(floor((1.0 - vcol.a) * 100.0 + 0.5));
	vec3 c = t.rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float k = clamp((l - 0.3) / 0.33, 0.0, 1.0);
	bool leaf = c.g > c.r + 0.02 && c.g >= c.b - 0.02;
	float v = vcol.r;
	if (leaf && id == 1) {
		c = ramp(vec3(0.14, 0.3, 0.3), vec3(0.78, 0.88, 0.96), vec3(0.97, 0.99, 1.0), k);
	} else if (leaf && id == 2) {
		c = ramp(vec3(0.3, 0.3, 0.12), vec3(0.55, 0.54, 0.22), vec3(0.8, 0.74, 0.38), k);
	} else if (leaf && id == 3) {
		c = ramp(vec3(0.08, 0.16, 0.11), vec3(0.18, 0.29, 0.16), vec3(0.34, 0.44, 0.2), k);
	} else if (leaf && id == 4) {
		c = ramp(vec3(0.16, 0.14, 0.2), vec3(0.3, 0.27, 0.34), vec3(0.47, 0.44, 0.52), k);
	} else if (leaf && id == 5) {
		vec3 hi = mix(vec3(1.0, 0.5, 0.16), vec3(1.0, 0.8, 0.28), v);
		c = ramp(vec3(0.4, 0.08, 0.05), mix(vec3(0.82, 0.26, 0.08), vec3(0.85, 0.48, 0.1), v), hi, k);
	} else if (id == 1 || id == 4) {
		c = c * vec3(0.88, 0.9, 1.0);
	}
	COLOR = vec4(c, t.a);
}
"""


func _ready() -> void:
	var sh := Shader.new()
	sh.code = LEAF_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var textures := [Sprites.tex("tree_1"), Sprites.tex("tree_2")]
	if textures[0] == null:
		return
	var rect := Rect2(-1e9, -1e9, 2e9, 2e9)
	if cam != null:
		var c := cam.get_screen_center_position()
		var half := get_viewport_rect().size / cam.zoom * 0.5 + Vector2(TILE, TILE * 2)
		rect = Rect2(c - half, half * 2.0)
	var x0 := floori(rect.position.x / TILE)
	var x1 := ceili(rect.end.x / TILE)
	var y0 := floori(rect.position.y / TILE)
	var y1 := ceili(rect.end.y / TILE) + 2
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c2 := Vector2i(x, y)
			if not cells.has(c2) or water.has(c2) or skip.has(c2):
				continue
			var tex: Texture2D = textures[(x + y) % 2]
			var bid := int(biome.get(c2, 0))
			var tint := Color(float((x * 7 + y * 3) % 5) / 4.0, 1.0, 1.0, 1.0 - float(bid) * 0.01)
			var h := tex.get_height()
			var top := float((y + 1) * TILE - h)
			var phase := float((x * 7 + y * 13) % 17)
			var r := 0
			while r < h:
				var k := 1.0 - minf(1.0, float(r) / (h * 0.62))     # 1 at the crown, 0 at the trunk
				var dx := roundf(sin(_t * 1.3 + phase + float(r) * 0.05) * 1.6 * k)
				var n := mini(STRIP, h - r)
				draw_texture_rect_region(tex, Rect2(x * TILE + dx, top + r, TILE, n), Rect2(0, r, tex.get_width(), n), tint)
				r += n
