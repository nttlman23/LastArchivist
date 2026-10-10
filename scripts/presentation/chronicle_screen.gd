extends Control
## Летопись (SPEC_SPRINT5 6, SPEC_SPRINT10 4–6): забеги — сводка по школам и строки забегов; страницы памяти по главам;
## просмотренные сценки — повтор. Кодекс забега — в подсказке строки.

const OUTCOME_ICONS := {
	ProfileState.OUTCOME_WON: UnitGlyphs.ICON_RETALIATION,
	ProfileState.OUTCOME_LOST: UnitGlyphs.ICON_KILL,
	ProfileState.OUTCOME_ABANDONED: UnitGlyphs.ICON_MOVE,
}
const OUTCOME_COLORS := {
	ProfileState.OUTCOME_WON: Color(0.95, 0.8, 0.4),
	ProfileState.OUTCOME_LOST: Color(1.0, 0.45, 0.4),
	ProfileState.OUTCOME_ABANDONED: Color(0.6, 0.62, 0.68),
}

## Вкладки (SPEC_SPRINT10 4, 6): забеги, страницы памяти, сценки. Выбранная запоминается до перезапуска.
enum Tab { RUNS, PAGES, SCENES }
static var tab := Tab.RUNS

var db: DefsDB
var _content: VBoxContainer


func _ready() -> void:
	db = Game.defs
	UiKit.add_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	head.add_child(UiKit.label(tr("CHRONICLE_TITLE"), 44, UiKit.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var group := ButtonGroup.new()
	for t in [Tab.RUNS, Tab.PAGES, Tab.SCENES]:
		var b := Button.new()
		b.text = tr(["CHRONICLE_TAB_RUNS", "CHRONICLE_TAB_PAGES", "CHRONICLE_TAB_SCENES"][t])
		if t == Tab.PAGES:
			b.text += " (%d/%d)" % [Game.profile.story_pages.size(), db.pages.size()]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == tab
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(230, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_set_tab.bind(t))
		head.add_child(b)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	var back := UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(back)
	_rebuild()


func _set_tab(t: Tab) -> void:
	tab = t
	Audio.play(&"ui_click")
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	match tab:
		Tab.PAGES:
			_build_pages()
		Tab.SCENES:
			_build_scenes()
		_:
			_build_runs()


func _scroll_list(separation: int = 6) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", separation)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _build_runs() -> void:
	_content.add_child(_summary())
	_content.add_child(UiKit.label(tr("CHRONICLE_RUNS"), 28, UiKit.ACCENT))
	var list := _scroll_list()
	if Game.profile.chronicle.is_empty():
		list.add_child(UiKit.label(tr("CHRONICLE_EMPTY"), 20, UiKit.MUTED))
	for entry in Game.profile.chronicle:
		list.add_child(_run_row(entry))


## Страницы памяти по главам: найденные — с текстом, ненайденные — тусклые, с подсказкой, где искать.
func _build_pages() -> void:
	var p := Game.profile
	var list := _scroll_list(10)
	for ch in range(1, Story.MAX_CHAPTER + 1):
		var open := ch <= p.story_chapter
		var title := UiKit.label(Story.chapter_name(ch), 28, UiKit.ACCENT if open else UiKit.MUTED)
		list.add_child(title)
		if not open:
			list.add_child(UiKit.label(tr("STORY_CHAPTER_LOCKED_%d" % ch), 18, UiKit.MUTED))
			continue
		for page in db.pages_sorted():
			if page.chapter == ch:
				list.add_child(_page_row(page))


func _page_row(page: PageDef) -> PanelContainer:
	var found := Game.profile.story_pages.has(page.id)
	var key := "PAGE_%s" % String(page.id).to_upper()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR if found else UiKit.PANEL_COLOR.darkened(0.25)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(UiKit.icon_rect(UnitGlyphs.ICON_PARCHMENT if found else UnitGlyphs.ICON_LOCK, 22, AchievementToast.PAGE_COLOR if found else UiKit.MUTED))
	row.add_child(UiKit.label(tr(key + "_TITLE") if found else tr("STORY_PAGE_UNKNOWN"), 22, AchievementToast.PAGE_COLOR if found else UiKit.MUTED))
	if found:
		var date := UiKit.label(Game.profile.story_pages[page.id], 14, UiKit.MUTED)
		date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(date)
		var text := UiKit.label(tr(key + "_TEXT"), 18, Color(0.9, 0.88, 0.82))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(text)
	else:
		col.add_child(UiKit.label(_page_hint(page), 16, UiKit.MUTED))
	return panel


## Где искать страницу: по условию; у сюжетного события — его акт.
func _page_hint(page: PageDef) -> String:
	if page.condition == Story.STORY_EVENT and db.has_event(page.arg):
		return tr("STORY_HINT_STORY_EVENT") % tr("STORY_ACT_%d" % db.event(page.arg).act)
	var text := tr("STORY_HINT_%s" % String(page.condition).to_upper())
	return text % page.count if "%d" in text else text


## Просмотренные сценки — пересмотреть; остальные — тусклые.
func _build_scenes() -> void:
	var list := _scroll_list(8)
	for id in Story.SCENES:
		var seen := Game.profile.story_seen.has(id)
		var title := tr("STORY_SCENE_%s_TITLE" % String(id).to_upper()) if seen else tr("STORY_SCENE_UNKNOWN")
		var b := UiKit.button(title, _replay.bind(id), 520)
		b.disabled = not seen
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		list.add_child(b)


func _replay(id: StringName) -> void:
	Game.show_story(id, Game.SCENE_CHRONICLE)


## Сводка: по карточке на школу — попытки, победы, лучший слой.
func _summary() -> HFlowContainer:
	var row := UiKit.flow(16)
	var ids: Array = db.schools.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return db.school(a).order < db.school(b).order)
	for id: StringName in ids:
		var school := db.school(id)
		if not school.implemented:
			continue
		var stats: Dictionary = Game.profile.school_stats.get(id, {"runs": 0, "wins": 0, "best": 0})
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, school.color.darkened(0.2), 2, true))
		panel.custom_minimum_size = Vector2(300, 0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		col.add_child(UiKit.label(tr(school.name_key), 22, school.color.lightened(0.2)))
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 16)
		chips.add_child(UiKit.chip(UnitGlyphs.ICON_MOVE, str(stats["runs"]), UiKit.STAT_COLOR, tr("CHRONICLE_ATTEMPTS"), tr("CHRONICLE_ATTEMPTS_TIP"), 18))
		chips.add_child(UiKit.chip(UnitGlyphs.ICON_RETALIATION, str(stats["wins"]), UiKit.ACCENT, tr("CHRONICLE_WINS"), tr("CHRONICLE_WINS_TIP"), 18))
		chips.add_child(UiKit.chip(UnitGlyphs.ICON_ORDER, str(stats["best"]), UiKit.STAT_COLOR, tr("CHRONICLE_BEST"), tr("CHRONICLE_BEST_TIP"), 18))
		# Лучший победный Кодекс — значком, состав в подсказке.
		var best: Dictionary = stats.get("best_codex", {})
		var body := tr("CHRONICLE_NO_BEST")
		if not best.is_empty():
			body = tr("CHRONICLE_BEST_CODEX_TIP") % [tr("DIFFICULTY_" + String(best.get("difficulty", "normal")).to_upper()),
					int(best.get("lost", 0)), String(best.get("date", ""))] + "\n\n" + _codex_text(best.get("codex", []))
		chips.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, "", UiKit.ACCENT if not best.is_empty() else UiKit.MUTED,
				tr("CHRONICLE_BEST_CODEX"), body, 18))
		col.add_child(chips)
		row.add_child(panel)
	return row


