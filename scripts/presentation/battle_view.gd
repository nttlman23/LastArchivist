class_name BattleView
extends Node2D
## Отрисовка поля и проигрывание событий боя. Состояние только читает.
##
## Поле разбито на слои, каждый перерисовывается только при своих изменениях:
## перестроение canvas-команд (триангуляция, сглаженные линии) дорогое,
## а повторный показ уже записанных команд почти бесплатен.
##   board   — сетка и препятствия, рисуется один раз;
##   overlay — подсветки (достижимость, путь, угроза, наведение), при смене подсветки;
##   units   — фишки, при синхронизации и во время анимаций;
##   fx      — снаряд и всплывающий урон, только пока они есть;
##   marker  — маркер ходящего стека, пульсирует через modulate/position без перерисовки;
##   cursor  — иконка действия у курсора, двигается через position.

const HEX_SIZE := 54.0
const UNIT_RADIUS := HEX_SIZE * 0.6
const STEP_TIME := 0.09
const LUNGE_TIME := 0.12
const SHOT_TIME := 0.22
const FADE_TIME := 0.3
const FLOATER_TIME := 1.2

const HEX_COLOR := Color(0.17, 0.19, 0.24)
const HEX_LINE := Color(0.3, 0.33, 0.4)
const OBSTACLE_COLOR := Color(0.32, 0.27, 0.22)
const REACH_COLOR := Color(0.25, 0.42, 0.32)
const PATH_COLOR := Color(0.4, 0.65, 0.45)
const HOVER_COLOR := Color(1, 1, 1, 0.12)
const ACTIVE_RING := Color(1.0, 0.85, 0.3)
const THREAT_COLOR := Color(1.0, 0.35, 0.3, 0.8)
const TARGET_COLOR := Color(1, 0.3, 0.25)
const BADGE_BG := Color(0.1, 0.11, 0.15)
const TEMP_WALL_COLOR := Color(0.62, 0.66, 0.72)
const WATER_COLOR := Color(0.25, 0.45, 0.75, 0.55)
const ILLUSION_ALPHA := 0.55
const TARGET_HEX_COLOR := Color(0.62, 0.4, 0.95, 0.45)
const AFFECTED_ALLY := Color(1, 0.3, 0.25)
const AFFECTED_ENEMY := Color(0.95, 0.8, 0.4)
const HEAL_COLOR := Color(0.45, 0.95, 0.5)
const DAMAGE_COLOR := Color(1, 0.4, 0.35)
const NAME_COLOR := Color(0.95, 0.85, 0.5)
const RIFT_COLOR := Color(0.8, 0.5, 1.0)
const ATTACK_ZONE_COLOR := Color(1.0, 0.3, 0.25, 0.22)
const HEAT_COLOR := Color(1.0, 0.3, 0.25)
const HEAT_STEP := 0.13
const HEAT_MAX := 0.55
const DIM_COLOR := Color(0, 0, 0, 0.22)
const WAVE_COLOR := Color(0.6, 0.8, 1.0, 0.8)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.9)
const SIDE_RING_WIDTH := 5.0
const MAX_STATUS_ICONS := 3

var state: BattleState
var db: DefsDB

