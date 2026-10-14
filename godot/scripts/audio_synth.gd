class_name AudioSynth
## Sons fabriques par calcul (aucun fichier audio, aucun droit a gerer) : boucles de moteur, klaxons, vagues...
## Chaque fonction renvoie un AudioStreamWAV pret a jouer (mono, 16 bits).

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func moto_loop() -> AudioStreamWAV:
	## Monocylindre 4 temps au ralenti accelere (~25 explosions / s). Boucle parfaite : nombre entier de cycles.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fire_hz := 25.0
	var n := int(RATE / fire_hz) * 12
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var ph := fmod(i * fire_hz / RATE, 1.0)
		var s := (exp(-ph * 9.0) * 2.0 - 0.45) * 0.6 + sin(ph * TAU) * 0.2
		s += rng.randf_range(-1.0, 1.0) * exp(-ph * 5.0) * 0.35
		lp += (s - lp) * 0.3
		out[i] = lp * 0.45
	return _wav(out, true)


static func voiture_loop() -> AudioStreamWAV:
	## Moteur 4 cylindres : ronronnement plus lisse et plus grave.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var f := 45.0
	var n := int(RATE / f) * 20
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 0.5 * t) * 0.3
		s += rng.randf_range(-1.0, 1.0) * 0.15
		lp += (s - lp) * 0.2
		out[i] = lp * 0.35
	return _wav(out, true)


static func klaxon(f1: float, f2: float, duration: float) -> AudioStreamWAV:
	## Klaxon deux tons (ondes carrees adoucies), attaque et relachement courts.
	var n := int(RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env: float = min(t / 0.02, 1.0) * min((duration - t) / 0.05, 1.0)
		var s := signf(sin(TAU * f1 * t)) * 0.5 + signf(sin(TAU * f2 * t)) * 0.5
		lp += (s - lp) * 0.5
		out[i] = lp * 0.5 * env
	return _wav(out, false)


static func vagues_loop() -> AudioStreamWAV:
	## Ressac : bruit filtre module par des vagues qui deferlent toutes les ~7 s (boucle de 21 s).
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := RATE * 21
	var out := PackedFloat32Array()
	out.resize(n)
	var b := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := fmod(t, 7.0) / 7.0
		var env := pow(sin(PI * clamp(w * 1.3, 0.0, 1.0)), 2.0) * 0.8 + 0.2
		b = b * 0.98 + rng.randf_range(-1.0, 1.0) * 0.2  # bruit "brun" : grondement
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * (0.15 + 0.5 * env)              # ecume plus brillante au deferlement
		out[i] = (b * 0.9 + lp * 0.35) * env * 0.55
	# fondu aux extremites pour une boucle sans clic
	for i in 2000:
		var k := float(i) / 2000.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func ville_loop() -> AudioStreamWAV:
	## Rumeur lointaine de la ville (circulation, foule) : bruit tres grave et doux, boucle de 12 s.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := RATE * 12
	var out := PackedFloat32Array()
	out.resize(n)
	var b := 0.0
	var b2 := 0.0
	for i in n:
		b = b * 0.995 + rng.randf_range(-1.0, 1.0) * 0.05
		b2 += (rng.randf_range(-1.0, 1.0) - b2) * 0.05
		out[i] = b * 0.8 + b2 * 0.25
	for i in 3000:
		var k := float(i) / 3000.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func oiseau() -> AudioStreamWAV:
	## Petit chant d'oiseau tropical (gazouillis : 3 a 5 notes glissees).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var notes := rng.randi_range(3, 5)
	var note_len := 0.09
	var n := int(RATE * note_len * notes * 1.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := int(t / (note_len * 1.3))
		var tn := fmod(t, note_len * 1.3)
		if tn > note_len:
			continue
		var base := 2600.0 + 900.0 * sin(float(k) * 2.3)
		var f := base + 1200.0 * (tn / note_len) * (1.0 if k % 2 == 0 else -0.6)
		ph += f / RATE
		out[i] = sin(TAU * ph) * sin(PI * tn / note_len) * 0.35
	return _wav(out, false)


static func grillons_loop() -> AudioStreamWAV:
	## Grillons / insectes de la nuit tropicale : stridulations rapides, boucle de 4 s.
	var n := RATE * 4
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var chirp := step_f(fmod(t * 3.0, 1.0), 0.45) * (0.5 + 0.5 * sin(TAU * 32.0 * t))
		var chirp2 := step_f(fmod(t * 2.3 + 0.4, 1.0), 0.35) * (0.5 + 0.5 * sin(TAU * 27.0 * t))
		out[i] = (sin(TAU * 4300.0 * t) * chirp + sin(TAU * 3900.0 * t) * chirp2 * 0.7) * 0.12
	return _wav(out, true)


static func jet_loop() -> AudioStreamWAV:
	## Reacteur d'avion de ligne : souffle large bande grave + sifflement de turbine, boucle de 4 s.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var n := RATE * 4
	var out := PackedFloat32Array()
	out.resize(n)
	var b := 0.0
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		b = b * 0.97 + rng.randf_range(-1.0, 1.0) * 0.3            # grondement
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45              # souffle
		ph += (2600.0 + 40.0 * sin(TAU * 0.5 * t)) / RATE
		var whine := sin(TAU * ph) * 0.08 + sin(TAU * ph * 1.5) * 0.04
		out[i] = b * 0.55 + lp * 0.3 + whine
	for i in 3000:
		var k := float(i) / 3000.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func step_f(x: float, edge: float) -> float:
	return 1.0 if x < edge else 0.0
