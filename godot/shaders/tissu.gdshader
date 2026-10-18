// GTB : tissu uni (t-shirts, chemises, pantalons, jeans, uniformes) : couleur, plis, trame, reflet doux du tissu.
// Choisi par scripts/pnj_util.gd (plain, jean).
shader_type spatial;
render_mode cull_disabled;   // tissu vu des deux cotes (interieur des manches, aisselles)
#include "res://shaders/tissu.gdshaderinc"

uniform vec4 couleur : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int armure = 0;          // 0 toile de coton, 1 serge (jean), 2 maille
uniform float use = 0.0;         // 0 neuf .. 1 delave (jean use aux cuisses et aux genoux)

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 n = NORMAL;
	float k = tissu_relief(opos, armure, VERTEX, n);
	NORMAL = n;
	vec3 col = couleur.rgb * k;
	if (use > 0.0) {
		vec2 c = tissu_coord(opos);
		float u = tissu_bruit(c * vec2(6.0, 9.0)) * smoothstep(0.75, 0.35, abs(c.y - 0.55));
		col = mix(col, col * 1.45 + 0.04, u * use);
	}
	ALBEDO = col;
	ROUGHNESS = armure == 1 ? 0.92 : 0.86;
	SPECULAR = 0.2;
	RIM = 0.35;          // fibres qui diffusent la lumiere sur les bords : aspect tissu, pas plastique
	RIM_TINT = 0.55;
}
