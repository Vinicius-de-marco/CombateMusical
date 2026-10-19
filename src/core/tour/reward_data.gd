class_name RewardData
extends Resource
## Melhoria escolhida na tela de recompensa entre shows. Vale para a banda inteira.
## Cada tipo usa só o seu grupo de campos.

enum Kind { UPGRADE, RESTORE, BUFF }

@export var id: StringName = &""
@export var display_name: String = "Recompensa"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.UPGRADE

@export_group("Upgrade (resto da turnê)")
@export_range(0, 99) var atk_bonus: int = 0
@export_range(0, 99) var def_bonus: int = 0

@export_group("Restore (na hora)")
## Fração do HP máximo recuperada (soma ao descanso do intervalo).
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.0
@export_range(0, 999) var volume_gain: int = 0

@export_group("Buff (próximo show)")
## Aplicado em todos os heróis no início do próximo show (inclusive nas tentativas de novo).
@export var next_show_effect: StatusEffect


static func kind_label(p_kind: Kind) -> String:
	match p_kind:
		Kind.UPGRADE:
			return "MELHORIA"
		Kind.RESTORE:
			return "RECUPERAÇÃO"
		_:
			return "BUFF"
