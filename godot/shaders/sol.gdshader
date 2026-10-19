// GTB : sols proceduraux en coordonnees monde (sable des quartiers, sable de plage, bitume, beton).
// mode 0 = sol des quartiers de Cotonou : sable gris-beige du cordon littoral (photos de Fidjrosse et d'Avotrou,
//          refs/rues/), plaques tassees plus sombres, rares remblais de laterite ocre, petits cailloux, traces.
// mode 1 = sable de plage : rides de vent, sable plus fonce et humide (marques), debris.
// mode 2 = bitume : grain, reparations, usure plus claire au centre, nids de poule.
// mode 3 = beton / paves : joints et taches.
// mode 4 = paves autobloquants, 5 = piste en sable, 6 = dalles du tarmac, 7 = peinture au sol (marquage, piste
// cyclable : couleur = tint), 8 = herbe, 9 = eau calme (bassin, piscine : couleur = tint).
// Les couches sont presque a plat (quelques mm, voir osm_import.py) : le vertex shader avance tres legerement
// vers la camera les couches les plus hautes (meme position a l'ecran) pour qu'elles ne scintillent jamais.
shader_type spatial;

global uniform float gtb_wet;  // 0 sec, 1 detrempe (scripts/weather.gd)
uniform int mode = 0;
// couleurs ecrites en sRGB, converties en lineaire a la fin
uniform vec3 tint = vec3(1.0);
uniform float depth_pull = 0.05;
uniform bool bordure_peinte = false;  // terre-plein : bordures peintes rouge et blanc (biseaux), herbe dessus
// Texture de matiere (refs/generees, blender/tools/textures_planches.py), posee par realism.gd pour les modes 0 a 5 :
// elle donne le grain et la matiere ; les grandes variations procedurales (plaques, laterite, poussiere) restent.
// tex_remplace : la texture remplace la couleur (paves : son propre calepinage) au lieu de la moduler.
uniform sampler2D tex_sol : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool avec_texture = false;
uniform bool tex_remplace = false;
uniform vec3 tex_moyenne = vec3(0.5);   // couleur moyenne de la texture (sRGB), pour ne garder que son detail
uniform float tex_taille = 2.0;         // m couverts par la texture
uniform float tex_force = 0.85;
uniform float tex_loin = 160.0;         // m : au-dela, le sol redevient procedural (pas de motif repete visible)

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
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= 1.0 - clamp(wpos.y, 0.0, 0.04) * depth_pull;
	POSITION = PROJECTION_MATRIX * view;
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
		vec3 sable = vec3(0.70, 0.64, 0.55);
		vec3 tasse = vec3(0.56, 0.51, 0.45);
		vec3 clair = vec3(0.80, 0.74, 0.64);
		vec3 remblai = vec3(0.66, 0.47, 0.34);   // laterite apportee en remblai, par plaques rares
		col = mix(sable, tasse, smoothstep(0.45, 0.75, large));
		col = mix(col, clair, smoothstep(0.55, 0.8, mid) * 0.6);
		col = mix(col, remblai, smoothstep(0.78, 0.9, fbm(p * 0.015 + 21.0)) * 0.7);
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
		// estran (plage_estran, sous le niveau du haut de plage) : sable mouille plus sombre et luisant sous la ligne
		// du ressac, qui monte et descend ; liseré d'ecume a sa limite
		float swash = -0.22 + 0.06 * sin(TIME * 0.45 + p.x * 0.02) + 0.02 * noise(p * 0.3 + TIME * 0.1);
		float wetness = smoothstep(swash + 0.1, swash - 0.02, wpos.y);
		col = mix(col, col * vec3(0.6, 0.58, 0.55), wetness);
		rough = mix(rough, 0.22, wetness);
		float foam = smoothstep(0.007, 0.0, abs(wpos.y - swash)) * smoothstep(0.35, 0.7, noise(p * 1.2 + TIME * 0.3));
		col = mix(col, vec3(0.95, 0.95, 0.93), foam * 0.45);
	} else if (mode == 2) {
		float g = noise(p * 8.0) * fine;
		float patches = fbm(p * 0.08);
		col = vec3(0.34, 0.34, 0.35) * (0.85 + 0.3 * g);
		// rapiecages plus fonces et usure plus claire
		col = mix(col, vec3(0.24, 0.24, 0.25), smoothstep(0.6, 0.65, patches) * 0.8);
		col = mix(col, vec3(0.46, 0.45, 0.44), smoothstep(0.35, 0.2, patches) * 0.5);
		// poussiere de sable apportee par les roues
		col = mix(col, vec3(0.62, 0.57, 0.49), smoothstep(0.55, 0.85, fbm(p * 0.05 + 3.0)) * 0.35);
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
		vec3 paver = mix(vec3(0.55, 0.53, 0.5), vec3(0.6, 0.52, 0.44), step(0.6, pick)) * (0.85 + 0.2 * hash(floor(q) + 7.0));
		col = mix(paver, vec3(0.62, 0.5, 0.36), clamp(joint, 0.0, 1.0) * fine);
		// usure, taches d'huile, sable apporte par le vent
		col = mix(col, col * 0.6, smoothstep(0.65, 0.85, fbm(p * 0.25)) * 0.5);
		col = mix(col, vec3(0.7, 0.58, 0.42), smoothstep(0.55, 0.8, fbm(p * 0.07 + 5.0)) * 0.55);
		rough = 0.85;
	} else if (mode == 5) {
		// piste en sable tasse (rare remblai de laterite) : ornieres, flaques sechees, cailloux
		float large = fbm(p * 0.06);
		vec3 sand = vec3(0.67, 0.61, 0.52);
		col = mix(sand, vec3(0.55, 0.49, 0.42), smoothstep(0.35, 0.7, large));
		col = mix(col, vec3(0.62, 0.46, 0.34), smoothstep(0.8, 0.9, fbm(p * 0.02 + 13.0)) * 0.6);
		col *= 0.9 + 0.15 * noise(p * 4.0) * fine;
		// zones tassees plus sombres (passage des roues)
		col = mix(col, col * 0.78, smoothstep(0.55, 0.75, fbm(p * 0.35 + 2.0)) * 0.6);
		// flaques sechees craquelees
		float puddle = smoothstep(0.72, 0.78, fbm(p * 0.12 + 9.0));
		col = mix(col, vec3(0.44, 0.40, 0.35), puddle * 0.7);
		rough = 1.0;
	} else if (mode == 7) {
		// peinture routiere : usee par endroits (le bitume reapparait), salie de poussiere de sable
		col = tint * (0.92 + 0.08 * noise(p * 3.0));
		float wear = smoothstep(0.5, 0.8, fbm(p * 1.3 + 7.0));
		col = mix(col, vec3(0.36, 0.35, 0.35), wear * 0.55);
		col = mix(col, vec3(0.66, 0.6, 0.5), smoothstep(0.6, 0.9, fbm(p * 0.05 + 3.0)) * 0.25);
		rough = 0.7;
	} else if (mode == 8) {
		// herbe tropicale : touffes vertes, plaques jaunies, sable visible
		float large = fbm(p * 0.05);
		float tuft = noise(p * 2.5) * fine;
		col = mix(vec3(0.33, 0.45, 0.17), vec3(0.5, 0.52, 0.24), smoothstep(0.35, 0.7, large));
		col *= 0.85 + 0.25 * tuft;
		col = mix(col, vec3(0.66, 0.6, 0.5), smoothstep(0.66, 0.82, fbm(p * 0.18 + 5.0)) * 0.6);
		rough = 1.0;
		vec3 nw = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		if (bordure_peinte && nw.y < 0.97) {
			// bandes de 1 m le long de la bordure (direction prise de la normale du biseau), usees et poussiereuses
			vec2 t = normalize(vec2(-nw.z, nw.x) + vec2(1e-4));
			float bande = mod(floor(dot(p, t) / 1.0), 2.0);
			col = mix(vec3(0.68, 0.14, 0.11), vec3(0.88, 0.87, 0.84), bande) * (0.9 + 0.1 * noise(p * 4.0));
			col = mix(col, vec3(0.66, 0.6, 0.5), smoothstep(0.45, 0.85, fbm(p * 1.7 + 11.0)) * 0.45);
			rough = 0.85;
		}
	} else if (mode == 10) {
		// carrelage interieur 60 x 60 cm : joints clairs, legeres variations, brillant
		vec2 q = p / 0.6;
		vec2 f = fract(q);
		float joint = step(f.x, 0.012) + step(f.y, 0.012);
		col = tint * (0.95 + 0.06 * hash(floor(q)));
		col = mix(col, col * 0.78, smoothstep(0.55, 0.8, fbm(q * 2.3)) * 0.12);
		col = mix(col, vec3(0.7, 0.68, 0.64), clamp(joint, 0.0, 1.0));
		rough = 0.32;
	} else if (mode == 12) {
		// terrazzo poli (batiments publics) : eclats de marbre dans le ciment, joints laiton tous les 1,5 m
		float chip = step(0.82, noise(p * 22.0)) * 0.5 + step(0.9, noise(p * 41.0 + 3.0)) * 0.5;
		col = tint * (0.95 + 0.05 * noise(p * 3.0));
		col = mix(col, vec3(0.45, 0.43, 0.4), chip * 0.6);
		col = mix(col, vec3(0.95, 0.94, 0.9), step(0.93, noise(p * 30.0 + 7.0)) * 0.6);
		vec2 g = fract(p / 1.5);
		col = mix(col, vec3(0.62, 0.52, 0.3), clamp(step(g.x, 0.006) + step(g.y, 0.006), 0.0, 1.0));
		rough = 0.3;
	} else if (mode == 9) {
		// eau calme : sombre au fond, reflets du ciel par la specularite
		col = tint * (0.85 + 0.1 * fbm(p * 0.3 + TIME * 0.05));
		rough = 0.08;
	} else {
		vec2 tile = fract(p / vec2(0.3, 0.2));
		float joint = step(0.92, tile.x) + step(0.9, tile.y);
		col = vec3(0.6, 0.55, 0.5) * (0.85 + 0.15 * hash(floor(p / vec2(0.3, 0.2))));
		col = mix(col, col * 0.6, clamp(joint, 0.0, 1.0) * fine);
		col = mix(col, col * 0.7, smoothstep(0.6, 0.8, fbm(p * 0.3)) * 0.5);
	}
	if (avec_texture && mode <= 5) {
		vec2 uv = p / tex_taille;
		// deux lectures (la seconde tournee et a une autre echelle), melangees par un bruit lent : pas de repetition
		vec3 a = texture(tex_sol, uv).rgb;
		vec3 b = texture(tex_sol, vec2(-uv.y, uv.x) * 0.73 + vec2(0.31, 0.57)).rgb;
		vec3 tx = pow(mix(a, b, smoothstep(0.4, 0.6, fbm(p * 0.07 + 31.0))), vec3(1.0 / 2.2));
		float f = tex_force * (1.0 - smoothstep(tex_loin * 0.5, tex_loin, dist));
		if (tex_remplace) {
			col = mix(col, tx * (0.88 + 0.24 * fbm(p * 0.03 + 5.0)), f);
		} else {
			col = mix(col, col * tx / max(tex_moyenne, vec3(0.05)), f);
		}
	}
	float spec = mode == 9 ? 0.5 : (mode >= 10 ? 0.45 : 0.15);  // sols exterieurs mats ; carrelage et terrazzo brillants
	// --- pluie : sol plus sombre et plus brillant, flaques dans les creux (pas sur le sable de plage) ---
	if (gtb_wet > 0.001 && mode != 1 && mode != 9 && mode < 10) {
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
