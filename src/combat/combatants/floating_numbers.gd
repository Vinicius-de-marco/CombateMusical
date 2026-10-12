class_name FloatingNumbers
extends Marker2D
## Componente: mostra números de dano/cura subindo a partir desta posição.
## Deve ser filho direto de um Combatant (posicione acima da cabeça).

const STATUS_Y_OFFSET: float = -14.0

@export_range(4.0, 96.0, 1.0) var rise_distance: float = 24.0
@export_range(0.2, 3.0, 0.1) var duration: float = 0.8
@export_range(6, 64) var font_size: int = 16
@export_range(1.0, 3.0, 0.1) var critical_scale: float = 1.5
@export var damage_color: Color = Color.WHITE
@export var critical_color: Color = Color(1.0, 0.85, 0.2)
@export var heal_color: Color = Color(0.4, 1.0, 0.5)


func _ready() -> void:
	var combatant: Combatant = get_parent() as Combatant
	if combatant == null:
		push_error("%s: precisa ser filho de um Combatant." % name)
		return
	combatant.damaged.connect(_on_damaged)
	combatant.healed.connect(_on_healed)
	combatant.status_applied.connect(_on_status_applied)


## y_offset negativo sobe o ponto de partida (evita sobrepor o número de dano do mesmo golpe).
func spawn(text: String, color: Color, scale_factor: float = 1.0, y_offset: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	# top_level: o número não acompanha a tremida/movimento do combatente.
	label.top_level = true
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * scale_factor
	var start: Vector2 = global_position - label.size / 2.0 + Vector2(randf_range(-6.0, 6.0), y_offset)
	label.global_position = start.round()

	var tween: Tween = label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", start.y - rise_distance, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(label.queue_free)


func _on_damaged(result: DamageCalculator.DamageResult) -> void:
	if result.is_critical:
		spawn("%d!" % result.amount, critical_color, critical_scale)
	else:
		spawn(str(result.amount), damage_color)


func _on_healed(amount: int) -> void:
	spawn("+%d" % amount, heal_color)


func _on_status_applied(_combatant: Combatant, effect: StatusEffect) -> void:
	spawn("%s!" % effect.display_name.to_upper(), effect.color, 0.8, STATUS_Y_OFFSET)
