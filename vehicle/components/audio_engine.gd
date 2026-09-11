class_name EngineAudio
extends Node3D

## A quel niveau de charge se trouve chaque haut-parleur (0 = ralenti,
## load_scale = plein regime). Il faut un nombre dans le bon ordre (croissant)
## pour chaque AudioStreamPlayer3D enfant, dans le meme ordre que dans l'arbre.
@export var layer_load: Array[float] = [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]

## Le plus grand chiffre de layer_load (ici 100). Sert juste a convertir les
## calculs internes, qui vont de 0 a 1, vers l'echelle que vous utilisez.
@export var load_scale := 100.0

@export_group("Inertie")
## Vitesse a laquelle le son monte quand on accelere. Petit chiffre = ca reagit vite.
@export var lag_rise := 0.80
## Vitesse a laquelle le son redescend quand on leve le pied (frein moteur). Lent.
@export var lag_coast := 1.20
## Vitesse a laquelle le son redescend quand on freine vraiment. Rapide.
@export var lag_brake := 0.15
## Vitesse de la petite chute de son au changement de rapport. Doit rester
## COURT : trop long et la remontee "mange" la chute, ca fait bizarre.
@export var lag_shift := 0.10

@export_group("Boite")
## Combien de rapports le moteur simule. 1 = pas de changement de vitesse
## (comme un scooter a variateur), plus de 1 = boite avec plusieurs rapports.
@export var gear_count := 1

## A quel moment (entre 0 et 1, sur l'echelle de vitesse) on passe au rapport
## suivant. Il faut gear_count - 1 chiffres, dans l'ordre croissant.
## Laissez vide pour repartir les rapports a egale distance automatiquement.
@export var gear_thresholds: Array[float] = []

## Charge du moteur juste apres un changement de rapport (la petite chute).
## Utilise seulement si gear_drop_per_gear est vide ou mal rempli.
@export var gear_drop := 0.40
## Optionnel : une chute differente pour chaque rapport. Il faut alors
## exactement gear_count valeurs, sinon gear_drop (au-dessus) est utilise partout.
@export var gear_drop_per_gear: Array[float] = []

## Forme de la montee en son pour le PREMIER rapport : depart franc, ca monte vite.
@export var gear_curve_first := 6.0
## Forme de la montee en son pour le DERNIER rapport : ca monte plus doucement,
## comme un moteur qui a plus de mal a prendre des tours. Doit rester plus
## petit que gear_curve_first pour avoir cet effet.
@export var gear_curve_last := 1.0
## Comment on passe de gear_curve_first a gear_curve_last d'un rapport a l'autre.
## = 1 : la baisse est reguliere. > 1 : ca baisse vite au debut puis se stabilise.
## < 1 : la baisse est douce et surtout visible sur les derniers rapports.
@export var gear_curve_falloff := 1.0

## Combien de charge reste quand on leve le pied, a vitesse egale (frein moteur).
@export var engine_brake := 0.50
## Charge visee quand on freine. Doit etre plus bas que engine_brake.
@export var brake_load := 0.25

@export_group("Surregime")
## A partir de quelle charge on considere qu'on est dans la zone rouge.
## En dessous : comportement normal. Au-dessus : ca monte tres lentement,
## meme a fond, comme un moteur qui butte contre son limiteur.
@export var overrev_threshold := 80.0
## Vitesse de montee dans la zone rouge. Un GROS chiffre expres (plusieurs
## secondes) pour qu'on n'atteigne quasiment jamais le maximum.
@export var lag_overrev := 10.0

@export_group("Rendu")
## Force avec laquelle le son "corrige" sa hauteur pour coller a la charge
## exacte. Ca evite les trous entre deux sons. Au-dela de 0.6 ca sonne faux.
@export var pitch_sensitivity := 0.5
@export var pitch_range := Vector2(0.85, 1.15)
## Volume general de toutes les couches. A baisser si ca sature quand deux
## sons se melangent.
@export var gain_db := 0.0

var _players: Array[AudioStreamPlayer3D] = []
var _load := 0.0
var _prev_gear := 0
var _shift_timer := 0.0

# Les seuils de rapport "par defaut" (repartis a egale distance), calcules
# une seule fois au demarrage au lieu de refaire le calcul a chaque frame.
var _default_thresholds: Array[float] = []


func _ready() -> void:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			_players.append(child)

	if _players.size() != layer_load.size():
		push_warning("EngineAudio: %d players pour %d entrees dans layer_load."
			% [_players.size(), layer_load.size()])

	# On lance tous les sons une seule fois au debut, et on ne touchera plus
	# qu'au volume ensuite. Arreter/relancer un son a chaque frame ferait un clic.
	for player in _players:
		player.volume_db = -80.0
		player.play()

	_rebuild_default_thresholds()


