extends Node2D
## The ground of the whole map, painted per world pixel by one small shader instead of thousands of tiles:
##   meadow   the grass art, with slow light and dry/lush patches, tiny flowers and no visible tile grid
##   biomes   snow, sand, swamp, graveyard and autumn ground, each with its own fine detail (sparkle, ripples,
##            puddles, cracks, leaf litter), meeting the meadow along a noisy, dithered edge with a little bank
##   fringes  worn soil around mud and paths and damp grass around ponds, so those layers sink into the ground
## The map itself goes to the GPU once as a tiny texture (one texel per tile). Nothing is redrawn while the camera
## moves: the GPU only shades the pixels on screen, which is cheaper than the old per-tile drawing on phones.

const TILE := 32
const Biomes := preload("res://biomes.gd")

var cam: Camera2D
var biome := {}      ## tile -> biome id (see biomes.gd); meadow tiles are absent
var cols := 1
var rows := 1
var _mat: ShaderMaterial
var _map_tex: ImageTexture
var _sig := -1
var _check := 0.0

const SHADER := """
shader_type canvas_item;

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D grass0 : filter_nearest, repeat_enable;
uniform sampler2D grass1 : filter_nearest, repeat_enable;
uniform sampler2D grass2 : filter_nearest, repeat_enable;
uniform vec2 map_size = vec2(180.0, 100.0);

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec4 cell(vec2 w) {
	ivec2 t = clamp(ivec2(floor(w / 32.0)), ivec2(0), ivec2(map_size) - 1);
	return texelFetch(map_tex, t, 0);
}

int bio_at(vec2 w) {
	return int(cell(w).r * 255.0 + 0.5);
}

vec3 grass(vec2 wp) {
	vec2 t = floor(wp / 32.0);
	float h = hash12(t * 1.73 + 3.1);
	vec2 uv = fract(wp / 32.0);
	if (hash12(t + 9.7) > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec3 g;
	if (h < 0.62) {
		g = texture(grass0, uv).rgb;
	} else if (h < 0.82) {
		g = texture(grass1, uv).rgb;
	} else {
		g = texture(grass2, uv).rgb;
	}
	return g;
}

// the meadow: grass art under slow light, with dry and lush patches and a few tiny flowers
vec3 meadow(vec2 wp, vec3 g) {
	float big = vnoise(wp / 96.0);
	float mid = vnoise(wp / 29.0 + 7.0);
	vec3 c = g * mix(0.86, 1.1, big * 0.65 + mid * 0.35);
	float dry = smoothstep(0.6, 0.82, vnoise(wp / 150.0 + 3.0));
	c = mix(c, c * vec3(1.22, 1.1, 0.68), dry * 0.4);
	float lush = smoothstep(0.62, 0.86, vnoise(wp / 66.0 + 11.0));
	c = mix(c, c * vec3(0.78, 0.9, 0.86), lush * 0.6);
	vec2 fc = floor(wp / 3.0);
	float fh = hash12(fc * 0.71 + 2.3);
	if (fh > 0.9965 && floor(mod(wp, 3.0)) == vec2(1.0)) {
		float k = hash12(fc + 5.5);
		c = k < 0.4 ? vec3(0.98, 0.95, 0.85) : (k < 0.7 ? vec3(1.0, 0.86, 0.32) : vec3(0.95, 0.6, 0.78));
	}
	return c;
}

vec3 ground(int b, vec2 wp, vec3 g) {
	float n1 = vnoise(wp / 23.0);
	float n2 = vnoise(wp / 61.0 + 13.0);
	float px = hash12(wp);
	if (b == 1) {
		// snow: soft drifts with blue shade, and sparkles that twinkle
		vec3 c = mix(vec3(0.76, 0.85, 0.99), vec3(0.92, 0.96, 1.0), n1 * 0.6 + n2 * 0.4);
		float drift = smoothstep(0.58, 0.7, vnoise(wp / vec2(44.0, 14.0) + 4.0));
		c = mix(c, vec3(0.7, 0.79, 0.97), drift * 0.35);
		float lip = smoothstep(0.58, 0.7, vnoise((wp + vec2(0.0, 2.0)) / vec2(44.0, 14.0) + 4.0));
		if (lip > drift + 0.2) {
			c = mix(c, vec3(1.0), 0.6);
		}
		if (px > 0.992) {
			c = mix(c, vec3(0.7, 0.77, 0.9), 0.6);
		}
		float tw = sin(TIME * 2.6 + hash12(wp + 1.3) * 40.0);
		if (px > 0.9965 && tw > 0.55) {
			c = vec3(1.0);
		}
		return c;
	}
	if (b == 2) {
		// sand: warm dunes with wind ripples and a few pebbles
		vec3 c = mix(vec3(0.82, 0.68, 0.45), vec3(0.9, 0.78, 0.55), n1 * 0.5 + n2 * 0.5);
		float r = sin(wp.y * 0.42 + wp.x * 0.07 + vnoise(wp / 34.0) * 9.0);
		float rm = smoothstep(0.35, 0.6, vnoise(wp / 80.0 + 2.0));
		if (r > 0.86) {
			c = mix(c, vec3(0.95, 0.85, 0.63), rm * 0.8);
		} else if (r < -0.9) {
			c = mix(c, vec3(0.72, 0.57, 0.36), rm * 0.7);
		}
		if (px > 0.995) {
			c = vec3(0.6, 0.48, 0.34);
		} else if (px > 0.985) {
			c = mix(c, vec3(0.97, 0.9, 0.72), 0.5);
		}
		return c;
	}
	if (b == 3) {
		// swamp: dark peat and moss, with still puddles that catch the sky
		vec3 c = mix(vec3(0.17, 0.25, 0.14), vec3(0.27, 0.36, 0.17), n1 * 0.6 + n2 * 0.4);
		float moss = smoothstep(0.62, 0.8, vnoise(wp / 11.0 + 21.0));
		c = mix(c, vec3(0.34, 0.43, 0.18), moss * 0.4);
		vec2 pq = wp / vec2(24.0, 15.0) + 40.0;
		float pv = vnoise(pq) * 0.75 + vnoise(wp / 70.0 + 3.0) * 0.25;
		if (pv > 0.72) {
			// a still puddle: dark water, the sky glinting along slow ripples, a muddy lip on the top edge
			c = mix(vec3(0.07, 0.13, 0.12), vec3(0.12, 0.2, 0.18), vnoise(wp / 6.0));
			float sh = vnoise(vec2(wp.x / 9.0 + TIME * 0.5, wp.y / 2.0));
			if (sh > 0.8) {
				c = vec3(0.3, 0.42, 0.38);
			}
			float above = vnoise((wp + vec2(0.0, -2.0)) / vec2(24.0, 15.0) + 40.0) * 0.75 + vnoise((wp + vec2(0.0, -2.0)) / 70.0 + 3.0) * 0.25;
			if (above <= 0.72) {
				c = vec3(0.09, 0.12, 0.08);
			}
		} else if (pv > 0.695) {
			c = mix(c, vec3(0.24, 0.3, 0.14), 0.7);
		} else if (px > 0.99) {
			c = vec3(0.46, 0.56, 0.24);
		} else if (px < 0.006) {
			c = vec3(0.12, 0.16, 0.1);
		}
		return c;
	}
	if (b == 4) {
		// graveyard: cold dead earth, patches of withered grass, cracks and grave pebbles
		vec3 c = mix(vec3(0.27, 0.26, 0.34), vec3(0.35, 0.33, 0.42), n1 * 0.6 + n2 * 0.4);
		float dead = smoothstep(0.58, 0.74, vnoise(wp / 19.0 + 9.0));
		float blade = hash12(floor(wp / vec2(1.0, 3.0)) + 4.0);
		vec3 dg = mix(vec3(0.31, 0.3, 0.33), vec3(0.42, 0.4, 0.38), blade);
		c = mix(c, dg, dead * 0.55);
		float cr = abs(vnoise(wp / 22.0 + 30.0) - 0.5);
		if (cr < 0.009 && vnoise(wp / 45.0 + 6.0) > 0.66 && vnoise(wp / 11.0 + 2.0) > 0.45) {
			c = vec3(0.17, 0.16, 0.22);
		}
		if (px > 0.995) {
			c = vec3(0.55, 0.54, 0.62);
		} else if (px < 0.008) {
			c = c * 0.78;
		}
		return c;
	}
	if (b == 5) {
		// autumn: the grass art painted through an ember gradient, with fallen leaves
		float l = dot(g, vec3(0.3, 0.59, 0.11));
		float k = smoothstep(0.22, 0.62, l + (n1 - 0.5) * 0.15);
		vec3 c = mix(vec3(0.34, 0.12, 0.07), vec3(0.84, 0.4, 0.12), k);
		c = mix(c, vec3(0.5, 0.42, 0.16) * (0.6 + l), smoothstep(0.62, 0.85, n2) * 0.55);
		vec2 lc = floor(wp / 2.0);
		float lh = hash12(lc * 0.37 + 8.0);
		if (lh > 0.94) {
			float q = hash12(lc + 2.0);
			c = q < 0.4 ? vec3(0.78, 0.2, 0.08) : (q < 0.75 ? vec3(0.95, 0.55, 0.12) : vec3(0.98, 0.78, 0.26));
			if (mod(wp.y, 2.0) > 1.0) {
				c *= 0.78;
			}
		}
		return c;
	}
	return meadow(wp, g);
}

// the bank under a biome's lower edge: a little thickness, as if the patch sat on the meadow
vec3 bank(int b, vec3 c) {
	if (b == 1) return mix(c, vec3(0.62, 0.7, 0.86), 0.7);
	if (b == 2) return c * vec3(0.8, 0.74, 0.66);
	if (b == 3) return c * 0.7;
	if (b == 4) return c * 0.72;
	return c;
}

void fragment() {
	vec2 wp = floor(world) + 0.5;
	vec3 g = grass(wp);
	vec2 warp = (vec2(vnoise(wp / 41.0), vnoise(wp / 41.0 + 19.0)) - 0.5) * 30.0
		+ (vec2(vnoise(wp / 8.0 + 3.0), vnoise(wp / 8.0 + 8.0)) - 0.5) * 7.0;
	int b = bio_at(wp + warp);
	vec3 c = ground(b, wp, g);
	// a dithered band where two grounds meet
	vec2 jit = (vec2(hash12(wp + 0.7), hash12(wp + 3.7)) - 0.5) * 8.0;
	int b2 = bio_at(wp + warp + jit);
	if (b2 != b) {
		c = mix(c, ground(b2, wp, g), 0.5);
	}
	// the lower edge of a patch shows a thin bank
	if (b != 0 && b != 5 && bio_at(wp + warp + vec2(0.0, 3.0)) != b) {
		c = bank(b, c);
	}
	// soil worn around mud and paths, damp grass around ponds
	vec2 fw = (vec2(vnoise(wp / 9.0 + 50.0), vnoise(wp / 9.0 + 60.0)) - 0.5) * 22.0 + jit * 0.5;
	float f = cell(wp + fw).g * 255.0;
	float fo = cell(wp).g * 255.0;
	float d = hash12(wp + 11.0);
	if (fo > 0.5) {
		// the ground that shows through the cut-away edge of a pond or a stone path
		f = fo;
	}
	if (f > 0.5) {
		if (f < 1.5) {
			c = mix(c, vec3(0.3, 0.22, 0.13), 0.45 + 0.35 * d);
		} else if (f < 2.5) {
			c = mix(c, vec3(0.45, 0.42, 0.42), 0.25 + 0.35 * d);
		} else if (f < 3.5) {
			c = c * 0.84 + vec3(-0.02, 0.0, 0.025);
		} else if (f < 4.5) {
			c = mix(c, vec3(0.5, 0.49, 0.52), 0.25 + 0.3 * d);
		} else {
			c = mix(c, vec3(0.62, 0.48, 0.31), 0.3 + 0.4 * d);
		}
	}
	COLOR = vec4(c, 1.0);
}
"""


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var main := get_parent()
	if main == null or main.get("biome") == null:
		return
	var sig := _signature(main)
	if sig != _sig:
		_sig = sig
		_build(main)


