class_name SkillData
extends Resource
## Definição de uma skill: custo em Volume, tipo de alvo, dano e/ou cura.

## ALL_ALLIES fica no fim: os .tres guardam o índice do enum.
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SELF, ALL_ALLIES }

@export var display_name: String = "Skill"
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export_range(0, 999) var volume_cost: int = 30
## Multiplicador sobre o ATK. 0 = skill sem dano. Ignorado em skills de aliados (SELF/ALL_ALLIES).
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0
## Cura como fração do max_hp do alvo (0.3 = 30%). 0 = sem cura.
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.0
## Som tocado ao usar a skill (via AudioManager).
@export var sfx: AudioStream

@export_group("Status Effects")
## Efeitos aplicados em cada alvo atingido.
@export var applies_effects: Array[StatusEffect] = []
## Chance rolada por alvo e por efeito (1.0 = sempre).
@export_range(0.0, 1.0, 0.05) var effect_chance: float = 1.0


## Só SINGLE_ENEMY pede escolha de alvo no HUD.
func needs_target_selection() -> bool:
	return target_type == TargetType.SINGLE_ENEMY


## Skills de suporte: miram o próprio time (nunca causam dano).
func targets_allies() -> bool:
	return target_type == TargetType.SELF or target_type == TargetType.ALL_ALLIES


func deals_damage() -> bool:
	return damage_multiplier > 0.0 and not targets_allies()


func heals() -> bool:
	return heal_ratio > 0.0
