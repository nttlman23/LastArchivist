extends "res://scripts/presentation/map_screen.gd"
## Второй урок (SPEC_SPRINT11 5), часть 2: учебная карта из трёх слоёв на настоящем экране карты.
## Шаги: полёт на остров по мосту, разведка, перелёт без моста, переход на пройденный остров.
## Острова не открываются — сразу считаются пройденными. Забег учебный: Game.run и путь сохранения
## подменяются на время урока и возвращаются при выходе — настоящий забег не трогается.

const SAVE_PATH := "user://tutorial_map_run.json"
## Острова: [слой, полоса, тип]; мосты — пары индексов.
const NODES := [
	[1, 0, MapState.NodeType.BATTLE], [1, 3, MapState.NodeType.BATTLE],
	[2, 0, MapState.NodeType.EVENT], [2, 1, MapState.NodeType.SHOP], [2, 2, MapState.NodeType.BATTLE],
	[3, 1, MapState.NodeType.HAVEN], [3, 2, MapState.NodeType.ELITE],
]
const EDGES := [[0, 2], [0, 3], [1, 4], [2, 5], [3, 5], [4, 6]]
## Шаг: задание (ключ), действие (travel / scout / flight / walk) и остров.
const STEPS := [
	{"key": "TUTMAP_STEP_TRAVEL", "action": &"travel", "node": 0},
	{"key": "TUTMAP_STEP_SCOUT", "action": &"scout", "node": 2},
	{"key": "TUTMAP_STEP_TRAVEL2", "action": &"travel", "node": 2},
	{"key": "TUTMAP_STEP_WALK", "action": &"walk", "node": 0},
	{"key": "TUTMAP_STEP_FLIGHT", "action": &"flight", "node": 4},
	{"key": "TUTMAP_STEP_DONE", "action": &"", "node": -1},
]

var step := 0
var _saved_run: RunState
var _saved_path := ""
var _step_label: Label
var _warn_label: Label
var _finish_button: Button


func _ready() -> void:
	Hints.suppressed = true
	_saved_run = Game.run
	_saved_path = SaveService.current_path
	SaveService.current_path = SAVE_PATH
	Game.run = make_run(Game.defs)
	super._ready()
	_build_step_panel()
	_update_step()


func _exit_tree() -> void:
	Hints.suppressed = false
	Game.run = _saved_run
	SaveService.current_path = _saved_path
	SafeFile.remove(SAVE_PATH)


## Учебный забег с картой из трёх слоёв (без Разлома) и запасом Эфира на разведку и перелёт.
static func make_run(db: DefsDB) -> RunState:
	var run := RunState.create(db, 5)
	var map := MapState.new()
	for i in NODES.size():
		var n := MapState.MapNode.new(i, NODES[i][0], NODES[i][1], NODES[i][2])
		if n.type == MapState.NodeType.EVENT:
			n.content = db.event_ids()[0]
		elif n.is_battle():
			n.content = &"crypt_1"
		map.nodes.append(n)
	for e: Array in EDGES:
		map.add_edge(e[0], e[1])
	run.map = map
	run.resources[RunState.AETHER] = MapActions.scout_cost(run) + MapActions.FLIGHT_COST
	return run


# --- Действия: только то, что просит шаг ----------------------------------------------

func _travel(id: int) -> void:
	var flight := not MapActions.reachable(run).has(id)
	if not _expect(&"flight" if flight else &"travel", id):
		return
	if MapActions.travel(run, id):
		MapActions.complete(run)
		Audio.play(&"spell" if flight else &"move")
		_next()


func _scout(id: int) -> void:
	if not _expect(&"scout", id):
		return
	if MapActions.scout(run, id):
		Audio.play(&"ability")
		_next()


func _walk(id: int) -> void:
	if not _expect(&"walk", id):
		return
	if MapActions.walk(run, id):
		Audio.play(&"move")
		_next()


func _expect(action: StringName, id: int) -> bool:
	var s: Dictionary = STEPS[step]
	if s["action"] == action and int(s["node"]) == id:
		return true
	_warn_label.text = tr("TUT_WRONG")
	Audio.play(&"ui_click")
	return false


func _next() -> void:
	step = mini(step + 1, STEPS.size() - 1)
	_selected = -1
	_refresh()
	_update_step()


# --- Плашка заданий --------------------------------------------------------------------

func _build_step_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.09, 0.13, 0.95), UiKit.ACCENT, 2, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_step_label = UiKit.label("", 22, UiKit.ACCENT)
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_label.custom_minimum_size = Vector2(760, 0)
	col.add_child(_step_label)
	_warn_label = UiKit.label("", 16, UiKit.DANGER)
	col.add_child(_warn_label)
	var finish := UiKit.button(tr("TUT_SKIP"), Game.finish_tutorial2, 260)
	finish.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(finish)
	add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 24
	# Сверху, под шапкой: учебная карта короткая и прижата к низу экрана.
	panel.offset_top = 90
	panel.offset_bottom = 220
	_finish_button = finish


func _update_step() -> void:
	if _step_label == null:
		return
	var s: Dictionary = STEPS[step]
	_step_label.text = "%s %d/%d. %s" % [tr("TUT_STEP"), step + 1, STEPS.size(), tr(s["key"])]
	_warn_label.text = ""
	if s["action"] == &"":
		_finish_button.text = tr("TUT_DONE_MENU") if Game.tutorial_from_menu else tr("TUT_DONE_NEXT")
	elif int(s["node"]) >= 0:
		view.selected = int(s["node"])
		view.queue_redraw()
