shader_type spatial;
// GTB : cheveux des personnages (noirs ou poivre et sel). Relie a la variable globale gtb_wet (scripts/weather.gd) :
// sous la pluie, les cheveux s'assombrissent et deviennent plus brillants (moins rugueux, reflet speculaire).

global uniform float gtb_wet;

uniform vec3 base_col = vec3(0.05, 0.04, 0.04);
uniform float white_share : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_local;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 col = pow(base_col, vec3(2.2));
	if (white_share > 0.001) {
		float n = noise(v_local * 55.0) * 0.65 + noise(v_local * 120.0) * 0.35;
		float m = smoothstep(1.0 - white_share - 0.15, 1.0 - white_share + 0.15, n);
		col = mix(col, pow(vec3(0.76, 0.75, 0.72), vec3(2.2)), m);
	}
	float wet = clamp(gtb_wet, 0.0, 1.0);
	ALBEDO = col * mix(1.0, 0.55, wet);
	ROUGHNESS = mix(0.88, 0.28, wet);
	SPECULAR = mix(0.25, 0.6, wet);
}

