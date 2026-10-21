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


static func pluie_loop() -> AudioStreamWAV:
	## Pluie tropicale : bruit large bande + crepitement de gouttes sur la tole, boucle de 6 s.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n := RATE * 6
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var drop := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.6
		if rng.randf() < 0.004:
			drop = rng.randf_range(0.3, 0.8)  # goutte qui claque sur un toit en tole
		drop *= 0.985
		out[i] = lp * 0.35 + rng.randf_range(-1.0, 1.0) * drop * 0.5
	for i in 3000:
		var k := float(i) / 3000.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func tonnerre() -> AudioStreamWAV:
	## Tonnerre : craquement puis long grondement grave qui roule et s'eteint (5 s).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := RATE * 5
	var out := PackedFloat32Array()
	out.resize(n)
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		b = b * 0.995 + rng.randf_range(-1.0, 1.0) * 0.1
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 12.0) * 0.6
		var roll := b * (1.0 + 0.6 * sin(TAU * 0.7 * t + rng.randf() * 0.2)) * exp(-t * 0.7) * 2.5
		out[i] = clamp(crack + roll, -1.0, 1.0)
	return _wav(out, false)


static func crissement_loop() -> AudioStreamWAV:
	## Crissement de pneus : sifflement aigu instable (frottement caoutchouc / bitume), boucle de 2 s.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1150.0 + 180.0 * sin(TAU * 3.1 * t) + 90.0 * sin(TAU * 7.7 * t)
		ph += f / RATE
		bp += (rng.randf_range(-1.0, 1.0) - bp) * 0.5
		out[i] = (sin(TAU * ph) * 0.5 + sin(TAU * ph * 2.02) * 0.2 + bp * 0.25) * 0.35
	for i in 1500:
		var k := float(i) / 1500.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func choc() -> AudioStreamWAV:
	## Choc de carrosserie : impact sourd + tole froissee + debris (0,8 s).
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := int(RATE * 0.8)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var thud := sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.9
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var crunch := lp * exp(-t * 7.0) * 0.8
		var metal := sin(TAU * (520.0 + 80.0 * rng.randf()) * t) * exp(-t * 12.0) * 0.25
		out[i] = clampf(thud + crunch + metal, -1.0, 1.0)
	return _wav(out, false)


static func cri(pitch: float, duration: float) -> AudioStreamWAV:
	## Exclamation (sans paroles) : voix approchee par une fondamentale glissante et des formants (eh ! / ah !).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := int(RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := pitch * (1.0 + 0.25 * sin(PI * t / duration)) * (1.0 + 0.01 * rng.randf_range(-1.0, 1.0))
		ph += f / RATE
		var env := minf(t / 0.03, 1.0) * minf((duration - t) / 0.08, 1.0)
		var v := sin(TAU * ph) * 0.6 + sin(TAU * ph * 2.0) * 0.3 + sin(TAU * ph * 3.0) * 0.2 + sin(TAU * ph * 5.0) * 0.08
		out[i] = v * env * 0.35
	return _wav(out, false)


static func ding() -> AudioStreamWAV:
	## Petit carillon d'arrivee (deux notes claires qui s'eteignent).
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 1046.5 * t) * exp(-t * 5.0) * minf(t / 0.005, 1.0)
		var b := 0.0
		if t > 0.16:
			var u := t - 0.16
			b = sin(TAU * 1568.0 * u) * exp(-u * 4.0) * minf(u / 0.005, 1.0)
		out[i] = (a + b) * 0.35
	return _wav(out, false)


static func step_f(x: float, edge: float) -> float:
	return 1.0 if x < edge else 0.0


# ------------------------------------------------------------------ moteurs de voiture (phase vehicules realistes)
const MOTEUR_REF_RPM := 2000.0     # regime de reference des boucles : pitch_scale = regime / MOTEUR_REF_RPM


