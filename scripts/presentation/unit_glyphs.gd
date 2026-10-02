class_name UnitGlyphs
extends RefCounted
## Процедурные силуэты существ и значки способностей (плейсхолдер вместо арта).
## Все фигуры задаются в нормированных координатах [-1, 1] и масштабируются радиусом.

const INK := Color(0.07, 0.07, 0.1)

# Значки способностей и состояний.
const ICON_MELEE := &"melee"
const ICON_RANGED := &"ranged"
const ICON_FLYING := &"flying"
const ICON_RETALIATION := &"retaliation"
const ICON_RETALIATION_USED := &"retaliation_used"
const ICON_DEFEND := &"defend"
const ICON_WAIT := &"wait"
const ICON_MOVE := &"move"


## Силуэт существа по id определения.
static func draw_unit(ci: CanvasItem, def_id: StringName, c: Vector2, r: float, body: Color, ink: Color = INK) -> void:
	match def_id:
		&"salt_guard":
			_shield(ci, c, r * 0.95, ink, body)
		&"chronicler":
			_scroll_and_quill(ci, c, r, ink, body)
		&"ash_ghoul":
			_claws(ci, c, r, ink)
		&"shard_archer":
			_bow(ci, c, r, ink)
		&"storm_wyrm_echo":
			_poly(ci, c, r, [Vector2(0.15, -0.8), Vector2(-0.45, 0.12), Vector2(-0.02, 0.12), Vector2(-0.22, 0.8), Vector2(0.48, -0.18), Vector2(0.05, -0.18)], ink)
		&"rust_sentinel":
			_tower(ci, c, r, ink, body)
		_:
			ci.draw_circle(c, r * 0.45, ink)


## Значок способности/состояния в круглом медальоне.
static func draw_icon(ci: CanvasItem, kind: StringName, c: Vector2, r: float, bg: Color, fg: Color = Color.WHITE) -> void:
	ci.draw_circle(c, r, bg)
	ci.draw_circle(c, r, Color(fg, 0.35 * fg.a), false, 1.5)
	var s := r * 0.75
	match kind:
		ICON_MELEE:
			_sword(ci, c, s, fg, -45.0)
		ICON_RANGED:
			_arrow(ci, c, s, fg)
		ICON_FLYING:
			_poly(ci, c, s, [Vector2(-0.9, 0.5), Vector2(-0.2, -0.8), Vector2(0.9, -0.9), Vector2(0.5, -0.3), Vector2(0.75, -0.2), Vector2(0.3, 0.2), Vector2(0.5, 0.3), Vector2(-0.1, 0.6)], fg)
		ICON_RETALIATION, ICON_RETALIATION_USED:
			_sword(ci, c, s, fg, -45.0)
			_sword(ci, c, s, fg, 45.0)
			if kind == ICON_RETALIATION_USED:
				ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), UiKit.DANGER, 3.0)
		ICON_DEFEND:
			_shield(ci, c, s, fg, bg)
		ICON_WAIT:
			_poly(ci, c, s, [Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0, 0)], fg)
			_poly(ci, c, s, [Vector2(0, 0), Vector2(0.6, 0.8), Vector2(-0.6, 0.8)], fg)
		ICON_MOVE:
			_poly(ci, c, s, [Vector2(-0.8, -0.25), Vector2(0.1, -0.25), Vector2(0.1, -0.7), Vector2(0.85, 0), Vector2(0.1, 0.7), Vector2(0.1, 0.25), Vector2(-0.8, 0.25)], fg)


# --- Примитивы ---------------------------------------------------------------

