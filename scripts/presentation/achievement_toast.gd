class_name AchievementToast
extends CanvasLayer
## Уведомление о достижении (SPEC_SPRINT9 6): плашка сверху — значок и название — на 3 с.
## Несколько достижений показываются по очереди. Клики проходят насквозь — бой не прерывается.

const SHOW_TIME := 3.0
const FADE := 0.25

var _queue: Array[StringName] = []
var _panel: PanelContainer
var _busy := false


func _ready() -> void:
	layer = 90


## Поставить достижения в очередь показа.
func show_ids(ids: Array[StringName]) -> void:
	_queue.append_array(ids)
	if not _busy:
		_next()


func _next() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	if _queue.is_empty() or Game.defs == null:
		_busy = false
		return
	_busy = true
	var a := Game.defs.achievement(_queue.pop_front())
	_panel = _build(a)
	add_child(_panel)
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, FADE)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "modulate:a", 0.0, FADE)
	tw.tween_callback(_next)


func _build(a: AchievementDef) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.1, 0.09, 0.08, 0.94), a.color, 2, true))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 24
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(UiKit.icon_rect(a.icon, 44, a.color))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiKit.label(tr("ACH_TOAST"), 16, UiKit.MUTED))
	col.add_child(UiKit.label(tr(a.name_key), 26, a.color.lightened(0.2)))
	col.add_child(UiKit.label(Achievements.reward_text(Game.defs, a), 16, UiKit.ACCENT))
	return panel
