class_name StageBackground
extends Control
## Fundo temporário de palco de show: parede em degradê, piso, caixas de som
## e refletores que balançam. Tudo desenhado em _draw (sem texturas).
## Deve ficar num CanvasLayer com layer negativo (atrás dos combatentes e do HUD).

const BEAM_SOURCE_Y: float = -8.0
const POOL_SEGMENTS: int = 24
## Fração do piso (a partir da borda do palco) onde os fachos tocam o chão.
const BEAM_LANDING_DEPTH: float = 0.45

@export_group("Parede")
@export var wall_top_color: Color = Color(0.02, 0.01, 0.04)
@export var wall_bottom_color: Color = Color(0.17, 0.03, 0.11)

@export_group("Piso")
## Altura da borda do palco, como fração da altura da tela.
@export_range(0.2, 0.9, 0.01) var floor_line: float = 0.42
@export var floor_color: Color = Color(0.08, 0.05, 0.07)
@export var floor_edge_color: Color = Color(0.42, 0.10, 0.20)
@export_range(4, 64) var plank_spacing: int = 12

@export_group("Refletores")
## Posição horizontal de cada refletor (fração da largura). Pareado com spotlight_colors.
@export var spotlight_positions: PackedFloat32Array = PackedFloat32Array([0.12, 0.38, 0.62, 0.88])
@export var spotlight_colors: PackedColorArray = PackedColorArray([
	Color(1.0, 0.25, 0.55), Color(1.0, 0.7, 0.3), Color(0.35, 0.6, 1.0), Color(0.85, 0.3, 1.0),
])
@export_range(0.0, 1.0, 0.01) var beam_alpha: float = 0.11
## Meia largura do facho ao tocar o chão, como fração da largura da tela.
@export_range(0.01, 0.5, 0.01) var beam_half_width: float = 0.08
@export_range(0.0, 45.0, 1.0) var sway_degrees: float = 14.0
## 0 = refletores parados (sem redesenhar a cada frame).
@export_range(0.0, 3.0, 0.05) var sway_speed: float = 0.5

@export_group("Caixas de som")
@export var speaker_color: Color = Color(0.06, 0.05, 0.06)
@export var speaker_grill_color: Color = Color(0.12, 0.10, 0.12)
@export var speaker_size: Vector2 = Vector2(40, 34)

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(sway_speed > 0.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var floor_y: float = roundf(size.y * floor_line)
	_draw_wall(floor_y)
	_draw_floor(floor_y)
	_draw_speakers(floor_y)
	_draw_spotlights(floor_y)


func _draw_wall(floor_y: float) -> void:
	_draw_vertical_gradient(Rect2(0.0, 0.0, size.x, floor_y), wall_top_color, wall_bottom_color)


func _draw_floor(floor_y: float) -> void:
	draw_rect(Rect2(0.0, floor_y, size.x, size.y - floor_y), floor_color)
	var plank_color: Color = floor_color.lightened(0.06)
	var y: float = floor_y + plank_spacing
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), plank_color)
		y += plank_spacing
	# Borda do palco: faixa clara que separa parede e piso.
	draw_rect(Rect2(0.0, floor_y, size.x, 2.0), floor_edge_color)


## Uma pilha de duas caixas em cada lateral, apoiada no piso.
func _draw_speakers(floor_y: float) -> void:
	var margin: float = 6.0
	var base_y: float = floor_y + speaker_size.y * 0.5
	for x: float in [margin, size.x - margin - speaker_size.x]:
		for level: int in 2:
			var top_left := Vector2(x, base_y - speaker_size.y * (level + 1))
			_draw_speaker(Rect2(top_left.round(), speaker_size))


func _draw_speaker(cabinet: Rect2) -> void:
	draw_rect(cabinet, speaker_color)
	var grill: Rect2 = cabinet.grow(-3.0)
	draw_rect(grill, speaker_grill_color)
	var radius: float = minf(grill.size.x * 0.25, grill.size.y * 0.4)
	var cone_y: float = grill.get_center().y
	for fraction: float in [0.27, 0.73]:
		var center := Vector2(grill.position.x + grill.size.x * fraction, cone_y)
		draw_circle(center, radius, speaker_color)
		draw_circle(center, radius * 0.35, speaker_grill_color.lightened(0.1))


func _draw_spotlights(floor_y: float) -> void:
	var landing_y: float = floor_y + (size.y - floor_y) * BEAM_LANDING_DEPTH
	var half_width: float = size.x * beam_half_width
	var count: int = mini(spotlight_positions.size(), spotlight_colors.size())
	for i: int in count:
		var source := Vector2(size.x * spotlight_positions[i], BEAM_SOURCE_Y)
		# Fases diferentes por refletor: cada um balança no seu ritmo.
		var angle: float = sin(_time * sway_speed + i * 1.7) * deg_to_rad(sway_degrees)
		var landing := Vector2(source.x + tan(angle) * (landing_y - source.y), landing_y)
		var color: Color = spotlight_colors[i]
		_draw_beam(source, landing, half_width, color)
		_draw_light_pool(landing, half_width, color)
		# Carcaça do refletor no alto da tela.
		draw_rect(Rect2(source.x - 5.0, 0.0, 10.0, 5.0), color.darkened(0.6))


## Facho em trapézio: forte perto do refletor, desbotando até o chão.
func _draw_beam(source: Vector2, landing: Vector2, half_width: float, color: Color) -> void:
	var points := PackedVector2Array([
		source + Vector2(-3.0, 0.0),
		source + Vector2(3.0, 0.0),
		landing + Vector2(half_width, 0.0),
		landing + Vector2(-half_width, 0.0),
	])
	var near := Color(color, beam_alpha * 1.6)
	var far := Color(color, beam_alpha * 0.5)
	draw_polygon(points, PackedColorArray([near, near, far, far]))


## Elipse de luz no piso, achatada para dar perspectiva.
func _draw_light_pool(center: Vector2, half_width: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in POOL_SEGMENTS:
		var theta: float = TAU * i / POOL_SEGMENTS
		points.append(center + Vector2(cos(theta) * half_width, sin(theta) * half_width * 0.22))
	draw_colored_polygon(points, Color(color, beam_alpha * 1.2))


func _draw_vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
