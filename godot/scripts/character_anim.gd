extends Node3D
## Animation procedurale du personnage blockout (blender/tools/build_character.py).
## Tourne les pivots aux articulations selon l'etat du joueur : idle, marche, course, saut.
## La phase du pas avance avec la distance parcourue : les pieds ne glissent pas.
## Convention : rotation.x positive = membre vers l'avant.

@export var stride_walk := 1.3   # metres par cycle complet (2 pas)
@export var stride_run := 2.4
@export var run_threshold := 6.0  # vitesse a partir de laquelle on court

var speed := 0.0
var on_floor := true
var vertical_speed := 0.0

var _phase := 0.0
var _run_blend := 0.0
var _move_blend := 0.0
var _air_blend := 0.0
var _t := 0.0
var _p := {}


func _ready() -> void:
	for n in ["piv_bassin", "piv_tronc", "piv_tete", "piv_epaule_G", "piv_epaule_D", "piv_coude_G", "piv_coude_D",
			"piv_hanche_G", "piv_hanche_D", "piv_genou_G", "piv_genou_D"]:
		_p[n] = find_child(n, true, false)
	_p["bassin_y"] = _p["piv_bassin"].position.y


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-10.0 * delta)
	_move_blend = lerp(_move_blend, clamp(speed / 1.5, 0.0, 1.0), k)
	_run_blend = lerp(_run_blend, clamp((speed - 4.0) / (run_threshold - 4.0), 0.0, 1.0), k)
	_air_blend = lerp(_air_blend, 0.0 if on_floor else 1.0, 1.0 - exp(-12.0 * delta))

	var stride: float = lerp(stride_walk, stride_run, _run_blend)
	_phase = fmod(_phase + speed * delta / stride * TAU, TAU)
	var s := sin(_phase)
	var c := cos(_phase)

	# --- Marche / course ---
	var leg_amp: float = lerp(0.45, 0.85, _run_blend) * _move_blend
	var arm_amp: float = lerp(0.35, 0.7, _run_blend) * _move_blend
	var hip_g := s * leg_amp
	var hip_d := -s * leg_amp
	# le genou plie surtout quand la jambe revient vers l'avant
	var knee_g: float = -max(0.0, -c) * lerp(0.6, 1.4, _run_blend) * _move_blend - 0.05
	var knee_d: float = -max(0.0, c) * lerp(0.6, 1.4, _run_blend) * _move_blend - 0.05
	var arm_g := -s * arm_amp
	var arm_d := s * arm_amp
	var elbow: float = lerp(0.15, 1.3, _run_blend) * _move_blend + 0.1
	var lean: float = 0.18 * _run_blend * _move_blend
	var bob: float = abs(s) * lerp(0.03, 0.07, _run_blend) * _move_blend

	# --- Idle : respiration ---
	var breath := sin(_t * 1.8) * 0.02 * (1.0 - _move_blend)

	# --- Saut / chute ---
	var tuck: float = clamp(0.4 + vertical_speed * -0.05, 0.2, 0.7) * _air_blend
	hip_g = lerp(hip_g, 0.5 + tuck * 0.3, _air_blend)
	hip_d = lerp(hip_d, 0.15, _air_blend)
	knee_g = lerp(knee_g, -0.9 - tuck, _air_blend)
	knee_d = lerp(knee_d, -0.4, _air_blend)
	arm_g = lerp(arm_g, -0.6, _air_blend)
	arm_d = lerp(arm_d, 0.9, _air_blend)
	elbow = lerp(elbow, 0.6, _air_blend)

	_p["piv_hanche_G"].rotation.x = hip_g
	_p["piv_hanche_D"].rotation.x = hip_d
	_p["piv_genou_G"].rotation.x = knee_g
	_p["piv_genou_D"].rotation.x = knee_d
	_p["piv_epaule_G"].rotation.x = arm_g
	_p["piv_epaule_D"].rotation.x = arm_d
	_p["piv_epaule_G"].rotation.z = -0.08 - 0.15 * _air_blend
	_p["piv_epaule_D"].rotation.z = 0.08 + 0.15 * _air_blend
	_p["piv_coude_G"].rotation.x = elbow
	_p["piv_coude_D"].rotation.x = elbow
	_p["piv_tronc"].rotation.x = -lean + breath
	_p["piv_tronc"].rotation.y = s * 0.12 * _move_blend
	_p["piv_tete"].rotation.x = lean * 0.6
	_p["piv_bassin"].position.y = _p["bassin_y"] - bob
