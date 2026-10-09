class_name ArtImport
extends RefCounted
## Конвейер арта (SPEC_SPRINT9 2): картинки из art/raw/ → обработанные art/<папка>/<id>.png
## и art/manifest.json. Удаляет однотонный фон, обрезает, масштабирует, находит точку опоры.
## Используется инструментом tools/art_import.gd и тестами.

const RAW_DIR := "res://art/raw"
const OUT_DIR := "res://art"
const MANIFEST := "res://art/manifest.json"

## Префикс имени файла → (папка, вид).
const KINDS := {
	"unit": "units",
	"card": "cards",
	"portrait": "portraits",
	"bg": "backgrounds",
	"ui": "ui",
	# Этап B (SPEC_SPRINT9 18).
	"school": "schools",
	"island": "islands",
	"relic": "relics",
	"ach": "achievements",
	"icon": "icons",
}
const UNIT_HEIGHT := 384
const UNIT_HEIGHT_LARGE := 448
const CARD_SIZE := Vector2i(512, 384)
const PORTRAIT_SIZE := 256
const BG_SIZE := Vector2i(1920, 1080)
const UI_MAX_SIDE := 640
const SCHOOL_SIZE := 384
## Острова, реликвии и медальоны достижений — по большей стороне; значки — квадрат.
const ISLAND_SIDE := 320
const RELIC_SIDE := 256
const ACH_SIDE := 256
const ICON_SIZE := 128
const MARGIN := 8
## Допуск цвета фона (сумма |dR|+|dG|+|dB| в 0..255).
const BG_TOLERANCE := 28 * 3
## Прозрачность ниже — считается пустотой (шум генератора).
const ALPHA_CUT := 12
const FLYER_ANCHOR_Y := 0.92
## Портрет из фигуры отряда: верхняя доля высоты.
const PORTRAIT_SHARE := 0.55
## Элементы интерфейса, у которых фон может быть замкнут внутри (окно рамки карты).
const KEY_ALL_UI: Array[String] = ["card_frame"]
## Высота элементов интерфейса, растягиваемых по 9-slice: поля должны быть меньше самой низкой кнопки.
const UI_HEIGHT := {"button": 64}
## Поля 9-slice: доля меньшей стороны.
const UI_PATCH := {"panel": 0.09, "button": 0.22}


## Разбор имени: "unit_salt_guard_v3.png" → {kind: "unit", id: "salt_guard", version: 3}; {} — не арт.
## Черновики («…-draft», «…_draft») пропускаются: в работу идёт чистовик.
static func parse_name(file: String) -> Dictionary:
	var base := file.get_basename().to_lower()
	if base.contains("draft"):
		return {}
	var cut := base.find("_")
	if cut <= 0:
		return {}
	var prefix := base.substr(0, cut)
	if not KINDS.has(prefix):
		return {}
	var id := base.substr(cut + 1)
	var version := 0
	var re := RegEx.create_from_string("^(.*)_v(\\d+)$")
	var m := re.search(id)
	if m:
		id = m.get_string(1)
		version = int(m.get_string(2))
	if id == "":
		return {}
	return {"kind": prefix, "id": id, "version": version}


## Исходники по назначению: для каждого (вид, id) — самый новый файл (версия, затем время изменения).
static func collect(raw_dir: String = RAW_DIR) -> Dictionary:
	var best := {}
	var dir := DirAccess.open(raw_dir)
	if dir == null:
		return best
	for file in dir.get_files():
		if not file.to_lower().ends_with(".png"):
			continue
		var info := parse_name(file)
		if info.is_empty():
			continue
		var path := raw_dir.path_join(file)
		info["path"] = path
		info["mtime"] = FileAccess.get_modified_time(path)
		var key := "%s/%s" % [info["kind"], info["id"]]
		if not best.has(key) or _newer(info, best[key]):
			best[key] = info
	return best


static func _newer(a: Dictionary, b: Dictionary) -> bool:
	if a["version"] != b["version"]:
		return a["version"] > b["version"]
	return a["mtime"] > b["mtime"]


static func load_image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Доля прозрачных пикселей.
static func transparent_share(img: Image) -> float:
	var data := img.get_data()
	var n := data.size() / 4
	var clear := 0
	for i in n:
		if data[i * 4 + 3] < ALPHA_CUT:
			clear += 1
	return float(clear) / maxf(1.0, n)


