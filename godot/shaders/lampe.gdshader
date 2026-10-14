// GTB : verre de lampe (lampadaires, phares) : s'allume la nuit, s'eteint pendant les coupures de courant.
shader_type spatial;

global uniform float gtb_night;
global uniform float gtb_power;
uniform vec3 light_color : source_color = vec3(1.0, 0.82, 0.55);  // sodium / LED chaude
uniform float strength = 7.0;

void fragment() {
	ALBEDO = vec3(0.85, 0.85, 0.8);
	ROUGHNESS = 0.2;
	EMISSION = light_color * strength * gtb_night * gtb_power;
}
