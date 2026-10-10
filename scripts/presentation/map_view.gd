class_name MapView
extends Node2D
## Отрисовка карты экспедиции: парящие острова снизу вверх, мосты пунктиром.
## Статичная часть рисуется заново только при refresh(); пульсация доступных островов —
## через modulate отдельных узлов-колец, без перерисовки (SPEC 6.6).

const LANE_SPACING := 200.0
const LAYER_SPACING := 124.0
const ISLAND_R := 36.0
const RIFT_R := 58.0
const JITTER := Vector2(26, 14)

const TYPE_COLORS := {
	MapState.NodeType.BATTLE: Color(0.62, 0.38, 0.32),
	MapState.NodeType.ELITE: Color(0.78, 0.22, 0.26),
	MapState.NodeType.EVENT: Color(0.38, 0.5, 0.78),
	MapState.NodeType.SHOP: Color(0.82, 0.66, 0.32),
	MapState.NodeType.HAVEN: Color(0.36, 0.66, 0.44),
	MapState.NodeType.RIFT: Color(0.48, 0.24, 0.66),
	MapState.NodeType.RELIQUARY: Color(0.78, 0.62, 0.36),
}
const TYPE_ICONS := {
	MapState.NodeType.BATTLE: UnitGlyphs.ICON_MELEE,
	MapState.NodeType.ELITE: UnitGlyphs.ICON_RETALIATION,
	MapState.NodeType.SHOP: UnitGlyphs.ICON_SPELL,
	MapState.NodeType.HAVEN: UnitGlyphs.ICON_HEAL,
	MapState.NodeType.RELIQUARY: UnitGlyphs.ICON_CHALICE,
}
## Рисованные острова (SPEC_SPRINT9 18): вид по типу острова, ширина — ART_SCALE радиусов.
const ISLAND_ART := {
	MapState.NodeType.BATTLE: &"battle", MapState.NodeType.ELITE: &"elite", MapState.NodeType.EVENT: &"event",
	MapState.NodeType.SHOP: &"shop", MapState.NodeType.HAVEN: &"haven", MapState.NodeType.RIFT: &"boss",
	MapState.NodeType.RELIQUARY: &"reliquary",
}
const ART_SCALE := 2.6
## Кольца выбора и пульсации вокруг рисованного острова — по его ширине, а не по радиусу вершины.
const ART_RING := 1.3
const ROCK := Color(0.24, 0.22, 0.27)
## Второй акт (SPEC_SPRINT7 4): затопленные залы — сине-зелёная скала, вода у подножия, туман.
const ROCK_FLOODED := Color(0.13, 0.22, 0.24)
const WATERLINE := Color(0.35, 0.7, 0.72)
const FOG := Color(0.45, 0.62, 0.62)
const BRIDGE := Color(0.55, 0.58, 0.66, 0.55)
const BRIDGE_DONE := Color(0.95, 0.8, 0.4, 0.9)
const FLIGHT := Color(0.75, 0.55, 1.0)
## Текущий остров: голубое кольцо и свечение (золото — у доступных), над ним — медальон Архивариуса.
const HERE := Color(0.55, 0.9, 1.0)
const HERE_DISC_R := 24.0

var run: RunState
var selected := -1
var hovered := -1
## Путь к острову под курсором (SPEC_SPRINT5 5) и ресурсы за бои на нём.
var hover_path: Array[int] = []
var hover_rewards: Dictionary[StringName, int] = {}
## Риск боёв: id острова -> CardAdvisor.Risk.
var risks: Dictionary[int, int] = {}
var _pos: Dictionary[int, Vector2] = {}
var _font: Font
var _time := 0.0
var _pulses: Array[Node2D] = []
## Облака двумя слоями с параллаксом и свечение Разлома (SPEC_SPRINT6 4) — позади островов.
var _clouds_far: Node2D
var _clouds_near: Node2D
var _rift_glow: Node2D
## «Вы здесь»: свечение под текущим островом и медальон над ним (покачивается через position, без перерисовки).
var _here_glow: Node2D
var _here: Node2D
var _here_y := 0.0
const PARALLAX_FAR := 0.012
const PARALLAX_NEAR := 0.035


