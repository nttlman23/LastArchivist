extends SceneTree
## Импорт арта (SPEC_SPRINT9 2): art/raw/*.png → art/<папка>/<id>.png и art/manifest.json.
## Запуск: godot --headless -s res://tools/art_import.gd [-- --force] [-- --only=unit|card|portrait|bg|ui|school|island|relic|ach|icon|scene]
## Потом откройте проект в редакторе (или godot --headless --import), чтобы Godot импортировал новые PNG.


func _init() -> void:
	var force := false
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--force":
			force = true
		elif arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	var t0 := Time.get_ticks_msec()
	var report := ArtImport.run(DefsDB.load_default(), force, only)
	for key: String in report["done"]:
		print("  обработано  %s" % key)
	for key: String in report["warnings"]:
		print("  ВНИМАНИЕ    %s: %s" % [key, ", ".join(report["warnings"][key])])
	for key: String in report["errors"]:
		print("  ОШИБКА      %s: %s" % [key, report["errors"][key]])
	var missing := ArtImport.missing_slice(ArtImport.read_manifest())
	print("ART: обработано %d, без изменений %d, предупреждений %d, ошибок %d за %.1f с" % [
		report["done"].size(), report["skipped"].size(), report["warnings"].size(), report["errors"].size(),
		(Time.get_ticks_msec() - t0) / 1000.0])
	if not missing.is_empty():
		print("Не хватает для вертикального среза: " + ", ".join(missing))
	quit(1 if not report["errors"].is_empty() else 0)
