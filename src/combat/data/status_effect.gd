class_name StatusEffect
extends Resource
## Definição de um efeito de status (buff, debuff ou dano por turno).
## Reaplicar o mesmo id renova a duração, sem acumular.

@export var id: StringName = &""
@export var display_name: String = "Status"
## Turnos do AFETADO (a duração cai no fim de cada turno dele).
@export_range(1, 99) var duration_turns: int = 2

@export_group("Modifiers")
## +0.3 = +30% de ATK; -0.4 = -40%.
@export_range(-1.0, 2.0, 0.05) var atk_ratio: float = 0.0
@export_range(-1.0, 2.0, 0.05) var def_ratio: float = 0.0
## Dano no início de cada turno, como fração do max_hp (mínimo 1).
@export_range(0.0, 1.0, 0.01) var dot_ratio: float = 0.0

@export_group("Visual")
@export var color: Color = Color.WHITE


func is_harmful() -> bool:
	return atk_ratio < 0.0 or def_ratio < 0.0 or dot_ratio > 0.0
