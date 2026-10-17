shader_type spatial;
// Vitre de voiture etoilee apres un choc (scripts/voiture.gd) : verre teinte, reseau de fissures blanches autour du
// point d'impact (cellules de Voronoi + rayons), un peu plus opaque la ou le verre est casse.

uniform vec3 impact = vec3(0.0);       // point d'impact, repere du modele
uniform float force = 1.0;             // 0..1 : etendue des fissures
uniform vec4 teinte : source_color = vec4(0.08, 0.1, 0.12, 0.45);

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	vec3 d = p_obj - impact;
	float r = length(d);
	float zone = clamp(1.0 - r / (0.25 + 0.9 * force), 0.0, 1.0);
	// fissures : cellules plus fines pres de l'impact, rayons qui partent du centre
	vec2 uv = p_obj.xy * 9.0 + p_obj.zz * 7.0;
	float cell = smoothstep(0.06, 0.0, voronoi_edge(uv * (1.0 + zone * 2.0)));
	float ang = atan(d.y + d.z, d.x);
	float rays = smoothstep(0.92, 1.0, abs(sin(ang * 7.0 + hash2(vec2(floor(ang * 1.1))).x * 3.0)));
	float crack = clamp(cell * zone + rays * zone * 0.8, 0.0, 1.0);
	ALBEDO = mix(teinte.rgb, vec3(0.85), crack);
	ALPHA = clamp(teinte.a + crack * 0.5 + zone * 0.15, 0.0, 0.95);
	ROUGHNESS = mix(0.05, 0.6, crack);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