static func moteur(diesel: bool, charge: bool, cylindres := 4) -> AudioStreamWAV:
	## Boucle de moteur 4 temps a MOTEUR_REF_RPM : une explosion par cylindre tous les deux tours (4 cylindres :
	## 2 par tour), chacune un peu differente (desequilibre des cylindres : grondement), resonance d'echappement.
	## En charge (pied sur l'accelerateur) : plus de mordant et de souffle ; a vide (frein moteur) : plus creux.
	## Diesel : cognement sec a chaque explosion (claquement aigu), timbre plus grave et plus rugueux.
	var rng := RandomNumberGenerator.new()
	rng.seed = (11 if diesel else 13) + (1 if charge else 0)
	var fire_hz := MOTEUR_REF_RPM / 60.0 * cylindres / 2.0
	var per := int(round(RATE / fire_hz))
	var pulses := cylindres * 12
	var n := per * pulses
	var out := PackedFloat32Array()
	out.resize(n)
	var amp: Array = []
	for c in cylindres:
		amp.append(rng.randf_range(0.8, 1.15))
	var res_f := (95.0 if diesel else 130.0)      # resonance du pot d'echappement
	var lp := 0.0
	var hp_prev := 0.0
	var bp := 0.0
	for k in pulses:
		var a: float = amp[k % cylindres] * rng.randf_range(0.93, 1.07)
		for j in per:
			var t := float(j) / RATE
			var env := exp(-t * (38.0 if charge else 55.0))
			var s := sin(TAU * res_f * t) * env * a
			s += sin(TAU * res_f * 2.7 * t) * exp(-t * 90.0) * a * (0.45 if charge else 0.2)
			s += (rng.randf() * 2.0 - 1.0) * env * (0.35 if charge else 0.15)
			if diesel:
				# cognement : salve aiguë tres courte au debut de chaque combustion
				var knock := (rng.randf() * 2.0 - 1.0) * exp(-t * 600.0) * 0.9
				var hp := knock - hp_prev
				hp_prev = knock
				s += hp * (0.8 if charge else 0.5)
			out[k * per + j] = s
	# lissage (filtre passe-bas doux) et souffle d'admission en charge
	for i in n:
		lp += (out[i] - lp) * (0.35 if diesel else 0.45)
		bp += ((rng.randf() * 2.0 - 1.0) - bp) * 0.08
		out[i] = (lp + (bp * 0.25 if charge else 0.0)) * 0.42
	# raccord de boucle sans clic
	for i in 200:
		var w := float(i) / 200.0
		out[n - 200 + i] = lerpf(out[n - 200 + i], out[i], w * 0.5)
	return _wav(out, true)


static func roulement_loop(gravier: bool) -> AudioStreamWAV:
	## Bruit de roulement des pneus : souffle doux sur le goudron, crepitement de cailloux sur la laterite et le sable.
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 if gravier else 53
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		lp += (w - lp) * (0.25 if gravier else 0.06)
		lp2 += (lp - lp2) * 0.3
		var s := lp2 * (0.9 if gravier else 1.4)
		if gravier and rng.randf() < 0.004:
			s += rng.randf_range(-1.0, 1.0) * 0.8       # caillou projete
		out[i] = s * 0.5
	for i in 1500:
		var k := float(i) / 1500.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func vent_loop() -> AudioStreamWAV:
	## Vent autour de la caisse a vitesse elevee : souffle large qui ondule.
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var n := RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.12
		out[i] = lp * (0.7 + 0.3 * sin(TAU * t / 3.0 * 2.0)) * 0.6
	for i in 2000:
		var k := float(i) / 2000.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


static func portiere(fermer: bool) -> AudioStreamWAV:
	## Portiere : clac sourd de la fermeture (ou declic de la poignee et grincement a l'ouverture).
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 if fermer else 63
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		if fermer:
			s = sin(TAU * 85.0 * t) * exp(-t * 22.0) * 0.9
			lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.4
			s += lp * exp(-t * 40.0) * 0.6
			s += sin(TAU * 1900.0 * t) * exp(-t * 70.0) * 0.12    # loquet
		else:
			s = sin(TAU * 2400.0 * t) * exp(-t * 90.0) * 0.3      # declic de la poignee
			if t > 0.05:
				var u := t - 0.05
				s += sin(TAU * (380.0 + 60.0 * sin(TAU * 9.0 * u)) * u) * exp(-u * 9.0) * 0.08    # charniere
		out[i] = s
	return _wav(out, false)


static func petarade() -> AudioStreamWAV:
	## Petarade d'echappement au lever de pied a haut regime (deux ou trois detonations seches).
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in 3:
		var t0 := [0.0, 0.09, 0.2][k] as float
		var a := [1.0, 0.7, 0.45][k] as float
		for i in n:
			var t := float(i) / RATE - t0
			if t < 0.0:
				continue
			out[i] += (sin(TAU * 110.0 * t) * 0.6 + (rng.randf() * 2.0 - 1.0) * 0.8) * exp(-t * 60.0) * a
	return _wav(out, false)


static func demarreur() -> AudioStreamWAV:
	## Demarreur (0,9 s) : le moteur electrique entraine le moteur par a-coups (compressions), puis il prend.
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var compressions := 0.55 + 0.45 * sin(TAU * 11.0 * t)
		var whine := sin(TAU * 230.0 * t) * 0.25 + sin(TAU * 460.0 * t) * 0.08
		var bruit := (rng.randf() * 2.0 - 1.0) * 0.12
		var prise := smoothstep(0.62, 0.9, t)
		out[i] = ((whine + bruit) * compressions * (1.0 - prise) + sin(TAU * 55.0 * t) * prise * 0.5) * 0.7
	return _wav(out, false)


static func tic_clignotant() -> AudioStreamWAV:
	## Relais de clignotant : tic sec.
	var n := int(RATE * 0.05)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 1900.0 * t) * exp(-t * 180.0) * 0.4
	return _wav(out, false)


static func passage_rapport() -> AudioStreamWAV:
	## Petit clonc mecanique du passage de rapport (boite automatique qui passe).
	var n := int(RATE * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 160.0 * t) * exp(-t * 60.0) * 0.35
	return _wav(out, false)