## Удаляет фон: заливка от краёв по цвету углов (или все пиксели этого цвета, если key_all).
static func remove_background(img: Image, key_all: bool = false, tolerance: int = BG_TOLERANCE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var key := _corner_color(data, w, h)
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack := PackedInt32Array()
	if true:
		for x in w:
			stack.append(x)
			stack.append((h - 1) * w + x)
		for y in h:
			stack.append(y * w)
			stack.append(y * w + w - 1)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			if bg[i] == 1 or not _near(data, i, key, tolerance):
				continue
			bg[i] = 1
			var x := i % w
			if x > 0:
				stack.append(i - 1)
			if x < w - 1:
				stack.append(i + 1)
			if i >= w:
				stack.append(i - w)
			if i < (h - 1) * w:
				stack.append(i + w)
	if key_all:
		_remove_enclosed(data, bg, w, h, key)
	# Прозрачность и смягчение края: пиксель на границе фона — полупрозрачный.
	for i in w * h:
		if bg[i] == 1:
			data[i * 4 + 3] = 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if bg[i] == 0 and (bg[i - 1] == 1 or bg[i + 1] == 1 or bg[i - w] == 1 or bg[i + w] == 1):
				data[i * 4 + 3] = mini(data[i * 4 + 3], 150)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


## Замкнутые области цвета фона (окно рамки): только крупные (≥ ENCLOSED_SHARE картинки)
## и со строгим допуском, чтобы не выесть светлые пятна самого объекта.
const ENCLOSED_TOLERANCE := 10 * 3
const ENCLOSED_SHARE := 0.02


static func _remove_enclosed(data: PackedByteArray, bg: PackedByteArray, w: int, h: int, key: Color) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var min_area := roundi(w * h * ENCLOSED_SHARE)
	for start in w * h:
		if bg[start] == 1 or seen[start] == 1 or not _near(data, start, key, ENCLOSED_TOLERANCE):
			continue
		var region := PackedInt32Array()
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			region.append(i)
			var x := i % w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if n >= 0 and n < w * h and seen[n] == 0 and bg[n] == 0 and _near(data, n, key, ENCLOSED_TOLERANCE):
					seen[n] = 1
					stack.append(n)
		if region.size() >= min_area:
			for i in region:
				bg[i] = 1


static func _corner_color(data: PackedByteArray, w: int, h: int) -> Color:
	var sum := [0, 0, 0]
	for i in [2 * w + 2, 2 * w + w - 3, (h - 3) * w + 2, (h - 3) * w + w - 3]:
		for c in 3:
			sum[c] += data[i * 4 + c]
	return Color8(sum[0] / 4, sum[1] / 4, sum[2] / 4)


static func _near(data: PackedByteArray, i: int, key: Color, tolerance: int) -> bool:
	var p := i * 4
	if data[p + 3] < ALPHA_CUT:
		return true
	return absi(data[p] - key.r8) + absi(data[p + 1] - key.g8) + absi(data[p + 2] - key.b8) <= tolerance


## Обнуляет почти прозрачные пиксели и обрезает по непрозрачной области с полем MARGIN.
static func trim(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	for i in w * h:
		if data[i * 4 + 3] < ALPHA_CUT:
			data[i * 4 + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	var out := Image.create(used.size.x + MARGIN * 2, used.size.y + MARGIN * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i(MARGIN, MARGIN))
	return out


static func scale_to_height(img: Image, height: int) -> void:
	var k := float(height) / img.get_height()
	img.resize(maxi(1, roundi(img.get_width() * k)), height, Image.INTERPOLATE_LANCZOS)


static func scale_to_fit(img: Image, max_side: int) -> void:
	var k := float(max_side) / maxi(img.get_width(), img.get_height())
	if k < 1.0:
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)


## Обрезка по центру до пропорции size и масштаб до size.
static func cover(img: Image, size: Vector2i) -> Image:
	var target := float(size.x) / size.y
	var w := img.get_width()
	var h := img.get_height()
	var rect := Rect2i(0, 0, w, h)
	if float(w) / h > target:
		var cw := roundi(h * target)
		rect = Rect2i((w - cw) / 2, 0, cw, h)
	else:
		var ch := roundi(w / target)
		rect = Rect2i(0, (h - ch) / 2, w, ch)
	var out := img.get_region(rect)
	out.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return out


## Точка опоры фигуры (доли размера): x — центр непрозрачных пикселей нижних 8 % фигуры, y — низ фигуры.
static func ground_anchor(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var bottom := h - MARGIN - 1
	var top := maxi(0, bottom - roundi((h - 2 * MARGIN) * 0.08))
	var sx := 0.0
	var n := 0
	for y in range(top, bottom + 1):
		for x in w:
			if data[(y * w + x) * 4 + 3] >= 128:
				sx += x
				n += 1
	var ax := (sx / n) / w if n > 0 else 0.5
	return Vector2(ax, float(h - MARGIN) / h)


## Кадр портрета из фигуры: квадрат в верхней части (доли размера: x, y, w, h).
static func portrait_frame(img: Image) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var band := roundi(h * 0.3)
	var sx := 0.0
	var n := 0
	for y in range(MARGIN, mini(h, MARGIN + band)):
		for x in w:
			if data[(y * w + x) * 4 + 3] >= 128:
				sx += x
				n += 1
	var cx := sx / n if n > 0 else w * 0.5
	var side := minf(w, h * PORTRAIT_SHARE)
	var x0 := clampf(cx - side * 0.5, 0.0, w - side)
	return Rect2(x0 / w, 0.0, side / w, side / h)


## Обработка одного исходника. Возвращает запись манифеста и предупреждения ("warnings").
## units_info: id → {"flying": bool, "large": bool} (из DefsDB).
static func process(info: Dictionary, units_info: Dictionary = {}, out_dir: String = OUT_DIR) -> Dictionary:
	var kind: String = info["kind"]
	var id: String = info["id"]
	var warnings: Array[String] = []
	var img := load_image(info["path"])
	if img == null or img.is_empty():
		return {"error": "не читается"}
	var entry := {"kind": kind, "id": id, "src": String(info["path"]).get_file(), "md5": FileAccess.get_md5(info["path"])}
	var src_size := Vector2i(img.get_width(), img.get_height())
	match kind:
		"unit":
			if transparent_share(img) < 0.05:
				remove_background(img)
			var share := 1.0 - transparent_share(img)
			if share < 0.1:
				warnings.append("фон съел объект (осталось %d%%)" % roundi(share * 100))
			elif share > 0.9:
				warnings.append("фон не удалился (непрозрачно %d%%)" % roundi(share * 100))
			img = trim(img)
			var u: Dictionary = units_info.get(id, {})
			var height := UNIT_HEIGHT_LARGE if u.get("large", false) else UNIT_HEIGHT
			if img.get_height() < height / 2:
				warnings.append("маленький исходник (%d px)" % img.get_height())
			scale_to_height(img, height)
			var anchor := ground_anchor(img)
			if u.get("flying", false):
				anchor.y = FLYER_ANCHOR_Y
			entry["anchor"] = [snappedf(anchor.x, 0.001), snappedf(anchor.y, 0.001)]
			var pf := portrait_frame(img)
			entry["portrait"] = [snappedf(pf.position.x, 0.001), snappedf(pf.position.y, 0.001), snappedf(pf.size.x, 0.001), snappedf(pf.size.y, 0.001)]
		"card":
			img = cover(img, CARD_SIZE)
		"portrait":
			img = cover(img, Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE))
		"bg":
			img = cover(img, BG_SIZE)
		"school":
			img = cover(img, Vector2i(SCHOOL_SIZE, SCHOOL_SIZE))
		"island", "relic", "ach", "icon":
			if transparent_share(img) < 0.05:
				remove_background(img)
			if 1.0 - transparent_share(img) < 0.05:
				warnings.append("фон съел объект")
			img = trim(img)
			match kind:
				"island":
					scale_to_fit(img, ISLAND_SIDE)
				"relic":
					scale_to_fit(img, RELIC_SIDE)
				"ach":
					scale_to_fit(img, ACH_SIDE)
				"icon":
					img = square(img, ICON_SIZE)
		"ui":
			if transparent_share(img) < 0.05:
				remove_background(img, KEY_ALL_UI.has(id))
			img = trim(img)
			if UI_HEIGHT.has(id):
				scale_to_height(img, UI_HEIGHT[id])
			else:
				scale_to_fit(img, UI_MAX_SIDE)
			if KEY_ALL_UI.has(id):
				var win := inner_window(img)
				if win.size.x > 0.0:
					entry["window"] = [snappedf(win.position.x, 0.001), snappedf(win.position.y, 0.001), snappedf(win.size.x, 0.001), snappedf(win.size.y, 0.001)]
			if UI_PATCH.has(id):
				entry["patch"] = maxi(4, roundi(mini(img.get_width(), img.get_height()) * float(UI_PATCH[id])))
	if src_size.x < 256 or src_size.y < 256:
		warnings.append("исходник меньше 256 px")
	entry["size"] = [img.get_width(), img.get_height()]
	var rel := "%s/%s.png" % [KINDS[kind], id]
	var out_path := out_dir.path_join(rel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var err := img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		return {"error": "не записывается (%d)" % err}
	entry["file"] = out_path
	entry["warnings"] = warnings
	return entry


## Вписать в прозрачный квадрат side × side по центру (значки — одного размера и без искажений).
static func square(img: Image, side: int) -> Image:
	var k := float(side) / maxi(img.get_width(), img.get_height())
	img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((side - img.get_width()) / 2, (side - img.get_height()) / 2))
	return out


## Окно внутри рамки: прямоугольник прозрачных пикселей, не касающихся края (доли размера).
static func inner_window(img: Image) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var inset := roundi(mini(w, h) * 0.06)
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in range(inset, h - inset):
		for x in range(inset, w - inset):
			if data[(y * w + x) * 4 + 3] < ALPHA_CUT:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2()
	return Rect2(float(lo.x) / w, float(lo.y) / h, float(hi.x - lo.x + 1) / w, float(hi.y - lo.y + 1) / h)


static func read_manifest(path: String = MANIFEST) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"version": 1, "items": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		return {"version": 1, "items": {}}
	return parsed


static func write_manifest(manifest: Dictionary, path: String = MANIFEST) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t", true))


## Весь конвейер: обрабатывает новые и изменённые исходники. only — вид ("unit", …) или "".
## Возвращает отчёт: {"done": [...], "skipped": [...], "warnings": {...}, "errors": {...}}.
static func run(db: DefsDB, force: bool = false, only: String = "", raw_dir: String = RAW_DIR, out_dir: String = OUT_DIR) -> Dictionary:
	var units_info := {}
	if db:
		for id in db.units:
			var d := db.unit(id)
			units_info[String(id)] = {"flying": d.is_flying, "large": d.size_class == &"large"}
	var manifest_path := out_dir.path_join("manifest.json")
	var manifest := read_manifest(manifest_path)
	var items: Dictionary = manifest["items"]
	var report := {"done": [], "skipped": [], "warnings": {}, "errors": {}}
	var sources := collect(raw_dir)
	var keys := sources.keys()
	keys.sort()
	for key: String in keys:
		var info: Dictionary = sources[key]
		if only != "" and info["kind"] != only:
			continue
		var md5 := FileAccess.get_md5(info["path"])
		var old: Dictionary = items.get(key, {})
		if not force and old.get("md5", "") == md5 and FileAccess.file_exists(String(old.get("file", ""))):
			report["skipped"].append(key)
			continue
		var entry := process(info, units_info, out_dir)
		if entry.has("error"):
			report["errors"][key] = entry["error"]
			continue
		if not entry["warnings"].is_empty():
			report["warnings"][key] = entry["warnings"]
		# Ручные поправки манифеста (опора летуна и т. п.) переживают повторную обработку.
		for k in ["anchor_manual", "portrait_manual"]:
			if old.has(k):
				entry[k] = old[k]
		entry.erase("warnings")
		items[key] = entry
		report["done"].append(key)
	write_manifest(manifest, manifest_path)
	return report


## Чего не хватает для вертикального среза (SPEC_SPRINT9 5).
const SLICE: Array[String] = [
	"unit/salt_guard", "unit/chronicler", "unit/ash_ghoul", "unit/ash_priest", "unit/rust_sentinel",
	"unit/rift_ram", "unit/shard_archer", "unit/storm_wyrm_echo", "unit/rift_warden", "unit/archive_relic",
	"card/salt_legion", "card/ash_chroniclers", "card/ghoul_pack", "card/shard_archers", "card/rust_sentinels",
	"card/storm_wyrm", "card/last_king",
	"portrait/archivist", "portrait/ash_overseer", "portrait/rift_herald", "portrait/salt_keeper",
	"bg/battle_act1", "bg/map_act1", "bg/menu", "ui/panel", "ui/button", "ui/card_frame",
]


static func missing_slice(manifest: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in SLICE:
		if not manifest["items"].has(key):
			result.append(key)
	return result
