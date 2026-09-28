shader_type spatial;
// Stylized low-poly terrain. Color comes from world height (rock strata), slope (cliff
// rock), a sand/soil base and the vertex color (R = road proximity for dusty verges,
// G = salt crust mask). The palette is set per track.

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.78, 0.55, 0.36);
uniform vec3 base_color2 : source_color = vec3(0.70, 0.45, 0.30);
uniform vec3 rock_color : source_color = vec3(0.55, 0.30, 0.24);
uniform vec3 strata_a : source_color = vec3(0.72, 0.30, 0.24);
uniform vec3 strata_b : source_color = vec3(0.48, 0.26, 0.40);
uniform vec3 strata_c : source_color = vec3(0.86, 0.66, 0.44);
uniform vec3 verge_color : source_color = vec3(0.70, 0.62, 0.52);
uniform vec3 salt_color : source_color = vec3(0.95, 0.94, 0.90);
uniform vec3 vegetation_color : source_color = vec3(0.30, 0.34, 0.16);
uniform float strata_scale = 0.16;
uniform float strata_strength = 1.0;
uniform float vegetation_amount = 0.0;
uniform float flat_shading = 0.55;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Faceted normal for the low-poly look, blended with the smooth one.
	vec3 facet = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
	if (dot(facet, world_nrm) < 0.0) facet = -facet;
	vec3 n = normalize(mix(world_nrm, facet, flat_shading));
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);

	float big = fbm(world_pos.xz * 0.004);
	float mid = fbm(world_pos.xz * 0.03);
	float fine = vnoise(world_pos.xz * 0.9);

	vec3 soil = mix(base_color, base_color2, smoothstep(0.35, 0.7, big));
	soil *= 0.92 + fine * 0.14;

	// Horizontal rock strata, warped slightly so bands follow the escarpment.
	float h = world_pos.y + (mid - 0.5) * 6.0;
	float band = fract(h * strata_scale);
	float band2 = fract(h * strata_scale * 0.37 + 0.3);
	vec3 strata = mix(strata_a, strata_b, smoothstep(0.3, 0.5, band) * (1.0 - smoothstep(0.75, 0.95, band)));
	strata = mix(strata, strata_c, smoothstep(0.6, 0.85, band2) * 0.8);
	strata = mix(rock_color, strata, strata_strength);
	strata *= 0.85 + fine * 0.2;

	float rock_mask = smoothstep(0.28, 0.52, slope + (mid - 0.5) * 0.25);
	vec3 col = mix(soil, strata, rock_mask);

	// Vegetation tint on gentle slopes.
	float veg = vegetation_amount * smoothstep(0.45, 0.7, mid + (1.0 - slope) * 0.3) * (1.0 - rock_mask);
	col = mix(col, vegetation_color * (0.8 + fine * 0.3), veg);

	// Salt crust and dusty verges from vertex color.
	col = mix(col, salt_color * (0.93 + fine * 0.1), clamp(COLOR.g, 0.0, 1.0));
	col = mix(col, verge_color * (0.9 + fine * 0.2), clamp(COLOR.r, 0.0, 1.0) * (1.0 - rock_mask * 0.7));

	ALBEDO = col;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.95 - COLOR.g * 0.25;
	SPECULAR = 0.2;
}
