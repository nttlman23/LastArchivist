extends GutTest
## Спринт 12: контраст текста — палитра интерфейса читается на своих фонах (WCAG 4,5 : 1 для основного
## текста, 3 : 1 для крупного/второстепенного), подложка под текстом спасает и на светлом рисованном фоне.

const ContrastAudit := preload("res://tools/contrast_audit.gd")

## Самый светлый участок рисованных фонов, на котором раньше лежал текст (пол боя, стол лавки).
const BRIGHT_ART := Color(0.78, 0.7, 0.6)


func _over(top: Color, bottom: Color) -> Color:
	return Color(lerpf(bottom.r, top.r, top.a), lerpf(bottom.g, top.g, top.a), lerpf(bottom.b, top.b, top.a))


func test_ui_text_on_dark_background() -> void:
	for c in [UiKit.ACCENT, UiKit.MUTED, Color.WHITE, UiKit.PLAYER_COLOR, UiKit.ENEMY_COLOR, UiKit.DANGER]:
		assert_gt(ContrastAudit.ratio(c, UiKit.BG_COLOR), 4.5, "#%s на фоне" % c.to_html(false))


func test_plate_makes_text_readable_on_bright_art() -> void:
	var plate := _over(UiKit.PLATE_COLOR, BRIGHT_ART)
	for c in [UiKit.ACCENT, UiKit.MUTED, Color.WHITE]:
		assert_lt(ContrastAudit.ratio(c, BRIGHT_ART), 4.5, "без подложки светлый текст на светлом фоне не читается")
		assert_gt(ContrastAudit.ratio(c, plate), 4.5, "#%s на подложке" % c.to_html(false))


func test_card_ink_on_parchment() -> void:
	for c in [MemoryCard.INK, MemoryCard.INK_HP, MemoryCard.INK_ACCENT]:
		assert_gt(ContrastAudit.ratio(c, MemoryCard.PARCHMENT), 4.5, "#%s на пергаменте" % c.to_html(false))
	assert_gt(ContrastAudit.ratio(MemoryCard.INK_MUTED, MemoryCard.PARCHMENT), 3.0, "второстепенный текст карты")
