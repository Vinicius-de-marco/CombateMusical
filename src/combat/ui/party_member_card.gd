class_name PartyMemberCard
extends PanelContainer
## Card compacto de status de um herói (nome, HP, Volume, efeitos).
## Criado em código pelo BattleHUD: um por membro da party, sem nós no .tscn.

const FONT_SIZE: int = 12
## Tamanho mínimo: as barras crescem para preencher o card, mas podem encolher
## até aqui quando a party tem mais membros (o card nunca invade o menu).
const BAR_MIN_SIZE: Vector2 = Vector2(24, 6)
const NAME_MIN_WIDTH: float = 24.0
const HP_COLOR: Color = Color(0.85, 0.2, 0.25)
const VOLUME_COLOR: Color = Color(0.6, 0.35, 0.95)
const INACTIVE_MODULATE: Color = Color(0.65, 0.65, 0.7)
const DEAD_MODULATE: Color = Color(0.5, 0.3, 0.3)
## Fundo opaco: o painel padrão do tema é translúcido e some sobre o palco escuro.
const PANEL_COLOR: Color = Color(0.07, 0.04, 0.09, 0.92)
const BORDER_COLOR: Color = Color(0.3, 0.14, 0.28)
const ACTIVE_BORDER_COLOR: Color = Color(1.0, 0.45, 0.7)

var combatant: Combatant

var _panel_style: StyleBoxFlat
var _name_label: Label
var _hp_label: Label
var _volume_label: Label
var _status_label: Label
var _hp_bar: ProgressBar
var _volume_bar: ProgressBar
var _is_active: bool = false


func _init() -> void:
	# Divide a largura da PartyStatusList igualmente entre os cards.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fica compacto, alinhado ao pé da BottomBar, mesmo quando o menu ao lado é mais alto.
	size_flags_vertical = Control.SIZE_SHRINK_END
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_COLOR
	_panel_style.border_color = BORDER_COLOR
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(2)
	_panel_style.set_content_margin_all(3)
	add_theme_stylebox_override("panel", _panel_style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	add_child(rows)

	var top := HBoxContainer.new()
	# Espaçamento curto: cabem 3 cards ao lado do menu em 640px.
	top.add_theme_constant_override("separation", 3)
	rows.add_child(top)
	_name_label = _make_label(top)
	# O nome absorve a sobra de largura; se faltar espaço, vira "..." (HP e Vol nunca cortam).
	_name_label.custom_minimum_size.x = NAME_MIN_WIDTH
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hp_label = _make_label(top)
	_volume_label = _make_label(top)

	var bars := HBoxContainer.new()
	rows.add_child(bars)
	_hp_bar = _make_bar(bars, HP_COLOR)
	_volume_bar = _make_bar(bars, VOLUME_COLOR)

	_status_label = _make_label(rows)
	# Status longo vira "..." em vez de alargar o card (e empurrar o menu).
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.custom_minimum_size.x = 1


func bind(hero: Combatant) -> void:
	combatant = hero
	hero.hp_changed.connect(_on_hp_changed)
	hero.volume_changed.connect(_on_volume_changed)
	hero.statuses_changed.connect(_refresh_statuses)
	hero.died.connect(_on_died)
	_on_hp_changed(hero.stats.current_hp, hero.stats.max_hp)
	_on_volume_changed(hero.stats.current_volume, hero.stats.max_volume)
	_refresh_statuses()
	set_active(false)


## Destaca o herói do turno atual.
func set_active(active: bool) -> void:
	if not is_instance_valid(combatant):
		return
	_is_active = active
	_name_label.text = ("> " if active else "") + combatant.stats.display_name
	_panel_style.border_color = ACTIVE_BORDER_COLOR if active else BORDER_COLOR
	_update_modulate()


func _on_hp_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d/%d" % [current, maximum]


func _on_volume_changed(current: int, maximum: int) -> void:
	_volume_bar.max_value = maximum
	_volume_bar.value = current
	_volume_label.text = "Vol %d" % current


func _refresh_statuses() -> void:
	var parts: PackedStringArray = []
	for status: StatusEffectContainer.ActiveStatus in combatant.get_active_statuses():
		parts.append("%s (%d)" % [status.effect.display_name, status.remaining_turns])
	_status_label.text = "  ".join(parts)
	_status_label.visible = not parts.is_empty()


func _on_died(_combatant: Combatant) -> void:
	_update_modulate()


func _update_modulate() -> void:
	if not combatant.is_alive():
		modulate = DEAD_MODULATE
	else:
		modulate = Color.WHITE if _is_active else INACTIVE_MODULATE


func _make_label(parent: Container) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(label)
	return label


func _make_bar(parent: Container, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_MIN_SIZE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.08, 0.12)
	bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	return bar
