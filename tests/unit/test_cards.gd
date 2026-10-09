extends GutTest
## Спринт 9, этап B: вертикальные карты Кодекса (MemoryCard, SPEC_SPRINT9 18.2) — с артом и без.

var db: DefsDB
var _detailed: bool


func before_all() -> void:
	db = DefsDB.load_default()
	_detailed = Settings.detailed


func after_all() -> void:
	Settings.detailed = _detailed
	ArtDB.enabled = DisplayServer.get_name() != "headless"
	ArtDB.reset()


func _build_all(art: bool, detailed: bool) -> void:
	ArtDB.reset()
	ArtDB.enabled = art
	Settings.detailed = detailed
	for id in db.memory_ids():
		var card := UiKit.card_button(db, id, 1, 2) as MemoryCard
		add_child_autofree(card)
		assert_not_null(card, "%s: вертикальная карта" % id)
		var h := MemoryCard.HEIGHT + (MemoryCard.DETAILED_EXTRA if detailed else 0.0)
		assert_eq(card.custom_minimum_size, Vector2(MemoryCard.WIDTH, h), "%s: размер карты" % id)
		assert_gt(card.get_child_count(), 3, "%s: окно, рамка, прочность, текст" % id)


func test_cards_without_art() -> void:
	_build_all(false, false)
	assert_null(MemoryCard.frame_texture(), "без арта — пергаментная панель")


func test_cards_with_art() -> void:
	_build_all(true, false)
	if DisplayServer.get_name() != "headless":
		assert_not_null(MemoryCard.frame_texture())


func test_cards_detailed() -> void:
	_build_all(false, true)
	_build_all(true, true)


func test_card_states() -> void:
	ArtDB.enabled = false
	var worn := UiKit.card_button(db, &"salt_legion", 1)
	var fresh := UiKit.card_button(db, &"salt_legion", 3)
	add_child_autofree(worn)
	add_child_autofree(fresh)
	assert_true(worn.get_theme_stylebox("normal") is StyleBoxFlat, "угасающая — красная обводка")
	assert_true(fresh.get_theme_stylebox("normal") is StyleBoxEmpty)
	assert_eq((worn.get_theme_stylebox("pressed") as StyleBoxFlat).border_color, UiKit.ACTIVE_BORDER, "выбрана — золото")
	fresh.disabled = true
	await wait_process_frames(2)
	assert_eq(fresh.modulate, MemoryCard.DIM, "недоступная — затемнена")
