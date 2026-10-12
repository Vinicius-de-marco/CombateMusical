class_name TurnManager
extends Node
## Orquestra rodadas e turnos. A ordem é recalculada por SPD a cada rodada.
## Fluxo: start_battle() -> turn_started(c) -> [quem controla age] -> end_turn() -> ...
## Quem escuta turn_started (UI do jogador ou IA) deve chamar end_turn() quando a ação terminar.

signal round_started(round_number: int)
signal turn_started(combatant: Combatant)
signal turn_ended(combatant: Combatant)
signal battle_ended(victory: bool)

enum State { IDLE, AWAITING_ACTION, BATTLE_OVER }

var state: State = State.IDLE
var round_number: int = 0
var active_combatant: Combatant = null

var _combatants: Array[Combatant] = []
var _turn_queue: Array[Combatant] = []


func start_battle(combatants: Array[Combatant]) -> void:
	assert(not combatants.is_empty(), "TurnManager: lista de combatentes vazia.")
	_combatants = combatants.duplicate()
	round_number = 0
	active_combatant = null
	state = State.IDLE
	_start_next_round()


## Encerra sem vencedor (fuga, reinício). Não emite battle_ended.
func stop_battle() -> void:
	state = State.IDLE
	active_combatant = null
	_turn_queue.clear()
	_combatants.clear()


func end_turn() -> void:
	if state != State.AWAITING_ACTION:
		push_warning("TurnManager: end_turn() chamado fora de um turno ativo.")
		return
	var finished: Combatant = active_combatant
	active_combatant = null
	if is_instance_valid(finished):
		finished.end_turn()  # reduz a duração dos efeitos de status
	turn_ended.emit(finished)
	if check_battle_end():
		return
	_advance_turn()


## Pode ser chamado a qualquer momento (ex.: após contra-ataque). Emite battle_ended uma única vez.
func check_battle_end() -> bool:
	if state == State.BATTLE_OVER:
		return true
	var players_alive: bool = not get_living(Combatant.Team.PLAYER).is_empty()
	var enemies_alive: bool = not get_living(Combatant.Team.ENEMY).is_empty()
	if players_alive and enemies_alive:
		return false
	state = State.BATTLE_OVER
	active_combatant = null
	_turn_queue.clear()
	battle_ended.emit(players_alive)
	return true


func get_living(team: Combatant.Team) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for combatant: Combatant in _combatants:
		if _is_active(combatant) and combatant.team == team:
			result.append(combatant)
	return result


func _start_next_round() -> void:
	if check_battle_end():
		return
	round_number += 1
	_turn_queue.assign(_combatants.filter(_is_active))
	_turn_queue.sort_custom(_compare_initiative)
	round_started.emit(round_number)
	_advance_turn()


func _advance_turn() -> void:
	# Pula quem morreu ou foi liberado depois que a fila foi montada.
	while not _turn_queue.is_empty():
		var next: Combatant = _turn_queue.pop_front()
		if not _is_active(next):
			continue
		next.begin_turn()  # aplica DoTs: pode matar o combatente
		if not next.is_alive():
			if check_battle_end():
				return
			continue
		active_combatant = next
		state = State.AWAITING_ACTION
		turn_started.emit(next)
		return
	_start_next_round()


## Protege contra combatentes que sofreram queue_free() durante a batalha.
static func _is_active(combatant: Combatant) -> bool:
	return is_instance_valid(combatant) and combatant.is_alive()


## Maior SPD efetivo (com status) primeiro; empate favorece o time do jogador.
## A fila já é filtrada por _is_active antes de ordenar.
static func _compare_initiative(a: Combatant, b: Combatant) -> bool:
	var a_spd: int = a.get_effective_spd()
	var b_spd: int = b.get_effective_spd()
	if a_spd != b_spd:
		return a_spd > b_spd
	return a.team == Combatant.Team.PLAYER and b.team != Combatant.Team.PLAYER
