extends Control
## Реликварий (SPEC_SPRINT7 11): одна из двух реликвий — постоянный бонус с ценой — или отказ.

var db: DefsDB
var run: RunState
var offer: Array[StringName] = []


func _ready() -> void:
	if Game.run == null or Game.run.pending() == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	offer = RelicOps.offer(db, run, run.pending_node)
	UiKit.add_background(self, false, &"reliquary")
	var box := UiKit.centered_column(self, 22)
	var title := UiKit.label(tr("RELIQUARY_TITLE"), 44, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiKit.label(tr("RELIQUARY_TEXT"), 22, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for id in offer:
		row.add_child(_tile(id))
	var leave := UiKit.button(tr("RELIQUARY_LEAVE"), Game.complete_node, 360)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(leave)
	Hints.show_hint(&"reliquary")


## Плитка реликвии: картинка или значок, имя, бонус и цена (текст описания).
func _tile(id: StringName) -> Button:
	var def := db.relic(id)
	var b := Button.new()
	var art := ArtDB.relic(id)
	b.custom_minimum_size = Vector2(380, 360 if art else 230)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.PANEL_COLOR, def.color.darkened(0.3), 2, true))
	b.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.PANEL_COLOR.lightened(0.08), def.color, 2, true))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18
	col.offset_right = -18
	col.offset_top = 16
	col.offset_bottom = -16
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	# Рисованная реликвия (SPEC_SPRINT9 18), без неё — значок цвета реликвии.
	col.add_child(UiKit.art_rect(art, Vector2(0, 150)) if art else UiKit.icon_rect(def.icon, 44, def.color))
	var name := UiKit.label(tr(def.name_key), 26, def.color.lightened(0.2))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var desc := UiKit.label(tr(def.desc_key), 18, Color.WHITE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(desc)
	b.pressed.connect(_take.bind(id))
	UiKit.add_hover_lift(b)
	return b


func _take(id: StringName) -> void:
	Audio.play(&"transform")
	RelicOps.take(db, run, id, run.node_seed(run.pending_node, "relic_cost"))
	Game.achievement_event(Achievements.Event.RELIC)
	Game.story_event(Story.Event.RELIC)
	Game.complete_node()
