extends Node
## Autoload "AudioManager" (sem class_name para não conflitar com o nome do autoload).
## SFX: pool de players no bus SFX (sons podem se sobrepor).
## BGM: um player no bus BGM com fade.

const SFX_BUS: StringName = &"SFX"
const BGM_BUS: StringName = &"BGM"
const SFX_POOL_SIZE: int = 8
const SILENT_DB: float = -40.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_index: int = 0
var _bgm_player: AudioStreamPlayer
var _bgm_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua tocando com o jogo pausado
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BGM_BUS
	add_child(_bgm_player)


func _exit_tree() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


## pitch_variation: 0.1 = ±10% de pitch aleatório (evita repetição robótica).
func play_sfx(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.1, 1.0 + randf_range(-pitch_variation, pitch_variation))
	player.play()


func play_bgm(stream: AudioStream, fade_duration: float = 1.0) -> void:
	if stream == null:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		# Mesma faixa (ex.: reload da cena durante o fade-out do fim da batalha):
		# cancela o fade e volta ao volume normal em vez de deixar parar.
		_bgm_tween = _restart_bgm_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_duration * 0.5)
		return
	_bgm_tween = _restart_bgm_tween()
	if _bgm_player.playing:
		_bgm_tween.tween_property(_bgm_player, "volume_db", SILENT_DB, fade_duration * 0.5)
	_bgm_tween.tween_callback(_start_bgm.bind(stream))
	_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_duration * 0.5)


func stop_bgm(fade_duration: float = 1.0) -> void:
	if not _bgm_player.playing:
		return
	_bgm_tween = _restart_bgm_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", SILENT_DB, fade_duration)
	_bgm_tween.tween_callback(_bgm_player.stop)


## Volume linear 0.0–1.0 de um bus (para um futuro menu de opções).
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("AudioManager: bus '%s' não existe." % bus_name)
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	if clamped > 0.001:
		AudioServer.set_bus_volume_db(index, linear_to_db(clamped))


## Prefere um player livre; se todos estiverem ocupados, reaproveita em rodízio.
func _get_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	var reused: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return reused


func _start_bgm(stream: AudioStream) -> void:
	_bgm_player.stream = stream
	_bgm_player.volume_db = SILENT_DB
	_bgm_player.play()


func _restart_bgm_tween() -> Tween:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	return create_tween()
