extends CanvasLayer
class_name DialogueBox

## Boite de dialogue : affiche des repliques une par une, en bas de l'ecran.
## A instancier dans la scene qui a besoin d'un
## dialogue (une cutscene, un PNJ dans la map).

## Emis a chaque replique affichee.
signal line_started(line: DialogueLine)
## Emis apres la derniere replique, une fois la boite cachee.
signal finished

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text

var _lines: Array[DialogueLine] = []
var _index := -1


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_accept"):
		resume()


## Lance le dialogue depuis sa premiere replique.
func start(lines: Array[DialogueLine]) -> void:
	_lines = lines
	_index = -1
	show()
	resume()


## Passe a la replique suivante, ou termine le dialogue apres la derniere.
func resume() -> void:
	_index += 1
	if _index >= _lines.size():
		_lines = []
		hide()
		finished.emit()
		return
	
	var line: DialogueLine = _lines[_index]
	_speaker.text = line.speaker
	_text.text = line.text
	line_started.emit(line)
