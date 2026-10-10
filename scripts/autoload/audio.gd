extends Node
## Звук: фоновая музыка с плавной сменой и пул голосов для эффектов.
## Громкость музыки и эффектов хранится в user://settings.cfg.
## Звуки — процедурные из tools/gen_audio.gd (заменяются файлами с теми же путями). Слой «напряжение»
## к музыке боя и петли окружения — SPEC_SPRINT9 12.

const MUSIC := {
	&"menu": "res://audio/music/menu.wav",
	&"battle": "res://audio/music/battle.wav",
	&"act2": "res://audio/music/act2.wav",
	&"boss": "res://audio/music/boss.wav",
	&"boss2": "res://audio/music/boss2.wav",
}
## Слои «напряжение» к трекам боя (SPEC_SPRINT9 12): та же длина — играют синхронно, громкость — от угрозы.
const MUSIC_LAYERS := {
	&"battle": "res://audio/music/battle_tension.wav",
	&"act2": "res://audio/music/act2_tension.wav",
}
## Петли окружения: тихо под музыкой, на своей шине.
const AMBIENCE := {
	&"archive": "res://audio/ambience/archive.wav",
	&"water": "res://audio/ambience/water.wav",
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
	# Удары по классам существ (SPEC_SPRINT9 12, UnitDef.sound_class).
	&"hit_metal": ["res://audio/sfx/hit_metal.wav", -7.0],
	&"hit_claw": ["res://audio/sfx/hit_claw.wav", -7.0],
	&"hit_magic": ["res://audio/sfx/hit_magic.wav", -8.0],
	&"hit_shard": ["res://audio/sfx/hit_shard.wav", -8.0],
	&"hit_heavy": ["res://audio/sfx/hit_heavy.wav", -5.0],
}

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const VOICES := 10
const FADE_TIME := 1.2
const MUSIC_BASE_DB := -6.0
## Один и тот же звук не чаще раза в это время (несколько попаданий в одном событии).
const MIN_REPEAT_MSEC := 40
const PITCH_JITTER := 0.05
## Разброс высоты ударов — повторы не режут слух.
const HIT_JITTER := 0.09
## Переход слоя напряжения и петель окружения.
const TENSION_FADE := 2.0
const AMBIENCE_FADE := 2.0
const AMBIENCE_BASE_DB := -14.0
const SILENT_DB := -80.0

var settings_path := "user://settings.cfg"
var music_volume := 0.7
var sfx_volume := 0.8
var ambience_volume := 0.6
var current_music := &""
var current_ambience := &""
## Напряжение боя 0..1 (громкость слоя «напряжение»).
var tension := 0.0
## Проверка сборки (--smoke) выключает музыку: без окна поток не успевает освободиться к выходу.
var music_allowed := true

var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _music_tween: Tween
var _tension_player: AudioStreamPlayer
var _tension_tween: Tween
var _ambience_player: AudioStreamPlayer
var _ambience_tween: Tween
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
	_ensure_bus(BUS_AMBIENCE)
	_tension_player = AudioStreamPlayer.new()
	_tension_player.bus = BUS_MUSIC
	_tension_player.volume_db = -80.0
	add_child(_tension_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.volume_db = -80.0
	add_child(_ambience_player)
	# Реверберация «зал» на музыке и звуках (SPEC_SPRINT9 12).
	_ensure_reverb(BUS_MUSIC, 0.12)
	_ensure_reverb(BUS_SFX, 0.18)
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
	for t in [_tension_tween, _ambience_tween]:
		if t:
			t.kill()
	for p in _music_players + _voices + [_tension_player, _ambience_player]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	current_music = &""
	current_ambience = &""
	tension = 0.0


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
	_start_layer(id, incoming)


## Слой «напряжение» трека id: запускается в одном кадре с треком (одинаковая длина — не расходятся),
## громкость — по текущему напряжению; у трека без слоя — слой затихает.
func _start_layer(id: StringName, track: AudioStreamPlayer) -> void:
	if _tension_tween:
		_tension_tween.kill()
	if not MUSIC_LAYERS.has(id):
		_tension_tween = create_tween()
		_tension_tween.tween_property(_tension_player, "volume_db", -80.0, FADE_TIME)
		_tension_tween.tween_callback(_tension_player.stop)
		return
	_tension_player.stream = _music_stream(MUSIC_LAYERS[id])
	_tension_player.volume_db = -80.0
	_tension_player.play(track.get_playback_position())
	_tension_tween = create_tween()
	_tension_tween.tween_property(_tension_player, "volume_db", tension_db(tension), FADE_TIME)


## Напряжение боя 0..1: громкость слоя плавно (TENSION_FADE) идёт к новому уровню.
func set_tension(value: float) -> void:
	tension = clampf(value, 0.0, 1.0)
	if not _tension_player.playing:
		return
	if _tension_tween:
		_tension_tween.kill()
	_tension_tween = create_tween()
	_tension_tween.tween_property(_tension_player, "volume_db", tension_db(tension), TENSION_FADE)


## Громкость слоя при напряжении value: 0 — тишина, 1 — как у трека.
static func tension_db(value: float) -> float:
	return SILENT_DB if value <= 0.01 else MUSIC_BASE_DB + linear_to_db(value)


## Петля окружения (&"" — тишина) с плавной сменой.
func play_ambience(id: StringName) -> void:
	if id == current_ambience or not music_allowed:
		return
	current_ambience = id
	if _ambience_tween:
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	if _ambience_player.playing:
		_ambience_tween.tween_property(_ambience_player, "volume_db", -80.0, AMBIENCE_FADE * 0.5)
		_ambience_tween.tween_callback(_ambience_player.stop)
	if not AMBIENCE.has(id):
		return
	_ambience_tween.tween_callback(func() -> void:
		_ambience_player.stream = _music_stream(AMBIENCE[id])
		_ambience_player.volume_db = -80.0
		_ambience_player.play())
	_ambience_tween.tween_property(_ambience_player, "volume_db", AMBIENCE_BASE_DB, AMBIENCE_FADE)


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


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_apply_volume(BUS_AMBIENCE, ambience_volume)
	save_settings()


func load_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
		ambience_volume = float(cfg.get_value("audio", "ambience", ambience_volume))
	_apply_volume(BUS_MUSIC, music_volume)
	_apply_volume(BUS_SFX, sfx_volume)
	_apply_volume(BUS_AMBIENCE, ambience_volume)


func save_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg == null:
		cfg = ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
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


## Реверберация «зал» на шине (один раз; wet — доля отражений).
static func _ensure_reverb(bus_name: StringName, wet: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectReverb:
			return
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.6
	reverb.damping = 0.55
	reverb.spread = 0.8
	reverb.wet = wet
	reverb.dry = 1.0
	AudioServer.add_bus_effect(idx, reverb)


static func _apply_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
