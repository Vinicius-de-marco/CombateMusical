class_name BattleScene
extends Node2D
## Orquestra a batalha: liga TurnManager, combatentes e HUD.
## Combatentes são lidos dos filhos de Party (heróis) e Enemies (inimigos).

## Pausa entre ações para o jogador conseguir ler o log.
@export_range(0.0, 3.0, 0.1) var action_delay: float = 0.8

## Chance de um inimigo usar skill quando tem Volume para alguma (senão, ataque básico).
@export_range(0.0, 1.0, 0.05) var enemy_skill_chance: float = 0.6

@export_group("Audio")
@export var battle_bgm: AudioStream = preload("res://assets/audio/bgm/battle_theme.wav")
@export var attack_sfx: AudioStream = preload("res://assets/audio/sfx/hit.wav")
@export var victory_sfx: AudioStream = preload("res://assets/audio/sfx/victory.wav")
@export var defeat_sfx: AudioStream = preload("res://assets/audio/sfx/defeat.wav")

@onready var _turn_manager: TurnManager = $TurnManager
@onready var _hud: BattleHUD = $BattleHUD
@onready var _party: Node2D = $Party
@onready var _enemies: Node2D = $Enemies


func _ready() -> void:
	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.battle_ended.connect(_on_battle_ended)
	_hud.attack_requested.connect(_on_attack_requested)
	_hud.skill_requested.connect(_on_skill_requested)
	_hud.defend_requested.connect(_on_defend_requested)
	_hud.play_again_requested.connect(_on_play_again_requested)
	_hud.quit_requested.connect(_on_quit_requested)

	var heroes: Array[Combatant] = _collect_combatants(_party, Combatant.Team.PLAYER)
	var combatants: Array[Combatant] = []
	combatants.append_array(heroes)
	combatants.append_array(_collect_combatants(_enemies, Combatant.Team.ENEMY))
	_hud.setup_party(heroes)
	for combatant: Combatant in combatants:
		combatant.died.connect(_on_combatant_died)
		combatant.status_applied.connect(_on_status_applied)
		combatant.status_expired.connect(_on_status_expired)
		combatant.status_ticked.connect(_on_status_ticked)

	if combatants.is_empty():
		push_error("BattleScene: nenhum combatente em Party/Enemies.")
		return
	AudioManager.play_bgm(battle_bgm)
	_turn_manager.start_battle(combatants)


func _collect_combatants(container: Node, team: Combatant.Team) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for child: Node in container.get_children():
		var combatant: Combatant = child as Combatant
		if combatant == null:
			continue
		combatant.team = team  # o container define o time; evita erro de configuração
		result.append(combatant)
	return result


# --- Fluxo de turnos -------------------------------------------------------

func _on_turn_started(combatant: Combatant) -> void:
	_hud.set_turn_info(_turn_manager.round_number, combatant)
	if combatant.team == Combatant.Team.PLAYER:
		_hud.show_action_menu(combatant, _opponents_of(combatant))
	else:
		_run_enemy_turn(combatant)


func _run_enemy_turn(enemy: Combatant) -> void:
	_hud.hide_menus()
	await get_tree().create_timer(action_delay).timeout
	if not is_inside_tree() or not _is_current_turn(enemy):
		return
	var heroes: Array[Combatant] = _opponents_of(enemy)
	if not heroes.is_empty():
		var target: Combatant = heroes.pick_random()
		if not _try_enemy_skill(enemy, target):
			_log_attack(enemy, target, enemy.basic_attack(target), "ataca")
			AudioManager.play_sfx(attack_sfx, 0.1)
	_finish_turn(enemy)


## IA simples: com chance enemy_skill_chance, usa uma skill aleatória entre as que tem Volume.
## Retorna false se não usou skill (o chamador faz o ataque básico).
func _try_enemy_skill(enemy: Combatant, target: Combatant) -> bool:
	var usable: Array[SkillData] = []
	for skill: SkillData in enemy.skills:
		if enemy.can_use_skill(skill) and _is_worth_using(skill, target):
			usable.append(skill)
	if usable.is_empty() or randf() >= enemy_skill_chance:
		return false
	var chosen: SkillData = usable.pick_random()
	var outcome: Combatant.SkillOutcome = enemy.use_skill(chosen, _resolve_targets(enemy, chosen, target))
	if outcome == null:
		return false
	_log_skill(enemy, chosen, outcome)
	AudioManager.play_sfx(chosen.sfx)
	return true


## Evita desperdício: skill só de status não vale se o alvo já tem todos os efeitos dela.
func _is_worth_using(skill: SkillData, target: Combatant) -> bool:
	if skill.deals_damage() or skill.heals():
		return true
	for effect: StatusEffect in skill.applies_effects:
		if effect != null and not target.has_status(effect.id):
			return true
	return false


func _finish_turn(actor: Combatant) -> void:
	await get_tree().create_timer(action_delay).timeout
	if not is_inside_tree():
		return
	if _is_current_turn(actor):
		_turn_manager.end_turn()


## Protege contra awaits que terminam depois da batalha acabar ou do turno mudar.
func _is_current_turn(combatant: Combatant) -> bool:
	return _turn_manager.state == TurnManager.State.AWAITING_ACTION \
			and _turn_manager.active_combatant == combatant


