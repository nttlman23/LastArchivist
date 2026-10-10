extends GutTest
## Звук: файлы на месте, события боя озвучены, громкость сохраняется; этап B — слои, окружение, удары, синтез.

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
		SafeFile.remove(TEST_SETTINGS)


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


# --- Спринт 9, этап B (SPEC_SPRINT9 12) ---------------------------------------------------

func test_stage_b_streams_load() -> void:
	for id in Audio.MUSIC_LAYERS:
		assert_not_null(load(Audio.MUSIC_LAYERS[id]), "слой %s" % id)
	for id in Audio.AMBIENCE:
		assert_not_null(load(Audio.AMBIENCE[id]), "окружение %s" % id)


func test_layers_match_tracks() -> void:
	for id in Audio.MUSIC_LAYERS:
		var track := load(Audio.MUSIC[id]) as AudioStreamWAV
		var layer := load(Audio.MUSIC_LAYERS[id]) as AudioStreamWAV
		assert_eq(layer.data.size(), track.data.size(), "%s: слой той же длины — не расходится при зацикливании" % id)
		assert_eq(layer.mix_rate, track.mix_rate)


func test_tension_layer_follows_battle() -> void:
	Audio.play_music(&"menu")
	Audio.play_music(&"battle")
	assert_eq(Audio._tension_player.stream, Audio._music_stream(Audio.MUSIC_LAYERS[&"battle"]), "у боя — свой слой")
	Audio.set_tension(1.0)
	assert_eq(Audio.tension, 1.0)
	Audio.set_tension(2.0)
	assert_eq(Audio.tension, 1.0, "напряжение ограничено 0..1")
	assert_eq(Audio.tension_db(1.0), Audio.MUSIC_BASE_DB, "полное напряжение — громкость трека")
	assert_eq(Audio.tension_db(0.0), Audio.SILENT_DB)
	assert_lt(Audio.tension_db(0.3), Audio.tension_db(0.8), "больше угроза — громче слой")
	Audio.set_tension(0.0)
	Audio.play_music(&"menu")


func test_threat_tension() -> void:
	var s := TestHelpers.empty_battle()
	var mine := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 4))
	var foe := TestHelpers.add(s, UnitState.Side.ENEMY, Vector2i(10, 4), 10, {"speed": 2})
	s.round_number = 1
	var calm := ThreatMap.tension(s)
	assert_almost_eq(calm, 0.0, 0.001, "враг далеко, первый раунд — тихо")
	foe.hex = Vector2i(1, 4)
	var near := ThreatMap.tension(s)
	assert_almost_eq(near, ThreatMap.TENSION_THREAT, 0.001, "весь отряд под ударом")
	s.round_number = 1 + ThreatMap.TENSION_ROUNDS
	assert_almost_eq(ThreatMap.tension(s), 1.0, 0.001, "долгий бой и угроза — максимум")
	mine.count = 0
	assert_true(ThreatMap.tension(s) <= ThreatMap.TENSION_ROUND + 0.001, "без своих стеков — только раунд")


func test_hit_sounds_by_class() -> void:
	var db := DefsDB.load_default()
	for id in db.units:
		var cls := db.unit(id).sound_class
		if cls != &"":
			assert_true(Audio.SFX.has(StringName("hit_" + cls)), "%s: звук удара %s" % [id, cls])
	var s := TestHelpers.empty_battle()
	var a := s.add_unit(db.unit(&"salt_guard"), UnitState.Side.PLAYER, 5, Vector2i(0, 0))
	var b := s.add_unit(db.unit(&"archive_relic"), UnitState.Side.PLAYER, 1, Vector2i(0, 2))
	var hit := BattleEvent.new(BattleEvent.ATTACKED, {"attacker": a.uid, "ranged": false})
	assert_eq(BattleView.hit_sound(db, s, hit), &"hit_metal")
	var plain := BattleEvent.new(BattleEvent.ATTACKED, {"attacker": b.uid, "ranged": false})
	assert_eq(BattleView.hit_sound(db, s, plain), &"", "без класса — общий звук")


func test_synth_deterministic() -> void:
	var a := AudioSynth.new(7)
	var b := AudioSynth.new(7)
	a._wrap = false
	b._wrap = false
	assert_eq(a.sfx_hit_shard(), b.sfx_hit_shard(), "один сид — один звук")
	var buf_a := a._buffer(0.5)
	var buf_b := b._buffer(0.5)
	a._lute(buf_a, 0.0, 220.0, 0.3, 0.4)
	b._lute(buf_b, 0.0, 220.0, 0.3, 0.4)
	a._choir(buf_a, 0.0, 0.5, 220.0, 0.1, &"a")
	b._choir(buf_b, 0.0, 0.5, 220.0, 0.1, &"a")
	assert_eq(buf_a, buf_b, "лютня и хор детерминированы")
	assert_ne(AudioSynth.new(8).sfx_hit_shard(), AudioSynth.new(7).sfx_hit_shard(), "другой сид — другой звук")


func test_ambience_volume_and_scenes() -> void:
	Audio.set_ambience_volume(0.3)
	Audio.ambience_volume = 1.0
	Audio.load_settings()
	assert_almost_eq(Audio.ambience_volume, 0.3, 0.001, "громкость окружения сохраняется")
	var real_run := Game.run
	Game.run = null
	assert_eq(Game.scene_ambience(Game.SCENE_MAP), &"", "вне забега — тишина")
	Game.run = RunState.create(DefsDB.load_default(), 3)
	assert_eq(Game.scene_ambience(Game.SCENE_MAP), &"archive")
	assert_eq(Game.scene_ambience(Game.SCENE_MAIN_MENU), &"")
	Game.run.act = 2
	assert_eq(Game.scene_ambience(Game.SCENE_BATTLE), &"water")
	Game.run = real_run