# Подсветка, задаётся экраном боя; после изменения вызвать refresh_highlights().
var reachable: Dictionary[Vector2i, int] = {}
var preview_path: Array[Vector2i] = []
var preview_target := -1
var hover_hex := Vector2i(-1, -1)
## Клетки, куда может дойти враг под курсором (зона угрозы).
var threat: Dictionary[Vector2i, int] = {}
## Клетки, которые враг под курсором может атаковать (кроме тех, куда может дойти).
var threat_attack: Dictionary[Vector2i, bool] = {}
## Суммарная угроза всех врагов (удержание Alt): клетка -> число достающих стеков.
var heat: Dictionary[Vector2i, int] = {}
## Свои стеки, которых враг может атаковать в этот раунд (значок «под ударом»).
var threatened: Dictionary[int, bool] = {}
## Цели выстрела вражеского стрелка под курсором: uid -> дальний выстрел (урон снижен).
var shot_targets: Dictionary[int, bool] = {}
## Стек, подсвеченный из полосы очереди (или -1).
var highlight_uid := -1
## Затемнять клетки, недоступные для хода (во время хода игрока).
var dim_unreachable := false
## Режим прицеливания: допустимые клетки-цели и стеки, которых заденет действие (uid -> свой ли).
var targets: Dictionary[Vector2i, bool] = {}
var affected: Dictionary[int, bool] = {}
## Подпись для ABILITY_USED/HERO_ACTED (название способности, приказа, заклинания); задаёт экран.
var event_label: Callable = func(_e: BattleEvent) -> String: return ""
var show_active := true

# Отображаемое состояние стеков — отстаёт от BattleState на время анимаций.
var _pos: Dictionary[int, Vector2] = {}
var _count: Dictionary[int, int] = {}
var _alpha: Dictionary[int, float] = {}
var _flash: Dictionary[int, float] = {}
var _projectile_from := Vector2.ZERO
var _projectile_to := Vector2.ZERO
var _projectile_t := -1.0
var _floaters: Array[Dictionary] = []
var _font: Font
var _time := 0.0
var _hex_fill: Dictionary[Vector2i, PackedVector2Array] = {}
var _hex_inner: Dictionary[Vector2i, PackedVector2Array] = {}

var _board: Layer
var _overlay: Layer
var _units: Layer
var _fx: Layer
var _marker: Layer
var _marker_arrow: Layer
var _cursor: CursorIcon


## Слой, делегирующий отрисовку функции BattleView.
class Layer:
	extends Node2D
	var painter: Callable

	func _init(p: Callable) -> void:
		painter = p

	func _draw() -> void:
		painter.call(self)


## Иконка действия у курсора: перерисовывается только при смене вида.
class CursorIcon:
	extends Node2D
	var kind := &"":
		set(value):
			if kind != value:
				kind = value
				visible = kind != &""
				queue_redraw()

	func _draw() -> void:
		if kind != &"":
			UnitGlyphs.draw_icon(self, kind, Vector2(26, 26), 16, Color(0.1, 0.1, 0.12, 0.9), UiKit.ACCENT)


func setup(p_state: BattleState, p_db: DefsDB) -> void:
	state = p_state
	db = p_db
	_font = ThemeDB.fallback_font
	_hex_fill.clear()
	_hex_inner.clear()
	for hex in state.grid.all_hexes():
		var c := hex_center(hex)
		_hex_fill[hex] = HexGrid.corners(c, HEX_SIZE - 1.5)
		var inner := HexGrid.corners(c, HEX_SIZE - 7.0)
		inner.append(inner[0])
		_hex_inner[hex] = inner
	if _board == null:
		_board = _add_layer(self, _draw_board)
		_overlay = _add_layer(self, _draw_overlay)
		_marker = _add_layer(self, _draw_marker_ring)
		_marker_arrow = _add_layer(_marker, _draw_marker_arrow)
		_units = _add_layer(self, _draw_units)
		_fx = _add_layer(self, _draw_fx)
		_cursor = CursorIcon.new()
		_cursor.visible = false
		add_child(_cursor)
	_board.queue_redraw()
	sync()


## Подгоняет отображение под текущее состояние.
func sync() -> void:
	_pos.clear()
	_count.clear()
	_alpha.clear()
	for u in state.units:
		_pos[u.uid] = hex_center(u.hex)
		_count[u.uid] = u.count
		_alpha[u.uid] = 1.0 if u.is_alive() else 0.0
	_units.queue_redraw()
	_overlay.queue_redraw()
	_update_marker()


func refresh_highlights() -> void:
	_overlay.queue_redraw()


func set_cursor(kind: StringName, local_pos: Vector2) -> void:
	_cursor.kind = kind
	_cursor.position = local_pos


