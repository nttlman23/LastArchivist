extends GutTest
## Спринт 9: конвейер арта (ArtImport) и доступ к нему в игре (ArtDB); этап B — новые виды и полнота набора.
## Исходники создаются тестом во временной папке user:// — бинарные фикстуры не нужны.

const RAW := "user://test_art/raw"
const OUT := "user://test_art/out"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func before_each() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAW))


func after_all() -> void:
	_clean()
	ArtDB.enabled = DisplayServer.get_name() != "headless"
	ArtDB.reset()


func _clean() -> void:
	var subdirs := ["units", "ui", "cards", "schools", "islands", "relics", "achievements", "icons"].map(func(s: String) -> String: return OUT.path_join(s))
	for dir in [RAW] + subdirs + [OUT]:
		var d := DirAccess.open(dir)
		if d:
			for f in d.get_files():
				d.remove(f)
	for dir in [RAW] + subdirs + [OUT, "user://test_art"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


## Картинка w×h: фон bg (прозрачный, если bg.a == 0), прямоугольник-«фигура» rect цвета fg.
func _make(file: String, w: int, h: int, bg: Color, rect: Rect2i, fg: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	img.fill_rect(rect, fg)
	img.save_png(ProjectSettings.globalize_path(RAW.path_join(file)))


func _run(force: bool = false) -> Dictionary:
	return ArtImport.run(db, force, "", RAW, OUT)


func _item(key: String) -> Dictionary:
	return ArtImport.read_manifest(OUT.path_join("manifest.json"))["items"].get(key, {})


func test_parse_name() -> void:
	assert_eq(ArtImport.parse_name("unit_salt_guard.png"), {"kind": "unit", "id": "salt_guard", "version": 0})
	assert_eq(ArtImport.parse_name("Unit_Salt_Guard_v3.PNG"), {"kind": "unit", "id": "salt_guard", "version": 3})
	assert_eq(ArtImport.parse_name("style_reference.png"), {}, "эталон стиля в игру не идёт")
	assert_eq(ArtImport.parse_name("unit_.png"), {})


func test_transparent_unit_trimmed_scaled_and_anchored() -> void:
	_make("unit_salt_guard.png", 400, 400, Color(0, 0, 0, 0), Rect2i(150, 60, 100, 300), Color(0.8, 0.8, 0.9))
	var report := _run()
	assert_eq(report["done"], ["unit/salt_guard"])
	var e := _item("unit/salt_guard")
	assert_eq(int(e["size"][1]), ArtImport.UNIT_HEIGHT, "масштаб по высоте")
	assert_almost_eq(float(e["anchor"][0]), 0.5, 0.02, "опора — середина ног")
	assert_gt(float(e["anchor"][1]), 0.95, "опора — внизу фигуры")
	var img := Image.load_from_file(ProjectSettings.globalize_path(e["file"]))
	assert_eq(img.get_height(), ArtImport.UNIT_HEIGHT)
	assert_lt(img.get_width(), img.get_height(), "лишние поля обрезаны")


func test_flat_background_removed() -> void:
	_make("unit_ash_ghoul.png", 300, 300, Color8(188, 188, 188), Rect2i(100, 50, 100, 200), Color8(140, 60, 30))
	_run()
	var img := Image.load_from_file(ProjectSettings.globalize_path(_item("unit/ash_ghoul")["file"]))
	assert_eq(img.get_pixel(1, 1).a, 0.0, "фон стал прозрачным")
	assert_gt(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a, 0.9, "фигура цела")


func test_background_that_eats_object_warns() -> void:
	_make("unit_rift_ram.png", 300, 300, Color8(188, 188, 188), Rect2i(100, 100, 50, 50), Color8(190, 190, 190))
	var report := _run()
	assert_true(report["warnings"].has("unit/rift_ram"), "объект цвета фона — предупреждение")


func test_large_and_flying_units() -> void:
	_make("unit_rift_ram.png", 400, 400, Color(0, 0, 0, 0), Rect2i(50, 100, 300, 200), Color.PURPLE)
	_make("unit_storm_wyrm_echo.png", 400, 400, Color(0, 0, 0, 0), Rect2i(50, 50, 300, 300), Color.BLUE)
	_run()
	assert_eq(int(_item("unit/rift_ram")["size"][1]), ArtImport.UNIT_HEIGHT_LARGE, "крупное существо выше")
	assert_eq(float(_item("unit/storm_wyrm_echo")["anchor"][1]), ArtImport.FLYER_ANCHOR_Y, "летун — опора под тенью")


func test_enclosed_window_of_frame() -> void:
	# Рамка: серый фон, тёмная рамка, светлый «пергамент» снизу, серое окно сверху.
	var img := Image.create(300, 400, false, Image.FORMAT_RGBA8)
	img.fill(Color8(188, 188, 188))
	img.fill_rect(Rect2i(20, 20, 260, 360), Color8(40, 40, 60))
	img.fill_rect(Rect2i(40, 220, 220, 140), Color8(225, 210, 180))
	img.fill_rect(Rect2i(40, 40, 220, 160), Color8(188, 188, 188))
	img.save_png(ProjectSettings.globalize_path(RAW.path_join("ui_card_frame.png")))
	_run()
	var e := _item("ui/card_frame")
	var out := Image.load_from_file(ProjectSettings.globalize_path(e["file"]))
	var s := Vector2(out.get_width(), out.get_height())
	assert_eq(out.get_pixelv(Vector2i(s * Vector2(0.5, 0.3))).a, 0.0, "окно прозрачное")
	assert_gt(out.get_pixelv(Vector2i(s * Vector2(0.5, 0.75))).a, 0.9, "пергамент цел")
	assert_true(e.has("window"), "окно рамки в манифесте")
	assert_almost_eq(float(e["window"][1]), 0.1, 0.05)


func test_newest_version_wins_and_unchanged_skipped() -> void:
	_make("card_salt_legion.png", 600, 400, Color.RED, Rect2i(0, 0, 1, 1), Color.RED)
	_make("card_salt_legion_v2.png", 600, 400, Color.GREEN, Rect2i(0, 0, 1, 1), Color.GREEN)
	_run()
	assert_eq(_item("card/salt_legion")["src"], "card_salt_legion_v2.png")
	var img := Image.load_from_file(ProjectSettings.globalize_path(_item("card/salt_legion")["file"]))
	assert_eq(Vector2i(img.get_width(), img.get_height()), ArtImport.CARD_SIZE)
	var again := _run()
	assert_eq(again["done"], [], "без изменений ничего не переписывается")
	assert_eq(again["skipped"], ["card/salt_legion"])
	assert_eq(_run(true)["done"], ["card/salt_legion"], "--force — заново")


func test_manual_anchor_survives_reimport() -> void:
	_make("unit_siren.png", 300, 300, Color(0, 0, 0, 0), Rect2i(100, 50, 100, 200), Color.WHITE)
	_run()
	var path := OUT.path_join("manifest.json")
	var m := ArtImport.read_manifest(path)
	m["items"]["unit/siren"]["anchor_manual"] = [0.4, 0.7]
	ArtImport.write_manifest(m, path)
	_run(true)
	assert_eq(_item("unit/siren")["anchor_manual"], [0.4, 0.7])


# --- ArtDB --------------------------------------------------------------------------------

func test_artdb_fallback_and_disabled() -> void:
	ArtDB.reset()
	ArtDB.enabled = true
	assert_null(ArtDB.unit(&"no_such_unit"), "нет картинки — null, рисуется глиф")
	assert_eq(ArtDB.anchor(&"no_such_unit"), Vector2(0.5, 0.98), "опора по умолчанию")
	ArtDB.enabled = false
	assert_null(ArtDB.unit(&"salt_guard"), "выключено — арт не грузится")


func test_project_manifest_ids_exist() -> void:
	var m := ArtImport.read_manifest()
	for key: String in m["items"]:
		var kind := key.get_slice("/", 0)
		var id := StringName(key.get_slice("/", 1))
		match kind:
			"unit":
				assert_true(db.units.has(id), "нет существа %s" % id)
			"card":
				assert_true(db.memories.has(id), "нет карты %s" % id)
			"portrait":
				assert_true(id == &"archivist" or db.commanders.has(id), "нет командира %s" % id)
			"school":
				assert_true(db.schools.has(id), "нет школы %s" % id)
			"relic":
				assert_true(db.relics.has(id), "нет реликвии %s" % id)
			"ach":
				assert_true(db.achievements.has(id), "нет достижения %s" % id)
			"icon":
				assert_true(UnitGlyphs.ALL_ICONS.has(id), "нет значка %s" % id)
			"island":
				var parts := String(id).rsplit("_act", true, 1)
				assert_true(MapView.ISLAND_ART.values().has(StringName(parts[0])) and parts[1] in ["1", "2"], "нет острова %s" % id)
	assert_eq(ArtImport.missing_slice(m), [] as Array[String], "вертикальный срез собран целиком")


func test_project_art_loads() -> void:
	ArtDB.reset()
	ArtDB.enabled = true
	assert_not_null(ArtDB.unit(&"salt_guard"))
	assert_gt(ArtDB.anchor(&"salt_guard").y, 0.9)
	assert_gt(ArtDB.portrait_region(&"salt_guard").size.x, 0.0)
	assert_gt(ArtDB.ui_patch(&"button"), 0)
	assert_gt(ArtDB.ui_window(&"card_frame").size.x, 0.0)
	ArtDB.enabled = false
	ArtDB.reset()


# --- Этап B (SPEC_SPRINT9 18) -----------------------------------------------------------

func test_parse_stage_b_names() -> void:
	assert_eq(ArtImport.parse_name("school_tide_order.png")["kind"], "school")
	assert_eq(ArtImport.parse_name("island_battle_act1.png"), {"kind": "island", "id": "battle_act1", "version": 0})
	assert_eq(ArtImport.parse_name("relic_rift_shard_v2.png"), {"kind": "relic", "id": "rift_shard", "version": 2})
	assert_eq(ArtImport.parse_name("ach_first_chapter.png")["kind"], "ach")
	assert_eq(ArtImport.parse_name("icon_melee.png")["id"], "melee")
	assert_eq(ArtImport.parse_name("portrait_abyss_lord_cmd-draft.png"), {}, "черновик пропускается")
	assert_eq(ArtImport.parse_name("relic_warden_shell_draft.png"), {})


func test_stage_b_kinds_processed() -> void:
	var clear := Color(0, 0, 0, 0)
	_make("icon_melee.png", 600, 600, clear, Rect2i(250, 50, 100, 500), Color.WHITE)
	_make("island_battle_act1.png", 1024, 1024, clear, Rect2i(100, 200, 800, 600), Color(0.6, 0.5, 0.4))
	_make("relic_rift_shard.png", 1024, 1024, Color(0.8, 0.8, 0.8), Rect2i(300, 200, 300, 600), Color(0.5, 0.3, 0.9))
	_make("ach_lightning.png", 1024, 1024, clear, Rect2i(40, 40, 940, 940), Color(0.5, 0.4, 0.2))
	_make("school_tide_order.png", 1024, 1024, Color(0.1, 0.2, 0.4), Rect2i(300, 200, 400, 800), Color(0.3, 0.6, 0.9))
	var report := _run()
	assert_eq(report["errors"], {})
	assert_eq(_item("icon/melee")["size"], [128.0, 128.0], "значок — квадрат 128, без искажений")
	assert_eq(maxf(_item("island/battle_act1")["size"][0], _item("island/battle_act1")["size"][1]), float(ArtImport.ISLAND_SIDE))
	var relic: Array = _item("relic/rift_shard")["size"]
	assert_eq(maxf(relic[0], relic[1]), float(ArtImport.RELIC_SIDE), "фон снят, реликвия обрезана и уменьшена")
	assert_lt(relic[0], relic[1], "обрезка по объекту: реликвия выше, чем шире")
	assert_eq(_item("school/tide_order")["size"], [384.0, 384.0], "портрет школы — квадрат с обрезкой по центру")
	var icon := Image.load_from_file(ProjectSettings.globalize_path(OUT.path_join("icons/melee.png")))
	assert_eq(icon.get_pixel(0, 0).a, 0.0, "поля значка прозрачные")


func test_project_stage_b_complete() -> void:
	var items: Dictionary = ArtImport.read_manifest()["items"]
	var expect: Array[String] = []
	for id in db.units:
		expect.append("unit/%s" % id)
	for id in db.memories:
		expect.append("card/%s" % id)
	for id in db.commanders:
		expect.append("portrait/%s" % id)
	for id in db.schools:
		expect.append("school/%s" % id)
	for id in db.relics:
		expect.append("relic/%s" % id)
	for id in db.achievements:
		expect.append("ach/%s" % id)
	for id in UnitGlyphs.ALL_ICONS:
		expect.append("icon/%s" % id)
	for act in [1, 2]:
		for type: StringName in MapView.ISLAND_ART.values():
			if not (type == &"reliquary" and act == 1):
				expect.append("island/%s_act%d" % [type, act])
	for id in ["battle_act2", "map_act2", "camp", "haven", "shop", "event", "reliquary", "hall", "run_end", "school"]:
		expect.append("bg/%s" % id)
	var missing := expect.filter(func(k: String) -> bool: return not items.has(k))
	assert_eq(missing, [], "весь арт игры импортирован")
	assert_eq(expect.size(), 133, "проверяется весь игровой арт, кроме Архивариуса, фонов и интерфейса среза")


func test_project_stage_b_art_loads() -> void:
	ArtDB.reset()
	ArtDB.enabled = true
	assert_not_null(ArtDB.school(&"tide_order"))
	assert_not_null(ArtDB.island(&"boss", 2))
	assert_null(ArtDB.island(&"reliquary", 1), "реликвариев в первом акте нет")
	assert_not_null(ArtDB.relic(&"synod_seal"))
	assert_not_null(ArtDB.achievement(&"daily_three"))
	assert_not_null(ArtDB.icon(&"melee"))
	assert_not_null(ArtDB.unit(&"abyss_lord"))
	ArtDB.enabled = false
	ArtDB.reset()
