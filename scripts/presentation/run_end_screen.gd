extends Control


func _ready() -> void:
	UiKit.add_background(self)
	var box := UiKit.centered_column(self, 24)
	var won := Game.run_won
	var title := UiKit.label(tr("RUN_WON_TITLE") if won else tr("RUN_LOST_TITLE"), 60, UiKit.ACCENT if won else UiKit.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := UiKit.label(tr("RUN_WON_TEXT") if won else tr("RUN_LOST_TEXT"), 26, UiKit.MUTED)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	if Game.run:
		var stats := UiKit.label(tr("RUN_STATS") % [Game.run.map.current_layer(), MapState.LAYERS, Game.run.battles_won,
				Game.run.codex.cards.size(), UiKit.resources_text(Game.run.resources)], 20, UiKit.MUTED)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(stats)
	var b := UiKit.button(tr("RUN_TO_MENU"), _to_menu, 360)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)


func _to_menu() -> void:
	Game.run = null
	Game.to_main_menu()