## `throttle` et `speed_ratio` ont un SIGNE : ca sert a savoir si on freine.
## Ce noeud ne connait rien du vehicule, il recoit juste ces deux chiffres.
func update(delta: float, throttle: float, speed_ratio: float) -> void:
	var braking := not is_zero_approx(throttle) \
		and not is_zero_approx(speed_ratio) \
		and signf(throttle) != signf(speed_ratio)

	var ratio := clampf(absf(speed_ratio), 0.0, 1.0)
	var gear_info := _gear_and_pos(ratio)
	var gear: int = gear_info[0]
	var gear_pos: float = gear_info[1]

	# Un changement de rapport dure plusieurs frames, donc on garde un petit
	# minuteur au lieu de comparer les rapports (qui ne matcherait qu'une frame).
	if gear > _prev_gear:
		_shift_timer = 0.25
	_prev_gear = gear
	_shift_timer = maxf(_shift_timer - delta, 0.0)

	# _target_load calcule un chiffre entre 0 et 1 : on le remet a l'echelle
	# de layer_load (0 a 100 par defaut) avant de lisser et d'appliquer.
	var target := _target_load(braking, absf(throttle), gear, gear_pos) * load_scale

	var tau := lag_rise
	if target < _load:
		if braking:
			tau = lag_brake
		elif _shift_timer > 0.0:
			tau = lag_shift
		else:
			tau = lag_coast
	elif _load >= overrev_threshold:
		# On est deja dans la zone rouge et ca continue de monter : on freine
		# fort la montee, quelle que soit la valeur visee.
		tau = lag_overrev

	# On avance doucement vers la cible au lieu d'y sauter directement.
	# Cette formule donne le meme resultat quel que soit le nombre d'images
	# par seconde du jeu.
	_load = lerpf(_load, target, 1.0 - exp(-delta / maxf(tau, 0.001)))
	_apply(_load)


## Recalcule les seuils de rapport "a egale distance" (utilises quand
## gear_thresholds est vide). A appeler si gear_count change en jeu.
func _rebuild_default_thresholds() -> void:
	_default_thresholds.clear()
	for i in range(1, gear_count):
		_default_thresholds.append(float(i) / float(gear_count))


## Trouve dans quel rapport on est, et a quel point on est avance dans ce
## rapport (entre 0 et 1), a partir de gear_thresholds (ou des seuils par
## defaut si ce tableau est vide ou de la mauvaise taille).
func _gear_and_pos(ratio: float) -> Array:
	var thresholds := gear_thresholds if gear_thresholds.size() == gear_count - 1 else _default_thresholds

	var gear := 0
	while gear < thresholds.size() and ratio >= thresholds[gear]:
		gear += 1
	gear = mini(gear, gear_count - 1)

	var lo: float = 0.0 if gear == 0 else thresholds[gear - 1]
	var hi: float = 1.0 if gear >= thresholds.size() else thresholds[gear]
	var gear_pos := clampf((ratio - lo) / maxf(hi - lo, 0.0001), 0.0, 1.0)

	return [gear, gear_pos]


## A quel point la montee en son est "cassante" pour ce rapport. Va de
## gear_curve_first (1er rapport, ca monte fort) a gear_curve_last (dernier
## rapport, ca monte doucement : le moteur a plus de mal a chaque rapport).
func _gear_curve(gear: int) -> float:
	var span := maxf(float(gear_count - 1), 1.0)
	var t := float(gear) / span
	t = pow(clampf(t, 0.0, 1.0), maxf(gear_curve_falloff, 0.0001))
	return lerpf(gear_curve_first, gear_curve_last, t)


## Chute de charge juste apres un changement de rapport.
func _gear_drop(gear: int) -> float:
	if gear_drop_per_gear.size() == gear_count:
		return gear_drop_per_gear[gear]
	return gear_drop


func _target_load(braking: bool, throttle: float, gear: int, gear_pos: float) -> float:
	var k := _gear_curve(gear)
	var shaped := _log_ease(gear_pos, k)

	# En freinant, on ignore l'accelerateur : pied leve, et meme plus bas encore.
	var load_mul := brake_load if braking else lerpf(engine_brake, 1.0, throttle)
	var geared := lerpf(_gear_drop(gear), 1.0, shaped) * load_mul

	# A l'arret, l'accelerateur monte "dans le vide" (pas encore embraye), puis
	# on bascule vers le calcul normal au fil du premier rapport.
	var launch := 0.0 if braking else throttle
	var launch_t := clampf(gear_pos + float(gear), 0.0, 1.0)

	return clampf(lerpf(launch, geared, launch_t), 0.0, 1.0)


func _apply(engine_load: float) -> void:
	# On cherche les deux haut-parleurs juste en dessous et juste au dessus
	# de la charge actuelle, pour faire un fondu entre les deux.
	var hi := 1
	while hi < _players.size() - 1 and layer_load[hi] < engine_load:
		hi += 1
	var lo := hi - 1

	var span: float = maxf(layer_load[hi] - layer_load[lo], 0.0001)
	var t := clampf((engine_load - layer_load[lo]) / span, 0.0, 1.0)

	for i in _players.size():
		var gain := 0.0
		# Une racine carree donne un fondu plus naturel qu'une ligne droite :
		# sinon on entend un creux de volume au milieu du fondu.
		if i == lo:
			gain = sqrt(1.0 - t)
		elif i == hi:
			gain = sqrt(t)

		_players[i].volume_db = linear_to_db(maxf(gain, 0.0001)) + gain_db

		# On ajuste un peu la hauteur du son pour combler l'ecart entre la
		# charge reelle et le son joue. On divise par load_scale pour que
		# pitch_sensitivity garde le meme effet, que l'echelle soit 0-1 ou 0-100.
		var load_delta := (engine_load - layer_load[i]) / maxf(load_scale, 0.0001)
		_players[i].pitch_scale = clampf(
			1.0 + load_delta * pitch_sensitivity,
			pitch_range.x, pitch_range.y
		)


## Courbe qui monte vite au debut puis s'aplatit vers la fin (comme un
## vrai moteur qui a de plus en plus de mal a prendre des tours).
## k = 0 -> montee bien droite. k grand -> montee forte puis plateau net.
func _log_ease(x: float, k: float) -> float:
	if k <= 0.001:
		return x
	return log(1.0 + k * x) / log(1.0 + k)
