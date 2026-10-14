// GTB : ciel tropical realiste, jour / coucher de soleil / nuit, nuages qui derivent en continu.
// - Degrade d'atmosphere ; horizon dore puis orange quand le soleil est bas ; nuit bleu sombre
// - Disque solaire + halo ; lune (opposee au soleil) ; etoiles qui scintillent la nuit
// - Deux couches de nuages (cumulus + cirrus) en bruit fractal, poussees par le vent (TIME),
//   eclairees cote soleil, rosees au coucher, sombres la nuit
// La direction du soleil et le facteur de nuit viennent de scripts/day_night.gd.
shader_type sky;

uniform vec3 sun_dir_u = vec3(0.3, 0.75, 0.1);   // direction vers le soleil
uniform float night = 0.0;

uniform vec3 zenith_color : source_color = vec3(0.16, 0.38, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.42, 0.40, 0.38);
uniform float horizon_softness = 0.35;

uniform float sun_size = 0.9997;      // cos de l'angle du disque
uniform float sun_halo = 6.0;
uniform vec3 sun_tint : source_color = vec3(1.0, 0.92, 0.78);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.18;
uniform float cloud_scale = 0.55;
uniform vec2 wind = vec2(0.022, 0.009);
uniform float high_cloud_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.60, 0.68);

// hash sur coordonnees entieres (stable, sans lignes parasites)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sun_dir = normalize(sun_dir_u);
	float elev = sun_dir.y;
	float day = 1.0 - night;
	// soleil proche de l'horizon (lever / coucher)
	float golden = (1.0 - smoothstep(0.0, 0.35, abs(elev))) * (1.0 - night * 0.6);
	vec2 sxz = normalize(sun_dir.xz + vec2(0.0001));
	float toward = max(dot(normalize(dir.xz + vec2(0.0001)), sxz), 0.0);

	// --- Atmosphere ---
	vec3 zen = mix(vec3(0.004, 0.007, 0.022), zenith_color, day);
	vec3 hor = mix(vec3(0.02, 0.03, 0.06), horizon_color, day);
	hor = mix(hor, vec3(1.0, 0.48, 0.2), golden * (0.3 + 0.7 * toward) * 0.85);
	zen = mix(zen, vec3(0.35, 0.3, 0.5), golden * 0.25);
	float t = pow(clamp(h, 0.0, 1.0), horizon_softness);
	vec3 col = mix(hor, zen, t);
	if (h < 0.0) {
		col = mix(hor, ground_color * mix(0.08, 1.0, day), clamp(-h * 6.0, 0.0, 1.0));
	}

	// --- Soleil ---
	float sd = dot(dir, sun_dir);
	float above = smoothstep(-0.05, 0.02, elev);
	vec3 stint = mix(sun_tint, vec3(1.0, 0.55, 0.25), golden);
	col += stint * pow(max(sd, 0.0), 400.0) * 0.6 * above;
	col += stint * pow(max(sd, 0.0), sun_halo) * (0.12 + 0.25 * golden) * above;
	float disc = smoothstep(sun_size, sun_size + 0.00015, sd) * above;

	// --- Lune et etoiles ---
	vec3 moon_dir = normalize(vec3(-sun_dir.x, abs(sun_dir.y) * 0.9 + 0.1, -sun_dir.z));
	float md = dot(dir, moon_dir);
	float moon = smoothstep(0.99955, 0.9997, md) * night;
	col += vec3(0.6, 0.65, 0.75) * pow(max(md, 0.0), 60.0) * 0.08 * night;
	if (h > 0.0 && night > 0.01 && !AT_CUBEMAP_PASS) {
		vec2 sc = vec2(atan(dir.z, dir.x), asin(h)) * 180.0;
		vec2 cell = floor(sc);
		float star = step(0.9965, hash(cell));
		float dist = length(fract(sc) - 0.5);
		float tw = 0.6 + 0.4 * sin(TIME * (2.0 + hash(cell + 3.0) * 4.0) + hash(cell) * 50.0);
		col += vec3(0.9, 0.92, 1.0) * star * smoothstep(0.35, 0.0, dist) * tw * night * smoothstep(0.0, 0.2, h) * 1.4;
	}

	// --- Nuages (projetes sur un plan au-dessus de la camera) ---
	if (h > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 uv = dir.xz / (h + 0.08) * cloud_scale;
		// TIME borne pour garder la precision du GPU sur de longues sessions
		vec2 drift = wind * mod(TIME, 4000.0);
		float base = fbm(uv + drift);
		float detail = fbm(uv * 2.7 - drift * 1.6);
		float dens = base * 0.75 + detail * 0.25;
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, dens);
		vec2 to_sun = sxz * 0.06;
		float dens_sun = fbm(uv + drift + to_sun) * 0.75 + detail * 0.25;
		float lit = clamp(1.0 - (dens_sun - dens) * 6.0, 0.0, 1.0);
		vec3 cl = mix(cloud_light, vec3(1.0, 0.62, 0.45), golden);           // nuages dores / roses au coucher
		vec3 cs = mix(cloud_shadow, vec3(0.45, 0.35, 0.45), golden);
		vec3 ccol = mix(cs, cl, lit * 0.7 + 0.3 * (1.0 - c * 0.5));
		ccol += stint * pow(max(sd, 0.0), 8.0) * 0.35 * (1.0 - c) * above;
		ccol *= mix(0.06, 1.0, day);                                            // sombres la nuit
		ccol += vec3(0.5, 0.55, 0.65) * pow(max(md, 0.0), 12.0) * 0.12 * night;   // eclaires par la lune
		float hi = fbm(uv * vec2(0.6, 2.2) * 0.7 + drift * 2.5);
		float cir = smoothstep(0.55, 0.85, hi) * high_cloud_amount;
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, cl * 0.95 * mix(0.06, 1.0, day), cir * fade * 0.6);
		col = mix(col, ccol, c * fade);
		disc *= 1.0 - c * fade;
		moon *= 1.0 - c * fade;
	}

	col += stint * disc * 8.0;
	col += vec3(0.95, 0.95, 0.9) * moon * 1.5;
	COLOR = col;
}
