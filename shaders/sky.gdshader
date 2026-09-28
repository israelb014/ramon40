shader_type sky;
// Stylized dynamic sky driven by the scene's DirectionalLight3D (the sun or the moon).
// Rayleigh-like gradient that warms toward the horizon as the sun gets low, a Mie halo,
// sun/moon disk, drifting clouds, stars and an optional city glow on the horizon.

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 zenith_day : source_color = vec3(0.16, 0.36, 0.72);
uniform vec3 horizon_day : source_color = vec3(0.62, 0.74, 0.86);
uniform vec3 zenith_sunset : source_color = vec3(0.14, 0.12, 0.34);
uniform vec3 horizon_sunset : source_color = vec3(1.0, 0.52, 0.26);
uniform vec3 zenith_night : source_color = vec3(0.01, 0.015, 0.04);
uniform vec3 horizon_night : source_color = vec3(0.05, 0.07, 0.13);
uniform vec3 ground_color : source_color = vec3(0.25, 0.18, 0.15);
uniform float night = 0.0;
uniform float sun_size = 0.9995;
uniform float halo_strength = 1.0;
uniform float cloud_amount = 0.35;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.92, 0.85);
uniform float star_amount = 0.0;
uniform vec3 city_glow_color : source_color = vec3(1.0, 0.55, 0.25);
uniform vec3 city_glow_dir = vec3(1.0, 0.0, 0.0);
uniform float city_glow = 0.0;
uniform float exposure = 1.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float sun_h = sun.y;
	// 0 = sun at zenith .. 1 = sun on the horizon
	float low = 1.0 - smoothstep(0.02, 0.55, sun_h);
	vec3 zenith = mix(zenith_day, zenith_sunset, low);
	vec3 horizon = mix(horizon_day, horizon_sunset, low);
	zenith = mix(zenith, zenith_night, night);
	horizon = mix(horizon, horizon_night, night);

	float up = clamp(d.y, 0.0, 1.0);
	float grad = pow(1.0 - up, 3.2);
	vec3 col = mix(zenith, horizon, grad);

	// Warm scattering concentrated toward the sun azimuth when it is low.
	vec2 sd = normalize(sun.xz + vec2(1e-4));
	vec2 dd = normalize(d.xz + vec2(1e-4));
	float az = dot(sd, dd) * 0.5 + 0.5;
	col += horizon_sunset * low * (1.0 - night) * pow(az, 3.0) * pow(1.0 - up, 6.0) * 0.6;

	float cosang = dot(d, sun);
	float mie = pow(max(cosang, 0.0), 12.0) * 0.35 + pow(max(cosang, 0.0), 240.0) * 1.2;
	col += LIGHT0_COLOR * mie * halo_strength * (1.0 - night * 0.7) * mix(0.5, 1.2, low);

	// Clouds on a flat plane above the camera.
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.12) * 1.6 + vec2(TIME * 0.004, TIME * 0.0015);
		float c = fbm(uv * 1.3);
		c = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.35, c) * smoothstep(0.0, 0.18, d.y);
		vec3 lit = mix(cloud_color, LIGHT0_COLOR * 1.1, low * 0.6) * mix(1.0, 0.18, night);
		lit += horizon_sunset * low * pow(az, 2.0) * 0.5;
		col = mix(col, lit, c * 0.85);
	}

	// Stars.
	if (star_amount > 0.0 && d.y > 0.0) {
		vec2 suv = d.xz / (d.y + 0.35) * 220.0;
		vec2 cell = floor(suv);
		float h = hash12(cell);
		vec2 pos = fract(suv) - vec2(hash12(cell + 3.1), hash12(cell + 7.7));
		float star = step(0.985, h) * smoothstep(0.08, 0.0, length(pos - 0.5 + 0.5));
		float tw = 0.6 + 0.4 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
		col += vec3(0.9, 0.95, 1.0) * star * tw * star_amount * smoothstep(0.0, 0.3, d.y);
	}

	// City light pollution on the horizon.
	if (city_glow > 0.0) {
		float g = max(dot(normalize(vec2(city_glow_dir.x, city_glow_dir.z)), dd), 0.0);
		col += city_glow_color * city_glow * pow(g, 2.5) * pow(1.0 - up, 10.0);
	}

	// Sun / moon disk.
	float disk = smoothstep(sun_size, sun_size + 0.00025, cosang);
	col += LIGHT0_COLOR * disk * mix(22.0, 2.5, night);

	// Below the horizon fade to ground color.
	if (d.y < 0.0) {
		col = mix(horizon * 0.8, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
	}
	COLOR = col * exposure;
}
