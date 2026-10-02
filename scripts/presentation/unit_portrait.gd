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
	var rect := Rect2(Vector2.ZERO, size)
	var side_color := UiKit.PLAYER_COLOR if side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	draw_rect(rect, body_color.darkened(0.15))
	var r := minf(size.x, size.y) * 0.42
	var center := size * Vector2(0.5, 0.44 if show_count else 0.5)
	UnitGlyphs.draw_unit(self, def_id, center, r, body_color.darkened(0.15))
	if show_count:
		var font := get_theme_default_font()
		var fs := int(size.y * 0.24)
		var band := Rect2(0, size.y - fs - 4, size.x, fs + 4)
		draw_rect(band, side_color.darkened(0.6))
		draw_string(font, Vector2(0, size.y - 5), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
	var border := UiKit.ACTIVE_BORDER if active else side_color
	draw_rect(rect, border, false, 4.0 if active else 2.0)
