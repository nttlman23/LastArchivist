extends SceneTree
## Генератор процедурного звука: музыка и звуковые эффекты в res://audio (синтез — AudioSynth).
## Запуск: godot --headless -s res://tools/gen_audio.gd   (затем --headless --import)
## У каждой партии свой сид: прежние файлы при перегенерации не меняются.

const OUT_MUSIC := "res://audio/music"
const OUT_SFX := "res://audio/sfx"
const OUT_AMBIENCE := "res://audio/ambience"


func _init() -> void:
	for dir in [OUT_MUSIC, OUT_SFX, OUT_AMBIENCE]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var t0 := Time.get_ticks_msec()
	# Спринты 1–6: меню, бой, эффекты.
	var s := AudioSynth.new(1337)
	s.save(OUT_MUSIC.path_join("menu.wav"), s.music_menu(), true)
	s.save(OUT_MUSIC.path_join("battle.wav"), s.music_battle(), true)
	s._wrap = false
	var sfx := {
		"ui_click": s.sfx_click(), "move": s.sfx_move(), "melee": s.sfx_melee(), "shoot": s.sfx_shoot(),
		"impact": s.sfx_impact(), "death": s.sfx_death(), "ability": s.sfx_ability(), "spell": s.sfx_spell(),
		"order": s.sfx_order(), "heal": s.sfx_heal(), "wall": s.sfx_wall(), "push": s.sfx_push(),
		"turn": s.sfx_turn(), "card": s.sfx_card(), "transform": s.sfx_transform(),
		"victory": s.sfx_victory(), "defeat": s.sfx_defeat(), "erase": s.sfx_erase(),
	}
	for id: String in sfx:
		s.save(OUT_SFX.path_join(id + ".wav"), sfx[id], false)
	# Второй акт (SPEC_SPRINT8 4).
	s = AudioSynth.new(2026)
	s.save(OUT_MUSIC.path_join("act2.wav"), s.music_act2(), true)
	s.save(OUT_MUSIC.path_join("boss.wav"), s.music_boss(false), true)
	s.save(OUT_MUSIC.path_join("boss2.wav"), s.music_boss(true), true)
	# Этап B Спринта 9 (SPEC_SPRINT9 12): слои напряжения, окружение, удары по классам существ.
	s = AudioSynth.new(4242)
	s.save(OUT_MUSIC.path_join("battle_tension.wav"), s.music_battle_tension(), true)
	s.save(OUT_MUSIC.path_join("act2_tension.wav"), s.music_act2_tension(), true)
	s.save(OUT_AMBIENCE.path_join("archive.wav"), s.ambience_archive(), true)
	s.save(OUT_AMBIENCE.path_join("water.wav"), s.ambience_water(), true)
	s._wrap = false
	for id: String in ["metal", "claw", "magic", "shard", "heavy"]:
		s.save(OUT_SFX.path_join("hit_%s.wav" % id), s.call("sfx_hit_" + id), false)
	print("Сгенерировано за %.1f с" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
