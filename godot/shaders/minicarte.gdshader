// GTB : mini-carte ronde (scripts/hud_carte.gd). Echantillonne le fond de carte (dessine une fois au lancement)
// et le calque de l'itineraire, centres sur le joueur et tournes pour que le haut = la direction de la camera.
shader_type canvas_item;

uniform sampler2D base_map : filter_linear, repeat_disable;
uniform sampler2D overlay : filter_linear, repeat_disable;
uniform vec2 map_origin;            // coin nord-ouest (x, z) du monde couvert par la texture
uniform vec2 map_size_m;            // taille couverte (m)
uniform vec2 center;                // position du joueur (x, z)
uniform float heading = 0.0;        // lacet de la camera
uniform float radius_m = 90.0;      // rayon visible (m)
uniform vec4 outside_color : source_color = vec4(0.1, 0.11, 0.1, 1.0);
uniform vec4 ring_color : source_color = vec4(0.04, 0.04, 0.05, 0.92);

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d);
	vec2 fwd = vec2(-sin(heading), -cos(heading));
	vec2 right = vec2(cos(heading), -sin(heading));
	vec2 local = d * radius_m;
	vec2 world = center + right * local.x - fwd * local.y;
	vec2 uv = (world - map_origin) / map_size_m;
	vec4 col = outside_color;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		col = texture(base_map, uv);
		vec4 ov = texture(overlay, uv);
		col.rgb = mix(col.rgb, ov.rgb, ov.a);
	}
	// leger assombrissement vers le bord, anneau, bord adouci
	col.rgb *= 1.0 - 0.18 * smoothstep(0.55, 0.95, r);
	col = mix(col, ring_color, smoothstep(0.925, 0.945, r));
	col.a *= 1.0 - smoothstep(0.985, 1.0, r);
	COLOR = col;
}