func setup(p_run: RunState) -> void:
	run = p_run
	_font = ThemeDB.fallback_font
	_pos.clear()
	for n in run.map.nodes:
		var lane_x := (n.lane - (MapState.LANES - 1) * 0.5) * LANE_SPACING
		var jitter := Vector2.ZERO
		if n.type != MapState.NodeType.RIFT:
			var h := hash("%d:%d" % [run.run_seed, n.id])
			jitter = Vector2(((h & 0xff) / 255.0 - 0.5) * 2.0 * JITTER.x, (((h >> 8) & 0xff) / 255.0 - 0.5) * 2.0 * JITTER.y)
		_pos[n.id] = Vector2(lane_x, -(n.layer - 1) * LAYER_SPACING) + jitter
	if _clouds_far == null:
		_clouds_far = _behind(_draw_clouds.bind(0, 0.045))
		_clouds_near = _behind(_draw_clouds.bind(1, 0.07))
		_rift_glow = _behind(_draw_rift_glow)
		_here_glow = _behind(_draw_here_glow)
		_here = Node2D.new()
		_here.draw.connect(_draw_here.bind(_here))
		add_child(_here)
	for n in run.map.nodes:
		if n.type == MapState.NodeType.RIFT:
			_rift_glow.position = _pos[n.id]
	refresh()


## Узел, рисующийся позади островов (show_behind_parent).
func _behind(painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.show_behind_parent = true
	n.draw.connect(painter.bind(n))
	add_child(n)
	n.queue_redraw()
	return n


## Мягкое голубое свечение под текущим островом.
func _draw_here_glow(ci: Node2D) -> void:
	for i in 7:
		var r := ISLAND_R * (2.3 - i * 0.22)
		var pts := PackedVector2Array()
		for k in 28:
			var a := TAU * k / 28.0
			pts.append(Vector2(cos(a) * r * 1.25, sin(a) * r * 0.75 + 6.0))
		ci.draw_colored_polygon(pts, Color(HERE, 0.07))


## Медальон с портретом Архивариуса на штырьке, острием к острову; без арта — кружок с глифом героя.
func _draw_here(ci: Node2D) -> void:
	var r := HERE_DISC_R
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, r - 3), Vector2(9, r - 3), Vector2(0, r + 16)]), HERE)
	ci.draw_circle(Vector2.ZERO, r + 4, Color(UiKit.BG_COLOR, 0.9))
	var tex := ArtDB.portrait(&"archivist")
	if tex:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var dir := Vector2.from_angle(TAU * i / 40.0)
			pts.append(dir * r)
			uvs.append(dir * 0.5 + Vector2(0.5, 0.5))
		ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	else:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_SPELL, Vector2.ZERO, 14, UiKit.BG_COLOR, HERE)
	ci.draw_arc(Vector2.ZERO, r + 2, 0, TAU, 40, HERE, 3.0)


func _draw_rift_glow(ci: Node2D) -> void:
	var glow := Color(0.25, 0.75, 0.8, 0.05) if _flooded() else Color(0.6, 0.3, 0.9, 0.05)
	for i in 8:
		ci.draw_circle(Vector2.ZERO, RIFT_R * (2.6 - i * 0.22), glow)


func _flooded() -> bool:
	return run != null and run.act >= 2


func node_pos(id: int) -> Vector2:
	return _pos[id]


## Верх и низ карты в локальных координатах (x — верх, y — низ) вместе с картинками островов и кольцами.
func vertical_span() -> Vector2:
	var span := Vector2(INF, -INF)
	for id in _pos:
		var n := run.map.node(id)
		var r := (RIFT_R if n.type == MapState.NodeType.RIFT else ISLAND_R) * ART_SCALE * 0.5 + 20.0
		span.x = minf(span.x, _pos[id].y - r)
		span.y = maxf(span.y, _pos[id].y + r)
	return span


## Узел под точкой в локальных координатах или -1.
func node_at(local: Vector2) -> int:
	for id in _pos:
		if local.distance_to(_pos[id]) <= ring_r(run.map.node(id)) + 8.0:
			return id
	return -1


