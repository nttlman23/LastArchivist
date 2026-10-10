class_name AchievementToast
extends CanvasLayer
## Уведомления сверху на 3 с (SPEC_SPRINT9 6, SPEC_SPRINT10 6): достижение, найденная страница памяти,
## открытая глава истории. Несколько — по очереди. Клики проходят насквозь — бой не прерывается.

const SHOW_TIME := 3.0
const FADE := 0.25
const PAGE_COLOR := Color(0.9, 0.82, 0.62)
const CHAPTER_COLOR := Color(0.75, 0.55, 1.0)

## Очередь: {"kind": &"ach" | &"page" | &"chapter", "id": StringName или номер главы}.
var _queue: Array[Dictionary] = []
var _panel: PanelContainer
var _busy := false


func _ready() -> void:
	layer = 90


## Поставить достижения в очередь показа.
func show_ids(ids: Array[StringName]) -> void:
	for id in ids:
		_push({"kind": &"ach", "id": id})


func show_page(id: StringName) -> void:
	_push({"kind": &"page", "id": id})


func show_chapter(chapter: int) -> void:
	_push({"kind": &"chapter", "id": chapter})


func _push(item: Dictionary) -> void:
	_queue.append(item)
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
	_panel = _build(_queue.pop_front())
	add_child(_panel)
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, FADE)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "modulate:a", 0.0, FADE)
	tw.tween_callback(_next)


func _build(item: Dictionary) -> PanelContainer:
	var head: String
	var title: String
	var sub: String
	var color: Color
	var picture: Control
	match item["kind"]:
		&"page":
			head = tr("STORY_PAGE_TOAST")
			title = tr("PAGE_%s_TITLE" % String(item["id"]).to_upper())
			sub = tr("STORY_PAGE_TOAST_SUB")
			color = PAGE_COLOR
			picture = UiKit.icon_rect(UnitGlyphs.ICON_PARCHMENT, 44, color)
		&"chapter":
			head = tr("STORY_CHAPTER_TOAST")
			title = Story.chapter_name(int(item["id"]))
			sub = tr("STORY_CHAPTER_TOAST_SUB")
			color = CHAPTER_COLOR
			picture = UiKit.icon_rect(UnitGlyphs.ICON_POINTS, 44, color)
		_:
			var a := Game.defs.achievement(item["id"])
			head = tr("ACH_TOAST")
			title = tr(a.name_key)
			sub = Achievements.reward_text(Game.defs, a)
			color = a.color
			var medal := ArtDB.achievement(a.id)
			picture = UiKit.art_rect(medal, Vector2(64, 64)) if medal else UiKit.icon_rect(a.icon, 44, a.color)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.1, 0.09, 0.08, 0.94), color, 2, true))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 24
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(picture)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiKit.label(head, 16, UiKit.MUTED))
	col.add_child(UiKit.label(title, 26, color.lightened(0.2)))
	col.add_child(UiKit.label(sub, 16, UiKit.ACCENT))
	return panel