## Sizes of everything the ground shows, so the map texture is rebuilt only when one of them changes.
func _signature(main) -> int:
	var s: int = main.biome.size()
	for key in ["mud", "paths", "water", "floors", "dirt"]:
		var d = main.get(key)
		s = s * 31 + (d.size() if d is Dictionary else 0)
	return s


## One texel per tile: R = biome id, G = 1 mud, 2 stone path, 3 pond, 4 paved floor, 5 dirt road.
func _build(main) -> void:
	var grass := [Sprites.tex("grass_1"), Sprites.tex("grass_2"), Sprites.tex("grass_3")]
	if grass[0] == null:
		return
	biome = main.biome
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var flags := [["mud", 1], ["paths", 2], ["water", 3], ["floors", 4], ["dirt", 5]]
	for t in biome:
		if t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows:
			img.set_pixel(t.x, t.y, Color8(int(biome[t]), 0, 0, 255))
	for fl in flags:
		var d = main.get(fl[0])
		if not (d is Dictionary):
			continue
		for t in d:
			if t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows:
				var c := img.get_pixel(t.x, t.y)
				img.set_pixel(t.x, t.y, Color8(int(round(c.r * 255.0)), int(fl[1]), 0, 255))
	if _map_tex == null:
		_map_tex = ImageTexture.create_from_image(img)
	else:
		_map_tex.update(img)
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat
	_mat.set_shader_parameter("map_tex", _map_tex)
	_mat.set_shader_parameter("grass0", grass[0])
	_mat.set_shader_parameter("grass1", grass[1] if grass[1] != null else grass[0])
	_mat.set_shader_parameter("grass2", grass[2] if grass[2] != null else grass[0])
	_mat.set_shader_parameter("map_size", Vector2(cols, rows))
	queue_redraw()


func _draw() -> void:
	if _mat == null:
		return
	draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color.WHITE)
