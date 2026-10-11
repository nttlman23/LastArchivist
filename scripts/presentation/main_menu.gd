extends Control
## Главное меню: экспедиция, ежедневный забег, Зал Архива, летопись, достижения, настройки.


func _ready() -> void:
	var bg := UiKit.add_background(self, false, &"menu")
	if bg is ColorRect:
		var emblem := MenuEmblem.new()
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(emblem)
	var box := UiKit.centered_column(self, 18)
	if not bg is ColorRect:
		# Рисованный фон: справа Архивариус над книгой, меню — в левой трети.
		box.get_parent().anchor_right = 0.42
	var title := UiKit.label(tr("GAME_TITLE"), 64, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var points := UiKit.chip(UnitGlyphs.ICON_POINTS, str(Game.profile.points), UiKit.ACCENT, tr("META_POINTS"), tr("META_POINTS_TIP"), 22)
	points.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(points)
	box.add_child(Control.new())

	# Первый забег — через пролог и учебный бой (SPEC_SPRINT10 8).
	box.add_child(UiKit.button(tr("MENU_NEW_RUN"), Game.begin_new_run, 360))
	var cont := UiKit.button(tr("MENU_CONTINUE"), Game.continue_run, 360)
	cont.disabled = SaveService.load_run() == null
	if SaveService.is_broken():
		# Файл есть, но ни он, ни резервная копия не читаются — подсказка вместо молчания.
		Tip.attach(cont, tr("MENU_CONTINUE"), tr("MENU_SAVE_BROKEN"))
	box.add_child(cont)
	var daily := UiKit.button(tr("MENU_DAILY"), Game.goto.bind(Game.SCENE_DAILY), 360)
	if DailyRun.entry_for(Game.profile, DailyRun.today()).is_empty():
		# Отметка: сегодняшний забег ещё не сыгран (SPEC_SPRINT9 7).
		daily.text = tr("MENU_DAILY_NEW")
		daily.add_theme_color_override("font_color", UiKit.ACCENT)
	box.add_child(daily)
	box.add_child(UiKit.button(tr("MENU_META"), Game.goto.bind(Game.SCENE_META), 360))
	box.add_child(UiKit.button(tr("MENU_CHRONICLE"), Game.goto.bind(Game.SCENE_CHRONICLE), 360))
	box.add_child(UiKit.button(tr("MENU_ACHIEVEMENTS") % [Game.profile.achievements.size(), Game.defs.achievements.size()],
			Game.goto.bind(Game.SCENE_ACHIEVEMENTS), 360))
	var tutorial := UiKit.button(tr("MENU_TUTORIAL"), _choose_tutorial, 360)
	if not Game.profile.tutorial2_done:
		# Отметка: второй урок ещё не пройден (SPEC_SPRINT11 5).
		tutorial.text = tr("MENU_TUTORIAL_NEW")
		tutorial.add_theme_color_override("font_color", UiKit.ACCENT)
	box.add_child(tutorial)
	box.add_child(UiKit.button(tr("MENU_HELP"), Help.open.bind(&""), 360))
	box.add_child(UiKit.button(tr("MENU_SETTINGS"), Game.goto.bind(Game.SCENE_SETTINGS), 360))
	box.add_child(UiKit.button(tr("MENU_QUIT"), Game.quit_game, 360))


## Большой бледный силуэт архива за меню; медленно «дышит».
class MenuEmblem:
	extends Control
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = 0.75 + 0.25 * sin(_t * 0.8)

	func _draw() -> void:
		var c := size * Vector2(0.5, 0.52)
		var r := size.y * 0.42
		draw_circle(c, r, Color(0.95, 0.75, 0.4, 0.025))
		draw_arc(c, r, 0, TAU, 96, Color(0.95, 0.75, 0.4, 0.06), 3.0)
		UnitGlyphs.draw_unit(self, &"archive_relic", c, r * 0.7, Color(0, 0, 0, 0), Color(0.95, 0.8, 0.5, 0.045))


## «Обучение»: два урока на выбор — бой-пролог и «Герой и Кодекс» (SPEC_SPRINT11 5).
func _choose_tutorial() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.ACCENT, 2, true))
	dim.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(UiKit.label(tr("MENU_TUTORIAL"), 36, UiKit.ACCENT))
	for lesson in [["TUT_LESSON_1", "TUT_LESSON_1_DESC", Game.start_tutorial], ["TUT_LESSON_2", "TUT_LESSON_2_DESC", Game.start_tutorial2]]:
		col.add_child(UiKit.button(tr(lesson[0]), lesson[2], 460))
		var d := UiKit.label(tr(lesson[1]), 17, UiKit.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(460, 0)
		col.add_child(d)
	col.add_child(UiKit.button(tr("SETTINGS_BACK"), dim.queue_free, 460))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
