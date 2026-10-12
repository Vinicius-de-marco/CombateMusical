class_name BattleHUD
extends CanvasLayer
## Interface da batalha. Só exibe estado e emite pedidos de ação:
## quem decide e executa é a BattleScene.

signal attack_requested(target: Combatant)
## target é null quando a skill não pede seleção (ALL_ENEMIES / SELF).
signal skill_requested(skill: SkillData, target: Combatant)
signal defend_requested
signal play_again_requested
signal quit_requested

const MAX_LOG_LINES: int = 3
## Botões de skill/alvo gerados em código: menores para o SkillMenu não subir sobre os sprites.
const MENU_BUTTON_FONT_SIZE: int = 11

@onready var _turn_label: Label = %TurnLabel
@onready var _log_label: Label = %LogLabel
## Um PartyMemberCard por herói é criado aqui (lado esquerdo da BottomBar).
@onready var _party_status_list: Container = %PartyStatusList
@onready var _action_menu: Control = %ActionMenu
@onready var _attack_button: Button = %AttackButton
@onready var _skills_button: Button = %SkillsButton
@onready var _defend_button: Button = %DefendButton
@onready var _skill_menu: Control = %SkillMenu
@onready var _skill_list: VBoxContainer = %SkillList
@onready var _skill_back_button: Button = %SkillBackButton
@onready var _target_menu: Control = %TargetMenu
@onready var _target_list: VBoxContainer = %TargetList
@onready var _cancel_button: Button = %CancelButton
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _quit_button: Button = %QuitButton

var _log_lines: PackedStringArray = []
## Herói do turno atual (dono do menu de skills).
var _hero: Combatant = null
var _cards: Array[PartyMemberCard] = []
var _targets: Array[Combatant] = []
## null = ataque básico; preenchido = skill de alvo único aguardando alvo.
var _pending_skill: SkillData = null


func _ready() -> void:
	_attack_button.pressed.connect(_on_attack_pressed)
	_skills_button.pressed.connect(_open_skill_menu)
	_defend_button.pressed.connect(_on_defend_pressed)
	_skill_back_button.pressed.connect(_show_only.bind(_action_menu, _attack_button))
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_play_again_button.pressed.connect(play_again_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)
	hide_menus()
	_result_panel.hide()
	_log_label.text = ""


## Cria um card por herói em %PartyStatusList (recria se chamado de novo).
func setup_party(heroes: Array[Combatant]) -> void:
	for card: PartyMemberCard in _cards:
		_party_status_list.remove_child(card)  # sai do layout já, sem esperar o fim do frame
		card.queue_free()
	_cards.clear()
	for hero: Combatant in heroes:
		var card := PartyMemberCard.new()
		_party_status_list.add_child(card)
		card.bind(hero)
		_cards.append(card)


## Destaca o card de quem está no turno (nenhum, se for um inimigo).
func highlight(combatant: Combatant) -> void:
	for card: PartyMemberCard in _cards:
		card.set_active(card.combatant == combatant)


func show_action_menu(hero: Combatant, targets: Array[Combatant]) -> void:
	_hero = hero
	highlight(hero)
	_targets = targets
	_pending_skill = null
	_skills_button.disabled = hero.skills.is_empty()
	_show_only(_action_menu, _attack_button)


func hide_menus() -> void:
	_action_menu.hide()
	_skill_menu.hide()
	_target_menu.hide()


func set_turn_info(round_number: int, combatant: Combatant) -> void:
	_turn_label.text = "Rodada %d - Vez de %s" % [round_number, combatant.stats.display_name]
	highlight(combatant)


func log_message(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)


func show_result(victory: bool) -> void:
	hide_menus()
	_result_label.text = "VITÓRIA!" if victory else "DERROTA..."
	_result_panel.show()
	_play_again_button.grab_focus()


func _open_skill_menu() -> void:
	_clear(_skill_list)
	var first_enabled: Button = null
	for skill: SkillData in _hero.skills:
		if skill == null:
			continue
		var button := _make_menu_button()
		button.text = "%s (%d)" % [skill.display_name, skill.volume_cost]
		button.disabled = not _hero.can_use_skill(skill)
		button.pressed.connect(_on_skill_chosen.bind(skill))
		_skill_list.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	_show_only(_skill_menu, first_enabled if first_enabled != null else _skill_back_button)


func _open_target_menu() -> void:
	_clear(_target_list)
	var first_button: Button = null
	for target: Combatant in _targets:
		if not is_instance_valid(target) or not target.is_alive():
			continue
		var button := _make_menu_button()
		button.text = "%s  (HP %d/%d)" % [target.stats.display_name, target.stats.current_hp, target.stats.max_hp]
		for status: StatusEffectContainer.ActiveStatus in target.get_active_statuses():
			button.text += " [%s]" % status.effect.display_name
		button.tooltip_text = button.text
		button.pressed.connect(_on_target_chosen.bind(target))
		_target_list.add_child(button)
		if first_button == null:
			first_button = button
	_show_only(_target_menu, first_button if first_button != null else _cancel_button)


## Mostra um único menu e dá foco a um botão dele (navegação por teclado/controle).
func _show_only(menu: Control, focus: Button) -> void:
	hide_menus()
	menu.show()
	if is_instance_valid(focus):
		focus.grab_focus()


## Botão gerado em código: texto longo vira "..." em vez de alargar o menu,
## que fica com a largura fixa do MenuArea. O texto completo vai no tooltip.
func _make_menu_button() -> Button:
	var button := Button.new()
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", MENU_BUTTON_FONT_SIZE)
	return button


## Remove os botões gerados. Por isso SkillBackButton/CancelButton devem ser IRMÃOS
## de SkillList/TargetList na árvore, nunca filhos.
func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_attack_pressed() -> void:
	_pending_skill = null
	_open_target_menu()


func _on_skill_chosen(skill: SkillData) -> void:
	if skill.needs_target_selection():
		_pending_skill = skill
		_open_target_menu()
		return
	hide_menus()
	skill_requested.emit(skill, null)


func _on_defend_pressed() -> void:
	hide_menus()
	defend_requested.emit()


## Voltar do menu de alvos: retorna ao menu de onde veio.
func _on_cancel_pressed() -> void:
	if _pending_skill != null:
		_pending_skill = null
		_open_skill_menu()
	else:
		_show_only(_action_menu, _attack_button)


func _on_target_chosen(target: Combatant) -> void:
	hide_menus()
	if _pending_skill != null:
		skill_requested.emit(_pending_skill, target)
	else:
		attack_requested.emit(target)
