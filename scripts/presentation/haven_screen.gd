extends Control
## Тихая гавань (SPEC_SPRINT3 5.2): один бесплатный выбор — починить, переписать или медитировать.

var db: DefsDB
var run: RunState
var _content: VBoxContainer


func _ready() -> void:
	if Game.run == null or Game.run.pending() == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	UiKit.add_background(self)
	_content = UiKit.centered_column(self, 18)
	_show_choices()
	Hints.show_hint(&"haven")


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()


func _show_choices() -> void:
	_clear()
	_content.add_child(UiKit.label(tr("HAVEN_TITLE"), 44, UiKit.ACCENT))
	_content.add_child(UiKit.label(tr("HAVEN_TEXT"), 22, UiKit.MUTED))
	var repairs := ShopOps.haven_repairs(db, run)
	var repair := UiKit.icon_button(UnitGlyphs.ICON_HEAL, tr("HAVEN_REPAIR") % [ShopOps.haven_repair_amount(run), repairs], _repair, "", "", 640)
	repair.disabled = repairs == 0
	_content.add_child(repair)
	_content.add_child(UiKit.icon_button(UnitGlyphs.ICON_SPELL, tr("HAVEN_REWRITE"), _show_rewrite, "", "", 640))
	var meditate := UiKit.icon_button(UnitGlyphs.ICON_AETHER, tr("HAVEN_MEDITATE") % run.hero.spells.size(), _meditate, "", "", 640)
	meditate.disabled = run.hero.spells.is_empty()
	_content.add_child(meditate)
	_content.add_child(UiKit.button(tr("SHOP_LEAVE"), Game.complete_node, 640))


func _repair() -> void:
	ShopOps.haven_repair_all(db, run)
	Audio.play(&"heal")
	Game.complete_node()


func _meditate() -> void:
	ShopOps.haven_meditate(run)
	Audio.play(&"spell")
	Game.complete_node()


func _show_rewrite() -> void:
	_clear()
	_content.add_child(UiKit.label(tr("HAVEN_REWRITE"), 34, UiKit.ACCENT))
	var rework := ReworkPanel.new()
	rework.setup(db, run)
	rework.confirmed.connect(_rewrite)
	_content.add_child(rework)
	_content.add_child(UiKit.button(tr("REWARD_CANCEL"), _show_choices, 260))


func _rewrite(card_index: int, form: CodexOps.Form) -> void:
	CodexOps.apply(db, run, card_index, form)
	Game.complete_node()