func hex_center(hex: Vector2i) -> Vector2:
	return HexGrid.to_pixel(hex, HEX_SIZE)


func board_size() -> Vector2:
	return Vector2(HexGrid.SQRT3 * HEX_SIZE * (state.grid.width + 0.5), HEX_SIZE * (1.5 * (state.grid.height - 1) + 2.0))


## Клетка под точкой в локальных координатах; (-1, -1) вне поля.
func hex_at(local: Vector2) -> Vector2i:
	var h := HexGrid.from_pixel(local, HEX_SIZE)
	return h if state.grid.in_bounds(h) else Vector2i(-1, -1)


func clear_preview() -> void:
	reachable = {}
	preview_path = []
	preview_target = -1
	threat = {}
	threat_attack = {}
	shot_targets = {}
	heat = {}
	targets = {}
	affected = {}
	dim_unreachable = false
	_cursor.kind = &""
	_overlay.queue_redraw()


func _add_layer(parent: Node, painter: Callable) -> Layer:
	var layer := Layer.new(painter)
	parent.add_child(layer)
	return layer


func _process(delta: float) -> void:
	_time += delta
	_update_marker()
	if not _floaters.is_empty():
		for f in _floaters:
			f["t"] = float(f["t"]) + delta
		_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < FLOATER_TIME)
		_fx.queue_redraw()
	if not _flash.is_empty():
		for uid in _flash.keys():
			_flash[uid] -= delta
			if _flash[uid] <= 0.0:
				_flash.erase(uid)
		_units.queue_redraw()


## Маркер следует за ходящим стеком и пульсирует без перерисовки.
func _update_marker() -> void:
	var active := state.active_unit()
	_marker.visible = show_active and active != null and _pos.has(active.uid)
	if not _marker.visible:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_marker.position = _pos[active.uid]
	_marker.modulate.a = 0.55 + 0.45 * pulse
	_marker.scale = Vector2.ONE * (1.0 + 0.05 * pulse)
	_marker_arrow.position.y = -6.0 * pulse


# --- Проигрывание событий ---------------------------------------------------

## Звук на событие боя (id из Audio.SFX); ATTACKED озвучивается отдельно.
const EVENT_SOUNDS := {
	BattleEvent.MOVED: &"move",
	BattleEvent.DIED: &"death",
	BattleEvent.HEALED: &"heal",
	BattleEvent.DAMAGED: &"impact",
	BattleEvent.PUSHED: &"push",
	BattleEvent.OBSTACLE_ADDED: &"wall",
	BattleEvent.ABILITY_USED: &"ability",
	BattleEvent.ERASED: &"erase",
	BattleEvent.RIFT_MARKED: &"order",
	BattleEvent.SUMMONED: &"spell",
}


static func sound_for(e: BattleEvent) -> StringName:
	match e.type:
		BattleEvent.ATTACKED:
			return &"shoot" if e.data["ranged"] else &"melee"
		BattleEvent.HERO_ACTED:
			return &"spell" if e.data["spell"] else &"order"
	return EVENT_SOUNDS.get(e.type, &"")


