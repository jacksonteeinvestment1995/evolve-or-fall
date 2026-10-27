shader_type canvas_item;
// HD-2D finish: tilt-shift blur toward the top and bottom of the screen, a soft vignette and a
// gentle warm/cool grade. Drawn over the world, under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 4.0) = 2.2;
uniform float focus_band : hint_range(0.0, 0.5) = 0.22;   // half-height of the sharp strip
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
uniform float saturation : hint_range(0.5, 1.6) = 1.12;
uniform vec3 warm : source_color = vec3(1.04, 1.0, 0.94);
uniform vec3 cool : source_color = vec3(0.94, 0.98, 1.06);

void fragment() {
	vec2 uv = SCREEN_UV;
	float off = abs(uv.y - 0.5);
	float k = smoothstep(focus_band, 0.5, off) * blur_amount;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (k > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE * k;
		vec3 acc = col;
		float w = 1.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 d = vec2(cos(a), sin(a)) * px * 2.0;
			acc += textureLod(screen_tex, uv + d, 0.0).rgb * 0.8;
			acc += textureLod(screen_tex, uv + d * 2.0, 0.0).rgb * 0.45;
			w += 1.25;
		}
		col = acc / w;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col *= mix(cool, warm, smoothstep(0.15, 0.85, lum));
	float v = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.25, 1.0)));
	col *= 1.0 - v * vignette;
	COLOR = vec4(col, 1.0);
}