func refresh() -> void:
	for p in _pulses:
		p.queue_free()
	_pulses.clear()
	# Доступные острова — кольцо, которое пульсирует через modulate.
	for id in MapActions.reachable(run):
		var ring := Node2D.new()
		ring.position = _pos[id]
		ring.draw.connect(_draw_pulse_ring.bind(ring, id))
		add_child(ring)
		_pulses.append(ring)
	# «Вы здесь» — у текущего острова; до первого острова (START) отметки нет. Последний ребёнок — поверх колец,
	# но без z_index: иначе отметка рисуется и поверх окон экрана (Кодекс, легенда).
	move_child(_here, -1)
	var here := run.map.current != MapState.START
	_here.visible = here
	_here_glow.visible = here
	if here:
		var n := run.map.node(run.map.current)
		_here_glow.position = _pos[n.id]
		# Острие штырька — в центре острова: Архивариус стоит на нём.
		_here_y = _pos[n.id].y - HERE_DISC_R - 18.0
		_here.position = Vector2(_pos[n.id].x, _here_y)
		_here.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var a := 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * 3.5))
	for p in _pulses:
		p.modulate.a = a
	if _here and _here.visible:
		_here.position.y = _here_y + sin(_time * 2.4) * 5.0
		_here_glow.modulate.a = 0.75 + 0.25 * sin(_time * 2.4)
	if _clouds_far:
		var m := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
		_clouds_far.position = -m * PARALLAX_FAR
		_clouds_near.position = -m * PARALLAX_NEAR
		_rift_glow.modulate.a = 0.7 + 0.3 * sin(_time * 1.6)
		_rift_glow.scale = Vector2.ONE * (1.0 + 0.04 * sin(_time * 1.6))


func _draw_pulse_ring(ring: Node2D, id: int) -> void:
	ring.draw_arc(Vector2.ZERO, ring_r(run.map.node(id)) + 10, 0, TAU, 40, UiKit.ACCENT, 4.0)


func _draw() -> void:
	if run == null:
		return
	var map := run.map
	var path := _visited_edges()
	var bridges := PackedVector2Array()
	var done := PackedVector2Array()
	for from in map.edges:
		for to in map.edges[from]:
			var dashes := _dashed(_pos[from], _pos[to], 10.0, 8.0)
			if path.has(Vector2i(from, to)):
				done.append_array(dashes)
			else:
				bridges.append_array(dashes)
	draw_multiline(bridges, BRIDGE, 2.0)
	if not done.is_empty():
		# Пройденный путь светится: широкий мягкий слой и яркая середина.
		draw_multiline(done, Color(BRIDGE_DONE, 0.18), 10.0)
		draw_multiline(done, BRIDGE_DONE, 3.0)
	if not hover_path.is_empty():
		var lit := PackedVector2Array()
		var from := map.current
		for id in hover_path:
			# Путь может спуститься к START (к другому острову первого слоя) — у START нет точки на карте.
			if from != MapState.START and id != MapState.START:
				lit.append_array(_dashed(_pos[from], _pos[id], 10.0, 8.0))
			from = id
		if not lit.is_empty():
			draw_multiline(lit, Color.WHITE, 3.5)

	var flights := MapActions.flight_targets(run)
	# Сверху вниз по экрану: ближние (нижние) острова перекрывают дальние.
	var order: Array = map.nodes.duplicate()
	order.sort_custom(func(a: MapState.MapNode, b: MapState.MapNode) -> bool: return _pos[a.id].y < _pos[b.id].y)
	for n: MapState.MapNode in order:
		# Непройденные острова не теряются (по карте можно вернуться) — темнее только пройденные, кроме текущего.
		var dim := map.visited.has(n.id) and n.id != map.current
		_draw_island(n, dim)
		var rr := ring_r(n)
		if flights.has(n.id):
			_dashed_ring(_pos[n.id], rr + 10, FLIGHT)
		if n.id == map.current:
			draw_arc(_pos[n.id], rr + 14, 0, TAU, 40, HERE, 4.0)
		if n.id == selected:
			draw_arc(_pos[n.id], rr + 18, 0, TAU, 40, Color.WHITE, 3.0)
		elif n.id == hovered:
			draw_arc(_pos[n.id], rr + 18, 0, TAU, 40, Color(1, 1, 1, 0.4), 2.0)
		elif hover_path.has(n.id):
			draw_arc(_pos[n.id], rr + 14, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0)
	_draw_path_rewards()


