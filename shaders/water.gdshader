shader_type spatial;
// Dead Sea water: dense turquoise with milky shallows, slow swells and sparkles.

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.05, 0.42, 0.50);
uniform vec3 shallow_color : source_color = vec3(0.45, 0.82, 0.78);
uniform float wave_scale = 0.04;
uniform float shore_fade = 60.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float t = TIME * 0.05;
	float n1 = fbm(p + vec2(t, t * 0.6));
	float n2 = fbm(p * 2.7 - vec2(t * 1.3, t * 0.4));
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.35 + (n2 - 0.5) * 0.25, 1.0, (n2 - 0.5) * 0.35 - (n1 - 0.5) * 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	float far = clamp(length(world_pos.xz) / 6000.0, 0.0, 1.0);
	float milky = smoothstep(0.35, 0.8, fbm(world_pos.xz * 0.0025));
	vec3 col = mix(shallow_color, deep_color, 0.55 + far * 0.4);
	col = mix(col, shallow_color * 1.05, milky * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
