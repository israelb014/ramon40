shader_type canvas_item;
// Full-screen post effect: speed-based radial motion blur, heat haze, subtle chromatic
// aberration at speed and a vignette. Reads the rendered screen texture.

#include "res://shaders/include/noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float haze_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform vec2 focus = vec2(0.5, 0.45);
uniform vec2 sun_pos = vec2(-10.0);
uniform float flare_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flare_color : source_color = vec3(1.0, 0.7, 0.45);

void fragment() {
	vec2 uv = SCREEN_UV;
	// Heat haze: shimmering distortion concentrated around the horizon band and road.
	if (haze_amount > 0.0) {
		float band = smoothstep(0.25, 0.5, uv.y) * (1.0 - smoothstep(0.62, 0.95, uv.y));
		vec2 n = vec2(vnoise(uv * vec2(18.0, 40.0) + vec2(0.0, TIME * 1.7)), vnoise(uv * vec2(22.0, 35.0) - vec2(TIME * 1.3, 0.0))) - 0.5;
		uv += n * 0.0035 * haze_amount * band;
	}
	vec3 col;
	if (blur_amount > 0.001) {
		vec2 dir = uv - focus;
		float edge = smoothstep(0.08, 0.6, length(dir));
		float strength = blur_amount * 0.045 * edge;
		col = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 10; i++) {
			float k = float(i) / 9.0;
			float w = 1.0 - k * 0.6;
			col += texture(screen_tex, uv - dir * strength * k).rgb * w;
			total += w;
		}
		col /= total;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (aberration > 0.001) {
		vec2 dir = (uv - 0.5) * aberration * 0.006;
		col.r = mix(col.r, texture(screen_tex, uv + dir).r, 0.8);
		col.b = mix(col.b, texture(screen_tex, uv - dir).b, 0.8);
	}
	// Lens flare from the sun: soft halo, streak and a few ghosts mirrored through center.
	if (flare_amount > 0.001) {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 p = SCREEN_UV - sun_pos;
		p.x *= aspect;
		float d = length(p);
		vec3 f = flare_color * (exp(-d * 7.0) * 0.35 + exp(-abs(p.y) * 90.0) * exp(-abs(p.x) * 3.0) * 0.12);
		vec2 axis = vec2(0.5) - sun_pos;
		for (int i = 1; i <= 3; i++) {
			vec2 gp = sun_pos + axis * (0.55 * float(i));
			vec2 q = SCREEN_UV - gp;
			q.x *= aspect;
			float r = 0.025 + 0.02 * float(i);
			float ring = smoothstep(r, r * 0.6, length(q)) * 0.08;
			f += mix(flare_color, vec3(0.5, 0.7, 1.0), float(i) / 3.0) * ring;
		}
		col += f * flare_amount;
	}
	float v = smoothstep(0.95, 0.3, length((SCREEN_UV - 0.5) * vec2(1.0, 0.9)));
	col *= mix(1.0, v, vignette);
	COLOR = vec4(col, 1.0);
}
