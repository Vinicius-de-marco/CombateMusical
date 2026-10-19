class_name RewardScreen
extends Control
## Tela entre shows: o jogador escolhe 1 entre as opções sorteadas pelo TourManager.
## Próximo Show / Voltar ao Menu só aparecem depois da escolha.
## Rodada sozinha (sem turnê ativa), começa a turnê padrão só para mostrar as opções.

const OPTION_SIZE: Vector2 = Vector2(150, 120)
const OPTION_FONT_SIZE: int = 11
const KIND_COLORS: Dictionary[RewardData.Kind, Color] = {
	RewardData.Kind.UPGRADE: Color(1.0, 0.45, 0.7),
	RewardData.Kind.RESTORE: Color(0.5, 1.0, 0.6),
	RewardData.Kind.BUFF: Color(1.0, 0.85, 0.35),
}
const PANEL_COLOR: Color = Color(0.08, 0.05, 0.12, 0.92)
const DIMMED: Color = Color(1, 1, 1, 0.35)

@export_file("*.tscn") var show_intro_scene: String = "res://src/scenes/tour/show_intro.tscn"
@export_file("*.tscn") var main_menu_scene: String = "res://src/scenes/main_menu/main_menu.tscn"

@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _options: HBoxContainer = %Options
@onready var _chosen_label: Label = %ChosenLabel
@onready var _after_choice: Control = %AfterChoice
@onready var _next_button: Button = %NextButton
@onready var _menu_button: Button = %MenuButton

var _option_buttons: Array[Button] = []


func _ready() -> void:
	if not TourManager.is_active():
		TourManager.start_tour()
	_next_button.pressed.connect(_on_next_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_set_after_choice_visible(false)
	_chosen_label.text = ""
	# show_index já avançou: o show vencido é o anterior (0 = cena rodada sozinha).
	if TourManager.show_index > 0:
		_subtitle_label.text = "Show %d concluído! Escolha uma melhoria para a banda:" % TourManager.show_index
	for reward: RewardData in TourManager.get_reward_offers():
		_add_option(reward)
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func _add_option(reward: RewardData) -> void:
	var button := Button.new()
	button.custom_minimum_size = OPTION_SIZE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
	# Depois da escolha todos ficam desabilitados: o escolhido continua legível (os outros esmaecem).
	button.add_theme_color_override("font_disabled_color", Color.WHITE)
	button.text = "%s\n%s\n\n%s" % [RewardData.kind_label(reward.kind), reward.display_name, reward.description]
	var color: Color = KIND_COLORS.get(reward.kind, Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _make_style(color, state))
	button.pressed.connect(_on_option_chosen.bind(reward, button))
	_options.add_child(button)
	_option_buttons.append(button)


## Borda na cor do tipo; mais grossa e clara no hover/foco.
func _make_style(color: Color, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR.lightened(0.08) if state in ["hover", "focus"] else PANEL_COLOR
	style.border_color = color if state != "normal" else color.darkened(0.35)
	style.set_border_width_all(3 if state in ["hover", "focus", "pressed"] else 2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	return style


func _on_option_chosen(reward: RewardData, chosen: Button) -> void:
	TourManager.claim_reward(reward)
	for button: Button in _option_buttons:
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		if button != chosen:
			button.modulate = DIMMED
	_chosen_label.text = "Escolhido: %s" % reward.display_name
	_set_after_choice_visible(true)
	_next_button.grab_focus()


## Transparente em vez de hide(): o espaço fica reservado e as opções não pulam de lugar.
func _set_after_choice_visible(value: bool) -> void:
	_after_choice.modulate.a = 1.0 if value else 0.0
	for button: Button in [_next_button, _menu_button]:
		button.disabled = not value
		button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE


func _on_next_pressed() -> void:
	_next_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(show_intro_scene)
	if error != OK:
		push_error("RewardScreen: não foi possível abrir '%s' (erro %d)." % [show_intro_scene, error])
		_next_button.disabled = false


func _on_menu_pressed() -> void:
	TourManager.end_tour()
	get_tree().change_scene_to_file(main_menu_scene)
