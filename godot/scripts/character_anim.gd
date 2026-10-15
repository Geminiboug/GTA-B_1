extends Node3D
## Animation procedurale du personnage blockout (blender/tools/build_character.py).
## Trois allures melangees selon la vitesse : marche (~1,6 m/s), trot (~4,2), sprint (~7).
## - La phase du pas avance avec la distance parcourue : pas de glissement des pieds.
## - Marche : le corps est haut au milieu de l'appui. Course : phase de vol, corps haut entre deux appuis.
## - En l'air la phase est figee : pose de saut selon la vitesse verticale (pas de gigotage).
## - Reception amortie selon la hauteur de chute, inclinaison dans les virages et a l'acceleration.
## Convention : rotation.x positive = membre vers l'avant.
## Tourne dans _physics_process : avec l interpolation physique activee, c est ce qui rend le mouvement fluide.

var speed := 0.0
var on_floor := true
var vertical_speed := 0.0
var turn_rate := 0.0
var accel := 0.0
var seated := false  # assis sur un vehicule
var femme := false   # demarche feminine : bassin qui balance davantage, bras plus pres du corps
var gesture := 0.0   # 0..1 : gesticule (colere, dispute) : bras leves, mains qui s'agitent
var _gest := 0.0
var _punch := 0.0


func punch() -> void:
	## Coup de poing / bousculade : le bras droit part vers l'avant puis revient.
	_punch = 0.45

var _seat := 0.0

# Allures : [vitesse, longueur de cycle (2 pas), amplitude hanche, flexion genou en vol de jambe,
#            amplitude bras, coude, penche du buste, rebond vertical (+ = vol), twist]
const GAITS := [
	[1.6, 1.45, 0.38, 0.55, 0.28, 0.15, 0.03, -0.025, 0.08],
	[4.2, 2.3, 0.62, 1.35, 0.55, 1.35, 0.12, 0.05, 0.12],
	[7.0, 3.3, 0.85, 1.9, 0.8, 1.55, 0.24, 0.07, 0.16],
]

var _phase := 0.0
var _move := 0.0
var _air := 0.0
var _land := 0.0
var _land_strength := 0.0
var _lean_fwd := 0.0
var _lean_side := 0.0
var _t := 0.0
var _g := GAITS[0].duplicate()
var _p := {}
const PIVOTS := ["piv_bassin", "piv_tronc", "piv_tete", "piv_epaule_G", "piv_epaule_D", "piv_coude_G", "piv_coude_D",
	"piv_hanche_G", "piv_hanche_D", "piv_genou_G", "piv_genou_D"]


var _skel: Skeleton3D
var _bones := {}


func _ready() -> void:
	# corps anime par squelette (personnages actuels) : on calcule les angles sur des pivots "fantomes"
	# (hors de l'arbre) puis on les recopie sur les os a la fin de chaque image ; sinon pivots d'un modele rigide
	_skel = Squelette.find(self)
	if _skel:
		_bones = Squelette.info(_skel)
	for n in PIVOTS:
		_p[n] = Node3D.new() if _skel else find_child(n, true, false)
	_p["bassin_y"] = _p["piv_bassin"].position.y


func _exit_tree() -> void:
	if _skel:
		for n in PIVOTS:
			(_p[n] as Node3D).free()
		_skel = null


func _sync_skeleton() -> void:
	for n in PIVOTS:
		var e: Vector3 = (_p[n] as Node3D).rotation
		if n.begins_with("piv_epaule_"):
			e = Squelette.arm_rest(e, n.right(1))
		Squelette.apply(_skel, _bones, n, e, (_p[n] as Node3D).position)


func land(fall_speed: float) -> void:
	_land_strength = clamp((fall_speed - 2.0) / 8.0, 0.15, 1.0)
	_land = 1.0


