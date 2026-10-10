extends Control


func _ready() -> void:
	UiKit.add_background(self, false, &"run_end")
	var box := UiKit.centered_column(self, 24)
	var won := Game.run_won
	var title := UiKit.label(tr("RUN_WON_TITLE") if won else tr("RUN_LOST_TITLE"), 60, UiKit.ACCENT if won else UiKit.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# Текст итога — по главе истории, в которой закончился забег (SPEC_SPRINT10 4–5).
	var text := UiKit.label(tr(Story.run_end_key(Game.run_end_chapter, won)), 26, UiKit.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(900, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	if Game.run:
		var stats := UiKit.label(tr("RUN_STATS") % [Game.run.total_layer(), 2 * (MapState.LAYERS + 1), Game.run.battles_won,
				Game.run.codex.cards.size(), UiKit.resources_text(Game.run.resources)], 20, UiKit.MUTED)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(stats)
	if Game.run and Game.run.daily_date != "":
		# Ежедневный забег (SPEC_SPRINT9 7): счёт; повторная попытка — без зачёта.
		var daily := UiKit.label(tr("RUN_DAILY_SCORE") % Game.last_daily_score + ("" if Game.last_daily_counted else "  " + tr("RUN_DAILY_NOT_COUNTED")),
				26, UiKit.ACCENT if Game.last_daily_counted else UiKit.MUTED)
		daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(daily)
	var gained := UiKit.chip(UnitGlyphs.ICON_POINTS, tr("RUN_POINTS") % [Game.last_points, Game.profile.points], UiKit.ACCENT,
			tr("META_POINTS"), tr("META_POINTS_TIP"), 26)
	gained.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(gained)
	var b := UiKit.button(tr("RUN_TO_MENU"), _to_menu, 360)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)


func _to_menu() -> void:
	Game.run = null
	Game.to_main_menu()
