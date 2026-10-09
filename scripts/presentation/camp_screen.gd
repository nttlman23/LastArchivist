extends Control
## Привал между актами (SPEC_SPRINT7 3): плашка «Разлом закрыт», затем один выбор —
## полный ремонт или один из трёх даров. Решение — плитками со значками, подробности в подсказке.

const TILE := Vector2(300, 260)

var db: DefsDB
var run: RunState


func _ready() -> void:
	if Game.run == null or not Game.run.at_camp:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	UiKit.add_background(self, false, &"camp")
	var box := UiKit.centered_column(self, 22)
	var title := UiKit.label(tr("CAMP_TITLE"), 48, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiKit.label(tr("CAMP_TEXT"), 22, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for option in CampOps.options(run):
		row.add_child(_tile(option))
	Hints.show_hint(&"camp")


func _tile(option: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var reason := CampOps.reason(db, run, option)
	var kind: StringName = option["kind"]
	match kind:
		CampOps.HERO, CampOps.UNIT:
			# Карта — как в наградах.
			var card := UiKit.card_button(db, option["id"])
			card.disabled = reason != ""
			card.pressed.connect(_choose.bind(option))
			col.add_child(card)
		_:
			var b := Button.new()
			b.custom_minimum_size = Vector2(TILE.x, MemoryCard.HEIGHT)
			b.focus_mode = Control.FOCUS_NONE
			b.icon = IconAtlas.get_icon(UnitGlyphs.ICON_HEAL if kind == CampOps.REPAIR else UnitGlyphs.ICON_POINTS)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 40)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 20)
			var key := "CAMP_REPAIR" if kind == CampOps.REPAIR else "CAMP_" + String(option["id"]).to_upper()
			b.text = tr(key)
			b.disabled = reason != ""
			Tip.attach(b, tr(key), tr(key + "_TIP"))
			b.pressed.connect(_choose.bind(option))
			UiKit.add_hover_lift(b)
			col.add_child(b)
	var label := UiKit.label(tr("CAMP_KIND_" + String(kind).to_upper()) if reason == "" else tr(reason), 18,
			UiKit.ACCENT if reason == "" else UiKit.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TILE.x if kind == CampOps.REPAIR or kind == CampOps.GIFT else 400.0
	col.add_child(label)
	return col


func _choose(option: Dictionary) -> void:
	Audio.play(&"transform")
	Game.leave_camp(option)
