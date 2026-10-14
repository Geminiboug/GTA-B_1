// GTB : ciel tropical realiste avec nuages qui derivent en continu.
// - Degrade d'atmosphere (zenith bleu profond, horizon clair et legerement brumeux comme sur la cote)
// - Disque solaire + halo, suit la DirectionalLight3D de la scene
// - Deux couches de nuages (cumulus bas + voile haut) en bruit fractal, poussees par le vent (TIME)
// - Eclairage des nuages : bords lumineux cote soleil, base plus sombre
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.16, 0.38, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.42, 0.40, 0.38);
uniform float horizon_softness = 0.35;

uniform float sun_size = 0.9997;      // cos de l'angle du disque
uniform float sun_halo = 6.0;
uniform vec3 sun_tint : source_color = vec3(1.0, 0.92, 0.78);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;   // part du ciel couverte
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.18;
uniform float cloud_scale = 0.55;
uniform vec2 wind = vec2(0.022, 0.009);   // vitesse de derive (unites / s)
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

	// --- Atmosphere ---
	float t = pow(clamp(h, 0.0, 1.0), horizon_softness);
	vec3 col = mix(horizon_color, zenith_color, t);
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 6.0, 0.0, 1.0));
	}

	// --- Soleil ---
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.3, 0.7, -0.6));
	float sd = dot(dir, sun_dir);
	col += sun_tint * pow(max(sd, 0.0), 400.0) * 0.6;            // halo serre
	col += sun_tint * pow(max(sd, 0.0), sun_halo) * 0.12;        // diffusion large
	float disc = smoothstep(sun_size, sun_size + 0.00015, sd);

	// --- Nuages (projetes sur un plan au-dessus de la camera) ---
	if (h > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 uv = dir.xz / (h + 0.08) * cloud_scale;
		// TIME borne pour garder la precision du GPU sur de longues sessions
		vec2 drift = wind * mod(TIME, 4000.0);
		// cumulus : forme qui evolue (deux couches de bruit a vitesses differentes)
		float base = fbm(uv + drift);
		float detail = fbm(uv * 2.7 - drift * 1.6);
		float dens = base * 0.75 + detail * 0.25;
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, dens);
		// eclairage : on echantillonne vers le soleil, moins dense = bord eclaire
		vec2 to_sun = normalize(sun_dir.xz + vec2(0.0001)) * 0.06;
		float dens_sun = fbm(uv + drift + to_sun) * 0.75 + detail * 0.25;
		float lit = clamp(1.0 - (dens_sun - dens) * 6.0, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow, cloud_light, lit * 0.7 + 0.3 * (1.0 - c * 0.5));
		ccol += sun_tint * pow(max(sd, 0.0), 8.0) * 0.35 * (1.0 - c);  // liseré lumineux face au soleil
		// voile d'altitude (cirrus) qui file plus vite
		float hi = fbm(uv * vec2(0.6, 2.2) * 0.7 + drift * 2.5);
		float cir = smoothstep(0.55, 0.85, hi) * high_cloud_amount;
		// les nuages s'estompent vers l'horizon (perspective atmospherique)
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, cloud_light * 0.95, cir * fade * 0.6);
		col = mix(col, ccol, c * fade);
		disc *= 1.0 - c * fade;
	}

	col += sun_tint * disc * 8.0;
	COLOR = col;
}
