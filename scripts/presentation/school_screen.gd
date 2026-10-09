extends Control
## Выбор школы памяти перед экспедицией (SPEC_SPRINT4 6).

var db: DefsDB
## Выбранная сложность — запоминается до перезапуска игры.
static var difficulty := Difficulty.NORMAL
var _difficulty_buttons: Dictionary[StringName, Button] = {}
## Выбранная ступень Испытания (SPEC_SPRINT8 3); при старте ограничивается открытой у школы.
static var trial := 0
var _trial_row: HBoxContainer


func _ready() -> void:
	db = Game.defs
	UiKit.add_background(self, false, &"school")
	var box := UiKit.centered_column(self, 20)
	box.add_child(UiKit.label(tr("SCHOOL_TITLE"), 44, UiKit.ACCENT))
	box.add_child(_difficulty_row())
	_trial_row = _make_trial_row()
	box.add_child(_trial_row)
	_trial_row.visible = Trials.allowed(difficulty)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for school in db.schools_sorted():
		row.add_child(_school_card(school))
	box.add_child(UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 300))
	Hints.show_hint(&"school")


## Три сложности переключателями; описание — в подсказке.
func _difficulty_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.label(tr("DIFFICULTY_TITLE"), 22, UiKit.MUTED)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var group := ButtonGroup.new()
	for d in Difficulty.ALL:
		var b := Button.new()
		b.text = tr("DIFFICULTY_" + String(d).to_upper())
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(170, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_pressed_color", UiKit.DIFFICULTY_COLORS[d])
		b.add_theme_color_override("font_hover_pressed_color", UiKit.DIFFICULTY_COLORS[d])
		b.button_pressed = d == difficulty
		b.pressed.connect(_set_difficulty.bind(d))
		Tip.attach(b, tr("DIFFICULTY_" + String(d).to_upper()), tr("DIFFICULTY_" + String(d).to_upper() + "_DESC"),
				UnitGlyphs.ICON_KILL, UiKit.DIFFICULTY_COLORS[d])
		_difficulty_buttons[d] = b
		row.add_child(b)
	return row


func _set_difficulty(d: StringName) -> void:
	difficulty = d
	_trial_row.visible = Trials.allowed(d)
	Audio.play(&"ui_click")


## Наибольшая ступень, открытая хотя бы у одной школы.
func _max_trial() -> int:
	var best := 0
	for school in db.schools_sorted():
		best = maxi(best, Game.profile.trial_open(school.id))
	return best


## Ступени 0–10 переключателями: «0» — без Испытания; правила ступени — в подсказке.
func _make_trial_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.label(tr("TRIAL_TITLE"), 20, UiKit.MUTED)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var max_open := _max_trial()
	trial = mini(trial, max_open)
	var group := ButtonGroup.new()
	for i in Trials.MAX + 1:
		var b := Button.new()
		b.text = "—" if i == 0 else str(i)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(48, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_pressed_color", UiKit.DIFFICULTY_COLORS[Difficulty.HARD])
		b.button_pressed = i == trial
		b.disabled = i > max_open
		b.pressed.connect(_set_trial.bind(i))
		var head := tr("TRIAL_NONE") if i == 0 else tr("TRIAL_LEVEL") % i
		var body := Trials.describe(i)
		if i > 0:
			body += "\n" + tr("TRIAL_POINTS_TIP") % roundi(Trials.POINTS_PER_TRIAL * 100 * i)
		if i > max_open:
			body += "\n" + tr("TRIAL_LOCKED_TIP")
		Tip.attach(b, head, body, UnitGlyphs.ICON_KILL, UiKit.DIFFICULTY_COLORS[Difficulty.HARD])
		row.add_child(b)
	return row


func _set_trial(i: int) -> void:
	trial = i
	Audio.play(&"ui_click")


func _school_card(school: SchoolDef) -> Button:
	var open := MetaRewards.is_school_open(Game.profile, school)
	var b := Button.new()
	var art := ArtDB.school(school.id)
	b.custom_minimum_size = Vector2(330, 520 if art else 300)
	b.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.PANEL_COLOR, school.color.darkened(0.2), 3, true))
	b.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.PANEL_COLOR.lightened(0.08), school.color, 3, true))
	b.add_theme_stylebox_override("disabled", UiKit.panel_style(UiKit.PANEL_COLOR.darkened(0.2), Color(0.3, 0.3, 0.35), 2, true))
	b.disabled = not open
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	if art:
		# Портрет школы (SPEC_SPRINT9 18); у закрытой — приглушён.
		col.add_child(UiKit.art_rect(art, Vector2(298, 220), true, Color.WHITE if open else Color(0.35, 0.35, 0.4)))
	col.add_child(UiKit.label(tr(school.name_key), 28, school.color.lightened(0.3) if open else UiKit.MUTED))
	var desc := UiKit.label(tr(school.desc_key + "_SHORT"), 18, Color.WHITE if open else UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(290, 0)
	col.add_child(desc)
	if open:
		var cards: Array[String] = []
		for id in school.starting_codex:
			cards.append(tr(db.memory(id).name_key))
		var start := UiKit.label(tr("SCHOOL_START") % ", ".join(cards), 16, UiKit.MUTED)
		start.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		start.custom_minimum_size = Vector2(290, 0)
		col.add_child(start)
		var opened := Game.profile.trial_open(school.id)
		if opened > 0:
			col.add_child(UiKit.chip(UnitGlyphs.ICON_KILL, tr("SCHOOL_TRIAL") % opened, UiKit.DIFFICULTY_COLORS[Difficulty.HARD], "", "", 16))
		b.pressed.connect(_choose.bind(school.id))
	elif not school.implemented:
		col.add_child(UiKit.chip(UnitGlyphs.ICON_LOCK, tr("SCHOOL_SOON"), UiKit.MUTED))
	else:
		col.add_child(UiKit.chip(UnitGlyphs.ICON_LOCK, tr("SCHOOL_LOCKED") % school.unlock_cost, UiKit.MUTED))
	Tip.attach(b, tr(school.name_key), tr(school.desc_key), UnitGlyphs.ICON_POINTS, school.color)
	return b


func _choose(school_id: StringName) -> void:
	Audio.play(&"ui_click")
	var t := mini(trial, Game.profile.trial_open(school_id)) if Trials.allowed(difficulty) else 0
	Game.new_run(school_id, difficulty, t)