func play(events: Array[BattleEvent]) -> void:
	for e in events:
		var sound := sound_for(e)
		if sound != &"":
			Audio.play(sound)
		match e.type:
			BattleEvent.MOVED:
				await _play_move(e.data["uid"], e.data["path"])
			BattleEvent.ATTACKED:
				await _play_attack(e.data)
			BattleEvent.DIED:
				await _tween_value(func(v: float) -> void: _alpha[int(e.data["uid"])] = v, 1.0, 0.0, FADE_TIME, _units)
			BattleEvent.PUSHED:
				var uid: int = e.data["uid"]
				var from := hex_center(e.data["from"])
				var to := hex_center(e.data["to"])
				await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, STEP_TIME * 1.5, _units)
			BattleEvent.HEALED:
				var uid: int = e.data["uid"]
				_count[uid] = _count.get(uid, 0) + int(e.data["revived"])
				_float_text(uid, "+%d" % int(e.data["amount"]), HEAL_COLOR)
				_units.queue_redraw()
				await get_tree().create_timer(0.3).timeout
			BattleEvent.DAMAGED:
				var uid: int = e.data["uid"]
				_count[uid] = maxi(0, _count.get(uid, 0) - int(e.data["killed"]))
				_flash[uid] = 0.25
				_float_text(uid, _damage_text(e.data["damage"], e.data["killed"]), DAMAGE_COLOR)
				_units.queue_redraw()
				await get_tree().create_timer(0.25).timeout
			BattleEvent.ABILITY_USED, BattleEvent.HERO_ACTED:
				# Название способности/приказа/заклинания над тем, кто действует (или над целью).
				var who: int = e.data["uid"] if e.data.has("uid") else int(e.data["target"])
				var label: String = event_label.call(e)
				if label != "" and _pos.has(who):
					_float_text(who, label, NAME_COLOR, -26.0)
					await get_tree().create_timer(0.35).timeout
			BattleEvent.OBSTACLE_ADDED, BattleEvent.OBSTACLE_EXPIRED:
				_overlay.queue_redraw()
			BattleEvent.SUMMONED:
				# Новый стек: добавить в отображение и проявить.
				var uid: int = e.data["uid"]
				var u := state.get_unit(uid)
				_pos[uid] = hex_center(u.hex)
				_count[uid] = u.count
				await _tween_value(func(v: float) -> void: _alpha[uid] = v, 0.0, 1.0, FADE_TIME, _units)
			BattleEvent.RIFT_MARKED:
				_float_text(int(e.data["uid"]), event_label.call(e), RIFT_COLOR, -26.0)
				_units.queue_redraw()
				await get_tree().create_timer(0.5).timeout
			BattleEvent.ERASED:
				var uid: int = e.data["uid"]
				_float_text(uid, event_label.call(e), RIFT_COLOR, -26.0)
				_flash[uid] = 0.4
				await _tween_value(func(v: float) -> void: _alpha[uid] = v, 1.0, 0.0, FADE_TIME * 2.0, _units)
	sync()


func _float_text(uid: int, text: String, color: Color, rise: float = 0.0) -> void:
	_floaters.append({"text": text, "pos": _pos[uid] + Vector2(0, rise), "t": 0.0, "color": color})


static func _damage_text(damage: int, killed: int) -> String:
	var text := "-%d" % damage
	if killed > 0:
		text += "  †%d" % killed
	return text


func _play_move(uid: int, path: Array) -> void:
	for i in range(1, path.size()):
		var from := hex_center(path[i - 1])
		var to := hex_center(path[i])
		var time := STEP_TIME * (HexGrid.distance(path[i - 1], path[i]))
		await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, time, _units)


func _play_attack(d: Dictionary) -> void:
	var attacker: int = d["attacker"]
	var target: int = d["target"]
	var from := _pos[attacker]
	var to := _pos[target]
	if d["ranged"]:
		_projectile_from = from
		_projectile_to = to
		await _tween_value(func(t: float) -> void: _projectile_t = t, 0.0, 1.0, SHOT_TIME, _fx)
		_projectile_t = -1.0
		_fx.queue_redraw()
		Audio.play(&"impact")
	else:
		var lunge := from.lerp(to, 0.35)
		await _tween_value(func(t: float) -> void: _pos[attacker] = from.lerp(lunge, t), 0.0, 1.0, LUNGE_TIME, _units)
		_pos[attacker] = from
	_count[target] = maxi(0, _count[target] - int(d["killed"]))
	_flash[target] = 0.25
	_floaters.append({"text": _damage_text(d["damage"], d["killed"]), "pos": to, "t": 0.0, "color": DAMAGE_COLOR})
	_units.queue_redraw()
	await get_tree().create_timer(0.25).timeout


