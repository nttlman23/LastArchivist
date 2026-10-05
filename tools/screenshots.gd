extends Node
## Скриншоты экранов (SPEC_SPRINT9): меню, достижения, ежедневный забег, карта, подготовка, бой (покой и в процессе), награда.
## Запуск: godot --path . res://tools/screenshots.tscn [-- папка] (нужно окно, не --headless).
## Профиль и сохранение — временные. По умолчанию снимки — в user://screenshots/.

var out_dir := "user://screenshots"


func _ready() -> void:
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.profile_path = "user://profile_shots.cfg"
	Game.profile = ProfileState.new()
	SaveService.current_path = "user://profile_shots_save.json"
	SaveService.daily_path = "user://profile_shots_daily.json"
	Settings.hints = false
	Game.run = null
	Game.goto(Game.SCENE_MAIN_MENU)
	await _shot("menu")
	# Достижения и ежедневный забег (SPEC_SPRINT9 6–7): часть достижений и история с пропусками дней.
	for id in [&"first_chapter", &"no_losses", &"miser", &"collector", &"lightning", &"daily_three"]:
		Achievements.grant(Game.defs, Game.profile, id, "2026-10-0%d" % (Game.profile.achievements.size() + 1))
	Game.goto(Game.SCENE_ACHIEVEMENTS)
	await _shot("achievements")
	var today := DailyRun.today()
	var outcomes := [ProfileState.OUTCOME_LOST, ProfileState.OUTCOME_WON, ProfileState.OUTCOME_ABANDONED]
	for d in range(28, 0, -1):
		if d % 5 == 3:
			continue
		var l := DailyRun.layout(Game.defs, Game.profile, DailyRun.shift_date(today, -d))
		Game.profile.record_daily({"date": DailyRun.shift_date(today, -d), "school": String(l["school"]), "modifiers": l["modifiers"],
				"layer": 4 + (d * 7) % 12, "score": 60 + (d * 37) % 240, "outcome": outcomes[d % 3]})
	Game.goto(Game.SCENE_DAILY)
	await _shot("daily")
	Game.run = DailyRun.create(Game.defs, Game.profile, today)
	Game.goto(Game.SCENE_MAP)
	Game._notify([&"four_wars"] as Array[StringName])
	await _shot("map_daily")
	Game.run = RunState.create(Game.defs, 7)
	Game.goto(Game.SCENE_MAP)
	await _shot("map")
	MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])
	Game.goto(Game.SCENE_PREP)
	await _shot("prep")
	for id in [&"shard_archers"]:
		Game.run.codex.add(Game.defs, id)
	Game.run.pending_battle = &"elite_fortress"
	Game.selected = [0, 1, 2, 3, 4]
	Game.goto(Game.SCENE_BATTLE)
	await _shot("battle", 2.0)
	var screen := get_tree().current_scene
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and screen.state.outcome == BattleState.Outcome.NONE:
		if not screen._busy and screen._is_player_turn():
			var s: BattleState = screen.state
			var hero := HeroAi.choose(s) if s.can_hero_act() else null
			screen._player_act(hero if hero else AiController.choose_action(s, s.active_uid))
		await get_tree().process_frame
	await _shot("battle_fight", 0.1)
	Game.run.pending_battle = &"rift"
	Game.goto(Game.SCENE_BATTLE)
	await _shot("battle_boss", 2.0)
	Game.goto(Game.SCENE_REWARD)
	await _shot("reward")
	SafeFile.remove(Game.profile_path)
	SafeFile.remove(SaveService.current_path)
	print("SHOTS: %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(name: String, wait: float = 1.2) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir.path_join(name + ".png")))
