class_name VehicleAirborne
extends Node

## Dynamique verticale du vehicule : gravite, saut et collage au sol.
## Comme les autres composants, il ne touche jamais au corps physique : il
## calcule une vitesse verticale que le Vehicle applique. Les composants
## calculent, le vehicule applique.

## Multiplicateur de gravite pendant la MONTEE d'un saut.
## Bas = tu flottes au sommet, ce qui laisse le temps de viser l'atterrissage.
@export var gravity_rise := 1.8

## Multiplicateur pendant la CHUTE. Plus haut que gravity_rise donne une
## retombee seche. C'est le reglage qui separe un saut arcade d'un saut lunaire.
## La gravite par defaut de Godot (9.8) est realiste, donc molle pour un jeu.
@export var gravity_fall := 2.8

## Force qui colle le vehicule au sol dans les descentes. Trop haut = pas de saut.
@export var ground_stick := 4.0

## Vitesse verticale courante, lue par le Vehicle pour composer sa velocite.
var vertical_speed := 0.0


## Appele au sol : on synchronise la vitesse verticale sur la composante
## verticale du vecteur de conduite. C'est CA qui te lance quand tu quittes la
## rampe : au moment du decollage la valeur est deja bonne.
func sync_launch(launch_speed: float) -> void:
	vertical_speed = launch_speed


## Appele en l'air : on integre la gravite, plus forte a la chute qu'a la montee.
func apply_gravity(delta: float, gravity: float) -> void:
	var scale := gravity_rise if vertical_speed > 0.0 else gravity_fall
	vertical_speed += gravity * scale * delta