func _tween_value(setter: Callable, from: float, to: float, time: float, layer: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_method(_tween_step.bind(setter, layer), from, to, time)
	await tw.finished


func _tween_step(value: float, setter: Callable, layer: CanvasItem) -> void:
	setter.call(value)
	layer.queue_redraw()


# --- Слои --------------------------------------------------------------------

## Пакет выпуклых многоугольников: все заливки слоя уходят одним вызовом отрисовки
## (каждый draw_colored_polygon — отдельный draw call).
class FillBatch:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(pts: PackedVector2Array, color: Color) -> void:
		var base := points.size()
		for p in pts:
			points.append(p)
			colors.append(color)
		for i in range(1, pts.size() - 1):
			indices.append_array([base, base + i, base + i + 1])

	func draw(ci: CanvasItem) -> void:
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)


func _draw_board(ci: CanvasItem) -> void:
	var fills := FillBatch.new()
	var outlines := PackedVector2Array()
	for hex in _hex_fill:
		var pts := _hex_fill[hex]
		fills.add(pts, OBSTACLE_COLOR if state.obstacles.has(hex) else HEX_COLOR)
		for i in 6:
			outlines.append(pts[i])
			outlines.append(pts[(i + 1) % 6])
		if state.obstacles.has(hex):
			fills.add(_rock(hex_center(hex)), OBSTACLE_COLOR.darkened(0.35))
	fills.draw(ci)
	# Все контуры одним вызовом.
	ci.draw_multiline(outlines, HEX_LINE, 1.5)


func _draw_overlay(ci: CanvasItem) -> void:
	var fills := FillBatch.new()
	var wall_dark := TEMP_WALL_COLOR.darkened(0.3)
	for hex in state.temp_obstacles:
		var c := hex_center(hex)
		fills.add(_hex_fill[hex], OBSTACLE_COLOR.lerp(TEMP_WALL_COLOR, 0.5))
		fills.add(PackedVector2Array([c + Vector2(-26, 14), c + Vector2(-26, -10), c + Vector2(26, -10), c + Vector2(26, 14)]), wall_dark)
		for x: float in [-26.0, -9.0, 8.0]:
			fills.add(PackedVector2Array([c + Vector2(x, -18), c + Vector2(x + 10, -18), c + Vector2(x + 10, -10), c + Vector2(x, -10)]), wall_dark)
	for hex in state.water:
		fills.add(_hex_fill[hex], WATER_COLOR)
	if dim_unreachable and not reachable.is_empty():
		var active := state.active_unit()
		for hex in _hex_fill:
			if not reachable.has(hex) and (active == null or hex != active.hex) and not state.obstacles.has(hex):
				fills.add(_hex_fill[hex], DIM_COLOR)
	for hex in heat:
		fills.add(_hex_fill[hex], Color(HEAT_COLOR, minf(HEAT_MAX, HEAT_STEP * heat[hex])))
	for hex in threat_attack:
		if not threat.has(hex):
			fills.add(_hex_fill[hex], ATTACK_ZONE_COLOR)
	for hex in targets:
		fills.add(_hex_fill[hex], TARGET_HEX_COLOR)
	for hex in reachable:
		fills.add(_hex_fill[hex], REACH_COLOR)
	for hex in preview_path:
		fills.add(_hex_fill[hex], PATH_COLOR)
	if _hex_fill.has(hover_hex):
		fills.add(_hex_fill[hover_hex], HOVER_COLOR)
	fills.draw(ci)

	# Вода: волнистая штриховка и оставшиеся раунды; временные стены: контур и раунды.
	var waves := PackedVector2Array()
	for hex in state.water:
		var c := hex_center(hex)
		for y: float in [-16.0, 0.0, 16.0]:
			for k in 6:
				var x0 := -27.0 + k * 9.0
				waves.append(c + Vector2(x0, y + 4.0 * sin(k * 1.7)))
				waves.append(c + Vector2(x0 + 9.0, y + 4.0 * sin((k + 1) * 1.7)))
	if not waves.is_empty():
		ci.draw_multiline(waves, WAVE_COLOR, 2.0)
	for hex in state.water:
		_draw_rounds(ci, hex_center(hex) + Vector2(14, -14), state.water[hex], WAVE_COLOR)
	for hex in state.temp_obstacles:
		ci.draw_polyline(_hex_inner[hex], TEMP_WALL_COLOR.lightened(0.2), 2.5)
		_draw_rounds(ci, hex_center(hex) + Vector2(0, 30), state.temp_obstacles[hex], Color.WHITE)

	if not threat.is_empty():
		var lines := PackedVector2Array()
		for hex in threat:
			var pts := _hex_inner[hex]
			for i in 6:
				lines.append(pts[i])
				lines.append(pts[i + 1])
		ci.draw_multiline(lines, THREAT_COLOR, 2.5)
	if preview_target >= 0 and _pos.has(preview_target):
		ci.draw_arc(_pos[preview_target], UNIT_RADIUS + 7, 0, TAU, 32, TARGET_COLOR, 4.0)
	for uid in shot_targets:
		if _pos.has(uid):
			ci.draw_arc(_pos[uid], UNIT_RADIUS + 7, 0, TAU, 32, THREAT_COLOR, 3.0)
			if shot_targets[uid]:
				# Дальний выстрел — половина урона.
				var p := _pos[uid] + Vector2(UNIT_RADIUS * 0.7, -UNIT_RADIUS * 0.7)
				ci.draw_circle(p, 12, BADGE_BG)
				ci.draw_string(_font, p + Vector2(-12, 6), "½", HORIZONTAL_ALIGNMENT_CENTER, 24, 17, THREAT_COLOR)
	if highlight_uid >= 0 and _pos.has(highlight_uid):
		ci.draw_arc(_pos[highlight_uid], UNIT_RADIUS + 10, 0, TAU, 40, HIGHLIGHT_COLOR, 3.0)
	for uid in affected:
		if _pos.has(uid):
			ci.draw_arc(_pos[uid], UNIT_RADIUS + 12, 0, TAU, 32, AFFECTED_ALLY if affected[uid] else AFFECTED_ENEMY, 3.0)