## Сумма ресурсов за бои на пути — у острова под курсором.
func _draw_path_rewards() -> void:
	if hover_path.is_empty() or hovered < 0 or hover_rewards.values().all(func(v: int) -> bool: return v == 0):
		return
	var rr := ring_r(run.map.node(hovered))
	var w := 0.0
	for k in RunState.RESOURCE_IDS:
		if hover_rewards.get(k, 0) > 0:
			w += 52.0
	var p := _pos[hovered] + Vector2(rr + 24, -rr * 0.4)
	if run.map.node(hovered).lane >= MapState.LANES - 1:
		# У правого края — слева от острова, чтобы не уйти под боковую панель.
		p.x = _pos[hovered].x - rr - 24 - w
	draw_rect(Rect2(p + Vector2(-8, -16), Vector2(w + 8, 32)), Color(UiKit.BG_COLOR, 0.85))
	for k in RunState.RESOURCE_IDS:
		var v: int = hover_rewards.get(k, 0)
		if v <= 0:
			continue
		var col: Color = UiKit.RESOURCE_COLORS[k]
		UnitGlyphs.draw_icon(self, UiKit.RESOURCE_ICONS[k], p + Vector2(10, 0), 11, Color(0, 0, 0, 0), col, false)
		draw_string(_font, p + Vector2(22, 7), "+%d" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		p.x += 52.0


## Рисованный остров типа и акта острова n или null (тогда — процедурный).
func island_art(n: MapState.MapNode) -> Texture2D:
	return ArtDB.island(ISLAND_ART[n.type], run.act)


## Радиус, от которого считаются кольца выбора, пульсации и попадание курсора.
func ring_r(n: MapState.MapNode) -> float:
	var r := RIFT_R if n.type == MapState.NodeType.RIFT else ISLAND_R
	return r * ART_RING if island_art(n) else r


func _draw_island(n: MapState.MapNode, dim: bool) -> void:
	var c := _pos[n.id]
	var r := RIFT_R if n.type == MapState.NodeType.RIFT else ISLAND_R
	var alpha := 0.4 if dim else 1.0
	var tex := island_art(n)
	if tex:
		# Картинка по центру острова; пройденные и недоступные — темнее и прозрачнее.
		var w := r * ART_SCALE
		var size := Vector2(w, w * tex.get_height() / tex.get_width())
		var tint := Color(0.55, 0.55, 0.6, 0.7) if dim else Color.WHITE
		draw_texture_rect(tex, Rect2(c - size * Vector2(0.5, 0.45), size), false, tint)
		_draw_marks(n, c, r * ART_RING * 0.8, dim)
		return
	var col: Color = TYPE_COLORS[n.type]
	# Скала снизу и плоская вершина острова.
	var rock := ROCK_FLOODED if _flooded() else ROCK
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 2), c + Vector2(r, 2), c + Vector2(r * 0.35, r * 1.05), c + Vector2(0, r * 1.35), c + Vector2(-r * 0.4, r * 0.95)]), Color(rock, alpha))
	if _flooded():
		# Затопленный зал: вода стоит у середины скалы, по ней — круги.
		var wl := c + Vector2(0, r * 0.7)
		draw_polyline(_ellipse_arc(wl, r * 1.15, 0.0, PI), Color(WATERLINE, 0.55 * alpha), 2.0)
		draw_polyline(_ellipse_arc(wl + Vector2(0, 5), r * 1.45, PI * 0.15, PI * 0.85), Color(WATERLINE, 0.3 * alpha), 1.5)
	var top := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		top.append(c + Vector2(cos(a) * r, sin(a) * r * 0.45))
	draw_colored_polygon(top, Color(col, alpha))
	# Объём: светлая кромка сверху, тень под вершиной.
	draw_polyline(_ellipse_arc(c + Vector2(0, -1), r * 0.9, PI * 1.08, PI * 1.92), Color(col.lightened(0.35), 0.8 * alpha), 3.0)
	draw_polyline(_ellipse_arc(c + Vector2(0, 2), r * 0.92, PI * 0.1, PI * 0.9), Color(0, 0, 0, 0.25 * alpha), 3.0)
	var icon_c := c + Vector2(0, -r * 0.55)
	if n.type == MapState.NodeType.RIFT:
		for i in 3:
			draw_arc(icon_c + Vector2(0, 6), 10.0 + i * 9.0, i * 1.3, i * 1.3 + PI * 1.4, 18, Color(0.9, 0.7, 1.0, alpha), 4.0)
	elif n.type == MapState.NodeType.EVENT:
		draw_circle(icon_c, 15, Color(UiKit.BG_COLOR, alpha))
		draw_string(_font, icon_c + Vector2(-15, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 30, 24, Color(1, 1, 1, alpha))
	else:
		UnitGlyphs.draw_icon(self, TYPE_ICONS[n.type], icon_c, 15, Color(UiKit.BG_COLOR, alpha), Color(1, 1, 1, alpha))
	_draw_marks(n, c, r, dim)


## Отметки поверх острова: пройден, разведан, риск боя.
func _draw_marks(n: MapState.MapNode, c: Vector2, r: float, dim: bool) -> void:
	if run.map.visited.has(n.id):
		draw_polyline(PackedVector2Array([c + Vector2(-9, 2), c + Vector2(-2, 9), c + Vector2(11, -6)]), Color(UiKit.ACCENT, 0.9), 4.0)
	if n.scouted and not run.map.visited.has(n.id):
		UnitGlyphs.draw_icon(self, UnitGlyphs.ICON_MARK, c + Vector2(r * 0.9, -r * 0.5), 10, UiKit.BG_COLOR, FLIGHT)
	if risks.has(n.id) and not dim:
		# Риск боя: череп цвета уровня (зелёный — ниже, жёлтый — равный, красный — выше).
		UnitGlyphs.draw_icon(self, UnitGlyphs.ICON_KILL, c + Vector2(-r * 0.95, -r * 0.45), 11, UiKit.BG_COLOR, CardAdvisor.RISK_COLORS[risks[n.id]])


## Дуга эллипса вершины острова (сплющена как сама вершина).
static func _ellipse_arc(c: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(from, to, i / 12.0)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.45))
	return pts


