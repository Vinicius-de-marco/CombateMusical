class_name Combatant
extends Node2D
## Um participante da batalha (herói ou inimigo).
## Não conhece o TurnManager nem a UI: comunica tudo por sinais.

signal hp_changed(current: int, maximum: int)
signal volume_changed(current: int, maximum: int)
signal damaged(result: DamageCalculator.DamageResult)
signal healed(amount: int)
signal defending_changed(is_defending: bool)
signal died(combatant: Combatant)
signal status_applied(combatant: Combatant, effect: StatusEffect)
signal status_expired(combatant: Combatant, effect: StatusEffect)
## Dano de um efeito por turno (DoT), aplicado no início do turno.
signal status_ticked(combatant: Combatant, effect: StatusEffect, damage: int)
## Qualquer mudança na lista ou na duração dos efeitos (para a UI).
signal statuses_changed

enum Team { PLAYER, ENEMY }

const BASIC_ATTACK_VOLUME_GAIN: int = 10
## Cada pancada recebida empolga a plateia: quem apanha (e sobrevive) ganha Volume.
const DAMAGE_VOLUME_GAIN: int = 5
const DEFEND_DAMAGE_FACTOR: float = 0.5


## Resultado de use_skill: dano por alvo e cura total aplicada.
class SkillOutcome:
	extends RefCounted
	var hits: Dictionary[Combatant, DamageCalculator.DamageResult] = {}
	var healed: int = 0


@export var base_stats: CombatantStats
@export var team: Team = Team.PLAYER
## Skills do personagem, na ordem em que aparecem no menu. Pode ficar vazio.
@export var skills: Array[SkillData] = []

## Cópia de runtime: nunca altera o .tres em disco.
var stats: CombatantStats
var is_defending: bool = false:
	set(value):
		if is_defending == value:
			return
		is_defending = value
		defending_changed.emit(is_defending)

var _statuses := StatusEffectContainer.new()
## true entre begin_turn() e end_turn(): efeitos aplicados agora não perdem duração neste turno.
var _is_taking_turn: bool = false


func _ready() -> void:
	if base_stats == null:
		push_error("%s: base_stats não definido." % name)
		return
	stats = base_stats.duplicate(true) as CombatantStats
	stats.reset_vitals()


func is_alive() -> bool:
	return stats != null and stats.current_hp > 0


## Chamado pelo TurnManager quando o turno deste combatente começa.
## Aplica os DoTs; o combatente pode morrer aqui (o TurnManager verifica).
func begin_turn() -> void:
	is_defending = false
	_is_taking_turn = true
	for effect: StatusEffect in _statuses.get_dot_effects():
		if not is_alive():
			break
		var amount: int = maxi(1, roundi(stats.max_hp * effect.dot_ratio))
		var result: DamageCalculator.DamageResult = take_damage(DamageCalculator.DamageResult.new(amount, false))
		if result != null:
			status_ticked.emit(self, effect, result.amount)


## Chamado pelo TurnManager quando o turno deste combatente termina: reduz durações.
func end_turn() -> void:
	_is_taking_turn = false
	if _statuses.is_empty():
		return
	for effect: StatusEffect in _statuses.tick_end_of_turn():
		status_expired.emit(self, effect)
	statuses_changed.emit()


# --- Ações -------------------------------------------------------------------

## Ataque básico: dano 1.0x e gera Volume. Retorna null se inválido.
func basic_attack(target: Combatant) -> DamageCalculator.DamageResult:
	var result: DamageCalculator.DamageResult = _strike(target, 1.0)
	if result != null:
		gain_volume(BASIC_ATTACK_VOLUME_GAIN)
	return result


