shader_type spatial;
// Maillot de foot de club fictif : rayures verticales ou bande horizontale sur la poitrine, col et manches unis.
// Coordonnees du modele (le maillot suit le corps anime : les motifs bougent avec lui).
uniform vec3 c1 : source_color = vec3(0.1, 0.5, 0.25);
uniform vec3 c2 : source_color = vec3(0.98, 0.85, 0.15);
uniform int motif = 0;            // 0 rayures verticales, 1 bande horizontale, 2 uni avec epaules contrastees
uniform float stripe = 0.07;      // largeur d'une rayure (m)
uniform float echelle = 1.0;      // taille du porteur / adulte (enfant ~0,76)

varying vec3 p;

void vertex() {
	p = VERTEX;
}

void fragment() {
	float h = p.y / echelle;
	vec3 col = c1;
	if (motif == 0) {
		col = mod(floor(p.x / stripe), 2.0) < 0.5 ? c1 : c2;
	} else if (motif == 1) {
		col = (h > 1.18 && h < 1.30) ? c2 : c1;
	} else {
		col = (h > 1.36) ? c2 : c1;
	}
	// manches : couleur unie c1, liseres c2 au bout (bras ecartes : |x| grand)
	if (abs(p.x) / echelle > 0.24) {
		col = c1;
	}
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