## Herói do turno atual, ou null se o pedido do HUD chegou fora de um turno do jogador.
func _acting_hero() -> Combatant:
	var actor: Combatant = _turn_manager.active_combatant
	if _turn_manager.state != TurnManager.State.AWAITING_ACTION or actor == null or actor.team != Combatant.Team.PLAYER:
		return null
	return actor


# --- Ações do jogador (vindas do HUD) --------------------------------------

func _on_attack_requested(target: Combatant) -> void:
	var hero: Combatant = _acting_hero()
	if hero == null:
		return
	var result: DamageCalculator.DamageResult = hero.basic_attack(target)
	if result == null:
		# Alvo inválido (ex.: morreu): devolve o menu sem gastar o turno.
		_hud.show_action_menu(hero, _opponents_of(hero))
		return
	_log_attack(hero, target, result, "ataca")
	AudioManager.play_sfx(attack_sfx, 0.1)
	_finish_turn(hero)


func _on_skill_requested(skill: SkillData, target: Combatant) -> void:
	var hero: Combatant = _acting_hero()
	if hero == null:
		return
	var outcome: Combatant.SkillOutcome = hero.use_skill(skill, _resolve_targets(hero, skill, target))
	if outcome == null:
		# Sem Volume ou alvo inválido: devolve o menu sem gastar o turno.
		_hud.log_message("Não foi possível usar %s!" % skill.display_name)
		_hud.show_action_menu(hero, _opponents_of(hero))
		return
	_log_skill(hero, skill, outcome)
	AudioManager.play_sfx(skill.sfx)
	_finish_turn(hero)


func _resolve_targets(user: Combatant, skill: SkillData, chosen: Combatant) -> Array[Combatant]:
	match skill.target_type:
		SkillData.TargetType.ALL_ENEMIES:
			return _opponents_of(user)
		SkillData.TargetType.SELF:
			return [user]
		_:
			# Array tipado explícito: o ternário com literais gera Array sem tipo.
			var single: Array[Combatant] = []
			if chosen != null:
				single.append(chosen)
			return single


func _opponents_of(combatant: Combatant) -> Array[Combatant]:
	var enemy_team: Combatant.Team = Combatant.Team.ENEMY if combatant.team == Combatant.Team.PLAYER else Combatant.Team.PLAYER
	return _turn_manager.get_living(enemy_team)


func _on_defend_requested() -> void:
	var hero: Combatant = _acting_hero()
	if hero == null:
		return
	hero.defend()
	_hud.log_message("%s está defendendo!" % hero.stats.display_name)
	_finish_turn(hero)


# --- Eventos ---------------------------------------------------------------

func _on_combatant_died(combatant: Combatant) -> void:
	# O fade visual de morte fica no componente CombatantVisuals.
	# Deferred: died é emitido no meio do ataque; assim a linha sai depois da linha do dano.
	_hud.log_message.call_deferred("%s caiu!" % combatant.stats.display_name)


# Deferred: estes sinais saem no meio da ação; a linha entra depois da linha do golpe.
func _on_status_applied(combatant: Combatant, effect: StatusEffect) -> void:
	_hud.log_message.call_deferred("%s: %s!" % [combatant.stats.display_name, effect.display_name])


func _on_status_expired(combatant: Combatant, effect: StatusEffect) -> void:
	_hud.log_message("%s: %s acabou." % [combatant.stats.display_name, effect.display_name])


func _on_status_ticked(combatant: Combatant, effect: StatusEffect, damage: int) -> void:
	_hud.log_message("%s sofre %d de %s." % [combatant.stats.display_name, damage, effect.display_name])


func _on_battle_ended(victory: bool) -> void:
	_hud.show_result(victory)
	AudioManager.stop_bgm(1.0)
	AudioManager.play_sfx(victory_sfx if victory else defeat_sfx)


func _on_play_again_requested() -> void:
	get_tree().reload_current_scene()


## Por enquanto fecha o jogo; quando existir menu principal, troca de cena aqui.
func _on_quit_requested() -> void:
	get_tree().quit()


func _log_skill(user: Combatant, skill: SkillData, outcome: Combatant.SkillOutcome) -> void:
	var parts: PackedStringArray = []
	for target: Combatant in outcome.hits:
		var hit: DamageCalculator.DamageResult = outcome.hits[target]
		parts.append("%s %d%s" % [target.stats.display_name, hit.amount, "!" if hit.is_critical else ""])
	if outcome.healed > 0:
		parts.append("+%d HP" % outcome.healed)
	var details: String = ": " + ", ".join(parts) if not parts.is_empty() else ""
	_hud.log_message("%s usa %s%s" % [user.stats.display_name, skill.display_name, details])


func _log_attack(actor: Combatant, target: Combatant, result: DamageCalculator.DamageResult, verb: String) -> void:
	if result == null:
		return
	var text: String = "%s %s %s: %d de dano" % [actor.stats.display_name, verb, target.stats.display_name, result.amount]
	if result.is_critical:
		text += " - CRÍTICO!"
	_hud.log_message(text)
