class_name CombatantStats
extends Resource
## Dados de atributos de um combatente. Salve variações como .tres.
## Em runtime, cada Combatant trabalha com uma cópia (duplicate(true)).

@export var display_name: String = "Combatant"

@export_group("Vitals")
@export_range(1, 9999) var max_hp: int = 100
## Volume = recurso das skills. Começa em starting_volume e sobe ao atacar.
@export_range(0, 999) var max_volume: int = 100
## Volume no início da batalha (ex.: elites/bosses que já abrem a luta com skill).
@export_range(0, 999) var starting_volume: int = 0

@export_group("Attributes")
@export_range(0, 999) var atk: int = 10
@export_range(0, 999) var def: int = 5
@export_range(0, 999) var spd: int = 10

@export_group("Critical")
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.05
@export_range(1.0, 5.0, 0.05) var crit_multiplier: float = 1.5

@export_group("Visual")
## Sprite de batalha (lido pelo componente CombatantVisuals).
@export var battle_sprite: Texture2D

@export_group("Audio")
## Som do ataque básico. Vazio = som padrão da batalha (BattleScene.attack_sfx).
@export var attack_sfx: AudioStream

## Valores de runtime (não exportados: não vão para o .tres).
var current_hp: int = 0
var current_volume: int = 0


func _init() -> void:
	reset_vitals()


## Estado de início de batalha: HP cheio, Volume em starting_volume.
func reset_vitals() -> void:
	current_hp = max_hp
	current_volume = mini(starting_volume, max_volume)


## Retorna o dano efetivamente aplicado.
func apply_damage(amount: int) -> int:
	var applied: int = mini(maxi(amount, 0), current_hp)
	current_hp -= applied
	return applied


## Retorna a cura efetivamente aplicada.
func apply_heal(amount: int) -> int:
	var applied: int = mini(maxi(amount, 0), max_hp - current_hp)
	current_hp += applied
	return applied


## Retorna o Volume efetivamente ganho (limitado a max_volume).
func gain_volume(amount: int) -> int:
	var applied: int = mini(maxi(amount, 0), max_volume - current_volume)
	current_volume += applied
	return applied


## Retorna false (sem gastar nada) se não houver Volume suficiente.
func consume_volume(amount: int) -> bool:
	if amount < 0 or amount > current_volume:
		return false
	current_volume -= amount
	return true