static func _poly(ci: CanvasItem, c: Vector2, r: float, pts: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p: Vector2 in pts:
		packed.append(c + p * r)
	ci.draw_colored_polygon(packed, color)


static func _shield(ci: CanvasItem, c: Vector2, r: float, ink: Color, accent: Color) -> void:
	_poly(ci, c, r, [Vector2(-0.6, -0.65), Vector2(0.6, -0.65), Vector2(0.6, 0.1), Vector2(0, 0.8), Vector2(-0.6, 0.1)], ink)
	ci.draw_line(c + Vector2(0, -0.5) * r, c + Vector2(0, 0.6) * r, accent, maxf(2.0, r * 0.12))
	ci.draw_line(c + Vector2(-0.45, -0.15) * r, c + Vector2(0.45, -0.15) * r, accent, maxf(2.0, r * 0.12))


static func _scroll_and_quill(ci: CanvasItem, c: Vector2, r: float, ink: Color, body: Color) -> void:
	# Свиток
	_poly(ci, c, r, [Vector2(-0.6, 0.0), Vector2(0.45, 0.0), Vector2(0.45, 0.55), Vector2(-0.6, 0.55)], ink)
	ci.draw_circle(c + Vector2(-0.6, 0.27) * r, r * 0.27, ink)
	ci.draw_circle(c + Vector2(0.45, 0.27) * r, r * 0.27, ink)
	for y: float in [0.17, 0.37]:
		ci.draw_line(c + Vector2(-0.45, y) * r, c + Vector2(0.3, y) * r, body, maxf(1.5, r * 0.06))
	# Перо
	_poly(ci, c, r, [Vector2(0.05, -0.05), Vector2(0.35, -0.85), Vector2(0.7, -0.75), Vector2(0.2, -0.1)], ink)


static func _claws(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	for i in 3:
		var dx := (i - 1) * 0.38
		var pts := PackedVector2Array()
		for t in 7:
			var k := t / 6.0
			pts.append(c + Vector2(dx - 0.3 + 0.55 * k + 0.12 * sin(k * PI), -0.7 + 1.4 * k) * r)
		ci.draw_polyline(pts, ink, maxf(3.0, r * 0.2))


static func _bow(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	var center := c + Vector2(-0.35, 0) * r
	ci.draw_arc(center, r * 0.75, deg_to_rad(-70), deg_to_rad(70), 16, ink, maxf(3.0, r * 0.15))
	var top := center + Vector2.from_angle(deg_to_rad(-70)) * r * 0.75
	var bottom := center + Vector2.from_angle(deg_to_rad(70)) * r * 0.75
	ci.draw_line(top, bottom, ink, maxf(1.0, r * 0.05))
	ci.draw_line(c + Vector2(-0.55, 0) * r, c + Vector2(0.55, 0) * r, ink, maxf(2.0, r * 0.08))
	_poly(ci, c, r, [Vector2(0.85, 0), Vector2(0.5, -0.2), Vector2(0.5, 0.2)], ink)


static func _tower(ci: CanvasItem, c: Vector2, r: float, ink: Color, body: Color) -> void:
	_poly(ci, c, r, [
		Vector2(-0.5, 0.7), Vector2(-0.5, -0.45), Vector2(-0.3, -0.45), Vector2(-0.3, -0.7),
		Vector2(-0.1, -0.7), Vector2(-0.1, -0.45), Vector2(0.1, -0.45), Vector2(0.1, -0.7),
		Vector2(0.3, -0.7), Vector2(0.3, -0.45), Vector2(0.5, -0.45), Vector2(0.5, 0.7),
	], ink)
	_poly(ci, c, r, [Vector2(-0.15, 0.7), Vector2(-0.15, 0.3), Vector2(0, 0.15), Vector2(0.15, 0.3), Vector2(0.15, 0.7)], body)
	ci.draw_line(c + Vector2(-0.25, -0.15) * r, c + Vector2(0.25, -0.15) * r, body, maxf(2.0, r * 0.1))


static func _sword(ci: CanvasItem, c: Vector2, r: float, color: Color, angle_deg: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var perp := dir.orthogonal()
	ci.draw_line(c - dir * r * 0.9, c + dir * r * 0.9, color, maxf(2.0, r * 0.18))
	ci.draw_line(c - dir * r * 0.45 - perp * r * 0.35, c - dir * r * 0.45 + perp * r * 0.35, color, maxf(2.0, r * 0.16))


static func _arrow(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var dir := Vector2(1, -1).normalized()
	ci.draw_line(c - dir * r * 0.85, c + dir * r * 0.4, color, maxf(2.0, r * 0.16))
	var tip := c + dir * r * 0.9
	var perp := dir.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * r * 0.55 + perp * r * 0.35, tip - dir * r * 0.55 - perp * r * 0.35]), color)
	var tail := c - dir * r * 0.85
	ci.draw_line(tail, tail + (perp - dir) * r * 0.3, color, maxf(1.5, r * 0.12))
	ci.draw_line(tail, tail + (-perp - dir) * r * 0.3, color, maxf(1.5, r * 0.12))
