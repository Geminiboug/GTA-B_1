class_name Qualite
## Prereglages graphiques (menu Options) : 0 bas (PC modeste), 1 moyen, 2 haut (reglage d'origine).
## Agit sur l'ombre du soleil, l'occlusion ambiante, l'eclairage indirect, le halo, la resolution 3D et le niveau
## de detail des maillages.

const NOMS := ["Bas", "Moyen", "Haut"]
# [ombre (m), ssao, ssil, halo, echelle 3D, seuil LOD (px)]
const PRESETS := [
	[80.0, false, false, false, 0.75, 4.0],
	[140.0, true, false, true, 0.9, 2.0],
	[160.0, true, false, true, 1.0, 1.0],
]


static func appliquer(scene: Node, niveau: int) -> void:
	var p: Array = PRESETS[clampi(niveau, 0, PRESETS.size() - 1)]
	var sun := scene.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.directional_shadow_max_distance = p[0]
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.ssao_enabled = p[1]
		we.environment.ssil_enabled = p[2]
		we.environment.glow_enabled = p[3]
		if we.environment.sky:
			we.environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var vp := scene.get_viewport()
	if vp:
		vp.scaling_3d_scale = p[4]
		vp.mesh_lod_threshold = p[5]
