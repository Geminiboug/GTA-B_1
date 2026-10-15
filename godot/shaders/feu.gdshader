shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Feu de balisage (piste, taxiway, approche) : point lumineux face a la camera, rond, additif.
// Taille apparente minimale pour rester visible de loin, comme un vrai feu (eblouissant a 2 km la nuit).

uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 3.0;
uniform float min_size = 0.35;     // taille au plus pres (m)
uniform float px = 0.0025;         // taille apparente : fraction de la distance
uniform float on = 1.0;            // 0 le jour, 1 la nuit (scripts/balisage.gd)

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float dist = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	VERTEX *= max(min_size, dist * px);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, r);
	ALBEDO = color * energy * a * a * on;
}