## Число оставшихся раундов в кружке.
func _draw_rounds(ci: CanvasItem, pos: Vector2, rounds: int, color: Color) -> void:
	ci.draw_circle(pos, 11, Color(0, 0, 0, 0.6))
	ci.draw_string(_font, pos + Vector2(-11, 6), str(rounds), HORIZONTAL_ALIGNMENT_CENTER, 22, 16, color)


func _draw_marker_ring(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(HexGrid.corners(Vector2.ZERO, HEX_SIZE - 1.5), Color(ACTIVE_RING, 0.3))
	ci.draw_arc(Vector2.ZERO, UNIT_RADIUS + 7, 0, TAU, 40, ACTIVE_RING, 5.0)


func _draw_marker_arrow(ci: CanvasItem) -> void:
	var tip := Vector2(0, -UNIT_RADIUS - 18)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16)]), ACTIVE_RING)


func _draw_units(ci: CanvasItem) -> void:
	for u in state.units:
		if _alpha.get(u.uid, 0.0) > 0.0:
			_draw_unit(ci, u)


func _draw_fx(ci: CanvasItem) -> void:
	if _projectile_t >= 0.0:
		var p := _projectile_from.lerp(_projectile_to, _projectile_t)
		var dir := (_projectile_to - _projectile_from).normalized()
		ci.draw_line(p - dir * 22, p, UiKit.ACCENT, 4.0)
	for f in _floaters:
		var t := float(f["t"])
		var pos: Vector2 = f["pos"] + Vector2(-30, -UNIT_RADIUS - 10 - 40 * t)
		var col: Color = f.get("color", DAMAGE_COLOR)
		col.a = clampf(1.6 - t * 1.4, 0, 1)
		ci.draw_string_outline(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color(0, 0, 0, col.a))
		ci.draw_string(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)


