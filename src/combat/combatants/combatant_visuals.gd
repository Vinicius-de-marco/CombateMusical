class_name CombatantVisuals
extends Node
## Componente de feedback visual de um Combatant: textura, flash de impacto,
## tremida, tom de defesa e fade de morte. Deve ser filho direto do Combatant.

const FLASH_COLOR: Color = Color(2.5, 2.5, 2.5)
const HIT_COLOR: Color = Color(1.0, 0.3, 0.3)
const HEAL_COLOR: Color = Color(0.5, 1.0, 0.6)
const DEFEND_COLOR: Color = Color(0.6, 0.75, 1.0)
const DEAD_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)
const NORMAL_COLOR: Color = Color.WHITE

@export var sprite: Sprite2D
@export_range(0.0, 16.0, 1.0) var shake_pixels: float = 3.0
@export_range(1.0, 4.0, 0.5) var critical_shake_factor: float = 2.0

var _combatant: Combatant
var _color_tween: Tween
var _shake_tween: Tween
var _rest_position: Vector2
## Cor para a qual o sprite volta depois de um flash (muda com defesa/morte).
var _base_color: Color = NORMAL_COLOR


func _ready() -> void:
	_combatant = get_parent() as Combatant
	if _combatant == null or sprite == null:
		push_error("%s: precisa ser filho de um Combatant e ter 'sprite' definido." % name)
		return
	_rest_position = sprite.position
	_combatant.damaged.connect(_on_damaged)
	_combatant.healed.connect(_on_healed)
	_combatant.defending_changed.connect(_on_defending_changed)
	_combatant.died.connect(_on_died)
	_combatant.status_ticked.connect(_on_status_ticked)
	# O filho fica pronto antes do pai: espera os stats existirem para aplicar a textura.
	if _combatant.is_node_ready():
		_apply_texture()
	else:
		_combatant.ready.connect(_apply_texture, CONNECT_ONE_SHOT)


func _apply_texture() -> void:
	if _combatant.stats != null and _combatant.stats.battle_sprite != null:
		sprite.texture = _combatant.stats.battle_sprite


func _on_damaged(result: DamageCalculator.DamageResult) -> void:
	_flash(HIT_COLOR)
	_shake(shake_pixels * (critical_shake_factor if result.is_critical else 1.0))


func _on_healed(_amount: int) -> void:
	_flash(HEAL_COLOR)


func _on_defending_changed(is_defending: bool) -> void:
	if not _combatant.is_alive():
		return
	_base_color = DEFEND_COLOR if is_defending else NORMAL_COLOR
	_tween_color_to(_base_color, 0.15)


## DoT: damaged já disparou o flash vermelho; refaz o flash na cor do efeito.
func _on_status_ticked(_combatant_ref: Combatant, effect: StatusEffect, _damage: int) -> void:
	if _combatant.is_alive():
		_flash(effect.color)


func _on_died(_combatant_ref: Combatant) -> void:
	# damaged chega no mesmo frame: refaz o flash terminando no tom de morte.
	_base_color = DEAD_COLOR
	_color_tween = _restart(_color_tween)
	sprite.modulate = FLASH_COLOR
	_color_tween.tween_property(sprite, "modulate", HIT_COLOR, 0.06)
	_color_tween.tween_property(sprite, "modulate", DEAD_COLOR, 0.5)


## Branco estourado -> cor do evento -> cor base.
func _flash(event_color: Color) -> void:
	_color_tween = _restart(_color_tween)
	sprite.modulate = FLASH_COLOR
	_color_tween.tween_property(sprite, "modulate", event_color, 0.06)
	_color_tween.tween_property(sprite, "modulate", _base_color, 0.2)


func _tween_color_to(color: Color, duration: float) -> void:
	_color_tween = _restart(_color_tween)
	_color_tween.tween_property(sprite, "modulate", color, duration)


## Tremida horizontal amortecida; volta sempre para a posição de repouso.
func _shake(amplitude: float) -> void:
	if amplitude <= 0.0:
		return
	_shake_tween = _restart(_shake_tween)
	sprite.position = _rest_position
	var offset: float = amplitude
	for i: int in 4:
		_shake_tween.tween_property(sprite, "position:x", _rest_position.x + offset, 0.03)
		offset = -offset * 0.6
	_shake_tween.tween_property(sprite, "position:x", _rest_position.x, 0.03)


func _restart(tween: Tween) -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	return create_tween()
