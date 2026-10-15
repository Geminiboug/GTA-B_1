shader_type spatial;
render_mode unshaded, cull_back;
// Optique de PAPI : rouge si l'oeil est sous l'angle de calage de l'unite, blanc au-dessus.
// Sur le plan de descente (3 degres) : 2 rouges (les plus proches de la piste) et 2 blanches.
// Visible seulement depuis le cote de l'approche ; de dos, on voit le boitier.

uniform float angle_deg = 3.0;
uniform vec3 approach_dir = vec3(0.0, 0.0, 1.0);   // direction vers l'avion qui arrive (monde, horizontale)
uniform float energy = 6.0;

void fragment() {
	vec3 d = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
	float ang = degrees(atan(d.y, max(length(d.xz), 0.01)));
	float facing = dot(normalize(vec3(d.x, 0.0, d.z)), normalize(approach_dir));
	// transition rouge / blanc sur ~0,1 degre (comme une vraie optique)
	float white = smoothstep(angle_deg - 0.05, angle_deg + 0.05, ang);
	vec3 lamp = mix(vec3(1.0, 0.05, 0.03), vec3(1.0, 0.97, 0.9), white);
	float on = smoothstep(0.2, 0.5, facing);
	ALBEDO = mix(vec3(0.12, 0.12, 0.12), lamp * energy, on);
}
