// GTB : relief commun des tissus (vetements unis, wax, maillots), calcule sans texture ni UV :
// - plis : bandes irregulieres aux manches, a la taille, aux genoux (creux plus sombres) ;
// - trame : toile de coton, serge diagonale du jean, ou maille, estompee au loin (pas de moire) ;
// Coordonnees cylindriques autour de l'axe vertical du personnage, comme les motifs wax.

float tissu_h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float tissu_bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tissu_h21(i), tissu_h21(i + vec2(1.0, 0.0)), f.x),
		mix(tissu_h21(i + vec2(0.0, 1.0)), tissu_h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 tissu_coord(vec3 opos) {
	return vec2(atan(opos.x, opos.z) * 0.17, opos.y);
}

// plis : 0 (creux) .. 1 (bosse)
float tissu_plis(vec2 c) {
	return tissu_bruit(vec2(c.x * 9.0, c.y * 15.0)) * 0.65 + tissu_bruit(vec2(c.x * 21.0 + 3.1, c.y * 36.0)) * 0.35;
}

// trame : -1..1 ; armure 0 toile, 1 serge (jean), 2 maille
float tissu_trame(vec2 c, int armure) {
	float f = 700.0;
	if (armure == 1) {
		return sin((c.x * 1.0 + c.y) * f * 0.9) * 0.8 + sin(c.y * f * 2.0) * 0.2;
	} else if (armure == 2) {
		return abs(sin(c.x * f * 0.45)) * 2.0 - 1.0 + sin(c.y * f * 0.7) * 0.3;
	}
	return sin(c.x * f) * sin(c.y * f);
}

// a appeler dans fragment() : facteur d'eclairage du tissu (creux des plis plus sombres, trame fine). Pas de relief
// par derivees d'ecran : sur des maillages peu detailles, il marquait les aretes des triangles.
float tissu_relief(vec3 opos, int armure, vec3 vertex, inout vec3 normal) {
	vec2 c = tissu_coord(opos);
	float plis = tissu_plis(c);
	// trame estompee quand un fil fait moins d'un pixel (au loin)
	float nette = clamp(1.0 - length(fwidth(c)) * 900.0, 0.0, 1.0);
	float trame = tissu_trame(c, armure) * nette;
	return mix(0.8, 1.0, smoothstep(0.08, 0.6, plis)) * (1.0 + trame * 0.04);
}
