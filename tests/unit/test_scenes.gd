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
	return UnitInfoPanel.abilities_of(u).map(func(e: Array) -> StringName: return e[0])


func test_abilities_reflect_state() -> void:
	var s := TestHelpers.empty_battle()
	var archer := TestHelpers.add(s, 0, Vector2i(0, 0), 5, {"is_ranged": true, "shots": 3, "is_flying": true})
	assert_eq(_icons(archer), [UnitGlyphs.ICON_RANGED, UnitGlyphs.ICON_FLYING, UnitGlyphs.ICON_RETALIATION])
	var guard := TestHelpers.add(s, 1, Vector2i(5, 0), 5)
	guard.retaliated = true
	guard.defending = true
	guard.waited = true
	assert_eq(_icons(guard), [UnitGlyphs.ICON_MELEE, UnitGlyphs.ICON_RETALIATION_USED, UnitGlyphs.ICON_DEFEND, UnitGlyphs.ICON_WAIT])
