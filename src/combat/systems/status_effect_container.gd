class_name StatusEffectContainer
extends RefCounted
## Efeitos ativos de um Combatant e seus contadores de duração.
## Não emite sinais: o Combatant é quem comunica as mudanças.


class ActiveStatus:
	extends RefCounted
	var effect: StatusEffect
	var remaining_turns: int
	## true = aplicado durante o turno do próprio afetado; não perde duração nesse fim de turno.
	var applied_this_turn: bool

	func _init(p_effect: StatusEffect, p_applied_this_turn: bool) -> void:
		effect = p_effect
		remaining_turns = p_effect.duration_turns
		applied_this_turn = p_applied_this_turn


var _active: Dictionary[StringName, ActiveStatus] = {}


## Retorna true se o efeito é novo; false se só renovou a duração.
func apply(effect: StatusEffect, during_own_turn: bool) -> bool:
	var existing: ActiveStatus = _active.get(effect.id)
	if existing != null:
		existing.remaining_turns = effect.duration_turns
		existing.applied_this_turn = during_own_turn
		return false
	_active[effect.id] = ActiveStatus.new(effect, during_own_turn)
	return true


## Chamado no fim do turno do afetado. Retorna os efeitos que expiraram.
func tick_end_of_turn() -> Array[StatusEffect]:
	var expired: Array[StatusEffect] = []
	for id: StringName in _active.keys():
		var status: ActiveStatus = _active[id]
		if status.applied_this_turn:
			status.applied_this_turn = false
			continue
		status.remaining_turns -= 1
		if status.remaining_turns <= 0:
			expired.append(status.effect)
			_active.erase(id)
	return expired


func get_active() -> Array[ActiveStatus]:
	var result: Array[ActiveStatus] = []
	result.assign(_active.values())
	return result


func has_effect(id: StringName) -> bool:
	return _active.has(id)


func is_empty() -> bool:
	return _active.is_empty()


func clear() -> void:
	_active.clear()


func get_atk_ratio() -> float:
	var total: float = 0.0
	for status: ActiveStatus in _active.values():
		total += status.effect.atk_ratio
	return total


func get_def_ratio() -> float:
	var total: float = 0.0
	for status: ActiveStatus in _active.values():
		total += status.effect.def_ratio
	return total


## Efeitos com dano por turno (o Combatant calcula e aplica o dano).
func get_dot_effects() -> Array[StatusEffect]:
	var result: Array[StatusEffect] = []
	for status: ActiveStatus in _active.values():
		if status.effect.dot_ratio > 0.0:
			result.append(status.effect)
	return result
