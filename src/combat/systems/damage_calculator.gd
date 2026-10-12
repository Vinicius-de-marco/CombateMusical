class_name DamageCalculator
extends RefCounted
## Matemática de dano pura e estática. Não depende de nós de cena.
## Fórmula: max(1, round(ATK * skill_mult - DEF * 0.5)); crítico multiplica o resultado final.

const DEF_FACTOR: float = 0.5
const MIN_DAMAGE: int = 1


class DamageResult:
	extends RefCounted
	var amount: int
	var is_critical: bool

	func _init(p_amount: int, p_is_critical: bool) -> void:
		amount = p_amount
		is_critical = p_is_critical


## `rng` é opcional: passe um RandomNumberGenerator com seed fixa para testes determinísticos.
static func calculate(
		attacker: CombatantStats,
		target: CombatantStats,
		skill_multiplier: float = 1.0,
		rng: RandomNumberGenerator = null
) -> DamageResult:
	if attacker == null or target == null:
		push_error("DamageCalculator: attacker ou target nulo.")
		return DamageResult.new(0, false)
	return calculate_values(attacker.atk, target.def, attacker.crit_rate, attacker.crit_multiplier, skill_multiplier, rng)


## Versão com valores já resolvidos (ex.: ATK/DEF efetivos com status aplicados).
static func calculate_values(
		atk: int,
		def: int,
		crit_rate: float,
		crit_multiplier: float,
		skill_multiplier: float = 1.0,
		rng: RandomNumberGenerator = null
) -> DamageResult:
	var raw: float = atk * skill_multiplier - def * DEF_FACTOR
	var damage: int = maxi(MIN_DAMAGE, roundi(raw))

	var is_critical: bool = roll_critical(crit_rate, rng)
	if is_critical:
		damage = roundi(damage * crit_multiplier)

	return DamageResult.new(damage, is_critical)


static func roll_critical(crit_rate: float, rng: RandomNumberGenerator = null) -> bool:
	if crit_rate <= 0.0:
		return false
	var roll: float = rng.randf() if rng else randf()
	return roll <= crit_rate
