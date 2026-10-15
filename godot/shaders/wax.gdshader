// GTB : tissu wax (pagnes, boubous, foulards) : motifs a trois couleurs vives, calcules en coordonnees de
// l'objet (aucune texture, aucun motif copie : cercles, losanges, vagues, damier generes).
// Couleurs ecrites en sRGB, converties en lineaire a la fin. Choisies par scripts/pnj_util.gd.
shader_type spatial;

uniform vec3 col_a = vec3(0.85, 0.25, 0.1);   // fond
uniform vec3 col_b = vec3(0.95, 0.75, 0.1);   // motif principal
uniform vec3 col_c = vec3(0.1, 0.2, 0.5);     // details
uniform int motif = 0;
uniform float scale = 14.0;                    // motifs par metre

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	// projection cylindrique autour de l'axe vertical (vetements autour du corps)
	vec2 p = vec2(atan(opos.x, opos.z) * 0.17, opos.y) * scale;
	vec2 cell = fract(p) - 0.5;
	vec2 id = floor(p);
	vec3 col = col_a;
	if (motif == 0) {
		// cercles concentriques et point central
		float d = length(cell);
		col = mix(col, col_b, smoothstep(0.36, 0.33, d) - smoothstep(0.24, 0.21, d));
		col = mix(col, col_c, smoothstep(0.12, 0.09, d));
	} else if (motif == 1) {
		// bandes et losanges alternes
		float band = step(0.5, fract(p.y * 0.5));
		float dia = step(abs(cell.x) + abs(cell.y), 0.32);
		col = mix(col, col_b, dia * band);
		col = mix(col, col_c, step(abs(cell.y), 0.06) * (1.0 - band));
	} else if (motif == 2) {
		// vagues (feuillages stylises) et petits points
		float w = sin(p.x * 3.0 + sin(p.y * 2.2) * 1.6);
		col = mix(col, col_b, smoothstep(0.25, 0.4, w));
		col = mix(col, col_c, step(length(cell - vec2(0.25, -0.25)), 0.09));
	} else {
		// damier a carre interieur
		float chk = mod(id.x + id.y, 2.0);
		col = mix(col, col_b, chk);
		col = mix(col, col_c, step(max(abs(cell.x), abs(cell.y)), 0.18));
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
}
