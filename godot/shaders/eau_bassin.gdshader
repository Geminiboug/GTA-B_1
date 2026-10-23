// GTB : eau calme des piscines et des bassins de retention : transparence selon la profondeur, reflets du ciel (fresnel),
// petites rides animees, motifs de lumiere (caustiques) sur le fond et ecume le long des bords.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_never;

uniform vec3 couleur_peu_profonde : source_color = vec3(0.25, 0.72, 0.78);
uniform vec3 couleur_profonde : source_color = vec3(0.04, 0.3, 0.42);
uniform float trouble : hint_range(0.0, 1.0) = 0.0;          // 0 : piscine claire ; 1 : bassin vaseux
uniform vec3 couleur_trouble : source_color = vec3(0.2, 0.28, 0.2);
uniform float vitesse_rides = 0.6;
uniform float force_rides = 0.35;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 wpos;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// reseau de lignes lumineuses (caustiques) : minimum de deux bruits deformes
float caustiques(vec2 p, float t) {
	float a = bruit(p * 2.2 + vec2(t * 0.35, t * 0.2));
	float b = bruit(p * 2.2 * 1.7 - vec2(t * 0.28, -t * 0.31) + a * 1.5);
	float c = abs(a - b);
	return smoothstep(0.1, 0.0, c) * 0.9;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * vitesse_rides;
	vec2 d = vec2(bruit(wpos.xz * 2.5 + t) , bruit(wpos.xz * 2.5 - t * 0.8 + 7.3)) - 0.5;
	vec2 d2 = vec2(bruit(wpos.xz * 6.0 - t * 1.4), bruit(wpos.xz * 6.0 + t * 1.2 + 3.1)) - 0.5;
	vec3 n = normalize(vec3(d.x * force_rides + d2.x * 0.12, 1.0, d.y * force_rides + d2.y * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// profondeur apparente : le plan d eau est pose au ras du sol (pas de cuvette), on la simule par un bruit lent
	float k = clamp(0.35 + 0.45 * bruit(wpos.xz * 0.18), 0.0, 1.0);
	vec3 base = mix(couleur_peu_profonde, couleur_profonde, k);
	base = mix(base, couleur_trouble, trouble * (0.4 + 0.6 * k));
	// fond vu a travers l'eau, teinte, avec des motifs de lumiere pour les eaux claires
	vec2 decalage = n.xz * 0.04;
	vec3 fond = textureLod(screen_tex, SCREEN_UV + decalage, 0.0).rgb;
	float lueur = caustiques(wpos.xz, TIME) * (1.0 - trouble) * (1.0 - k * 0.6);
	vec3 col = mix(fond, base, 0.35 + 0.5 * k + 0.2 * trouble) + vec3(lueur * 0.18);
	// reflets du ciel : fresnel
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = col * 0.55;
	EMISSION = col * 0.3 + vec3(0.5, 0.65, 0.8) * f * 0.35;
	ROUGHNESS = mix(0.06, 0.2, trouble);
	SPECULAR = 0.9;
	METALLIC = 0.0;
	ALPHA = clamp(0.55 + 0.35 * k + f * 0.3, 0.0, 0.97);
}
