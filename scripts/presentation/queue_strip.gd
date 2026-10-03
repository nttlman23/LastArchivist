class_name QueueStrip
extends Control
## Полоса очереди ходов (SPEC_SPRINT6 11): все портреты рисуются одним объектом.
## Отдельный Control на портрет давал ~5 вызовов отрисовки на каждый — при программной
## отрисовке это ~5 мс на кадр. Наведение и подсказка определяются по координате мыши.

signal hovered(uid: int)

const GAP := 6.0
const ROUND_GAP := 56.0

## Слоты: {"uid", "def", "color", "side", "count", "size", "active", "next"}.
var slots: Array[Dictionary] = []
var round_label := ""
var highlight_uid := -1
var _rects: Array[Rect2] = []
var _hover := -1


func set_slots(p_slots: Array[Dictionary], p_round_label: String) -> void:
	slots = p_slots
	round_label = p_round_label
	_layout()
	queue_redraw()


func set_highlight(uid: int) -> void:
	if uid != highlight_uid:
		highlight_uid = uid
		queue_redraw()


func _layout() -> void:
	_rects.clear()
	var x := 0.0
	var height := 0.0
	var gap_done := false
	for s in slots:
		if s["next"] and not gap_done:
			x += ROUND_GAP
			gap_done = true
		var sz: float = s["size"]
		height = maxf(height, sz)
		_rects.append(Rect2(x, 0, sz, sz))
		x += sz + GAP
	for i in _rects.size():
		_rects[i].position.y = (height - _rects[i].size.y) * 0.5
	custom_minimum_size = Vector2(maxf(0.0, x - GAP), height)


func _slot_at(pos: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _slot_at(event.position)
		var uid: int = slots[i]["uid"] if i >= 0 else -1
		if uid != _hover:
			_hover = uid
			hovered.emit(uid)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		hovered.emit(-1)


func _get_tooltip(at_position: Vector2) -> String:
	var i := _slot_at(at_position)
	return String(slots[i].get("name", "")) if i >= 0 else ""


func _draw() -> void:
	var font := get_theme_default_font()
	var label_drawn := false
	for i in slots.size():
		var s := slots[i]
		var r := _rects[i]
		if s["next"] and not label_drawn:
			label_drawn = true
			draw_string(font, Vector2(r.position.x - ROUND_GAP + 4, r.get_center().y + 7), round_label,
					HORIZONTAL_ALIGNMENT_CENTER, ROUND_GAP - 8, 18, UiKit.MUTED)
		var dim: bool = s["next"] and s["uid"] != highlight_uid
		UnitPortrait.draw_portrait(self, r, s["def"], s["color"], s["side"], s["count"], s["active"], font, 0.5 if dim else 1.0,
				s["uid"] == highlight_uid)
