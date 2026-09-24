# Gère uniquement le son du klaxon.
extends Node3D

# Référence vers le nœud audio enfant "Klaxon".
# @onready attend que la scène soit chargée avant de chercher le nœud.
@onready var _player: AudioStreamPlayer3D = $Klaxon


# Joue le son du klaxon.
# Si le son est déjà en cours, play() le relance depuis le début.
func play() -> void:
	_player.play()
