class_name TourData
extends Resource
## Sequência de shows de uma turnê.

@export var shows: Array[EncounterData] = []
## Fração do HP máximo recuperada no intervalo entre shows. Quem caiu volta com essa fração.
@export_range(0.0, 1.0, 0.05) var rest_heal_ratio: float = 0.3

@export_group("Rewards")
## Recompensas que podem ser oferecidas depois de cada show (menos o último).
@export var reward_pool: Array[RewardData] = []
## Quantas opções a tela de recompensa mostra (uma de cada tipo, quando possível).
@export_range(1, 6) var reward_choices: int = 3
