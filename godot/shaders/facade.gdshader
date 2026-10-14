// GTB : facades et toits proceduraux pour les volumes de batiments (aucune texture).
// Murs : etages de 3 m ; fenetres vitrees avec grille OU persiennes en bois peintes ; rez-de-chaussee avec
//        fenetres, portes et rideaux metalliques de boutique ; bandeaux de dalle ; peinture ecaillee ;
//        environ 1 batiment sur 5 en parpaings bruts non enduits ; salissure et humidite en bas.
// Murs d'enceinte (plain_wall) : enduit ou parpaings, portails metalliques peints tous les ~20 m.
// Toits : toles ondulees (rouillees ou non) ou dalle beton avec taches.
// Nuit : fenetres eclairees au hasard (variables globales gtb_night et gtb_power).
// Tout est calcule en coordonnees monde : aucune UV necessaire (volumes generes depuis OSM / Overture).
shader_type spatial;
render_mode diffuse_burley;

global uniform float gtb_night;   // 0 = jour, 1 = nuit noire
global uniform float gtb_power;   // 1 = courant, 0 = coupure (delestage)
global uniform float gtb_wet;     // pluie : murs et toits mouilles

// couleurs ecrites en sRGB (comme dans un logiciel de dessin), converties en lineaire a la fin
uniform vec3 wall_color = vec3(0.85, 0.82, 0.76);
uniform float floor_height = 3.0;
uniform float window_spacing = 3.4;
uniform float roof_tin_ratio : hint_range(0.0, 1.0) = 0.55;  // part des toits plats rendus en tole (auto)
uniform int roof_force = 0;       // 0 auto, 1 tole, 2 beton
uniform bool plain_wall = false;  // mur d'enceinte / pignon : pas de fenetres ni portes
uniform int style = 0;            // 0 habitat, 1 mur-rideau vitre (terminal), 2 bardage tole (hangar)

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

vec3 paint_pick(float h) {
	// couleurs de peinture courantes (portails, volets, portes)
	if (h < 0.2) return vec3(0.12, 0.28, 0.55);
	if (h < 0.4) return vec3(0.15, 0.42, 0.25);
	if (h < 0.55) return vec3(0.55, 0.12, 0.1);
	if (h < 0.75) return vec3(0.1, 0.1, 0.1);
	if (h < 0.9) return vec3(0.42, 0.28, 0.16);
	return vec3(0.6, 0.6, 0.62);
}

