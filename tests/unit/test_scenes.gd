extends GutTest
## Smoke-тесты экранов: сцены создаются и работают без ошибок движка.

const SCENES := [
	"res://scenes/main_menu/main_menu.tscn",
	"res://scenes/prep/prep.tscn",
	"res://scenes/reward/reward.tscn",
	"res://scenes/run_end/run_end.tscn",
]


func before_each() -> void:
	Game.run = RunState.create(Game.defs, 3)
	Game.selected = [0, 1, 2, 3]
	# Бой и подготовка открываются для начатого острова; на 1-м слое — всегда бои.
	MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])


func after_all() -> void:
	Game.run = null


func test_static_screens_build() -> void:
	for path: String in SCENES:
		var scene: Node = load(path).instantiate()
		add_child_autofree(scene)
		await wait_physics_frames(2)
		assert_gt(scene.get_child_count(), 0, path)


func test_battle_plays_ai_turns_until_player() -> void:
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_seconds(3.0)
	var state: BattleState = scene.state
	assert_eq(state.round_number, 1)
	assert_eq(state.active_unit().side, UnitState.Side.PLAYER, "AI отходил, ждём игрока")


func test_battle_player_actions() -> void:
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_seconds(3.0)
	var state: BattleState = scene.state
	var acted := state.active_uid
	scene._on_defend()
	await wait_seconds(3.0)
	assert_ne(state.active_uid, acted)
	assert_true(state.get_unit(acted).defending or state.active_uid == -1 or state.round_number > 1)


func test_cursor_picks_action() -> void:
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_seconds(3.0)
	var state: BattleState = scene.state
	var view: BattleView = scene.view
	var u := state.active_unit()
	var enemy := state.alive(UnitState.Side.ENEMY)[0]
	var at_enemy: BattleAction = scene._action_at(view.hex_center(enemy.hex), enemy.hex)
	if u.can_shoot() and not state.is_blocked(u):
		assert_eq(at_enemy.type, BattleAction.Type.SHOOT)
	var reach := Pathfinding.reachable(state, u)
	var dest: Vector2i = reach.keys()[0]
	var move: BattleAction = scene._action_at(view.hex_center(dest), dest)
	assert_eq(move.type, BattleAction.Type.MOVE)
	assert_null(scene._action_at(Vector2(-500, -500), Vector2i(-1, -1)))


func test_melee_side_follows_cursor() -> void:
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_seconds(0.5)
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(3, 4), 10, {"speed": 5})
	var e := TestHelpers.add(s, 1, Vector2i(5, 4), 10)
	TestHelpers.activate(s, u)
	scene.state = s
	scene.view.state = s
	scene.view.reachable = Pathfinding.reachable(s, u)
	var center: Vector2 = scene.view.hex_center(e.hex)
	var left: BattleAction = scene._melee_from_cursor(u, e, center + Vector2(-30, 0))
	var right: BattleAction = scene._melee_from_cursor(u, e, center + Vector2(30, 0))
	assert_eq(left.dest, Vector2i(4, 4))
	assert_eq(right.dest, Vector2i(6, 4))


func _icons(u: UnitState) -> Array:
	return UnitInfoPanel.abilities_of(Game.defs, u).map(func(e: Array) -> StringName: return e[0])


func test_abilities_reflect_state() -> void:
	var s := TestHelpers.empty_battle()
	var archer := TestHelpers.add(s, 0, Vector2i(0, 0), 5, {"is_ranged": true, "shots": 3, "is_flying": true})
	assert_eq(_icons(archer), [UnitGlyphs.ICON_RANGED, UnitGlyphs.ICON_FLYING, UnitGlyphs.ICON_RETALIATION])
	var guard := TestHelpers.add(s, 1, Vector2i(5, 0), 5)
	guard.retaliated = true
	guard.defending = true
	guard.waited = true
	assert_eq(_icons(guard), [UnitGlyphs.ICON_MELEE, UnitGlyphs.ICON_RETALIATION_USED, UnitGlyphs.ICON_DEFEND, UnitGlyphs.ICON_WAIT])
	var priest := TestHelpers.add(s, 1, Vector2i(6, 0), 5, {"ability_id": Abilities.RESTORE})
	priest.ability_cd = 1
	priest.statuses[UnitState.STATUS_MARKED] = UnitState.PERMANENT
	assert_eq(_icons(priest), [UnitGlyphs.ICON_ABILITY, UnitGlyphs.ICON_MELEE, UnitGlyphs.ICON_RETALIATION, UnitGlyphs.ICON_MARK])
	assert_false(UnitInfoPanel.abilities_of(Game.defs, priest)[0][2], "способность на перезарядке — серая")


func test_memory_screen_forms() -> void:
	Game.run.codex.add(Game.defs, &"last_king")
	Game.last_faded = [&"storm_wyrm"]
	var scene: Node = load("res://scenes/reward/reward.tscn").instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	for key: String in scene.FORM_KEYS.values():
		assert_ne(tr(key), key, "перевод %s" % key)
	# Легион: пара есть; жертва бесполезна — все карты целы.
	scene._on_select_card(0)
	await wait_physics_frames(1)
	var buttons: Array = scene._forms_box.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_eq(buttons.size(), 4)
	assert_eq(buttons.filter(func(b: Button) -> bool: return b.disabled).size(), 1)
	assert_true(buttons[2].disabled, "жертва недоступна")
	assert_string_contains(buttons[3].text, "18")
	# Король: всё недоступно.
	scene._on_select_card(Game.run.codex.cards.size() - 1)
	await wait_physics_frames(1)
	buttons = scene._forms_box.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_eq(buttons.filter(func(b: Button) -> bool: return b.disabled).size(), 4)
	Game.last_faded = []


func test_prep_excludes_hero_cards() -> void:
	Game.run.codex.add(Game.defs, &"last_king")
	var scene: Node = load("res://scenes/prep/prep.tscn").instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	assert_eq(scene._selected, [0, 1, 2, 3] as Array[int])
	assert_false(scene._buttons.has(4), "геройская карта не выбирается")


func test_battle_hero_panel() -> void:
	Game.run.hero.spells.append(HeroState.SpellSlot.new(&"ash_record", 2, &"ash_chroniclers"))
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(scene)
	await wait_seconds(3.0)
	var state: BattleState = scene.state
	assert_eq(state.active_unit().side, UnitState.Side.PLAYER)
	assert_eq(scene._hero_entries.size(), 3, "2 приказа + заклинание")
	var enemy := state.alive(UnitState.Side.ENEMY)[0]
	scene._on_hero(2)
	assert_false(scene._targeting.is_empty(), "включился выбор цели")
	scene._cancel_targeting()
	assert_true(scene._targeting.is_empty())
	var before := enemy.total_hp()
	scene._player_act(BattleAction.spell(0, &"ash_record", enemy.uid))
	await wait_seconds(1.5)
	assert_eq(enemy.total_hp(), maxi(0, before - 60))
	assert_eq(state.active_unit().side, UnitState.Side.PLAYER, "ход отряда продолжается")
	assert_false(state.can_hero_act())