## Строка забега: дата, школа, сложность, слой, исход, кто победил, очки; Кодекс — в подсказке.
func _run_row(e: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var outcome: String = e.get("outcome", ProfileState.OUTCOME_LOST)
	var color: Color = OUTCOME_COLORS.get(outcome, UiKit.MUTED)
	row.add_child(UiKit.chip(OUTCOME_ICONS.get(outcome, UnitGlyphs.ICON_KILL), tr("OUTCOME_" + outcome.to_upper()), color, "", "", 20))
	var school_id := StringName(e.get("school", ""))
	var school_name: String = tr(db.school(school_id).name_key) if db.schools.has(school_id) else String(school_id)
	var name_l := UiKit.label(school_name, 20)
	name_l.custom_minimum_size = Vector2(230, 0)
	row.add_child(name_l)
	row.add_child(UiKit.label(tr("DIFFICULTY_" + String(e.get("difficulty", "normal")).to_upper()), 18, UiKit.MUTED))
	if int(e.get("trial", 0)) > 0:
		row.add_child(UiKit.trial_chip(int(e.get("trial", 0)), 18))
	if String(e.get("daily", "")) != "":
		row.add_child(UiKit.chip(UnitGlyphs.ICON_WAIT, tr("DAILY_SHORT"), UiKit.ACCENT, tr("DAILY_TITLE"), String(e.get("daily", "")), 18))
	row.add_child(UiKit.chip(UnitGlyphs.ICON_ORDER, tr("CHRONICLE_LAYER") % int(e.get("layer", 0)), UiKit.STAT_COLOR, tr("CHRONICLE_BEST"), "", 18))
	var enc_id := StringName(e.get("encounter", ""))
	if enc_id != &"" and db.encounters.has(enc_id) and outcome == ProfileState.OUTCOME_LOST:
		row.add_child(UiKit.label(tr("CHRONICLE_DEFEATED_BY") % tr(db.encounter(enc_id).name_key), 18, UiKit.ENEMY_COLOR))
	_add_relic_chips(row, e)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, "+%d" % int(e.get("points", 0)), UiKit.ACCENT, "", "", 18))
	row.add_child(UiKit.label(String(e.get("date", "")), 16, UiKit.MUTED))
	Tip.attach(panel, tr("CHRONICLE_CODEX"), _codex_text(e.get("codex", [])))
	return panel


func _codex_text(ids: Array) -> String:
	var counts := {}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	var lines: Array[String] = []
	for id in counts:
		var name: String = tr(db.memory(StringName(id)).name_key) if db.memories.has(StringName(id)) else String(id)
		lines.append("%s ×%d" % [name, counts[id]] if counts[id] > 1 else name)
	return "\n".join(lines) if not lines.is_empty() else tr("CHRONICLE_CODEX_EMPTY")


## Дары привала и реликвии забега (SPEC_SPRINT7 11): значки, описание — в подсказке.
## Старые записи летописи этих полей не имеют.
func _add_relic_chips(row: HBoxContainer, e: Dictionary) -> void:
	for g in e.get("gifts", []):
		var key := "CAMP_" + String(g).to_upper()
		row.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, "", Color(0.55, 0.85, 1.0), tr(key), tr(key + "_TIP"), 18))
	for id in e.get("relics", []):
		if not db.relics.has(StringName(id)):
			continue
		var r := db.relic(StringName(id))
		row.add_child(UiKit.chip(r.icon, "", r.color, tr(r.name_key), tr(r.desc_key), 18))
