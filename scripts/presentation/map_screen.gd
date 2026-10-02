extends Control
## Карта экспедиции — хаб забега (SPEC_SPRINT3 3.3): выбор острова, разведка, перелёт, Кодекс.

const SIDE_WIDTH := 420.0
const TYPE_KEYS := {
	MapState.NodeType.BATTLE: "NODE_BATTLE",
	MapState.NodeType.ELITE: "NODE_ELITE",
	MapState.NodeType.EVENT: "NODE_EVENT",
	MapState.NodeType.SHOP: "NODE_SHOP",
	MapState.NodeType.HAVEN: "NODE_HAVEN",
	MapState.NodeType.RIFT: "NODE_RIFT",
}

var db: DefsDB
var run: RunState
var view: MapView
var _resources_label: Label
var _resources_box: HBoxContainer
var _layer_label: Label
var _info: VBoxContainer
var _codex_overlay: PanelContainer
var _selected := -1


func _ready() -> void:
	if Game.run == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UiKit.add_background(self)
	bg.color = Color(0.06, 0.08, 0.13)
	view = MapView.new()
	add_child(view)
	view.setup(run)
	_build_hud()
	resized.connect(_layout)
	_layout()
	if run.pending_node >= 0:
		_select(run.pending_node)
	_refresh()
	Hints.show_hint(&"map")


func _layout() -> void:
	var map_w := size.x - SIDE_WIDTH
	view.position = Vector2(map_w * 0.5, size.y - 90.0)


func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(24, 16)
	top.add_theme_constant_override("separation", 24)
	add_child(top)
	top.add_child(UiKit.label(tr("MAP_TITLE"), 34, UiKit.ACCENT))
	_layer_label = UiKit.label("", 22, UiKit.MUTED)
	_layer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_layer_label)
	_resources_label = UiKit.label("", 22)
	_resources_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resources_label.visible = false
	top.add_child(_resources_label)
	_resources_box = HBoxContainer.new()
	_resources_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_resources_box)
	var points := UiKit.chip(UnitGlyphs.ICON_POINTS, str(Game.profile.points), UiKit.ACCENT, tr("META_POINTS"), tr("META_POINTS_TIP"), 20)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(points)

	var side := PanelContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -SIDE_WIDTH + 10
	side.offset_right = -16
	side.offset_top = 16
	side.offset_bottom = -16
	side.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	add_child(side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	side.add_child(col)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 10)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_info)
	col.add_child(UiKit.button(tr("MAP_CODEX"), _toggle_codex, 380))
	col.add_child(UiKit.button(tr("PREP_TO_MENU"), Game.to_main_menu, 380))


func _refresh() -> void:
	_resources_label.text = UiKit.resources_text(run.resources)
	for child in _resources_box.get_children():
		child.queue_free()
	_resources_box.add_child(UiKit.resource_row(run.resources, false, 22))
	_layer_label.text = tr("MAP_LAYER") % [run.map.current_layer(), MapState.LAYERS]
	view.selected = _selected
	view.refresh()
	_show_info()


# --- Ввод ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _codex_overlay:
		return
	if event is InputEventMouseMotion:
		var id := view.node_at(view.get_local_mouse_position())
		if id != view.hovered:
			view.hovered = id
			view.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := view.node_at(view.get_local_mouse_position())
		if id >= 0:
			_select(id)
			_refresh()


func _select(id: int) -> void:
	_selected = id
	Audio.play(&"ui_click")


# --- Панель острова --------------------------------------------------------------

