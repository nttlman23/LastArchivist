extends SceneTree
## Импорт присланной музыки и звуков (SPEC_SPRINT10, звук из ChatGPT по audio/CHATGPT_AUDIO_PROMPT.md):
## audio/raw/<имя>.wav → audio/music | audio/ambience | audio/sfx, проверка и audio/manifest.json.
## Файлы из манифеста gen_audio.gd больше не перезаписывает.
## Запуск: godot --headless -s res://tools/audio_import.gd   (затем --headless --import)

const RAW := "res://audio/raw"
const MANIFEST := "res://audio/manifest.json"
const MUSIC: Array[String] = ["menu", "battle", "battle_tension", "act2", "act2_tension", "boss", "boss2"]
const AMBIENCE: Array[String] = ["archive", "water"]
## Пары, которые звучат одновременно: число кадров должно совпадать точно.
const PAIRS := [["battle", "battle_tension"], ["act2", "act2_tension"], ["boss", "boss2"]]
const MAX_RATE := 44100


func _init() -> void:
	var manifest := {}
	var errors: Array[String] = []
	var frames := {}
	var files := DirAccess.get_files_at(RAW)
	files.sort()
	for f in files:
		if not f.to_lower().ends_with(".wav"):
			continue
		var name := f.get_basename()
		var info := wav_info(RAW.path_join(f))
		if info.is_empty():
			errors.append("%s: не WAV PCM 16 бит" % f)
			continue
		if int(info["rate"]) > MAX_RATE:
			errors.append("%s: частота %d > %d" % [f, info["rate"], MAX_RATE])
			continue
		var dest := destination(name)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(RAW.path_join(f)), ProjectSettings.globalize_path(dest))
		frames[name] = info["frames"]
		manifest[name] = {"file": dest, "md5": FileAccess.get_md5(dest), "rate": info["rate"], "channels": info["channels"],
				"frames": info["frames"], "seconds": snappedf(float(info["frames"]) / float(info["rate"]), 0.01)}
		print("  %-20s → %s (%.2f с, %d Гц, %d кан.)" % [f, dest, manifest[name]["seconds"], info["rate"], info["channels"]])
	for p: Array in PAIRS:
		if frames.has(p[0]) and frames.has(p[1]) and frames[p[0]] != frames[p[1]]:
			errors.append("пара %s / %s: %d и %d кадров — разойдутся при зацикливании" % [p[0], p[1], frames[p[0]], frames[p[1]]])
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "items": manifest}, "\t", true))
	f.close()
	for e in errors:
		print("  ОШИБКА  " + e)
	print("AUDIO: импортировано %d, ошибок %d" % [manifest.size(), errors.size()])
	quit(1 if not errors.is_empty() else 0)


## Папка назначения по имени: музыка, окружение, остальное — эффекты.
static func destination(name: String) -> String:
	if name in MUSIC:
		return "res://audio/music/%s.wav" % name
	if name in AMBIENCE:
		return "res://audio/ambience/%s.wav" % name
	return "res://audio/sfx/%s.wav" % name


## Частота, каналы и число кадров WAV PCM 16 бит; {} — не подходит.
static func wav_info(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var pos := 12
	var fmt := {}
	var data_size := -1
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			fmt = {"code": bytes.decode_u16(pos + 8), "channels": bytes.decode_u16(pos + 10), "rate": bytes.decode_u32(pos + 12), "bits": bytes.decode_u16(pos + 22)}
		elif id == "data":
			data_size = size
		pos += 8 + size + (size % 2)
	if fmt.get("code", 0) != 1 or fmt.get("bits", 0) != 16 or data_size < 0:
		return {}
	return {"rate": fmt["rate"], "channels": fmt["channels"], "frames": data_size / (2 * int(fmt["channels"]))}
