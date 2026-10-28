shader_type canvas_item;
// The light version of the HD-2D finish for phones and the web: no screen copy, no blur, no bloom (those read the
// whole screen back every frame, which a phone cannot afford). It keeps the vignette, the daylight shafts and the
// night wash, drawn as an ordinary overlay.

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float shaft_power : hint_range(0.0, 1.0) = 1.0;

float shaft(vec2 uv, float x0, float scale) {
	float px = uv.x * 960.0;
	float lo = x0 + 150.0 * uv.y;
	float hi = x0 + 70.0 + 260.0 * uv.y;
	float a = smoothstep(lo - 14.0, lo + 18.0, px) * (1.0 - smoothstep(hi - 18.0, hi + 14.0, px));
	return a * scale * (1.0 - uv.y);
}

void fragment() {
	vec2 uv = UV;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		float x0 = 40.0 + float(i) * 250.0 + sin(TIME * 0.3 + float(i)) * 14.0;
		s += shaft(uv, x0, 0.11);
	}
	s *= shaft_power * (1.0 - night);
	float moon = 0.14 * clamp(1.0 - (uv.x + uv.y) * 0.5, 0.0, 1.0) * night;
	float d = length((uv - 0.5) * vec2(960.0, 540.0));
	float v = smoothstep(540.0 * 0.32, 960.0 * 0.62, d) * mix(0.5, 0.78, night);
	vec3 vcol = mix(vec3(0.07, 0.03, 0.13), vec3(0.02, 0.016, 0.086), night);
	vec3 light = vec3(1.0, 0.89, 0.63) * s + vec3(0.43, 0.51, 0.90) * moon;
	float la = clamp(s * 1.6 + moon * 2.0, 0.0, 0.5);
	// vignette dark at the edges, a soft warm or blue wash in the shafts
	vec3 rgb = (vcol * v + light * la * (1.0 - v)) / max(v + la * (1.0 - v), 0.001);
	COLOR = vec4(rgb, v + la * (1.0 - v));
}
