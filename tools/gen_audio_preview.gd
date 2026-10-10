extends SceneTree
## Варианты звуков на выбор автору (SPEC_SPRINT9 21): build/sound_preview/*.wav — слушать любым плеером.
## В игру не подключаются; выбранный вариант переносится в gen_audio.gd.
## Запуск: godot --headless -s res://tools/gen_audio_preview.gd

const OUT := "res://build/sound_preview"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t0 := Time.get_ticks_msec()
	var s := AudioSynth.new(5150)
	_save(s, "battle_A_dark", s.music_battle_dark(), true)
	_save(s, "battle_B_march", s.music_battle_march(), true)
	s._wrap = false
	_save(s, "victory_1_chord", s.sfx_victory_chord(), false)
	_save(s, "victory_2_fanfare", s.sfx_victory_fanfare(), false)
	_save(s, "victory_3_memory", s.sfx_victory_memory(), false)
	_save(s, "turn_1_knock", s.sfx_turn_knock(), false)
	_save(s, "turn_2_page", s.sfx_turn_page(), false)
	_save(s, "turn_3_string", s.sfx_turn_string(), false)
	print("Варианты готовы за %.1f с: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, ProjectSettings.globalize_path(OUT)])
	quit()


func _save(s: AudioSynth, id: String, buf: PackedFloat32Array, loop: bool) -> void:
	s.save(OUT.path_join(id + ".wav"), buf, loop)
