class_name Dialogues
## Repliques des PNJ (francais du Benin, quelques formules en fon). A completer / corriger librement :
## {appel} est remplace par la facon de s'adresser au joueur selon son genre (tonton, ma soeur...).
## Au Benin, on dit "bonsoir" des le debut de l'apres-midi.

const APPEL := {
	"homme": ["tonton", "mon frère", "chef", "patron", "grand frère", "le vieux"],
	"femme": ["tantie", "ma sœur", "maman", "ma copine", "grande sœur", "la go"],
}

const LIGNES := {
	"salut_matin": ["Bonjour {appel} !", "A fon ganji à ?", "Bonne journée {appel}.", "Bonjour, ça va un peu ?"],
	"salut_soir": ["Bonsoir {appel} !", "Bonsoir, ça va ?", "On dit quoi {appel} ?", "Bonne arrivée !", "Mi kwabo !"],
	"vendeuse": ["{appel}, viens acheter !", "Eau glacée ! Pure water !", "C'est frais, viens voir !", "Ma copine, approche !",
		"Je te fais un bon prix !", "Arachides grillées !", "Ananas bien sucré !", "Pain chaud, pain chaud !"],
	# cris selon la marchandise de l'etal (retour d'Olympe du 21/10/2026 : pas d'arachides grillees pour un etal de pain)
	"vendeuse_pain": ["Pain chaud, pain chaud !", "{appel}, le pain vient de sortir !", "Baguette fraîche, viens voir !", "Pain au lait, pain au lait !"],
	"vendeuse_fruits": ["Ananas bien sucré !", "Oranges, bananes, ananas !", "{appel}, goûte l'ananas !", "Fruits frais du matin !"],
	"vendeuse_arachides": ["Arachides grillées !", "Arachides chaudes, {appel} !", "Arachides bouillies, arachides grillées !", "Goûte, c'est salé comme il faut !"],
	"vendeuse_eau": ["Eau glacée ! Pure water !", "Eau fraîche, {appel} !", "Ça glace ! Viens boire !", "Jus de gingembre bien frais !"],
	"vendeuse_legumes": ["Tomates, piment, oignons !", "{appel}, les tomates sont belles !", "Légumes frais, bon prix !", "Piment fort, piment fort !"],
	"vendeuse_kpayo": ["Essence ! Le litre à 650 !", "Kpayo, l'essence pour ta moto !", "{appel}, tu as besoin d'essence ?"],
	"vendeuse_maquis": ["Pâte rouge et poulet, c'est chaud !", "Bière bien fraîche, {appel} !", "Akassa et poisson frit !", "Viens manger, {appel} !"],
	"zem": ["Zem ? On va où ?", "{appel}, je te dépose ?", "Montez, je connais la route !"],
	"bouscule": ["Eh ! Tu ne vois pas devant toi ?", "Doucement {appel} !", "Pardon hein !", "Tu es aveugle ou quoi ?",
		"Eh Dieu !", "Regarde où tu marches !", "Ça va pas non ?"],
	"bassine": ["Mes affaires ! Tu vas payer !", "Eh ! Ma marchandise !", "Regarde ce que tu as fait !"],
	"frappe": ["Tu me frappes pourquoi ?!", "Eh ! Tu es malade ?", "Au secours !", "Laisse-moi tranquille !"],
	"temoin_bagarre": ["Eh ! Laisse-le !", "Qu'est-ce qui ne va pas chez toi ?", "Séparez-les !", "Eh Seigneur !"],
	"renverse": ["Ahi ! Ma jambe !", "Tu es fou ? Tu ne sais pas conduire ?", "Il faut payer mes soins !", "Eh Dieu, j'ai mal !"],
	"temoin_accident": ["Il a renversé quelqu'un !", "Arrêtez-le !", "Eh Seigneur !", "Appelez quelqu'un !", "Il faut payer !"],
	"frole": ["Eh ! Tu veux me tuer ?", "Doucement chauffeur !", "Tu roules comme un fou !", "Eh ! Freine !"],
	"vole": ["Mon véhicule ! Voleur !", "Au voleur ! Attrapez-le !", "Descends de là ! C'est à moi !", "Eh ! On vole ma voiture !"],
	"klaxon": ["Avance !", "Eh, bouge de là !", "Tu attends quoi ?", "Doucement, on va où ?"],
	"choc_voiture": ["Eh ! Tu es fou ?", "Tu as vu ce que tu as fait ?", "Il faut payer la réparation !", "Tu ne sais pas conduire ?"],
	"fuite": ["Ahi ! Courez !", "Eh Dieu !", "Au secours !"],
	"vigile": ["Eh ! On ne se bat pas ici !", "Sortez du magasin !", "Sécurité ! Arrêtez ça !", "Doucement, monsieur !"],
	"croise": ["Pardon {appel}.", "Excusez-moi.", "Eh, doucement !"],
	"bagarre": ["Viens ! Tu vas voir !", "Tu me cherches, {appel} ?", "On va régler ça ici !", "Approche si tu es fort !"],
	"appel_police": ["Allô, la police ? On m'agresse !", "Venez vite, il y a un fou qui frappe les gens !", "Allô ? Il m'a frappé, venez !"],
	"ko": ["Ahi... ma tête...", "Pitié, pitié !", "Arrête, arrête !"],
}


static func pick(cat: String, rng: RandomNumberGenerator, player_genre := "homme") -> String:
	var arr: Array = LIGNES.get(cat, ["..."])
	var line: String = arr[rng.randi() % arr.size()]
	var appels: Array = APPEL.get(player_genre, APPEL["homme"])
	return line.replace("{appel}", appels[rng.randi() % appels.size()])


static func greeting(hour: float, rng: RandomNumberGenerator, player_genre := "homme") -> String:
	return pick("salut_matin" if hour < 12.0 else "salut_soir", rng, player_genre)