func _show_info() -> void:
	for child in _info.get_children():
		child.queue_free()
	if run.pending_node >= 0:
		_info.add_child(_wrapped(tr("MAP_PENDING"), UiKit.ACCENT))
		_add_node_card(run.pending())
		_info.add_child(UiKit.button(tr("MAP_RESUME"), Game.resume_node, 380))
		return
	if _selected < 0:
		_info.add_child(_wrapped(tr("MAP_HINT"), UiKit.MUTED))
		return
	var n := run.map.node(_selected)
	_add_node_card(n)
	var reachable := MapActions.reachable(run).has(n.id)
	var flight := MapActions.flight_targets(run).has(n.id)
	if reachable:
		_info.add_child(UiKit.button(tr("MAP_TRAVEL"), _travel.bind(n.id), 380))
	elif flight:
		var b := UiKit.icon_button(UnitGlyphs.ICON_AETHER, tr("MAP_FLIGHT_SHORT") % MapActions.FLIGHT_COST, _travel.bind(n.id),
				tr("MAP_FLIGHT_TITLE"), tr("MAP_FLIGHT_TIP"), 380)
		b.disabled = not MapActions.can_travel(run, n.id)
		_info.add_child(b)
	elif run.map.visited.has(n.id):
		_info.add_child(_wrapped(tr("MAP_VISITED"), UiKit.MUTED))
	else:
		_info.add_child(_wrapped(tr("MAP_UNREACHABLE"), UiKit.MUTED))
	if (reachable or flight) and n.content != &"" and not n.scouted:
		var s := UiKit.icon_button(UnitGlyphs.ICON_AETHER, tr("MAP_SCOUT_SHORT") % MapActions.SCOUT_COST, _scout.bind(n.id),
				tr("MAP_SCOUT_TITLE"), tr("MAP_SCOUT_TIP"), 380)
		s.disabled = not MapActions.can_scout(run, n.id)
		_info.add_child(s)


func _add_node_card(n: MapState.MapNode) -> void:
	var title := UiKit.label(tr(TYPE_KEYS[n.type]), 28, MapView.TYPE_COLORS[n.type].lightened(0.3))
	Tip.attach(title, tr(TYPE_KEYS[n.type]), tr(TYPE_KEYS[n.type] + "_DESC"))
	_info.add_child(title)
	if Settings.detailed:
		_info.add_child(_wrapped(tr(TYPE_KEYS[n.type] + "_DESC"), Color.WHITE))
	else:
		_info.add_child(_wrapped(tr(TYPE_KEYS[n.type] + "_SHORT"), Color.WHITE))
	if n.type == MapState.NodeType.BATTLE:
		_info.add_child(UiKit.label(tr("MAP_TIER") % MapGenerator.tier_for_layer(n.layer), 0, UiKit.MUTED))
	if n.is_battle():
		var enc := db.encounter(n.content)
		if n.scouted or n.type == MapState.NodeType.RIFT:
			var enemies: Array[String] = []
			for i in enc.unit_ids.size():
				enemies.append("%d × %s" % [enc.counts[i], UiKit.unit_name(db, enc.unit_ids[i])])
			_info.add_child(_wrapped("%s %s" % [tr("PREP_ENEMIES"), ", ".join(enemies)], UiKit.ENEMY_COLOR))
		var rewards := MapActions.battle_rewards(enc)
		if not rewards.values().all(func(v: int) -> bool: return v == 0):
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 10)
			line.add_child(UiKit.label(tr("MAP_REWARD_SHORT"), 18, UiKit.MUTED))
			line.add_child(UiKit.resource_row(rewards, true, 18))
			_info.add_child(line)
	elif n.type == MapState.NodeType.EVENT and n.scouted:
		_info.add_child(_wrapped(tr(db.event(n.content).title_key), Color(0.7, 0.8, 1.0)))


func _wrapped(text: String, color: Color) -> Label:
	var l := UiKit.label(text, 18, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(370, 0)
	return l


func _travel(id: int) -> void:
	var flight := not MapActions.reachable(run).has(id)
	if Game.enter_node(id):
		Audio.play(&"move" if not flight else &"spell")


func _scout(id: int) -> void:
	if MapActions.scout(run, id):
		Audio.play(&"ability")
		SaveService.save_run(run)
		_refresh()


# --- Кодекс --------------------------------------------------------------------

func _toggle_codex() -> void:
	if _codex_overlay:
		_codex_overlay.queue_free()
		_codex_overlay = null
		return
	_codex_overlay = PanelContainer.new()
	_codex_overlay.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.BG_COLOR, UiKit.ACCENT, 2))
	_codex_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_codex_overlay.offset_left = 30
	_codex_overlay.offset_top = 30
	_codex_overlay.offset_bottom = -30
	_codex_overlay.offset_right = -SIDE_WIDTH - 10
	add_child(_codex_overlay)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_codex_overlay.add_child(col)
	col.add_child(UiKit.label(tr("MAP_CODEX_TITLE") % [run.codex.cards.size(), CodexState.MAX_CARDS], 30, UiKit.ACCENT))
	col.add_child(UiKit.hero_summary(db, run))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for card in run.codex.cards:
		var b := UiKit.card_button(db, card.memory_id, card.durability, card.level)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(b)
	col.add_child(UiKit.button(tr("MAP_CODEX_CLOSE"), _toggle_codex, 260))
