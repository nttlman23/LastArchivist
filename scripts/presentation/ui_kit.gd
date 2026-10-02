class_name UiKit
extends RefCounted
## Общие элементы интерфейса-плейсхолдера.

const BG_COLOR := Color(0.07, 0.08, 0.11)
const PANEL_COLOR := Color(0.12, 0.13, 0.18)
const ACCENT := Color(0.95, 0.8, 0.4)
const ACTIVE_BORDER := Color(1.0, 0.85, 0.3)
const PLAYER_COLOR := Color(0.35, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const MUTED := Color(0.65, 0.67, 0.72)
const DANGER := Color(1.0, 0.45, 0.4)


static func add_background(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


static func label(text: String, size: int = 0, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_pressed: Callable, min_width: int = 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.pressed.connect(on_pressed)
	return b


static func panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


static func centered_column(parent: Control, separation: int = 16) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


static func unit_name(db: DefsDB, def_id: StringName) -> String:
	return TranslationServer.translate(db.unit(def_id).name_key)


## Короткая подпись стека: первые буквы слов названия («Пепельный Гуль» -> «ПГ»).
static func unit_abbr(db: DefsDB, def_id: StringName) -> String:
	var words := unit_name(db, def_id).replace("-", " ").split(" ", false)
	var abbr := ""
	for i in mini(2, words.size()):
		abbr += words[i].left(1).to_upper()
	return abbr


static func unit_stats(def: UnitDef) -> String:
	var text := TranslationServer.translate("CARD_STATS") % [def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative]
	var tags: Array[String] = []
	if def.is_ranged:
		tags.append(TranslationServer.translate("TAG_RANGED") % def.shots)
	if def.is_flying:
		tags.append(TranslationServer.translate("TAG_FLYING"))
	if not tags.is_empty():
		text += "\n" + ", ".join(tags)
	return text


## Карта-воспоминание в виде кнопки. durability < 0 — показывать максимальную.
static func card_button(db: DefsDB, memory_id: StringName, durability: int = -1) -> Button:
	var mem := db.memory(memory_id)
	var def := db.unit(mem.unit_id)
	var dur := mem.max_durability if durability < 0 else durability

	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 215)
	var normal := panel_style(PANEL_COLOR, Color(0.25, 0.27, 0.33), 2)
	var hover := panel_style(PANEL_COLOR.lightened(0.08), Color(0.45, 0.48, 0.55), 2)
	var pressed := panel_style(PANEL_COLOR.lightened(0.05), ACCENT, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	b.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var strip := ColorRect.new()
	strip.color = def.color
	strip.custom_minimum_size = Vector2(10, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(label(TranslationServer.translate(mem.name_key), 24, ACCENT))
	col.add_child(label("%d × %s" % [mem.count, TranslationServer.translate(def.name_key)]))
	var dur_color := DANGER if dur <= 1 else MUTED
	col.add_child(label(TranslationServer.translate("CARD_DURABILITY") % [dur, mem.max_durability], 0, dur_color))
	var stats := label(unit_stats(def), 17, MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(stats)
	return b
