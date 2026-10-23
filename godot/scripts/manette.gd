extends RefCounted
## Disposition de manette par defaut : celle de la PlayStation (noms Godot : A = Croix, B = Rond, X = Carre, Y = Triangle,
## L1 / R1 = epaules, L2 / R2 = gachettes analogiques, L3 / R3 = clics des sticks, Back = Share / Select, Start = Options).
## Appelee au demarrage (partie.gd) : chaque action du jeu a ses boutons de manette, sans doublon dans un meme contexte
## (a pied, en vehicule, en avion). Les actions creees par le code (garde, arme, torche...) sont creees ici si besoin.
##
## A PIED : stick gauche bouger (l'inclinaison regle l'allure) · stick droit camera · Croix courir (tapoter) · Carre sauter ·
## Rond frapper / tirer (ou R2) · Triangle monter / descendre · L1 ou L2 viser / se proteger · R1 arme suivante ·
## L3 recharger · R3 s'accroupir · Haut telephone · Gauche inventaire · Droite parler / acheter · Bas changer de vue ·
## Share carte · Options pause · Share + Options mode photo.
## EN AVION : D-pad gauche / droite palonnier (a la place de inventaire / parler).
## EN VEHICULE : R2 accelerer · L2 freiner / reculer · stick gauche tourner · R1 frein a main · L3 klaxon · L1 limiteur ·
## Triangle descendre · Droite chercher un client (zem) · Bas changer de vue.
## Autres : pave tactile (PS) heler un zem (aussi dans le telephone, application Zem) · bouton Misc1 torche (aussi dans l inventaire) ·
## palette arriere (manettes elite) appeler la bande. La marche lente se regle avec l inclinaison du stick.

const AXE_L2 := JOY_AXIS_TRIGGER_LEFT
const AXE_R2 := JOY_AXIS_TRIGGER_RIGHT

## action -> [touche par defaut du clavier (0 = deja creee ailleurs), [boutons], [[axe, sens], ...]]
const TABLE := {
	"sprint": [0, [JOY_BUTTON_A], []],
	"jump": [0, [JOY_BUTTON_X], []],
	"attaque": [0, [JOY_BUTTON_B], [[AXE_R2, 1.0]]],
	"interact": [0, [JOY_BUTTON_Y], []],
	"garde": [0, [JOY_BUTTON_LEFT_SHOULDER], [[AXE_L2, 1.0]]],
	"arme_suivante": [KEY_TAB, [JOY_BUTTON_RIGHT_SHOULDER], []],
	"recharger": [KEY_R, [JOY_BUTTON_LEFT_STICK], []],
	"crouch": [0, [JOY_BUTTON_RIGHT_STICK], []],
	"walk": [0, [], []],
	"handbrake": [0, [JOY_BUTTON_RIGHT_SHOULDER], []],
	"horn": [0, [JOY_BUTTON_LEFT_STICK], []],
	"accelerate": [0, [], [[AXE_R2, 1.0]]],
	"brake": [0, [], [[AXE_L2, 1.0]]],
	"limiteur": [KEY_K, [JOY_BUTTON_LEFT_SHOULDER], []],
	"parler": [0, [JOY_BUTTON_DPAD_RIGHT], []],
	"inventaire": [KEY_I, [JOY_BUTTON_DPAD_LEFT], []],
	"telephone": [KEY_P, [JOY_BUTTON_DPAD_UP], []],
	"camera_vue": [0, [JOY_BUTTON_DPAD_DOWN], []],
	"map": [0, [JOY_BUTTON_BACK], []],
	"map_pin": [0, [JOY_BUTTON_A], []],
	"pause": [0, [JOY_BUTTON_START], []],
	"photo": [KEY_F12, [], []],
	"torche": [KEY_L, [JOY_BUTTON_MISC1], []],
	"heler": [KEY_H, [JOY_BUTTON_TOUCHPAD], []],
	"bande": [KEY_G, [JOY_BUTTON_PADDLE1], []],
	"lacet_g": [KEY_Z, [JOY_BUTTON_DPAD_LEFT], []],
	"lacet_d": [KEY_X, [JOY_BUTTON_DPAD_RIGHT], []],
}


static func appliquer() -> void:
	## Pose la disposition PlayStation (idempotent) : on retire les boutons de manette existants des actions de la table
	## puis on ajoute ceux de la table ; le clavier et la souris ne sont pas touches.
	for a in TABLE:
		var e: Array = TABLE[a]
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			if int(e[0]) != 0:
				var k := InputEventKey.new()
				k.physical_keycode = int(e[0]) as Key
				InputMap.action_add_event(a, k)
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(a, ev)
		for b in e[1]:
			var j := InputEventJoypadButton.new()
			j.button_index = int(b) as JoyButton
			InputMap.action_add_event(a, j)
		for ax in e[2]:
			var m := InputEventJoypadMotion.new()
			m.axis = int(ax[0]) as JoyAxis
			m.axis_value = float(ax[1])
			InputMap.action_add_event(a, m)

