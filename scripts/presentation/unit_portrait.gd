class_name UnitPortrait
extends Control
## Квадратный портрет стека: силуэт, численность, рамка стороны.

var def_id: StringName
var body_color := Color.GRAY
var side := 0
var count := 0
var active := false
var show_count := true


static func create(db: DefsDB, u: UnitState, p_size: float, p_active: bool = false) -> UnitPortrait:
	var p := UnitPortrait.new()
	p.custom_minimum_size = Vector2(p_size, p_size)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.set_unit(db, u, p_active)
	return p


func set_unit(db: DefsDB, u: UnitState, p_active: bool = false) -> void:
	def_id = u.def_id
	body_color = db.unit(u.def_id).color
	side = u.side
	count = u.count
	active = p_active
	tooltip_text = UiKit.unit_name(db, u.def_id)
	queue_redraw()


func _draw() -> void:
	draw_portrait(self, Rect2(Vector2.ZERO, size), def_id, body_color, side, count if show_count else -1, active, get_theme_default_font())


## Портрет в прямоугольнике rect; count < 0 — без численности. Общий для карточек и полосы очереди.
static func draw_portrait(ci: CanvasItem, rect: Rect2, p_def: StringName, color: Color, p_side: int, p_count: int,
		p_active: bool, font: Font, alpha: float = 1.0, lit: bool = false) -> void:
	var side_color := UiKit.PLAYER_COLOR if p_side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	var body := color.darkened(0.15)
	if lit:
		body = body.lightened(0.25)
	body.a = alpha
	ci.draw_rect(rect, body)
	var r := minf(rect.size.x, rect.size.y) * 0.42
	var center := rect.position + rect.size * Vector2(0.5, 0.44 if p_count >= 0 else 0.5)
	var art := ArtDB.unit(p_def)
	var tex := IconAtlas.get_glyph(p_def, Color(body, 1.0)) if art == null else null
	if art:
		# Рисованный портрет: верхняя часть фигуры (кадр из манифеста), на тёмном фоне цвета существа.
		ci.draw_rect(rect, Color(color.darkened(0.6), alpha))
		var inner := rect.grow(-2.0)
		ci.draw_texture_rect_region(art, inner, ArtDB.portrait_region(p_def), Color(1.15, 1.15, 1.15, alpha) if lit else Color(1, 1, 1, alpha))
	elif tex:
		ci.draw_texture_rect(tex, IconAtlas.glyph_rect(center, r), false, Color(1, 1, 1, alpha))
	else:
		UnitGlyphs.draw_unit(ci, p_def, center, r, body, Color(UnitGlyphs.INK, alpha))
		UnitGlyphs.draw_details(ci, p_def, center, r, body)
	if p_count >= 0:
		var fs := int(rect.size.y * 0.24)
		var band := Rect2(rect.position.x, rect.end.y - fs - 4, rect.size.x, fs + 4)
		ci.draw_rect(band, Color(side_color.darkened(0.6), alpha))
		ci.draw_string(font, Vector2(rect.position.x, rect.end.y - 5), str(p_count), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(1, 1, 1, alpha))
	var border := UiKit.ACTIVE_BORDER if p_active else (Color.WHITE if lit else side_color)
	ci.draw_rect(rect, Color(border, alpha), false, 4.0 if p_active or lit else 2.0)
