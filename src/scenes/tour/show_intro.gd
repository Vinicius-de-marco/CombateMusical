class_name ShowIntro
extends Control
## Tela de abertura de cada show da turnê: número do show, local e chamada.
## Rodada sozinha (sem turnê ativa), começa a turnê padrão para facilitar testes.

@export_file("*.tscn") var battle_scene: String = "res://src/scenes/battle/battle_scene.tscn"

@onready var _show_label: Label = %ShowLabel
@onready var _venue_label: Label = %VenueLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _rest_label: Label = %RestLabel
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	if not TourManager.is_active():
		TourManager.start_tour()
	var encounter: EncounterData = TourManager.get_current_show()
	if encounter == null:
		return
	_show_label.text = "SHOW %d DE %d" % [TourManager.get_show_number(), TourManager.get_show_count()]
	if TourManager.is_last_show():
		_show_label.text += " - FINAL"
	_venue_label.text = encounter.venue_name
	_tagline_label.text = encounter.tagline
	# Depois do primeiro show, avisa que a banda descansou no intervalo.
	_rest_label.visible = TourManager.show_index > 0
	_rest_label.text = "Intervalo: a banda recuperou %d%% do HP." % roundi(TourManager.tour.rest_heal_ratio * 100.0)
	for effect: StatusEffect in TourManager.get_next_show_effects():
		_rest_label.text += "\nBuff para este show: %s" % effect.display_name
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	_start_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(battle_scene)
	if error != OK:
		push_error("ShowIntro: não foi possível abrir '%s' (erro %d)." % [battle_scene, error])
		_start_button.disabled = false
