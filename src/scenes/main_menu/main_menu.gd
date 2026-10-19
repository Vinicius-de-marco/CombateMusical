class_name MainMenu
extends Control
## Menu principal: inicia a turnê ou fecha o jogo.
## A música é a mesma da batalha: o AudioManager mantém a faixa tocando na troca de cena.

## Primeira tela da turnê (abertura do show 1).
@export_file("*.tscn") var show_intro_scene: String = "res://src/scenes/tour/show_intro.tscn"
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
	TourManager.start_tour()
	var error: Error = get_tree().change_scene_to_file(show_intro_scene)
	if error != OK:
		push_error("MainMenu: não foi possível abrir '%s' (erro %d)." % [show_intro_scene, error])
		_start_button.disabled = false


func _on_quit_pressed() -> void:
	get_tree().quit()
