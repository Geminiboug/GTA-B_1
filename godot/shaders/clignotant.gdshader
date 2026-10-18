shader_type spatial;
// Clignotants d'une voiture : un seul materiau pour les quatre feux orange ; le cote s'allume selon la position du
// feu dans le repere du vehicule (x < 0 : gauche, la voiture regarde vers -Z). scripts/voiture.gd regle gauche/droite.
uniform vec3 couleur : source_color = vec3(0.95, 0.5, 0.05);
uniform float gauche = 0.0;
uniform float droite = 0.0;
varying float cote;

void vertex() {
	cote = VERTEX.x;
}

void fragment() {
	ALBEDO = couleur * 0.55;
	ROUGHNESS = 0.2;
	EMISSION = couleur * (cote < 0.0 ? gauche : droite) * 3.0;
}
