// GTB : facades et toits proceduraux pour les volumes de batiments (aucune texture).
// Murs : etages de 3 m, fenetres (vitre sombre + cadre + grille), rez-de-chaussee avec portes / rideaux metalliques,
//        bandeau de dalle a chaque etage, parapet en haut, salissure et remontees d'humidite en bas, variations de teinte.
// Toits : toles ondulees (rouillees ou non) ou dalle beton avec taches, selon le batiment.
// Tout est calcule en coordonnees monde : aucune UV necessaire (volumes generes depuis OSM / Overture).
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 wall_color : source_color = vec3(0.85, 0.82, 0.76);
uniform float floor_height = 3.0;
uniform float window_spacing = 3.4;
uniform float roof_tin_ratio : hint_range(0.0, 1.0) = 0.55;  // part des toits en tole
uniform bool plain_wall = false;  // mur d enceinte : enduit sans fenetres ni portes

varying vec3 wpos;
varying vec3 wnorm;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	// identifiant grossier du batiment : cellule de 9 m autour du point (varie d'un batiment a l'autre)
	vec2 cell = floor(wpos.xz / 9.0);
	float bid = hash(cell);
	vec3 albedo;
	float rough = 0.85;
	float metal = 0.0;

	if (n.y > 0.7) {
		// ---------------- TOIT ----------------
		if (bid < roof_tin_ratio) {
			// tole ondulee : stries + rouille par plaques
			vec3 tin = mix(vec3(0.62, 0.64, 0.66), vec3(0.50, 0.30, 0.18), smoothstep(0.35, 0.75, fbm(wpos.xz * 0.35 + bid * 50.0)));
			float ridges = 0.5 + 0.5 * sin(wpos.x * 9.0 + wpos.z * 2.0 * (bid - 0.5));
			albedo = tin * (0.85 + 0.15 * ridges);
			metal = 0.45 * (1.0 - smoothstep(0.4, 0.8, fbm(wpos.xz * 0.35)));
			rough = 0.55;
		} else {
			// dalle beton : taches d'eau, mousse sombre
			float stain = fbm(wpos.xz * 0.6 + 7.0);
			albedo = mix(vec3(0.62, 0.60, 0.56), vec3(0.38, 0.37, 0.35), smoothstep(0.45, 0.8, stain));
			rough = 0.95;
		}
	} else if (n.y < -0.5) {
		albedo = wall_color * 0.5;
	} else {
		// ---------------- MUR ----------------
		vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
		float u = dot(wpos, t);
		float y = wpos.y;
		float fl = floor(y / floor_height);
		float fy = fract(y / floor_height);
		float wx = fract(u / window_spacing + bid * 7.0);
		float col_id = floor(u / window_spacing + bid * 7.0);

		// teinte du batiment legerement variee + peinture qui fane avec la hauteur
		vec3 base = wall_color * (0.88 + 0.24 * hash(cell + 3.1));
		base = mix(base, base * vec3(1.05, 1.0, 0.92), fbm(vec2(u, y) * 0.15));
		// peinture ecaillee par plaques
		float peel = smoothstep(0.62, 0.72, fbm(vec2(u, y) * 0.8 + bid * 20.0));
		base = mix(base, vec3(0.62, 0.60, 0.56), peel * 0.7);
		// bandeau de dalle a chaque etage
		float slab = smoothstep(0.0, 0.02, fy) * (1.0 - smoothstep(0.06, 0.08, fy));
		base = mix(base, base * 0.82, slab);

		albedo = base;
		bool ground_floor = fl < 0.5;
		if (plain_wall) {
			ground_floor = false;
			wx = 0.0;
		}
		if (ground_floor) {
			// rez-de-chaussee : portes / rideaux metalliques de boutique, 1 travee sur 2 environ
			float shop = step(0.45, hash(vec2(col_id, bid * 13.0)));
			float door = step(0.2, wx) * step(wx, 0.8) * step(fy, 0.75);
			if (door > 0.5) {
				if (shop > 0.5) {
					// rideau metallique ondule
					float slats = 0.5 + 0.5 * sin(y * 40.0);
					albedo = mix(vec3(0.45, 0.47, 0.5), vec3(0.3, 0.32, 0.34), slats) * (0.8 + 0.4 * hash(vec2(col_id, 5.0)));
					metal = 0.5;
					rough = 0.5;
				} else {
					// porte en bois ou metal peint
					albedo = mix(vec3(0.32, 0.2, 0.12), vec3(0.2, 0.32, 0.45), step(0.5, hash(vec2(col_id, 9.0))));
				}
			}
		} else {
			// fenetre : cadre, vitre sombre, grille de securite (jamais sur un mur d enceinte)
			if (plain_wall) { fy = 0.0; }
			float in_x = step(0.28, wx) * step(wx, 0.72);
			float in_y = step(0.3, fy) * step(fy, 0.75);
			float frame_x = step(0.25, wx) * step(wx, 0.75);
			float frame_y = step(0.27, fy) * step(fy, 0.78);
			if (frame_x * frame_y > 0.5) {
				albedo = vec3(0.85, 0.85, 0.82);
			}
			if (in_x * in_y > 0.5) {
				float grid = step(0.85, fract(u * 4.0)) + step(0.85, fract(y * 4.0));
				vec3 glass = vec3(0.08, 0.1, 0.12) + vec3(0.25, 0.3, 0.35) * pow(1.0 - abs(dot(n, normalize(CAMERA_POSITION_WORLD - wpos))), 3.0);
				albedo = mix(glass, vec3(0.2, 0.2, 0.2), clamp(grid, 0.0, 1.0) * 0.8);
				rough = 0.15;
			}
		}
		// salissure et remontee d'humidite en bas du mur
		float dirt = 1.0 - smoothstep(0.0, 0.9 + 0.4 * noise(vec2(u * 0.7, 3.0)), y);
		albedo = mix(albedo, albedo * vec3(0.55, 0.42, 0.32), dirt * 0.8);
		// coulures sous les fenetres
		float streak = smoothstep(0.6, 1.0, noise(vec2(u * 3.0, y * 0.25))) * (1.0 - fy) * 0.25;
		albedo *= 1.0 - streak;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	METALLIC = metal;
}
