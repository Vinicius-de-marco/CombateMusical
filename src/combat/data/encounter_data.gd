class_name EncounterData
extends Resource
## Um show (encontro): local e formação de inimigos.
## A BattleScene instancia os inimigos; os heróis ficam fixos na Party da cena.

@export var venue_name: String = "Show"
## Frase curta da tela de abertura do show.
@export_multiline var tagline: String = ""
## Cenas de inimigo (herdadas de combatant.tscn), na ordem da formação.
@export var enemies: Array[PackedScene] = []
## Posição de cada inimigo, pareada com enemies. Vazio = posições padrão da BattleScene.
@export var positions: PackedVector2Array = PackedVector2Array()
