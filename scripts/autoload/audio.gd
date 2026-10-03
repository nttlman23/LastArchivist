extends Node
## Звук: фоновая музыка с плавной сменой и пул голосов для эффектов.
## Громкость музыки и эффектов хранится в user://settings.cfg.
## Сами звуки — плейсхолдеры из tools/gen_audio.gd; заменяются файлами с теми же путями.

const MUSIC := {
	&"menu": "res://audio/music/menu.wav",
	&"battle": "res://audio/music/battle.wav",
}
## id -> [путь, громкость дБ]
const SFX := {
	&"ui_click": ["res://audio/sfx/ui_click.wav", -10.0],
	&"card": ["res://audio/sfx/card.wav", -8.0],
	&"transform": ["res://audio/sfx/transform.wav", -6.0],
	&"move": ["res://audio/sfx/move.wav", -12.0],
	&"melee": ["res://audio/sfx/melee.wav", -6.0],
	&"shoot": ["res://audio/sfx/shoot.wav", -8.0],
	&"impact": ["res://audio/sfx/impact.wav", -9.0],
	&"death": ["res://audio/sfx/death.wav", -7.0],
	&"ability": ["res://audio/sfx/ability.wav", -8.0],
	&"spell": ["res://audio/sfx/spell.wav", -6.0],
	&"order": ["res://audio/sfx/order.wav", -9.0],
	&"heal": ["res://audio/sfx/heal.wav", -9.0],
	&"wall": ["res://audio/sfx/wall.wav", -7.0],
	&"push": ["res://audio/sfx/push.wav", -7.0],
	&"turn": ["res://audio/sfx/turn.wav", -14.0],
	&"erase": ["res://audio/sfx/erase.wav", -4.0],
	&"victory": ["res://audio/sfx/victory.wav", -4.0],
	&"defeat": ["res://audio/sfx/defeat.wav", -4.0],
}

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const VOICES := 10
const FADE_TIME := 1.2
const MUSIC_BASE_DB := -6.0
## Один и тот же звук не чаще раза в это время (несколько попаданий в одном событии).
const MIN_REPEAT_MSEC := 40
const PITCH_JITTER := 0.05

var settings_path := "user://settings.cfg"
var music_volume := 0.7
var sfx_volume := 0.8
var current_music := &""
## Проверка сборки (--smoke) выключает музыку: без окна поток не успевает освободиться к выходу.
var music_allowed := true

var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _music_tween: Tween
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary[String, AudioStream] = {}
var _last_played: Dictionary[StringName, int] = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_MUSIC
		p.volume_db = -80.0
		add_child(p)
		_music_players.append(p)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = BUS_SFX
		add_child(v)
		_voices.append(v)
	load_settings()


## Плавно переключает музыку; повторный вызов с той же темой ничего не делает.
## При выходе останавливаем все голоса: иначе потоки воспроизведения остаются у аудиосервера
## и движок сообщает об утечке (SPEC_SPRINT6 11).
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		stop_all()


func stop_all() -> void:
	if _music_tween:
		_music_tween.kill()
	for p in _music_players + _voices:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	current_music = &""


func play_music(id: StringName) -> void:
	if id == current_music or not MUSIC.has(id) or not music_allowed:
		return
	current_music = id
	var stream := _music_stream(MUSIC[id])
	var old := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(incoming, "volume_db", MUSIC_BASE_DB, FADE_TIME)
	_music_tween.tween_property(old, "volume_db", -60.0, FADE_TIME)
	_music_tween.chain().tween_callback(old.stop)


func play(id: StringName, jitter: float = PITCH_JITTER) -> void:
	if not SFX.has(id):
		push_warning("Unknown sound %s" % id)
		return
	var now := Time.get_ticks_msec()
	if now - _last_played.get(id, -MIN_REPEAT_MSEC) < MIN_REPEAT_MSEC:
		return
	_last_played[id] = now
	var entry: Array = SFX[id]
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = _load(entry[0])
	v.volume_db = entry[1]
	v.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	v.play()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(BUS_MUSIC, music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume(BUS_SFX, sfx_volume)
	save_settings()


func load_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volume(BUS_MUSIC, music_volume)
	_apply_volume(BUS_SFX, sfx_volume)


func save_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg == null:
		cfg = ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	SafeFile.save_config(cfg, settings_path)


func _music_stream(path: String) -> AudioStream:
	var stream := _load(path)
	var wav := stream as AudioStreamWAV
	if wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


static func _apply_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
