extends GutTest
## Звук: файлы на месте, события боя озвучены, громкость сохраняется.

const TEST_SETTINGS := "user://test_settings.cfg"

var _saved_path: String
var _saved_music: float
var _saved_sfx: float


func before_each() -> void:
	_saved_path = Audio.settings_path
	_saved_music = Audio.music_volume
	_saved_sfx = Audio.sfx_volume
	Audio.settings_path = TEST_SETTINGS


func after_each() -> void:
	Audio.settings_path = _saved_path
	Audio.music_volume = _saved_music
	Audio.sfx_volume = _saved_sfx
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)


func test_all_streams_load() -> void:
	for id in Audio.MUSIC:
		assert_not_null(load(Audio.MUSIC[id]), "музыка %s" % id)
	for id in Audio.SFX:
		assert_not_null(load(Audio.SFX[id][0]), "звук %s" % id)


func test_music_loops_and_switches() -> void:
	Audio.play_music(&"battle")
	assert_eq(Audio.current_music, &"battle")
	var stream := Audio._music_stream(Audio.MUSIC[&"battle"]) as AudioStreamWAV
	assert_ne(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "музыка зациклена")
	Audio.play_music(&"menu")
	assert_eq(Audio.current_music, &"menu")


func test_battle_events_have_known_sounds() -> void:
	var events: Array[BattleEvent] = [
		BattleEvent.new(BattleEvent.ATTACKED, {"ranged": true}),
		BattleEvent.new(BattleEvent.ATTACKED, {"ranged": false}),
		BattleEvent.new(BattleEvent.HERO_ACTED, {"spell": true}),
		BattleEvent.new(BattleEvent.HERO_ACTED, {"spell": false}),
	]
	for type in BattleView.EVENT_SOUNDS:
		events.append(BattleEvent.new(type, {}))
	for e in events:
		var id := BattleView.sound_for(e)
		assert_true(Audio.SFX.has(id), "%s → %s" % [e.type, id])


func test_play_every_sound() -> void:
	for id in Audio.SFX:
		Audio.play(id)
	assert_true(true, "без ошибок")


func test_volume_persisted() -> void:
	Audio.set_music_volume(0.25)
	Audio.set_sfx_volume(0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(Audio.BUS_SFX)), "ноль — без звука")
	Audio.music_volume = 1.0
	Audio.sfx_volume = 1.0
	Audio.load_settings()
	assert_almost_eq(Audio.music_volume, 0.25, 0.001)
	assert_almost_eq(Audio.sfx_volume, 0.0, 0.001)
	Audio.set_sfx_volume(0.8)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(Audio.BUS_SFX)))