func _rock(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(-24, 14), c + Vector2(-14, -12), c + Vector2(4, -20), c + Vector2(22, -6), c + Vector2(20, 16)])


## Значки временных состояний: [значок, цвет]. Порядок — по важности.
static func status_icons(u: UnitState) -> Array:
	var list: Array = []
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		list.append([UnitGlyphs.ICON_MARK, RIFT_COLOR])
	if u.has_status(UnitState.STATUS_MARKED):
		list.append([UnitGlyphs.ICON_MARK, DAMAGE_COLOR])
	if u.defending:
		list.append([UnitGlyphs.ICON_DEFEND, UiKit.PLAYER_COLOR.lightened(0.3)])
	if u.has_status(UnitState.STATUS_SHIELD_WALL):
		list.append([UnitGlyphs.ICON_RETALIATION, UiKit.ACCENT])
	elif u.retaliated:
		list.append([UnitGlyphs.ICON_RETALIATION_USED, UiKit.MUTED])
	if u.has_status(UnitState.STATUS_RUST_ARMOR):
		list.append([UnitGlyphs.ICON_ARMOR, UiKit.ACCENT])
	if u.has_status(UnitState.STATUS_ADVANCE):
		list.append([UnitGlyphs.ICON_ORDER, UiKit.ACCENT])
	if u.fury > 0:
		list.append([UnitGlyphs.ICON_MELEE, UiKit.DANGER])
	return list