static func coup_de_feu(kind: int) -> AudioStreamWAV:
	## Detonation : claquement sec (bruit tres court) + souffle grave qui s'eteint + echo des facades.
	## kind 0 pistolet (sec), 1 fusil a pompe (gros et grave), 2 fusil de chasse artisanal (long, poudre noire).
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + kind
	var n := int(RATE * (0.9 if kind == 0 else 1.3))
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var dec := [55.0, 30.0, 22.0][kind] as float
	var grave := [140.0, 85.0, 70.0][kind] as float
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf() * 2.0 - 1.0
		lp += (w - lp) * (0.6 if t < 0.01 else 0.12)
		var s := w * exp(-t * 300.0) * 1.0 + lp * exp(-t * dec) * 1.4 + sin(TAU * grave * t) * exp(-t * 25.0) * 0.6
		# echo des murs (rue etroite) : repetition attenuee a 120 ms et 260 ms
		out[i] = s
	for e in [[0.12, 0.35], [0.26, 0.18]]:
		var off := int(RATE * float(e[0]))
		for i in range(n - 1, off - 1, -1):
			out[i] += out[i - off] * float(e[1])
	for i in n:
		out[i] = clampf(out[i] * 0.7, -1.0, 1.0)
	return _wav(out, false)


static func coup_arme(verre: bool) -> AudioStreamWAV:
	## Coup porte avec une arme blanche : bruit sourd (corps), tintement de verre si la bouteille frappe.
	var rng := RandomNumberGenerator.new()
	rng.seed = 79 if verre else 83
	var n := int(RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.25
		var s := sin(TAU * 95.0 * t) * exp(-t * 35.0) * 0.8 + lp * exp(-t * 30.0) * 0.5
		if verre:
			s += (sin(TAU * 3100.0 * t) + sin(TAU * 4700.0 * t) * 0.6) * exp(-t * 18.0) * 0.18
		out[i] = s
	return _wav(out, false)


static func fanfare_loop() -> AudioStreamWAV:
	## Fanfare de funerailles (boucle de 8 s) : cuivres a l'unisson sur une melodie lente et grave, soubassophone,
	## caisse claire et grosse caisse au pas. Notes inventees, aucun air existant.
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var bpm := 72.0
	var temps := 60.0 / bpm
	var n := int(RATE * temps * 10.0)
	var out := PackedFloat32Array()
	out.resize(n)
	# melodie (demi-tons depuis la4 grave) et basse, un temps par note
	var melodie := [0, 3, 5, 3, 7, 5, 3, 0, 2, 0]
	var basse := [-12, -12, -7, -7, -9, -9, -5, -5, -12, -12]
	for k in 10:
		var f := 220.0 * pow(2.0, float(melodie[k]) / 12.0)
		var fb := 110.0 * pow(2.0, float(basse[k]) / 12.0)
		var i0 := int(k * temps * RATE)
		var i1 := int((k + 1) * temps * RATE)
		for i in range(i0, mini(i1, n)):
			var t := float(i - i0) / RATE
			var env := minf(t / 0.04, 1.0) * (1.0 - smoothstep(temps * 0.75, temps, t))
			var ph := TAU * f * t
			# timbre cuivre : harmoniques decroissantes, leger vibrato
			var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t)
			var cuivre := 0.0
			for h in range(1, 7):
				cuivre += sin(ph * h * vib) / float(h)
			var tuba := sin(TAU * fb * t) * 0.9 + sin(TAU * fb * 2.0 * t) * 0.3
			out[i] += (cuivre * 0.22 + tuba * 0.25) * env
		# grosse caisse sur chaque temps, caisse claire roulee en contretemps
		for i in range(i0, mini(i0 + int(RATE * 0.25), n)):
			var t := float(i - i0) / RATE
			out[i] += sin(TAU * 60.0 * t) * exp(-t * 14.0) * 0.5
		var ic := i0 + int(temps * 0.5 * RATE)
		for i in range(ic, mini(ic + int(RATE * 0.12), n)):
			var t := float(i - ic) / RATE
			out[i] += (rng.randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.25
	for i in n:
		out[i] = clampf(out[i] * 0.6, -1.0, 1.0)
	return _wav(out, true)


static func explosion() -> AudioStreamWAV:
	## Explosion : claquement sec, souffle grave qui roule, grondement et echo qui s'eteint (3,2 s).
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := int(RATE * 3.2)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var bruit := rng.randf_range(-1.0, 1.0)
		lp += (bruit - lp) * 0.5
		lp2 += (bruit - lp2) * 0.04
		var f := 28.0 + 70.0 * exp(-t * 5.0)       # fondamentale qui chute : le "boum"
		ph += TAU * f / RATE
		var boum := sin(ph) * exp(-t * 2.2) * 1.0
		var claque := lp * exp(-t * 14.0) * 0.9
		var souffle := lp2 * exp(-t * 1.3) * 3.2
		out[i] = clampf((boum + claque + souffle) * 0.8, -1.0, 1.0)
	return _wav(out, false)