vec3 cement_blocks(vec2 p) {
	// parpaings 40 x 20 cm, joints de mortier, blocs legerement differents
	vec2 b = vec2(p.x / 0.4, p.y / 0.2);
	b.x += 0.5 * mod(floor(b.y), 2.0);
	vec2 f = fract(b);
	float mortar = step(f.x, 0.05) + step(f.y, 0.08);
	vec3 block = vec3(0.56, 0.55, 0.52) * (0.88 + 0.2 * hash(floor(b)));
	return mix(block, vec3(0.66, 0.64, 0.6), clamp(mortar, 0.0, 1.0));
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
	vec3 emit = vec3(0.0);
	float rough = 0.85;
	float metal = 0.0;
	float night_light = gtb_night * gtb_power;

	if (n.y > 0.7) {
		// ---------------- TOIT ----------------
		bool tin_roof = roof_force == 1 || (roof_force == 0 && bid < roof_tin_ratio);
		if (tin_roof) {
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
		albedo = roof_force == 1 ? vec3(0.4, 0.38, 0.36) : wall_color * 0.5;
	} else {
		// ---------------- MUR ----------------
		vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
		float u = dot(wpos, t);
		float y = wpos.y;
		float fl = floor(y / floor_height);
		float fy = fract(y / floor_height);
		float wx = fract(u / window_spacing + bid * 7.0);
		float col_id = floor(u / window_spacing + bid * 7.0);
		float wall_h = hash(cell + 11.7);
		bool raw = plain_wall ? wall_h < 0.5 : wall_h < 0.2;

		// teinte du batiment legerement variee + peinture qui fane
		vec3 base = wall_color * (0.88 + 0.24 * hash(cell + 3.1));
		base = mix(base, base * vec3(1.05, 1.0, 0.92), fbm(vec2(u, y) * 0.15));
		float peel = smoothstep(0.62, 0.72, fbm(vec2(u, y) * 0.8 + bid * 20.0));
		base = mix(base, cement_blocks(vec2(u, y)), peel * 0.8);
		if (raw) {
			base = cement_blocks(vec2(u, y));
		}
		// bandeau de dalle a chaque etage
		if (!plain_wall) {
			float slab = smoothstep(0.0, 0.02, fy) * (1.0 - smoothstep(0.06, 0.08, fy));
			base = mix(base, vec3(0.6, 0.58, 0.55), slab * (raw ? 1.0 : 0.3));
		}
		albedo = base;

		if (style == 1) {
			// terminal : mur-rideau vitre, meneaux tous les 1,5 m, traverses a chaque niveau, socle beton
			float mx = fract(u / 1.5);
			float my = fract(y / 3.75);
			float frame = step(mx, 0.04) + step(my, 0.035);
			vec3 view = normalize(CAMERA_POSITION_WORLD - wpos);
			float fres = pow(1.0 - abs(dot(n, view)), 2.5);
			vec3 glass = mix(vec3(0.12, 0.2, 0.26), vec3(0.55, 0.68, 0.8), fres) * (0.9 + 0.1 * hash(floor(vec2(u / 1.5, y / 3.75))));
			albedo = mix(glass, vec3(0.78, 0.8, 0.82), clamp(frame, 0.0, 1.0));
			rough = mix(0.08, 0.4, clamp(frame, 0.0, 1.0));
			metal = 0.2;
			if (y < 0.5) {
				albedo = vec3(0.6, 0.58, 0.55);
				rough = 0.9;
			}
			emit = vec3(1.0, 0.92, 0.8) * night_light * 1.2 * (1.0 - clamp(frame, 0.0, 1.0)) * step(0.5, y);
		} else if (style == 2) {
			// hangar : bardage en tole ondulee verticale, grande porte coulissante, rouille en bas
			float ribs = 0.5 + 0.5 * sin(u * 22.0);
			albedo = vec3(0.72, 0.74, 0.76) * (0.85 + 0.15 * ribs);
			float door = step(fract(u / 60.0 + bid), 0.35) * step(y, 9.0);
			albedo = mix(albedo, vec3(0.5, 0.55, 0.6) * (0.85 + 0.15 * ribs), door);
			albedo = mix(albedo, vec3(0.45, 0.25, 0.12), (1.0 - smoothstep(0.0, 1.5, y)) * smoothstep(0.4, 0.7, fbm(vec2(u, y) * 1.5)));
			metal = 0.5;
			rough = 0.5;
		} else if (plain_wall) {
			// portail metallique peint (3 m) environ tous les 21 m
			float gu = u / 21.0 + bid * 3.0;
			float gx = fract(gu);
			if (gx < 0.14 && y < 2.05) {
				vec3 gate = paint_pick(hash(vec2(floor(gu), 4.2)));
				float ribs = 0.5 + 0.5 * sin(u * 26.0);
				albedo = gate * (0.8 + 0.25 * ribs);
				albedo = mix(albedo, vec3(0.42, 0.22, 0.1), smoothstep(0.55, 0.8, fbm(vec2(u, y) * 2.0)) * 0.6);
				metal = 0.4;
				rough = 0.55;
				if (gx < 0.006 || gx > 0.134) {
					albedo *= 0.4;  // montants
				}
			}
		} else {
			bool ground_floor = fl < 0.5;
			float bay = hash(vec2(col_id, bid * 13.0 + fl * 3.0));
			bool has_door = ground_floor && bay < 0.25;
			bool has_shop = ground_floor && bay > 0.82;
			if (has_door || has_shop) {
				float door = step(has_shop ? 0.1 : 0.32, wx) * step(wx, has_shop ? 0.9 : 0.68) * step(fy, has_shop ? 0.78 : 0.72);
				if (door > 0.5) {
					if (has_shop) {
						float slats = 0.5 + 0.5 * sin(y * 40.0);
						albedo = mix(vec3(0.45, 0.47, 0.5), vec3(0.3, 0.32, 0.34), slats) * (0.8 + 0.4 * hash(vec2(col_id, 5.0)));
						metal = 0.5;
						rough = 0.5;
					} else {
						albedo = paint_pick(hash(vec2(col_id, 9.0)));
						albedo *= 0.85 + 0.15 * step(0.5, fract(y * 3.0));
					}
				}
			} else {
				// fenetre : cadre ; vitre + grille de securite, ou persiennes en bois
				float in_x = step(0.3, wx) * step(wx, 0.7);
				float in_y = step(0.32, fy) * step(fy, 0.76);
				float frame_x = step(0.27, wx) * step(wx, 0.73);
				float frame_y = step(0.29, fy) * step(fy, 0.79);
				if (frame_x * frame_y > 0.5) {
					albedo = raw ? vec3(0.55, 0.54, 0.5) : vec3(0.85, 0.85, 0.82);
				}
				if (in_x * in_y > 0.5) {
					float win = hash(vec2(col_id, fl * 7.0 + bid * 17.0));
					if (win < 0.35) {
						// persiennes (lames horizontales)
						vec3 sh = paint_pick(hash(vec2(col_id + 3.0, bid * 5.0)));
						albedo = sh * (0.7 + 0.3 * step(0.4, fract(y * 18.0)));
						rough = 0.8;
					} else {
						float grid = step(0.85, fract(u * 4.0)) + step(0.85, fract(y * 4.0));
						vec3 glass = vec3(0.07, 0.09, 0.11) + vec3(0.25, 0.3, 0.35) * pow(1.0 - abs(dot(n, normalize(CAMERA_POSITION_WORLD - wpos))), 3.0);
						albedo = mix(glass, vec3(0.2, 0.2, 0.2), clamp(grid, 0.0, 1.0) * 0.8);
						rough = 0.15;
						// la nuit, une fenetre sur trois est allumee (ampoule chaude ou neon froid)
						float lit = step(0.62, hash(vec2(col_id * 1.7, fl + bid * 31.0)));
						vec3 lamp = mix(vec3(1.0, 0.72, 0.4), vec3(0.85, 0.95, 1.0), step(0.5, hash(vec2(col_id, fl + 2.0))));
						emit = lamp * lit * night_light * 2.2 * (1.0 - clamp(grid, 0.0, 1.0) * 0.7);
					}
				}
			}
		}
		// salissure et remontee d'humidite en bas du mur
		float dirt = 1.0 - smoothstep(0.0, 0.9 + 0.4 * noise(vec2(u * 0.7, 3.0)), y);
		albedo = mix(albedo, albedo * vec3(0.55, 0.42, 0.32), dirt * 0.8);
		// coulures
		float streak = smoothstep(0.6, 1.0, noise(vec2(u * 3.0, y * 0.25))) * (1.0 - fy) * 0.25;
		albedo *= 1.0 - streak;
	}
	if (gtb_wet > 0.001) {
		// murs assombris par l'eau (plus en haut, ruissellement), toits luisants
		float run = n.y > 0.7 ? 1.0 : (0.55 + 0.45 * noise(vec2(dot(wpos.xz, vec2(0.7, 0.7)) * 2.0, wpos.y * 0.3)));
		albedo *= mix(1.0, 0.68, gtb_wet * run);
		rough = mix(rough, 0.25, gtb_wet * (n.y > 0.7 ? 1.0 : 0.4));
	}
	ALBEDO = pow(clamp(albedo, 0.0, 1.0), vec3(2.2));
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	METALLIC = metal;
}
