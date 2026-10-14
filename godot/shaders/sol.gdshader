// GTB : sols proceduraux en coordonnees monde (terre rouge, sable, bitume, beton).
// mode 0 = terre rouge de Cotonou (laterite) : plaques plus sombres, zones sableuses, petits cailloux, traces.
// mode 1 = sable de plage : rides de vent, sable plus fonce et humide (marques), debris.
// mode 2 = bitume : grain, reparations, usure plus claire au centre, nids de poule.
// mode 3 = beton / paves : joints et taches.
shader_type spatial;

global uniform float gtb_wet;  // 0 sec, 1 detrempe (scripts/weather.gd)
uniform int mode = 0;
// couleurs ecrites en sRGB, converties en lineaire a la fin
uniform vec3 tint = vec3(1.0);

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
		vec3 laterite = vec3(0.72, 0.42, 0.27);
		vec3 dark = vec3(0.58, 0.33, 0.22);
		vec3 sandy = vec3(0.78, 0.62, 0.45);
		col = mix(laterite, dark, smoothstep(0.4, 0.7, large));
		col = mix(col, sandy, smoothstep(0.55, 0.8, mid) * 0.7);
		// herbe seche par endroits
		col = mix(col, vec3(0.55, 0.52, 0.32), smoothstep(0.68, 0.85, fbm(p * 0.12 + 40.0)) * 0.6);
		// cailloux
		col *= 0.9 + 0.2 * grain;
		col = mix(col, col * vec3(0.7, 0.68, 0.66), step(0.9, noise(p * 3.0)) * fine * 0.6);
	} else if (mode == 1) {
		float dunes = fbm(p * 0.05);
		float ripples = 0.5 + 0.5 * sin(p.x * 3.0 + p.y * 1.2 + noise(p * 0.8) * 6.0);
		vec3 sand = vec3(0.86, 0.76, 0.58);
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
		col = vec3(0.34, 0.34, 0.35) * (0.85 + 0.3 * g);
		// rapiecages plus fonces et usure plus claire
		col = mix(col, vec3(0.24, 0.24, 0.25), smoothstep(0.6, 0.65, patches) * 0.8);
		col = mix(col, vec3(0.46, 0.45, 0.44), smoothstep(0.35, 0.2, patches) * 0.5);
		// poussiere rouge apportee par les roues
		col = mix(col, vec3(0.6, 0.42, 0.32), smoothstep(0.55, 0.85, fbm(p * 0.05 + 3.0)) * 0.35);
		rough = 0.8;
	} else if (mode == 6) {
		// dalles de beton du tarmac (5 x 5 m) : joints, taches d'huile et de kerosene, traces de pneus
		vec2 q = p / 5.0;
		vec2 f = fract(q);
		float joint = step(f.x, 0.006) + step(f.y, 0.006);
		col = vec3(0.68, 0.66, 0.62) * (0.9 + 0.12 * hash(floor(q)));
		col = mix(col, vec3(0.35, 0.34, 0.33), clamp(joint, 0.0, 1.0) * fine);
		col = mix(col, vec3(0.3, 0.29, 0.28), smoothstep(0.7, 0.85, fbm(p * 0.15)) * 0.6);
		col = mix(col, col * 0.8, smoothstep(0.5, 0.7, fbm(p * 0.03 + 4.0)) * 0.5);
		rough = 0.85;
	} else if (mode == 4) {
		// paves autobloquants (rues de quartier) : rangees decalees, gris et ocre, sable dans les joints
		vec2 q = p / vec2(0.22, 0.11);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 f = fract(q);
		float joint = step(f.x, 0.08) + step(f.y, 0.14);
		float pick = hash(floor(q));
		vec3 paver = mix(vec3(0.5, 0.48, 0.46), vec3(0.58, 0.38, 0.28), step(0.6, pick)) * (0.85 + 0.2 * hash(floor(q) + 7.0));
		col = mix(paver, vec3(0.62, 0.5, 0.36), clamp(joint, 0.0, 1.0) * fine);
		// usure, taches d'huile, sable apporte par le vent
		col = mix(col, col * 0.6, smoothstep(0.65, 0.85, fbm(p * 0.25)) * 0.5);
		col = mix(col, vec3(0.7, 0.58, 0.42), smoothstep(0.55, 0.8, fbm(p * 0.07 + 5.0)) * 0.55);
		rough = 0.85;
	} else if (mode == 5) {
		// piste en sable et laterite tassee : ornieres, flaques sechees, cailloux
		float large = fbm(p * 0.06);
		vec3 sand = vec3(0.66, 0.55, 0.43);
		col = mix(sand, vec3(0.6, 0.42, 0.3), smoothstep(0.35, 0.7, large));
		col *= 0.9 + 0.15 * noise(p * 4.0) * fine;
		// zones tassees plus sombres (passage des roues)
		col = mix(col, col * 0.78, smoothstep(0.55, 0.75, fbm(p * 0.35 + 2.0)) * 0.6);
		// flaques sechees craquelees
		float puddle = smoothstep(0.72, 0.78, fbm(p * 0.12 + 9.0));
		col = mix(col, vec3(0.45, 0.33, 0.24), puddle * 0.7);
		rough = 1.0;
	} else {
		vec2 tile = fract(p / vec2(0.3, 0.2));
		float joint = step(0.92, tile.x) + step(0.9, tile.y);
		col = vec3(0.6, 0.55, 0.5) * (0.85 + 0.15 * hash(floor(p / vec2(0.3, 0.2))));
		col = mix(col, col * 0.6, clamp(joint, 0.0, 1.0) * fine);
		col = mix(col, col * 0.7, smoothstep(0.6, 0.8, fbm(p * 0.3)) * 0.5);
	}
	float spec = 0.15;  // sols mats : pas de reflet bleu du ciel
	// --- pluie : sol plus sombre et plus brillant, flaques dans les creux (pas sur le sable de plage) ---
	if (gtb_wet > 0.001 && mode != 1) {
		col *= mix(1.0, 0.6, gtb_wet);
		rough = mix(rough, 0.35, gtb_wet * 0.8);
		spec = mix(spec, 0.5, gtb_wet);
		float puddle = smoothstep(0.6, 0.66, fbm(p * 0.09 + 17.0)) * smoothstep(0.3, 0.8, gtb_wet);
		col = mix(col, col * 0.45, puddle);
		rough = mix(rough, 0.02, puddle);
		spec = mix(spec, 0.9, puddle);
	} else if (gtb_wet > 0.001) {
		col *= mix(1.0, 0.8, gtb_wet);  // sable mouille plus fonce
	}
	ALBEDO = pow(clamp(col * tint, 0.0, 1.0), vec3(2.2));
	SPECULAR = spec;
	ROUGHNESS = rough;
}
