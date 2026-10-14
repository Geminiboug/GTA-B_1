// GTB : sols proceduraux en coordonnees monde (terre rouge, sable, bitume, beton).
// mode 0 = terre rouge de Cotonou (laterite) : plaques plus sombres, zones sableuses, petits cailloux, traces.
// mode 1 = sable de plage : rides de vent, sable plus fonce et humide (marques), debris.
// mode 2 = bitume : grain, reparations, usure plus claire au centre, nids de poule.
// mode 3 = beton / paves : joints et taches.
shader_type spatial;

uniform int mode = 0;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 wpos;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	// le detail fin s'estompe au loin (evite le scintillement)
	float fine = 1.0 - smoothstep(30.0, 120.0, dist);
	vec3 col;
	float rough = 0.95;

	if (mode == 0) {
		float large = fbm(p * 0.03);
		float mid = fbm(p * 0.25);
		float grain = noise(p * 6.0) * fine;
		vec3 laterite = vec3(0.50, 0.21, 0.10);
		vec3 dark = vec3(0.33, 0.15, 0.08);
		vec3 sandy = vec3(0.62, 0.43, 0.26);
		col = mix(laterite, dark, smoothstep(0.4, 0.7, large));
		col = mix(col, sandy, smoothstep(0.55, 0.8, mid) * 0.7);
		// herbe seche par endroits
		col = mix(col, vec3(0.42, 0.42, 0.2), smoothstep(0.68, 0.85, fbm(p * 0.12 + 40.0)) * 0.6);
		// cailloux
		col *= 0.9 + 0.2 * grain;
		col = mix(col, col * vec3(0.7, 0.68, 0.66), step(0.9, noise(p * 3.0)) * fine * 0.6);
	} else if (mode == 1) {
		float dunes = fbm(p * 0.05);
		float ripples = 0.5 + 0.5 * sin(p.x * 3.0 + p.y * 1.2 + noise(p * 0.8) * 6.0);
		vec3 sand = vec3(0.80, 0.63, 0.38);
		col = sand * (0.9 + 0.1 * dunes);
		col *= 0.94 + 0.06 * ripples * fine;
		// traces de pas / sable remue plus sombre
		col = mix(col, sand * 0.82, smoothstep(0.6, 0.8, fbm(p * 0.4 + 9.0)) * 0.5);
		// debris (coquillages, plastique)
		col = mix(col, vec3(0.85, 0.82, 0.76), step(0.97, noise(p * 5.0)) * fine * 0.4);
		rough = 1.0;
	} else if (mode == 2) {
		float g = noise(p * 8.0) * fine;
		float patches = fbm(p * 0.08);
		col = vec3(0.16, 0.16, 0.17) * (0.85 + 0.3 * g);
		// rapiecages plus fonces et usure plus claire
		col = mix(col, vec3(0.1, 0.1, 0.11), smoothstep(0.6, 0.65, patches) * 0.8);
		col = mix(col, vec3(0.3, 0.29, 0.28), smoothstep(0.35, 0.2, patches) * 0.5);
		// poussiere rouge apportee par les roues
		col = mix(col, vec3(0.45, 0.28, 0.2), smoothstep(0.55, 0.85, fbm(p * 0.05 + 3.0)) * 0.35);
		rough = 0.8;
	} else {
		vec2 tile = fract(p / vec2(0.3, 0.2));
		float joint = step(0.92, tile.x) + step(0.9, tile.y);
		col = vec3(0.6, 0.55, 0.5) * (0.85 + 0.15 * hash(floor(p / vec2(0.3, 0.2))));
		col = mix(col, col * 0.6, clamp(joint, 0.0, 1.0) * fine);
		col = mix(col, col * 0.7, smoothstep(0.6, 0.8, fbm(p * 0.3)) * 0.5);
	}
	ALBEDO = col * tint;
	SPECULAR = 0.15;  // sols mats : pas de reflet bleu du ciel
	ROUGHNESS = rough;
}
