extends Node
## Autoload "TourManager" (sem class_name para não conflitar com o nome do autoload).
## Guarda o estado da turnê entre cenas: show atual, HP/Volume dos heróis e recompensas.
## Não troca de cena: as cenas consultam o estado e decidem para onde ir.


## Vitais de um herói guardados entre shows (com os máximos, para a recompensa de cura).
class HeroVitals:
	extends RefCounted
	var hp: int
	var volume: int
	var max_hp: int
	var max_volume: int

	func _init(p_hp: int, p_volume: int, p_max_hp: int, p_max_volume: int) -> void:
		hp = p_hp
		volume = p_volume
		max_hp = p_max_hp
		max_volume = p_max_volume


const DEFAULT_TOUR: TourData = preload("res://src/core/tour/data/main_tour.tres")

var tour: TourData = null
## Índice do show atual em tour.shows.
var show_index: int = 0

## Chave: nome do nó do herói na Party (estável entre cenas).
## Vazio no primeiro show: os heróis começam com HP cheio.
var _vitals: Dictionary[StringName, HeroVitals] = {}
## Bônus permanentes (resto da turnê) somados aos stats de toda a banda.
var _atk_bonus: int = 0
var _def_bonus: int = 0
## Efeitos aplicados na banda no início do próximo show; consumidos quando ele é vencido.
var _next_show_effects: Array[StatusEffect] = []
## true entre a vitória de um show (que não é o último) e a escolha da recompensa.
var _reward_pending: bool = false
## Opções sorteadas para a recompensa pendente (fixas até a escolha).
var _reward_offers: Array[RewardData] = []


func is_active() -> bool:
	return tour != null and show_index < tour.shows.size()


func start_tour(p_tour: TourData = DEFAULT_TOUR) -> void:
	if p_tour == null or p_tour.shows.is_empty():
		push_error("TourManager: turnê sem shows.")
		return
	_reset()
	tour = p_tour


func end_tour() -> void:
	_reset()


## null quando não há turnê ativa.
func get_current_show() -> EncounterData:
	return tour.shows[show_index] if is_active() else null


func get_show_count() -> int:
	return tour.shows.size() if tour != null else 0


## Número do show atual para exibição (1, 2, 3...).
func get_show_number() -> int:
	return show_index + 1


func is_last_show() -> bool:
	return is_active() and show_index == tour.shows.size() - 1


## Antes da luta (e antes dos cards do HUD): bônus permanentes e vitais guardados.
## Sem registro de vitais, o herói fica como está (HP cheio).
func prepare_party(heroes: Array[Combatant]) -> void:
	for hero: Combatant in heroes:
		if hero.stats == null:
			continue
		hero.stats.atk += _atk_bonus
		hero.stats.def += _def_bonus
		var vitals: HeroVitals = _vitals.get(hero.name)
		if vitals != null:
			hero.set_vitals(vitals.hp, vitals.volume)


## No início da luta, depois dos sinais conectados (o log mostra os buffs).
func apply_show_effects(heroes: Array[Combatant]) -> void:
	for effect: StatusEffect in _next_show_effects:
		for hero: Combatant in heroes:
			hero.apply_status(effect)


func get_next_show_effects() -> Array[StatusEffect]:
	return _next_show_effects.duplicate()


## Chamado na vitória: guarda os vitais com o descanso do intervalo e avança.
## Retorna true se ainda há show pela frente (e deixa uma recompensa pendente).
func complete_show(heroes: Array[Combatant]) -> bool:
	if not is_active():
		return false
	for hero: Combatant in heroes:
		var rest: int = roundi(hero.stats.max_hp * tour.rest_heal_ratio)
		var hp: int = mini(hero.stats.max_hp, hero.stats.current_hp + rest)
		_vitals[hero.name] = HeroVitals.new(hp, hero.stats.current_volume, hero.stats.max_hp, hero.stats.max_volume)
	# O buff era só deste show: vencido, ele acaba.
	_next_show_effects.clear()
	show_index += 1
	var has_next_show: bool = show_index < tour.shows.size()
	_reward_pending = has_next_show and not tour.reward_pool.is_empty()
	_reward_offers.clear()
	return has_next_show


func has_pending_reward() -> bool:
	return _reward_pending


## Sorteia uma vez por recompensa pendente: uma opção de cada tipo, depois completa
## com as restantes até reward_choices. Chamadas seguintes devolvem as mesmas opções.
func get_reward_offers() -> Array[RewardData]:
	if _reward_offers.is_empty() and tour != null:
		var pool: Array[RewardData] = tour.reward_pool.duplicate()
		pool.shuffle()
		for kind: int in RewardData.Kind.values():
			for reward: RewardData in pool:
				if reward != null and reward.kind == kind and _reward_offers.size() < tour.reward_choices:
					_reward_offers.append(reward)
					break
		for reward: RewardData in pool:
			if _reward_offers.size() >= tour.reward_choices:
				break
			if reward != null and not _reward_offers.has(reward):
				_reward_offers.append(reward)
	return _reward_offers.duplicate()


func claim_reward(reward: RewardData) -> void:
	if reward == null or not _reward_pending:
		return
	match reward.kind:
		RewardData.Kind.UPGRADE:
			_atk_bonus += reward.atk_bonus
			_def_bonus += reward.def_bonus
		RewardData.Kind.RESTORE:
			for vitals: HeroVitals in _vitals.values():
				vitals.hp = mini(vitals.max_hp, vitals.hp + roundi(vitals.max_hp * reward.heal_ratio))
				vitals.volume = mini(vitals.max_volume, vitals.volume + reward.volume_gain)
		RewardData.Kind.BUFF:
			if reward.next_show_effect != null:
				_next_show_effects.append(reward.next_show_effect)
	_reward_pending = false
	_reward_offers.clear()


func _reset() -> void:
	tour = null
	show_index = 0
	_vitals.clear()
	_atk_bonus = 0
	_def_bonus = 0
	_next_show_effects.clear()
	_reward_pending = false
	_reward_offers.clear()
