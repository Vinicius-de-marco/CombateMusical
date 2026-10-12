class_name MainMenu
extends Control
## Menu principal: inicia a batalha ou fecha o jogo.
## A música é a mesma da batalha: o AudioManager mantém a faixa tocando na troca de cena.

@export_file("*.tscn") var battle_scene: String = "res://src/scenes/battle/battle_scene.tscn"
@export var menu_bgm: AudioStream = preload("res://assets/audio/bgm/battle_theme.wav")

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.grab_focus()
	AudioManager.play_bgm(menu_bgm)


func _on_start_pressed() -> void:
	# Evita duplo clique disparando duas trocas de cena.
	_start_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(battle_scene)
	if error != OK:
		push_error("MainMenu: não foi possível abrir '%s' (erro %d)." % [battle_scene, error])
		_start_button.disabled = false


func _on_quit_pressed() -> void:
	get_tree().quit()