## Облака слоя layer (дальний — больше и бледнее); рисуются один раз. Во втором акте — туман.
func _draw_clouds(ci: Node2D, layer: int, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.run_seed + layer * 977
	if _flooded():
		_draw_fog(ci, rng, layer, alpha)
		return
	for i in (9 if layer == 0 else 7):
		var c := Vector2(rng.randf_range(-720, 720), rng.randf_range(-LAYER_SPACING * 7.8, LAYER_SPACING * 1.0))
		var w := rng.randf_range(120, 260) if layer == 0 else rng.randf_range(80, 170)
		# Облако из нескольких перекрывающихся эллипсов.
		for blob in 3:
			var bc := c + Vector2((blob - 1) * w * 0.45, absf(blob - 1.0) * w * 0.05)
			var bw := w * (0.75 if blob != 1 else 1.0)
			var pts := PackedVector2Array()
			for k in 18:
				var a := TAU * k / 18.0
				pts.append(bc + Vector2(cos(a) * bw * 0.6, sin(a) * bw * 0.2))
			ci.draw_colored_polygon(pts, Color(0.62, 0.66, 0.8, alpha))


## Туман второго акта: длинные пологие полосы над водой.
func _draw_fog(ci: Node2D, rng: RandomNumberGenerator, layer: int, alpha: float) -> void:
	for i in (14 if layer == 0 else 10):
		var c := Vector2(rng.randf_range(-760, 760), rng.randf_range(-LAYER_SPACING * 7.8, LAYER_SPACING * 1.0))
		var w := rng.randf_range(260, 520) if layer == 0 else rng.randf_range(180, 360)
		for band in 2:
			var pts := PackedVector2Array()
			var bc := c + Vector2(band * w * 0.3, band * 10.0)
			for k in 24:
				var a := TAU * k / 24.0
				pts.append(bc + Vector2(cos(a) * w * 0.6, sin(a) * w * 0.07))
			ci.draw_colored_polygon(pts, Color(FOG, alpha * (0.9 if band == 0 else 0.6)))


func _visited_edges() -> Array[Vector2i]:
	# Светятся мосты между пройденными островами (и к начатому): по карте ходят в обе стороны.
	var result: Array[Vector2i] = []
	var map := run.map
	var done := func(id: int) -> bool: return map.visited.has(id) or id == run.pending_node
	for from in map.edges:
		for to in map.edges[from]:
			if done.call(from) and done.call(int(to)):
				result.append(Vector2i(from, to))
	return result


## Отрезки пунктира от a к b (пары точек для draw_multiline).
static func _dashed(a: Vector2, b: Vector2, dash: float, gap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var t := ISLAND_R * 0.6
	while t < len - ISLAND_R * 0.6:
		out.append(a + dir * t)
		out.append(a + dir * minf(t + dash, len))
		t += dash + gap
	return out


func _dashed_ring(c: Vector2, r: float, color: Color) -> void:
	var segs := PackedVector2Array()
	for i in 16:
		var a0 := TAU * i / 16.0
		segs.append(c + Vector2.from_angle(a0) * r)
		segs.append(c + Vector2.from_angle(a0 + TAU / 32.0) * r)
	draw_multiline(segs, color, 2.5)
