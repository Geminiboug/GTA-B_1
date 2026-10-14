// GTB : ocean du golfe de Guinee. Houle qui avance vers la cote, reflets du ciel (fresnel),
// ecume aux cretes et le long du rivage (detectee avec la profondeur), couleur turquoise pres du bord.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.04, 0.2, 0.3);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.45, 0.48);
uniform vec3 foam_color : source_color = vec3(0.95, 0.96, 0.95);
uniform float wave_height = 0.35;
uniform float wave_speed = 1.2;
uniform vec2 swell_dir = vec2(0.0, -1.0);  // vers le nord : la houle arrive sur la plage
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;
varying float crest;

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

// somme de vagues (houle + clapot) ; renvoie hauteur, accumule la pente pour la normale
float waves(vec2 p, float t, out vec2 grad) {
	grad = vec2(0.0);
	float h = 0.0;
	vec2 dirs[4] = {normalize(swell_dir), normalize(swell_dir + vec2(0.3, 0.0)), normalize(vec2(0.7, -0.6)), normalize(vec2(-0.5, -0.8))};
	float lens[4] = {28.0, 17.0, 7.0, 4.3};
	float amps[4] = {1.0, 0.5, 0.18, 0.1};
	for (int i = 0; i < 4; i++) {
		float k = TAU / lens[i];
		float c = sqrt(9.8 / k) * wave_speed * 0.15;
		float ph = k * (dot(dirs[i], p) - c * t);
		h += amps[i] * sin(ph);
		grad += amps[i] * k * cos(ph) * dirs[i];
	}
	return h;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g;
	float h = waves(wpos.xz, TIME, g);
	VERTEX.y += h * wave_height * 0.5;
	crest = h;
}

void fragment() {
	vec2 g;
	float h = waves(wpos.xz, TIME, g);
	// detail fin anime pour le scintillement
	vec2 d = vec2(noise(wpos.xz * 1.5 + TIME * 0.6), noise(wpos.xz * 1.5 - TIME * 0.5)) - 0.5;
	vec3 n = normalize(vec3(-g.x * wave_height * 0.5 + d.x * 0.15, 1.0, -g.y * wave_height * 0.5 + d.y * 0.15));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	// profondeur d'eau sous ce pixel (pour l'ecume du rivage et la couleur)
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * ndc;
	world.xyz /= world.w;
	float water_depth = clamp(wpos.y - world.y, 0.0, 10.0);

	vec3 col = mix(shallow_color, deep_color, smoothstep(0.2, 3.0, water_depth));
	float shore_foam = 1.0 - smoothstep(0.0, 0.6 + 0.3 * sin(TIME * 1.3 + wpos.x * 0.1), water_depth);
	float crest_foam = smoothstep(1.1, 1.5, h) * (0.6 + 0.4 * noise(wpos.xz * 3.0 + TIME));
	float foam = clamp(shore_foam * (0.7 + 0.3 * noise(wpos.xz * 4.0 - TIME)) + crest_foam, 0.0, 1.0);
	col = mix(col, foam_color, foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.05, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(0.85, 1.0, smoothstep(0.0, 1.5, water_depth) * 0.5 + foam);
}
