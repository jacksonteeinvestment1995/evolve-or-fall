shader_type canvas_item;
// HD-2D finish, ported from art/preview.src.html: daylight shafts or a moon wash, bloom,
// tilt-shift blur bands at the top and bottom, and a vignette. Drawn over the world, under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float night : hint_range(0.0, 1.0) = 0.0;     // 0 = day, 1 = night
uniform float blur_amount : hint_range(0.0, 4.0) = 2.4;
uniform float shaft_power : hint_range(0.0, 1.0) = 1.0;

float shaft(vec2 uv, float x0, float scale) {
	// parallelogram from the reference: (x0,0)(x0+70,0)(x0+330,H)(x0+150,H) in a 960 x 540 frame
	float px = uv.x * 960.0;
	float lo = x0 + 150.0 * uv.y;
	float hi = x0 + 70.0 + 260.0 * uv.y;
	float a = smoothstep(lo - 14.0, lo + 18.0, px) * (1.0 - smoothstep(hi - 18.0, hi + 14.0, px));
	return a * scale * (1.0 - uv.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;

	// tilt-shift: two soft bands (the reference blurs 32% and 20% of the height at each edge)
	float off = abs(uv.y - 0.5);
	float k = smoothstep(0.18, 0.5, off) * blur_amount;
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

	// bloom: a blurred, brightened copy screen-blended on top
	vec3 bl = textureLod(screen_tex, uv, 2.6).rgb;
	bl = clamp((bl * mix(1.25, 1.5, night) - 0.5) * 1.25 + 0.5, 0.0, 1.0);
	float ba = mix(0.24, 0.42, night);
	col = 1.0 - (1.0 - col) * (1.0 - bl * ba);

	// light shafts by day, a blue moon wash at night (screen blend)
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		float x0 = 40.0 + float(i) * 250.0 + sin(TIME * 0.3 + float(i)) * 14.0;
		s += shaft(uv, x0, 0.11);
	}
	vec3 add = vec3(1.0, 0.89, 0.63) * s * shaft_power * (1.0 - night);
	float moon = 0.14 * clamp(1.0 - (uv.x + uv.y) * 0.5, 0.0, 1.0) * night;
	add += vec3(0.43, 0.51, 0.90) * moon;
	col = 1.0 - (1.0 - col) * (1.0 - add);

	// vignette (the reference: warm violet by day, deep blue at night)
	float d = length((uv - 0.5) * vec2(960.0, 540.0));
	float v = smoothstep(540.0 * 0.32, 960.0 * 0.62, d);
	vec3 vcol = mix(vec3(0.07, 0.03, 0.13), vec3(0.02, 0.016, 0.086), night);
	col = mix(col, vcol, v * mix(0.5, 0.78, night));

	COLOR = vec4(col, 1.0);
}
