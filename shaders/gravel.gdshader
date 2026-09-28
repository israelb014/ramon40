shader_type spatial;
// Gravel / dirt road shoulder. UV.x = lateral offset (m), UV.y = distance (m).

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 gravel_color : source_color = vec3(0.62, 0.56, 0.48);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = vnoise(world_pos.xz * 14.0) * 0.5 + vnoise(world_pos.xz * 43.0) * 0.5;
	float patches = fbm(world_pos.xz * 0.15);
	vec3 col = gravel_color * (0.78 + g * 0.3) * mix(0.9, 1.08, patches);
	// Slight darkening right next to the asphalt (dust and oil).
	float inner = abs(UV.x);
	col *= mix(0.85, 1.0, smoothstep(0.0, 1.2, inner - 5.5));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
