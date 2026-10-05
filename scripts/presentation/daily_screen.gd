extends Control
## Ежедневный забег (SPEC_SPRINT9 7): раскладка дня, начало или продолжение попытки,
## история — график счёта за 30 дней и список последних 7 попыток.

const HISTORY_DAYS := 30
const LIST_SIZE := 7
const OUTCOME_COLORS := {
	ProfileState.OUTCOME_WON: Color(0.95, 0.8, 0.4),
	ProfileState.OUTCOME_LOST: Color(1.0, 0.45, 0.4),
	ProfileState.OUTCOME_ABANDONED: Color(0.6, 0.62, 0.68),
}

var db: DefsDB
var _today: String


func _ready() -> void:
	db = Game.defs
	_today = DailyRun.today()
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
	head.add_theme_constant_override("separation", 24)
	box.add_child(head)
	head.add_child(UiKit.label(tr("DAILY_TITLE"), 44, UiKit.ACCENT))
	var date := UiKit.label(_today, 24, UiKit.MUTED)
	date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(date)
	box.add_child(_today_panel())

	box.add_child(UiKit.label(tr("DAILY_HISTORY"), 28, UiKit.ACCENT))
	var chart := DailyChart.new()
	chart.custom_minimum_size = Vector2(0, 260)
	chart.setup(Game.profile, _today, HISTORY_DAYS, _entry_tip)
	box.add_child(chart)
	box.add_child(_legend())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if Game.profile.daily.is_empty():
		list.add_child(UiKit.label(tr("DAILY_EMPTY"), 20, UiKit.MUTED))
	for i in mini(LIST_SIZE, Game.profile.daily.size()):
		list.add_child(_row(Game.profile.daily[i]))

	var back := UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(back)


## Раскладка дня: школа, сложность, модификаторы; статус и кнопки попытки.
func _today_panel() -> PanelContainer:
	var layout := DailyRun.layout(db, Game.profile, _today)
	var school := db.school(layout["school"])
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, school.color.darkened(0.2), 2, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	info.add_child(line)
	line.add_child(UiKit.label(tr(school.name_key), 28, school.color.lightened(0.2)))
	var diff := UiKit.difficulty_chip(Difficulty.NORMAL, 20)
	diff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(diff)
	var mods := HBoxContainer.new()
	mods.add_theme_constant_override("separation", 22)
	info.add_child(mods)
	for id: StringName in layout["modifiers"]:
		mods.add_child(UiKit.modifier_chip(id, 20))
	var played := DailyRun.entry_for(Game.profile, _today)
	var status := tr("DAILY_NOT_PLAYED") if played.is_empty() else tr("DAILY_PLAYED") % int(played.get("score", 0))
	info.add_child(UiKit.label(status, 20, UiKit.ACCENT if played.is_empty() else UiKit.MUTED))
	info.add_child(UiKit.label(tr("DAILY_SCORE_RULE"), 16, UiKit.MUTED))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var saved := SaveService.load_run(SaveService.daily_path)
	if saved:
		var cont := UiKit.button(tr("DAILY_CONTINUE") % saved.daily_date, Game.continue_daily, 340)
		buttons.add_child(cont)
	var start := UiKit.button(tr("DAILY_START") if played.is_empty() else tr("DAILY_REPLAY"), Game.new_daily, 340)
	if saved:
		Tip.attach(start, tr("DAILY_START"), tr("DAILY_ABANDON_WARN"))
	elif not played.is_empty():
		Tip.attach(start, tr("DAILY_REPLAY"), tr("DAILY_REPEAT"))
	buttons.add_child(start)
	return panel


## Легенда цветов точек: исход попытки (цвет дублирован подписью в подсказке точки).
func _legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	for outcome: String in OUTCOME_COLORS:
		row.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, tr("OUTCOME_" + outcome.to_upper()), OUTCOME_COLORS[outcome], "", "", 16))
	var best := UiKit.label(tr("DAILY_BEST") % Game.profile.daily_best, 16, UiKit.MUTED)
	row.add_child(best)
	return row