func _draw_unit(ci: CanvasItem, u: UnitState) -> void:
	var k := 1.3 if Settings.large_icons else 1.0
	var c: Vector2 = _pos[u.uid]
	var alpha: float = _alpha[u.uid] * (ILLUSION_ALPHA if u.illusion else 1.0)
	var is_player := u.side == UnitState.Side.PLAYER
	var side_color := UiKit.PLAYER_COLOR if is_player else UiKit.ENEMY_COLOR
	var body := db.unit(u.def_id).color
	if _flash.has(u.uid):
		body = body.lerp(Color.WHITE, 0.7)
	body.a = alpha
	var ink := Color(UnitGlyphs.INK, alpha)
	var ring := Color(side_color, alpha)
	var fg := Color(1, 1, 1, alpha)
	var bg := Color(BADGE_BG, alpha)

	ci.draw_circle(c, UNIT_RADIUS, body)
	if u.illusion:
		# Иллюзия: пунктирное кольцо.
		for i in 12:
			var a0 := TAU * i / 12.0
			ci.draw_arc(c, UNIT_RADIUS, a0, a0 + TAU / 24.0, 4, Color(side_color, _alpha[u.uid]), SIDE_RING_WIDTH)
	else:
		ci.draw_arc(c, UNIT_RADIUS, 0, TAU, 32, ring, SIDE_RING_WIDTH)
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		ci.draw_arc(c, UNIT_RADIUS + 9, 0, TAU, 32, Color(RIFT_COLOR, alpha), 3.0)
	UnitGlyphs.draw_unit(ci, u.def_id, c, UNIT_RADIUS * 0.82, body, ink)

	# Постоянные свойства по бокам: стрелок (с выстрелами) слева, летун справа, способность снизу слева.
	var badge_r := 11.0 * k
	var font_size := int(15 * k)
	if u.is_ranged:
		var pos := c + Vector2(-UNIT_RADIUS - 2, -6)
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_RANGED, pos, badge_r, bg, fg if u.shots_left > 0 else Color(UiKit.MUTED, alpha))
		_outlined(ci, pos + Vector2(-badge_r - 18 * k, 6 * k), str(u.shots_left), HORIZONTAL_ALIGNMENT_RIGHT, 16 * k, font_size, fg, alpha)
	if u.is_flying:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_FLYING, c + Vector2(UNIT_RADIUS + 2, -6), badge_r, bg, fg)
	if u.ability_id != &"":
		# Способность: золотая звезда — готова, серая с цифрой — раунды до готовности.
		var pos := c + Vector2(-UNIT_RADIUS - 2, UNIT_RADIUS - 10)
		var ready := u.ability_cd <= 0
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_ABILITY, pos, badge_r, bg, Color(UiKit.ACCENT if ready else UiKit.MUTED, alpha))
		if not ready:
			_outlined(ci, pos + Vector2(-8 * k, 6 * k), str(u.ability_cd), HORIZONTAL_ALIGNMENT_CENTER, 16 * k, font_size, fg, alpha)
	if threatened.has(u.uid):
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_THREAT, c + Vector2(UNIT_RADIUS + 2, UNIT_RADIUS - 10), badge_r, bg, Color(UiKit.DANGER, alpha))
	if u.illusion:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_MASK, c + Vector2(UNIT_RADIUS + 2, UNIT_RADIUS - 10 - (2.2 * badge_r if threatened.has(u.uid) else 0.0)),
				badge_r, bg, Color(0.85, 0.85, 1.0, _alpha[u.uid]))

	# Временные состояния — рядом над фишкой, не больше трёх, остальное «+N».
	var statuses := status_icons(u)
	var shown := mini(statuses.size(), MAX_STATUS_ICONS)
	var step := badge_r * 2.1
	var extra := statuses.size() - shown
	var total := shown + (1 if extra > 0 else 0)
	for i in total:
		var pos := c + Vector2((i - (total - 1) * 0.5) * step, -UNIT_RADIUS - 2)
		if i < shown:
			UnitGlyphs.draw_icon(ci, statuses[i][0], pos, badge_r, bg, Color(statuses[i][1], alpha))
		else:
			ci.draw_circle(pos, badge_r, bg)
			_outlined(ci, pos + Vector2(-badge_r, 5 * k), "+%d" % extra, HORIZONTAL_ALIGNMENT_CENTER, badge_r * 2, int(13 * k), fg, alpha)

	# Численность: у своих — прямоугольник, у врагов — заострённый книзу щиток (различимо без цвета).
	var bw := 48.0 * k
	var bh := 24.0 * k
	var top := c + Vector2(-bw * 0.5, UNIT_RADIUS - 12)
	var shape := PackedVector2Array([top, top + Vector2(bw, 0), top + Vector2(bw, bh), top + Vector2(0, bh)])
	var tip := 0.0
	if not is_player:
		tip = 7.0 * k
		shape = PackedVector2Array([top, top + Vector2(bw, 0), top + Vector2(bw, bh), top + Vector2(bw * 0.5, bh + tip), top + Vector2(0, bh)])
	ci.draw_colored_polygon(shape, Color(side_color.darkened(0.55), alpha))
	var outline := shape.duplicate()
	outline.append(shape[0])
	ci.draw_polyline(outline, ring, 2.0)
	ci.draw_string(_font, top + Vector2(0, 19 * k), str(_count.get(u.uid, u.count)), HORIZONTAL_ALIGNMENT_CENTER, bw, int(19 * k), fg)
	var hp_ratio := clampf(float(u.top_hp) / u.hp, 0.0, 1.0) if u.is_alive() else 0.0
	var bar := Rect2(top + Vector2(0, bh + tip + 1), Vector2(bw, 4))
	ci.draw_rect(bar, Color(0.1, 0.1, 0.1, alpha))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_ratio, bar.size.y)), Color(Color(0.4, 0.85, 0.4).lerp(UiKit.DANGER, 1.0 - hp_ratio), alpha))


func _outlined(ci: CanvasItem, pos: Vector2, text: String, align: HorizontalAlignment, width: float, font_size: int, color: Color, alpha: float) -> void:
	ci.draw_string_outline(_font, pos, text, align, width, font_size, 4, Color(0, 0, 0, alpha))
	ci.draw_string(_font, pos, text, align, width, font_size, color)
