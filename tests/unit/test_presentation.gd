extends GutTest
## Этап A Спринта 6: эффекты, намерения врагов, лучший Кодекс, настройки подачи.

const SETTINGS_PATH := "user://test_presentation_settings.cfg"

var db: DefsDB
var _real_settings: Array


func before_all() -> void:
	db = DefsDB.load_default()
	_real_settings = [Settings.settings_path, Settings.anim_speed, Settings.screen_shake, Settings.effects_full]


func after_all() -> void:
	Settings.settings_path = _real_settings[0]
	Settings.anim_speed = _real_settings[1]
	Settings.screen_shake = _real_settings[2]
	Settings.effects_full = _real_settings[3]
	if FileAccess.file_exists(SETTINGS_PATH):
		SafeFile.remove(SETTINGS_PATH)


func _battle(enc: StringName) -> BattleState:
	var c := CodexState.new()
	for id in [&"salt_legion", &"ghoul_pack", &"ash_chroniclers"]:
		c.add(db, id)
	var s := BattleState.create(db, db.encounter(enc), c, [0, 1, 2], 3)
	BattleResolver.begin(s)
	return s


# --- Эффекты ------------------------------------------------------------------------

func test_fx_pool_limit_and_reuse() -> void:
	Settings.effects_full = true
	var pool := FxPool.new()
	add_child_autofree(pool)
	for i in FxPool.MAX_EMITTERS:
		assert_true(pool.burst(FxPool.SPARK, Vector2.ZERO))
	assert_false(pool.burst(FxPool.ASH, Vector2.ZERO), "сверх лимита — отказ")
	assert_eq(pool.get_child_count(), FxPool.MAX_EMITTERS)
	for p: CPUParticles2D in pool.get_children():
		p.emitting = false
	assert_true(pool.burst(FxPool.HEAL, Vector2.ZERO), "свободный эмиттер берётся снова")
	assert_eq(pool.get_child_count(), FxPool.MAX_EMITTERS, "новых узлов не создано")


func test_fx_off_in_simple_mode() -> void:
	Settings.effects_full = false
	var pool := FxPool.new()
	add_child_autofree(pool)
	assert_false(pool.burst(FxPool.MAGIC, Vector2.ZERO, Color.RED))
	assert_eq(pool.get_child_count(), 0)
	Settings.effects_full = true


func test_presentation_settings_persist() -> void:
	Settings.settings_path = SETTINGS_PATH
	Settings.set_anim_speed(2.0)
	Settings.set_screen_shake(false)
	Settings.set_effects_full(false)
	Settings.anim_speed = 1.0
	Settings.screen_shake = true
	Settings.effects_full = true
	Settings.load_settings()
	assert_eq(Settings.anim_speed, 2.0)
	assert_false(Settings.screen_shake)
	assert_false(Settings.effects_full)
	Settings.effects_full = true


# --- Намерения врагов -----------------------------------------------------------

func test_intent_matches_actual_enemy_turn() -> void:
	var s := _battle(&"t1_priests")
	# Пропускаем ходы игрока защитой, пока не походит первый враг.
	while s.active_unit().side == UnitState.Side.PLAYER:
		BattleResolver.apply(s, BattleAction.defend())
	var enemy := s.active_unit()
	var predicted := EnemyIntents.predict(s)
	var actual := AiController.choose_action(s, enemy.uid)
	assert_true(predicted.has(enemy.uid))
	assert_eq(predicted[enemy.uid]["type"], actual.type)
	assert_eq(predicted[enemy.uid]["target"], actual.target_uid)


func test_intent_does_not_change_state() -> void:
	var s := _battle(&"t2_storm")
	var before := s.to_dict()
	var intents := EnemyIntents.predict(s)
	assert_eq(intents.size(), s.alive(UnitState.Side.ENEMY).size())
	assert_eq(s.to_dict(), before, "копия боя, исходный не меняется")


# --- Лучший Кодекс ----------------------------------------------------------------

func test_best_codex_rule() -> void:
	var p := ProfileState.new()
	var base := {"school": "ash_archive", "outcome": ProfileState.OUTCOME_WON, "layer": 8}
	var e1 := base.merged({"difficulty": "normal", "lost": 3, "codex": ["a"]})
	var e2 := base.merged({"difficulty": "easy", "lost": 0, "codex": ["b"]})
	var e3 := base.merged({"difficulty": "normal", "lost": 1, "codex": ["c"]})
	var e4 := base.merged({"difficulty": "hard", "lost": 5, "codex": ["d"]})
	p.record_run(e1)
	assert_eq(p.school_stats[&"ash_archive"]["best_codex"]["codex"], ["a"])
	p.record_run(e2)
	assert_eq(p.school_stats[&"ash_archive"]["best_codex"]["codex"], ["a"], "«Легко» хуже «Нормально»")
	p.record_run(e3)
	assert_eq(p.school_stats[&"ash_archive"]["best_codex"]["codex"], ["c"], "меньше потерь")
	p.record_run(e4)
	assert_eq(p.school_stats[&"ash_archive"]["best_codex"]["codex"], ["d"], "сложность важнее потерь")
	p.record_run(base.merged({"outcome": ProfileState.OUTCOME_LOST, "difficulty": "hard", "lost": 0, "codex": ["x"]}, true))
	assert_eq(p.school_stats[&"ash_archive"]["best_codex"]["codex"], ["d"], "поражение не считается")


func test_cards_lost_counted_and_saved() -> void:
	var run := RunState.create(db, 5)
	run.codex.cards[0].durability = 1
	var gone := run.after_battle(db, [0] as Array[int])
	assert_eq(gone.size(), 1)
	assert_eq(run.cards_lost, 1)
	assert_eq(RunState.from_dict(run.to_dict()).cards_lost, 1)
	var p := ProfileState.new()
	MetaRewards.finish_run(p, run, true, db)
	assert_eq(p.school_stats[run.school_id]["best_codex"]["lost"], 1)


func test_battle_scene_simple_effects() -> void:
	Settings.effects_full = false
	Game.run = RunState.create(db, 3)
	Game.selected = [0, 1, 2, 3]
	MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	assert_not_null(scene.view)
	Settings.effects_full = true
	Game.run = null
