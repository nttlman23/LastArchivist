class_name ArtDB
extends RefCounted
## Рисованный арт (SPEC_SPRINT9 2.3): текстуры по соглашению art/<папка>/<id>.png и данные манифеста.
## Нет картинки — null, и вызывающий код рисует прежний глиф. Без рендера (headless) арт не грузится.

const MANIFEST := "res://art/manifest.json"
const DIRS := {&"unit": "units", &"card": "cards", &"portrait": "portraits", &"bg": "backgrounds", &"ui": "ui",
		&"school": "schools", &"island": "islands", &"relic": "relics", &"ach": "achievements", &"icon": "icons"}

## Включён ли арт; по умолчанию — если есть рендер. Тесты включают явно.
static var enabled: bool = DisplayServer.get_name() != "headless"
static var _cache: Dictionary = {}
static var _manifest: Dictionary = {}
static var _manifest_loaded := false


static func texture(kind: StringName, id: StringName) -> Texture2D:
	if not enabled or id == &"":
		return null
	var key := "%s/%s" % [kind, id]
	if not _cache.has(key):
		_cache[key] = load_png("res://art/%s/%s.png" % [DIRS.get(kind, String(kind)), id])
	return _cache[key]


## Импортированная текстура, а если Godot картинку ещё не импортировал (проект не открывали
## в редакторе после art_import) — прямо из PNG. Нет файла — null.
static func load_png(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			return tex
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


static func unit(id: StringName) -> Texture2D:
	return texture(&"unit", id)


static func card(id: StringName) -> Texture2D:
	return texture(&"card", id)


static func portrait(id: StringName) -> Texture2D:
	return texture(&"portrait", id)


static func background(id: StringName) -> Texture2D:
	return texture(&"bg", id)


static func ui(id: StringName) -> Texture2D:
	return texture(&"ui", id)


# --- Этап B (SPEC_SPRINT9 18) ---------------------------------------------------------

static func school(id: StringName) -> Texture2D:
	return texture(&"school", id)


## Остров карты: тип (battle, elite, shop, haven, event, reliquary, boss) и акт.
static func island(type: StringName, act: int) -> Texture2D:
	return texture(&"island", StringName("%s_act%d" % [type, act]))


static func relic(id: StringName) -> Texture2D:
	return texture(&"relic", id)


static func achievement(id: StringName) -> Texture2D:
	return texture(&"ach", id)


## Рисованный значок интерфейса (монохромный, тонируется modulate).
static func icon(id: StringName) -> Texture2D:
	return texture(&"icon", id)


static func entry(kind: StringName, id: StringName) -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if typeof(parsed) == TYPE_DICTIONARY:
				_manifest = parsed.get("items", {})
	return _manifest.get("%s/%s" % [kind, id], {})


## Точка опоры фигуры (доли размера): ручная из манифеста, иначе найденная импортом.
static func anchor(id: StringName) -> Vector2:
	var e := entry(&"unit", id)
	var a: Array = e.get("anchor_manual", e.get("anchor", [0.5, 0.98]))
	return Vector2(a[0], a[1])


## Кадр портрета внутри картинки отряда (в пикселях текстуры).
static func portrait_region(id: StringName) -> Rect2:
	var tex := unit(id)
	if tex == null:
		return Rect2()
	var e := entry(&"unit", id)
	var r: Array = e.get("portrait_manual", e.get("portrait", [0.0, 0.0, 1.0, 0.55]))
	var s := tex.get_size()
	return Rect2(r[0] * s.x, r[1] * s.y, r[2] * s.x, r[3] * s.y)


## Поля 9-slice элемента интерфейса (px) или 0.
static func ui_patch(id: StringName) -> int:
	return int(entry(&"ui", id).get("patch", 0))


## Окно рамки (доли размера) или пустой прямоугольник.
static func ui_window(id: StringName) -> Rect2:
	var w: Array = entry(&"ui", id).get("window", [])
	return Rect2(w[0], w[1], w[2], w[3]) if w.size() == 4 else Rect2()


## Сброс кэша (после импорта, в тестах).
static func reset() -> void:
	_cache.clear()
	MemoryCard.reset()
	_manifest.clear()
	_manifest_loaded = false
