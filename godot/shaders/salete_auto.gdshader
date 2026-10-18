shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Couche d'usure posee par-dessus la peinture des voitures (next_pass du materiau de carrosserie, scripts/voiture.gd) :
// poussiere de laterite rouge en bas de caisse et derriere les roues (plus epaisse vers le sol), coulures sous les
// vitres, points de rouille sur les vieilles voitures. Chaque voiture a ses propres quantites.

uniform float poussiere = 0.5;          // 0..1
uniform float rouille = 0.0;            // 0..1
uniform float haut_caisse = 1.0;        // m : hauteur de la ceinture (la poussiere monte jusqu'a mi-hauteur)
uniform vec3 couleur_poussiere : source_color = vec3(0.6, 0.53, 0.43);   // poussiere de sable gris-beige (sols de Cotonou)
uniform vec3 couleur_rouille : source_color = vec3(0.35, 0.16, 0.07);

varying vec3 p_obj;
varying vec3 n_obj;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
	VERTEX += NORMAL * 0.0015;     // juste au-dessus de la peinture
}

void fragment() {
	float n = noise(p_obj * 2.5) * 0.7 + noise(p_obj * 14.0) * 0.3;
	// poussiere : du bas de caisse jusqu'a mi-hauteur, plus forte vers le sol, en trainees irregulieres
	float bas = 1.0 - smoothstep(0.15, haut_caisse * 0.62, p_obj.y + (n - 0.5) * 0.25);
	float dessus = smoothstep(0.8, 0.98, n_obj.y) * 0.18;          // poussiere deposee sur le capot et le toit
	float d = clamp((bas * bas + dessus) * poussiere * (0.75 + 0.3 * n), 0.0, 0.7);
	// rouille : taches aux bords bas et autour des passages de roue
	float r = smoothstep(0.78 - rouille * 0.25, 0.86 - rouille * 0.2, noise(p_obj * 11.0 + 3.7)) * rouille;
	r *= 1.0 - smoothstep(0.3, haut_caisse, p_obj.y) * 0.6;
	vec3 c = mix(couleur_poussiere * (0.85 + 0.3 * n), couleur_rouille * (0.7 + 0.5 * n), clamp(r * 1.5, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(max(d, r * 0.95), 0.0, 0.95);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