## Gasta Volume e aplica a skill em cada alvo (dano, cura e efeitos).
## Quem chama resolve os alvos pelo target_type. Retorna null se inválido ou sem Volume.
func use_skill(skill: SkillData, targets: Array[Combatant]) -> SkillOutcome:
	if not can_use_skill(skill):
		return null
	var valid_targets: Array[Combatant] = []
	for target: Combatant in targets:
		if is_instance_valid(target) and target.is_alive():
			valid_targets.append(target)
	if valid_targets.is_empty():
		return null

	stats.consume_volume(skill.volume_cost)
	volume_changed.emit(stats.current_volume, stats.max_volume)

	var outcome := SkillOutcome.new()
	for target: Combatant in valid_targets:
		if skill.deals_damage():
			# Cada alvo rola o próprio crítico (DamageCalculator é chamado por alvo).
			var hit: DamageCalculator.DamageResult = _strike(target, skill.damage_multiplier)
			if hit != null:
				outcome.hits[target] = hit
		if skill.heals():
			outcome.healed += target.heal(maxi(1, roundi(target.stats.max_hp * skill.heal_ratio)))
		for effect: StatusEffect in skill.applies_effects:
			# Estrito: chance 0 nunca aplica; chance 1 sempre aplica.
			if effect != null and (skill.effect_chance >= 1.0 or randf() < skill.effect_chance):
				target.apply_status(effect)
	return outcome


func can_use_skill(skill: SkillData) -> bool:
	return is_alive() and skill != null and stats.current_volume >= skill.volume_cost


func defend() -> void:
	if is_alive():
		is_defending = true


# --- Recebendo efeitos -------------------------------------------------------

## Retorna o resultado final (com redução de Defender) ou null se já estava morto.
func take_damage(result: DamageCalculator.DamageResult) -> DamageCalculator.DamageResult:
	if not is_alive():
		return null
	var final_result: DamageCalculator.DamageResult = result
	if is_defending:
		final_result = DamageCalculator.DamageResult.new(maxi(1, roundi(result.amount * DEFEND_DAMAGE_FACTOR)), result.is_critical)
	stats.apply_damage(final_result.amount)
	damaged.emit(final_result)
	hp_changed.emit(stats.current_hp, stats.max_hp)
	if not is_alive():
		_clear_statuses()
		died.emit(self)
	else:
		gain_volume(DAMAGE_VOLUME_GAIN)
	return final_result


## Retorna a cura efetivamente aplicada.
func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var applied: int = stats.apply_heal(amount)
	if applied > 0:
		healed.emit(applied)
		hp_changed.emit(stats.current_hp, stats.max_hp)
	return applied


func gain_volume(amount: int) -> void:
	if not is_alive():
		return
	if stats.gain_volume(amount) > 0:
		volume_changed.emit(stats.current_volume, stats.max_volume)


## Aplica (ou renova) um efeito. Emite status_applied nos dois casos.
func apply_status(effect: StatusEffect) -> void:
	if not is_alive() or effect == null:
		return
	if effect.id == &"":
		# Sem id, efeitos diferentes colidiriam na mesma chave do container.
		push_error("%s: StatusEffect '%s' sem id; preencha o campo id no .tres." % [name, effect.display_name])
		return
	_statuses.apply(effect, _is_taking_turn)
	status_applied.emit(self, effect)
	statuses_changed.emit()


func has_status(id: StringName) -> bool:
	return _statuses.has_effect(id)


func get_active_statuses() -> Array[StatusEffectContainer.ActiveStatus]:
	return _statuses.get_active()


# --- Stats efetivos (com status) ---------------------------------------------

func get_effective_atk() -> int:
	return maxi(1, roundi(stats.atk * (1.0 + _statuses.get_atk_ratio())))


func get_effective_def() -> int:
	return maxi(0, roundi(stats.def * (1.0 + _statuses.get_def_ratio())))


func get_effective_spd() -> int:
	return maxi(1, roundi(stats.spd * (1.0 + _statuses.get_spd_ratio())))


# --- Internos -----------------------------------------------------------------

func _can_strike(target: Combatant) -> bool:
	return is_alive() and is_instance_valid(target) and target.is_alive()


## Retorna o resultado já com a redução de Defender do alvo aplicada.
func _strike(target: Combatant, multiplier: float) -> DamageCalculator.DamageResult:
	if not _can_strike(target):
		return null
	var result: DamageCalculator.DamageResult = DamageCalculator.calculate_values(
			get_effective_atk(), target.get_effective_def(), stats.crit_rate, stats.crit_multiplier, multiplier)
	return target.take_damage(result)


func _clear_statuses() -> void:
	if _statuses.is_empty():
		return
	_statuses.clear()
	statuses_changed.emit()