## Строка попытки: исход, дата, школа, модификаторы, слой, счёт.
func _row(e: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var outcome: String = e.get("outcome", ProfileState.OUTCOME_LOST)
	row.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, tr("OUTCOME_" + outcome.to_upper()), OUTCOME_COLORS.get(outcome, UiKit.MUTED), "", "", 18))
	row.add_child(UiKit.label(String(e.get("date", "")), 18, UiKit.MUTED))
	var school_id := StringName(e.get("school", ""))
	var name_l := UiKit.label(tr(db.school(school_id).name_key) if db.schools.has(school_id) else String(school_id), 18)
	name_l.custom_minimum_size = Vector2(230, 0)
	row.add_child(name_l)
	for id in e.get("modifiers", []):
		if DailyRun.ALL.has(StringName(id)):
			row.add_child(UiKit.modifier_chip(StringName(id), 18, false))
	row.add_child(UiKit.chip(UnitGlyphs.ICON_ORDER, tr("CHRONICLE_LAYER") % int(e.get("layer", 0)), UiKit.STAT_COLOR, "", "", 18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UiKit.label(tr("DAILY_SCORE") % int(e.get("score", 0)), 20, UiKit.ACCENT))
	return panel


## Подсказка точки графика: дата, исход, школа, модификаторы, слой, счёт.
func _entry_tip(e: Dictionary) -> Array[String]:
	var school_id := StringName(e.get("school", ""))
	var mods: Array[String] = []
	for id in e.get("modifiers", []):
		mods.append(tr("DAILY_MOD_" + String(id).to_upper()))
	var body := "%s\n%s\n%s\n%s" % [
		tr("OUTCOME_" + String(e.get("outcome", "lost")).to_upper()),
		tr(db.school(school_id).name_key) if db.schools.has(school_id) else String(school_id),
		", ".join(mods),
		tr("CHRONICLE_LAYER") % int(e.get("layer", 0)),
	]
	return [String(e.get("date", "")) + " · " + tr("DAILY_SCORE") % int(e.get("score", 0)), body]


## График счёта за последние days дней: линия (пропуски — разрывы), точки по исходу,
## лучший результат — пунктир. Подсказки — на невидимых областях вокруг точек.
class DailyChart:
	extends Control

	const PAD := Vector4(56, 16, 16, 30)  # слева, сверху, справа, снизу
	const LINE := Color(0.85, 0.87, 0.92, 0.85)
	const GRID := Color(1, 1, 1, 0.07)
	const BEST := Color(0.95, 0.8, 0.4, 0.7)
	const HIT := 28.0

	var _days: Array[String] = []
	var _entries: Array = []   # по дням: Dictionary или null
	var _best := 0
	var _max := 1
	var _tip: Callable
	var _hits: Array[Control] = []

	func setup(profile: ProfileState, today: String, days: int, tip: Callable) -> void:
		_tip = tip
		_best = profile.daily_best
		for i in range(days - 1, -1, -1):
			var d := DailyRun.shift_date(today, -i)
			_days.append(d)
			var e := DailyRun.entry_for(profile, d)
			_entries.append(null if e.is_empty() else e)
			if not e.is_empty():
				_max = maxi(_max, int(e.get("score", 0)))
		_max = maxi(_max, _best)
		# Верх шкалы — «круглое» число над максимумом.
		var step := 50 if _max <= 500 else 100
		_max = (floori(_max / float(step)) + 1) * step
		resized.connect(_place_hits)

	func _plot() -> Rect2:
		return Rect2(PAD.x, PAD.y, size.x - PAD.x - PAD.z, size.y - PAD.y - PAD.w)

	func _point(i: int, score: int) -> Vector2:
		var r := _plot()
		var x := r.position.x + r.size.x * (i / float(maxi(1, _days.size() - 1)))
		return Vector2(x, r.end.y - r.size.y * clampf(score / float(_max), 0.0, 1.0))

	func _draw() -> void:
		var r := _plot()
		var font := get_theme_default_font()
		# Сетка и подписи шкалы: 4 горизонтальные линии.
		for k in 5:
			var v := _max * k / 4
			var y := r.end.y - r.size.y * k / 4.0
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), GRID, 1.0)
			draw_string(font, Vector2(4, y + 5), str(v), HORIZONTAL_ALIGNMENT_RIGHT, PAD.x - 12, 14, Color(1, 1, 1, 0.45))
		# Подписи дат: первый, средний, последний день.
		for i in [0, _days.size() / 2, _days.size() - 1]:
			var p := _point(i, 0)
			draw_string(font, Vector2(p.x - 40, size.y - 6), _days[i].substr(5), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1, 1, 1, 0.45))
		# Лучший результат — пунктир.
		if _best > 0:
			var y := _point(0, _best).y
			draw_dashed_line(Vector2(r.position.x, y), Vector2(r.end.x, y), BEST, 1.5, 8.0)
		# Линия счёта; пропущенный день разрывает её.
		for i in range(1, _entries.size()):
			if _entries[i] != null and _entries[i - 1] != null:
				draw_line(_point(i - 1, int(_entries[i - 1]["score"])), _point(i, int(_entries[i]["score"])), LINE, 2.0, true)
		for i in _entries.size():
			if _entries[i] == null:
				continue
			var e: Dictionary = _entries[i]
			var p := _point(i, int(e["score"]))
			var c: Color = OUTCOME_COLORS.get(String(e.get("outcome", "")), Color.WHITE)
			draw_circle(p, 7.0, UiKit.BG_COLOR)
			draw_circle(p, 5.0, c)

	## Невидимые области подсказок вокруг точек (крупнее самой точки).
	func _place_hits() -> void:
		for h in _hits:
			h.queue_free()
		_hits.clear()
		for i in _entries.size():
			if _entries[i] == null:
				continue
			var p := _point(i, int(_entries[i]["score"]))
			var hit := Control.new()
			hit.mouse_filter = Control.MOUSE_FILTER_STOP
			hit.position = p - Vector2(HIT, HIT) * 0.5
			hit.size = Vector2(HIT, HIT)
			var tip: Array[String] = _tip.call(_entries[i])
			Tip.attach(hit, tip[0], tip[1], UnitGlyphs.ICON_POINTS, OUTCOME_COLORS.get(String(_entries[i].get("outcome", "")), Color.WHITE))
			add_child(hit)
			_hits.append(hit)
		queue_redraw()
