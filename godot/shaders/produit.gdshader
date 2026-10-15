shader_type spatial;
// Produits des rayons (Ararat Hypermarket) : un bloc de geometrie par rangee de produits identiques ; ce shader
// dessine les articles un par un sur la face avant (joints sombres tous les item_w le long de la gondole) et la
// bande d'etiquette (a hauteur fixe au-dessus de chaque etagere). Aucune marque : couleurs et aplats generiques.

uniform vec3 base_color : source_color = vec3(0.8);
uniform vec3 label_color : source_color = vec3(0.95);
uniform float item_w = 0.12;               // largeur d'un article (m)
uniform vec3 axis = vec3(1.0, 0.0, 0.0);   // direction des gondoles (monde)
uniform float shelf0 = 0.12;               // dessus du socle
uniform float shelf_step = 0.42;           // ecart entre etageres

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = base_color;
	vec3 perp = normalize(cross(axis, vec3(0.0, 1.0, 0.0)));
	float front = abs(dot(wnrm, perp));
	if (front > 0.9) {
		float f = fract(dot(wpos, axis) / item_w);
		float seam = smoothstep(0.0, 0.04, f) * smoothstep(1.0, 0.96, f);
		float zl = mod(wpos.y - shelf0, shelf_step);
		float band = smoothstep(0.045, 0.05, zl) * smoothstep(0.14, 0.135, zl);
		// petit logo rond au centre de l'etiquette
		vec2 q = vec2(f - 0.5, (zl - 0.095) / item_w);
		float logo = smoothstep(0.17, 0.15, length(q)) * band;
		col = mix(col, label_color, band * 0.92);
		col = mix(col, base_color * 0.7, logo);
		col *= mix(0.45, 1.0, seam);
	} else if (wnrm.y > 0.9) {
		col *= 0.85;   // dessus des cartons, un peu plus sombre
	}
	ALBEDO = col;
	ROUGHNESS = 0.45;
}
