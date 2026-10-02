extends Control
## «Архив открытий» (SPEC_SPRINT4 5.3): очки памяти тратятся на школы, карты и события.

var db: DefsDB
var _content: VBoxContainer


func _ready() -> void:
	db = Game.defs
	UiKit.add_background(self)
	_content = UiKit.centered_column(self, 14)
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var p := Game.profile
	_content.add_child(UiKit.label(tr("META_TITLE"), 44, UiKit.ACCENT))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	top.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, str(p.points), UiKit.ACCENT, tr("META_POINTS"), tr("META_POINTS_TIP"), 26))
	top.add_child(UiKit.label(tr("META_STATS") % [p.runs, p.wins, p.best_layer], 18, UiKit.MUTED))
	_content.add_child(top)
	for unlock in MetaRewards.all_unlocks(db):
		_content.add_child(_row(unlock))
	_content.add_child(Control.new())
	_content.add_child(UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 300))


func _row(unlock: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_l := UiKit.label(_unlock_name(unlock), 22)
	name_l.custom_minimum_size = Vector2(460, 0)
	Tip.attach(name_l, _unlock_name(unlock), _unlock_desc(unlock))
	row.add_child(name_l)
	var reason := MetaRewards.buy_reason(db, Game.profile, unlock)
	if reason == "REASON_UNLOCKED":
		row.add_child(UiKit.label(tr("META_OPEN"), 20, UiKit.ACCENT))
		return row
	var b := UiKit.icon_button(UnitGlyphs.ICON_POINTS, str(unlock["cost"]), _buy.bind(unlock), "", "", 140)
	b.disabled = reason != ""
	row.add_child(b)
	if reason != "" and reason != "REASON_NO_POINTS":
		row.add_child(UiKit.label(tr(reason), 18, UiKit.MUTED))
	return row


func _unlock_name(u: Dictionary) -> String:
	match u["kind"]:
		MetaRewards.Kind.SCHOOL:
			return tr("META_KIND_SCHOOL") % tr(db.school(u["target"]).name_key)
		MetaRewards.Kind.CARD:
			return tr("META_KIND_CARD") % tr(db.memory(u["target"]).name_key)
		MetaRewards.Kind.EVENT:
			return tr("META_KIND_EVENT") % tr(db.event(u["target"]).title_key)
	return ""


func _unlock_desc(u: Dictionary) -> String:
	match u["kind"]:
		MetaRewards.Kind.SCHOOL:
			return tr(db.school(u["target"]).desc_key)
		MetaRewards.Kind.CARD:
			return tr("META_CARD_TIP")
		MetaRewards.Kind.EVENT:
			return tr(db.event(u["target"]).text_key)
	return ""


func _buy(unlock: Dictionary) -> void:
	if MetaRewards.buy(db, Game.profile, unlock):
		Game.save_profile()
		Audio.play(&"transform")
		_rebuild()