func _gait_at(v: float) -> Array:
	if v <= GAITS[0][0]:
		return GAITS[0]
	for i in range(GAITS.size() - 1):
		var a: Array = GAITS[i]
		var b: Array = GAITS[i + 1]
		if v <= b[0]:
			var t: float = smoothstep(a[0], b[0], v)
			var out := []
			for k in a.size():
				out.append(lerp(float(a[k]), float(b[k]), t))
			return out
	return GAITS[GAITS.size() - 1]


func _physics_process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-8.0 * delta)
	_move = lerp(_move, clamp(speed / 1.2, 0.0, 1.0), k)
	_air = lerp(_air, 0.0 if on_floor else 1.0, 1.0 - exp(-14.0 * delta))
	_land = max(0.0, _land - delta * 3.5)

	var target_g := _gait_at(speed)
	for i in _g.size():
		_g[i] = lerp(float(_g[i]), float(target_g[i]), k)
	var stride: float = _g[1]
	if on_floor:
		_phase = fmod(_phase + speed * delta / stride * TAU, TAU)

	var s := sin(_phase)
	var c := cos(_phase)
	var m := _move
	var hip_amp: float = _g[2] * m
	var knee_amp: float = _g[3] * m
	var arm_amp: float = _g[4] * m * (0.8 if femme else 1.0)

	# jambe gauche : phase, jambe droite : phase + PI
	var hip_g: float = s * hip_amp
	var hip_d: float = -s * hip_amp
	# genou : flexion forte pendant le retour de la jambe (cos > 0), legere pendant l'appui
	var knee_g: float = -pow(max(0.0, c), 1.3) * knee_amp - max(0.0, -c) * 0.12 * m - 0.04
	var knee_d: float = -pow(max(0.0, -c), 1.3) * knee_amp - max(0.0, c) * 0.12 * m - 0.04
	var arm_g: float = -s * arm_amp
	var arm_d: float = s * arm_amp
	var elbow: float = _g[5] * m + 0.1
	var bounce: float = _g[7] * m
	var bob: float = (abs(s) * bounce) if bounce > 0.0 else (-abs(s) * -bounce + -bounce)
	# corps : penche avec l'allure, l'acceleration et les virages
	_lean_fwd = lerp(_lean_fwd, clamp(accel * 0.03, -0.2, 0.25), k)
	_lean_side = lerp(_lean_side, clamp(-turn_rate * speed * 0.025, -0.35, 0.35), k)
	var lean: float = _g[6] * m + _lean_fwd
	var breath := sin(_t * 1.7) * 0.02 * (1.0 - m)

	# --- En l'air : pose figee selon la montee / la descente ---
	if _air > 0.001:
		var rising: float = clamp(vertical_speed / 4.0, 0.0, 1.0)
		var falling: float = clamp(-vertical_speed / 6.0, 0.0, 1.0)
		var a := _air
		hip_g = lerp(hip_g, 0.75 * rising + 0.25 * falling + 0.2, a)
		knee_g = lerp(knee_g, -1.3 * rising - 0.35 * falling - 0.3, a)
		hip_d = lerp(hip_d, -0.25 * rising + 0.1 * falling, a)
		knee_d = lerp(knee_d, -0.5 * rising - 0.2 * falling - 0.15, a)
		arm_g = lerp(arm_g, -0.5 + 0.3 * falling, a)
		arm_d = lerp(arm_d, 0.7 - 0.3 * falling, a)
		elbow = lerp(elbow, 0.7, a)
		bob = lerp(bob, 0.0, a)
		lean = lerp(lean, 0.1 + 0.1 * falling, a)

	# --- Reception : flexion amortie ---
	var squat := _land * _land_strength
	hip_g += 0.55 * squat
	hip_d += 0.55 * squat
	knee_g -= 1.0 * squat
	knee_d -= 1.0 * squat
	lean += 0.25 * squat
	bob -= 0.16 * squat

	# --- Assis sur le zem : cuisses vers l'avant, genoux plies, mains au guidon ---
	_seat = lerp(_seat, 1.0 if seated else 0.0, 1.0 - exp(-10.0 * delta))
	if _seat > 0.001:
		var st := _seat
		hip_g = lerp(hip_g, 1.35, st)
		hip_d = lerp(hip_d, 1.35, st)
		knee_g = lerp(knee_g, -1.45, st)
		knee_d = lerp(knee_d, -1.45, st)
		arm_g = lerp(arm_g, 0.95, st)
		arm_d = lerp(arm_d, 0.95, st)
		elbow = lerp(elbow, 0.45, st)
		lean = lerp(lean, 0.25, st)
		bob = lerp(bob, 0.0, st)

	_p["piv_hanche_G"].rotation.x = hip_g
	_p["piv_hanche_D"].rotation.x = hip_d
	_p["piv_genou_G"].rotation.x = knee_g
	_p["piv_genou_D"].rotation.x = knee_d
	_p["piv_epaule_G"].rotation.x = arm_g
	_p["piv_epaule_D"].rotation.x = arm_d
	_p["piv_epaule_G"].rotation.z = -0.07 - 0.25 * _air
	_p["piv_epaule_D"].rotation.z = 0.07 + 0.25 * _air
	_p["piv_coude_G"].rotation.x = elbow
	_p["piv_coude_D"].rotation.x = elbow
	_p["piv_tronc"].rotation.x = -lean + breath
	_p["piv_tronc"].rotation.y = s * _g[8] * m * (1.0 - _air)
	_p["piv_tete"].rotation.x = lean * 0.5
	_p["piv_bassin"].position.y = _p["bassin_y"] + bob
	# balancement du bassin a chaque pas (plus marque chez la femme), oppose a la rotation des epaules
	var walk := m * (1.0 - _air) * (1.0 - _seat)
	_p["piv_bassin"].rotation.z = s * (0.055 if femme else 0.02) * walk
	_p["piv_bassin"].rotation.y = -s * (0.09 if femme else 0.05) * walk
	if femme:
		_p["piv_coude_G"].rotation.x = elbow + 0.12
		_p["piv_coude_D"].rotation.x = elbow + 0.12
	# dispute : bras qui montent et s'agitent, buste penche vers l'interlocuteur
	_gest = lerpf(_gest, gesture, 1.0 - exp(-6.0 * delta))
	if _gest > 0.01:
		var wave := sin(_t * 7.0)
		_p["piv_epaule_D"].rotation.x = lerpf(_p["piv_epaule_D"].rotation.x, 1.4 + 0.35 * wave, _gest)
		_p["piv_coude_D"].rotation.x = lerpf(_p["piv_coude_D"].rotation.x, 0.9 - 0.4 * wave, _gest)
		_p["piv_epaule_G"].rotation.x = lerpf(_p["piv_epaule_G"].rotation.x, 0.9 - 0.25 * wave, _gest)
		_p["piv_coude_G"].rotation.x = lerpf(_p["piv_coude_G"].rotation.x, 1.3, _gest)
		_p["piv_tronc"].rotation.x = lerpf(_p["piv_tronc"].rotation.x, -0.12, _gest)
		_p["piv_tete"].rotation.x = lerpf(_p["piv_tete"].rotation.x, 0.08 * sin(_t * 5.0), _gest)
	# coup : epaule droite vers l'avant, bras tendu, rotation du buste
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - delta)
		var k2 := sin((0.45 - _punch) / 0.45 * PI)
		_p["piv_epaule_D"].rotation.x = lerpf(_p["piv_epaule_D"].rotation.x, 1.55, k2)
		_p["piv_coude_D"].rotation.x = lerpf(_p["piv_coude_D"].rotation.x, 0.1, k2)
		_p["piv_tronc"].rotation.y = lerpf(_p["piv_tronc"].rotation.y, -0.45, k2)
	rotation.z = _lean_side
	if _skel:
		_sync_skeleton()
