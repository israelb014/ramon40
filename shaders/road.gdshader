shader_type spatial;
// Asphalt road with Israeli-style markings: yellow edge lines and white dashed center line.
// UV.x = lateral offset in meters (0 at center), UV.y = distance along the lap in meters.

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 asphalt_color : source_color = vec3(0.29, 0.29, 0.31);
uniform vec3 asphalt_light : source_color = vec3(0.44, 0.43, 0.42);
uniform vec3 edge_color : source_color = vec3(0.98, 0.78, 0.10);
uniform vec3 center_color : source_color = vec3(0.95, 0.95, 0.92);
uniform float half_width = 5.5;
uniform float edge_inset = 0.55;
uniform float line_width = 0.15;
uniform float dash_length = 3.0;
uniform float dash_period = 12.0;
uniform float lap_length = 1000.0;
uniform float wetness = 0.0;
uniform float marking_emission = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float aa_band(float x, float a, float b) {
	float w = fwidth(x) * 0.75;
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

void fragment() {
	float lat = UV.x;
	float dist = UV.y;
	float ax = abs(lat);

	// Asphalt: coarse aggregate + patches + darker tire tracks in the lanes.
	float grain = vnoise(world_pos.xz * 9.0) * 0.55 + vnoise(world_pos.xz * 31.0) * 0.45;
	float patches = fbm(world_pos.xz * 0.08);
	float tracks = exp(-pow((ax - half_width * 0.45) / 0.55, 2.0)) * 0.6;
	vec3 col = mix(asphalt_color, asphalt_light, clamp(patches * 0.9 - 0.25 + grain * 0.25, 0.0, 1.0));
	col *= 1.0 - tracks * 0.18;

	// Markings.
	float edge = aa_band(ax, half_width - edge_inset - line_width, half_width - edge_inset);
	float dash_phase = mod(dist, dash_period);
	float dash_on = step(dash_phase, dash_length);
	float center = aa_band(ax, -1.0, line_width * 0.5) * dash_on;
	// Start / finish checker band.
	float sf = step(mod(dist + 0.0, lap_length), 1.6) + step(lap_length - 0.01, dist);
	float checker = mod(floor(lat / 0.8) + floor(dist / 0.8), 2.0);
	float wear = smoothstep(0.25, 0.75, vnoise(world_pos.xz * 2.3 + 11.0));
	float paint_mask = (edge + center) * mix(1.0, 0.72, wear);

	vec3 paint = edge > 0.01 ? edge_color : center_color;
	col = mix(col, paint, clamp(paint_mask, 0.0, 1.0));
	if (sf > 0.5) {
		col = mix(col, mix(vec3(0.05), vec3(0.95), checker), 0.92);
	}

	// Darken the very edge where asphalt meets gravel.
	col *= mix(0.78, 1.0, smoothstep(half_width, half_width - 0.25, ax));

	ALBEDO = col;
	float rough = mix(0.86, 0.55, paint_mask) - grain * 0.08;
	ROUGHNESS = mix(rough, 0.12, wetness);
	SPECULAR = 0.35;
	EMISSION = paint * paint_mask * marking_emission;
}
