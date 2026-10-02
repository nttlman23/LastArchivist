extends SceneTree
## Процедурный генератор звука-плейсхолдера: музыка (2 лупа) и звуковые эффекты в res://audio.
## Всё синтезируется здесь же (синусы, Karplus–Strong, шум), без внешних файлов и лицензий.
## Запуск: godot --headless -s res://tools/gen_audio.gd   (затем --headless --import)

const RATE := 22050
const OUT_MUSIC := "res://audio/music"
const OUT_SFX := "res://audio/sfx"
const PEAK := 0.85

var rng := RandomNumberGenerator.new()
## Заворачивать хвосты в начало буфера: да для музыкальных лупов, нет для эффектов.
var _wrap := true


func _init() -> void:
	rng.seed = 1337
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_MUSIC))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SFX))
	var t0 := Time.get_ticks_msec()
	_save(OUT_MUSIC.path_join("menu.wav"), _music_menu(), true)
	_save(OUT_MUSIC.path_join("battle.wav"), _music_battle(), true)
	_wrap = false
	var sfx := {
		"ui_click": _sfx_click(), "move": _sfx_move(), "melee": _sfx_melee(), "shoot": _sfx_shoot(),
		"impact": _sfx_impact(), "death": _sfx_death(), "ability": _sfx_ability(), "spell": _sfx_spell(),
		"order": _sfx_order(), "heal": _sfx_heal(), "wall": _sfx_wall(), "push": _sfx_push(),
		"turn": _sfx_turn(), "card": _sfx_card(), "transform": _sfx_transform(),
		"victory": _sfx_victory(), "defeat": _sfx_defeat(),
	}
	for id: String in sfx:
		_save(OUT_SFX.path_join(id + ".wav"), sfx[id], false)
	print("Сгенерировано за %.1f с" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


# --- Музыка ----------------------------------------------------------------------

## Меню: медленный эмбиент в ре миноре — пэд, бас-гул, редкие колокольчики. 8 аккордов × 4 с.
func _music_menu() -> PackedFloat32Array:
	var chord_len := 4.0
	var chords := [
		[38, [57, 62, 65]], [34, [53, 58, 62]], [31, [55, 58, 62]], [33, [57, 61, 64]],
		[38, [57, 62, 65]], [41, [57, 60, 65]], [31, [55, 58, 62]], [33, [56, 61, 64]],
	]
	var buf := _buffer(chord_len * chords.size())
	for i in chords.size():
		var t := i * chord_len
		var bass: int = chords[i][0]
		_tone(buf, t, chord_len + 1.0, _hz(bass), 0.11, 1.0, 1.5, [1.0, 0.4, 0.1])
		for note: int in chords[i][1]:
			_pad(buf, t, chord_len + 1.2, _hz(note), 0.045)
		# Колокольчики: ноты аккорда октавой выше, примерно раз в секунду.
		for beat in 4:
			if rng.randf() < 0.65:
				var notes: Array = chords[i][1]
				_bell(buf, t + beat + rng.randf_range(0.0, 0.3), _hz(notes[rng.randi_range(0, notes.size() - 1)] + 12), 0.05)
	_echo(buf, 0.37, 0.35)
	_echo(buf, 0.61, 0.25)
	_lowpass(buf, 0.35)
	return buf


## Бой: ля минор, 100 уд/мин, 16 тактов — щипковое остинато, барабаны, пэд, рог во второй половине.
func _music_battle() -> PackedFloat32Array:
	var beat := 0.6
	var bar := beat * 4
	var progression := [45, 41, 43, 40, 45, 41, 38, 40]  # Am F G E Am F Dm E (корни)
	var pads := [[57, 60, 64], [57, 60, 65], [55, 59, 62], [56, 59, 64], [57, 60, 64], [57, 60, 65], [57, 62, 65], [56, 59, 64]]
	var buf := _buffer(bar * 16)
	for c in progression.size():
		var start := c * bar * 2
		var root: int = progression[c]
		for p: int in pads[c]:
			_pad(buf, start, bar * 2 + 0.6, _hz(p), 0.03)
		_tone(buf, start, bar * 2, _hz(root - 12), 0.09, 0.05, 0.3, [1.0, 0.5, 0.2])
		# Остинато восьмыми: корень, корень, квинта, корень, октава…
		var pattern := [0, 0, 7, 0, 12, 0, 7, 3]
		for e in 16:
			var note := root + int(pattern[e % pattern.size()])
			_pluck(buf, start + e * beat * 0.5, _hz(note), 0.13, 0.45)
	for b in 16:
		var t := b * bar
		_kick(buf, t, 0.5)
		_kick(buf, t + beat * 2, 0.45)
		_kick(buf, t + beat * 3.5, 0.3)
		_snare(buf, t + beat, 0.16)
		_snare(buf, t + beat * 3, 0.18)
		if b % 4 == 3:
			_noise(buf, t + beat * 2, beat * 2, 0.05, 0.0, 0.6, true)  # нарастающая «тарелка»
	# Рог: короткий мотив во второй половине.
	var motif := [[8, 69, 1.0], [9, 72, 1.0], [10, 71, 2.0], [12, 69, 1.0], [13, 72, 1.0], [14, 74, 1.0], [15, 76, 1.5]]
	for m: Array in motif:
		_horn(buf, float(m[0]) * bar, float(m[2]) * beat * 2, _hz(m[1]), 0.07)
	_echo(buf, 0.3, 0.2)
	_lowpass(buf, 0.5)
	return buf


# --- Звуковые эффекты -----------------------------------------------------------

func _sfx_click() -> PackedFloat32Array:
	var buf := _buffer(0.08)
	_tone(buf, 0, 0.05, 1800, 0.3, 0.002, 0.04, [1.0])
	_noise(buf, 0, 0.02, 0.2, 0.01, 0.2)
	return buf


func _sfx_move() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_noise(buf, 0, 0.3, 0.35, 0.12, 0.08, true)
	_tone(buf, 0.02, 0.15, 90, 0.2, 0.01, 0.12, [1.0])
	return buf


func _sfx_melee() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_kick(buf, 0, 0.9)
	_noise(buf, 0, 0.12, 0.6, 0.06, 0.4)
	_tone(buf, 0, 0.08, 640, 0.15, 0.001, 0.07, [1.0, 0.7, 0.4])  # лязг
	return buf


func _sfx_shoot() -> PackedFloat32Array:
	var buf := _buffer(0.4)
	_pluck(buf, 0, 220, 0.6, 0.25)
	_noise(buf, 0.03, 0.25, 0.25, 0.1, 0.5, true)
	return buf


func _sfx_impact() -> PackedFloat32Array:
	var buf := _buffer(0.25)
	_noise(buf, 0, 0.15, 0.6, 0.05, 0.25)
	_kick(buf, 0, 0.5)
	return buf


func _sfx_death() -> PackedFloat32Array:
	var buf := _buffer(0.9)
	_sweep(buf, 0, 0.8, 320, 70, 0.35)
	_noise(buf, 0, 0.5, 0.2, 0.3, 0.15)
	return buf


func _sfx_ability() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	for i in 4:
		_bell(buf, i * 0.07, _hz(72 + [0, 4, 7, 12][i]), 0.18)
	_noise(buf, 0, 0.4, 0.08, 0.2, 0.8, true)
	return buf


func _sfx_spell() -> PackedFloat32Array:
	var buf := _buffer(1.2)
	_noise(buf, 0, 0.6, 0.25, 0.25, 0.5, true)
	_sweep(buf, 0, 0.5, 200, 900, 0.12)
	for n in [62, 66, 69, 74]:
		_bell(buf, 0.35, _hz(n), 0.12)
	_echo(buf, 0.18, 0.3)
	return buf


func _sfx_order() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	_horn(buf, 0, 0.25, _hz(57), 0.3)
	_horn(buf, 0.22, 0.45, _hz(64), 0.3)
	return buf


func _sfx_heal() -> PackedFloat32Array:
	var buf := _buffer(1.0)
	for i in 3:
		_bell(buf, i * 0.12, _hz([84, 88, 91][i]), 0.2)
	return buf


func _sfx_wall() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	_noise(buf, 0, 0.6, 0.6, 0.3, 0.04)
	_kick(buf, 0.05, 0.7)
	return buf


func _sfx_push() -> PackedFloat32Array:
	var buf := _buffer(0.4)
	_kick(buf, 0, 0.7)
	_noise(buf, 0.03, 0.25, 0.3, 0.1, 0.3, true)
	return buf


func _sfx_turn() -> PackedFloat32Array:
	var buf := _buffer(0.6)
	_bell(buf, 0, _hz(81), 0.18)
	return buf


func _sfx_card() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_noise(buf, 0, 0.1, 0.3, 0.04, 0.9)
	_bell(buf, 0.05, _hz(88), 0.08)
	return buf


func _sfx_transform() -> PackedFloat32Array:
	var buf := _buffer(1.4)
	_sweep(buf, 0, 0.9, 150, 600, 0.1)
	_noise(buf, 0, 0.9, 0.15, 0.4, 0.4, true)
	for i in 5:
		_bell(buf, 0.5 + i * 0.08, _hz(74 + [0, 3, 7, 10, 12][i]), 0.12)
	_echo(buf, 0.21, 0.3)
	return buf


func _sfx_victory() -> PackedFloat32Array:
	var buf := _buffer(2.2)
	var notes := [62, 66, 69, 74]
	for i in notes.size():
		_horn(buf, i * 0.16, 0.5 if i < 3 else 1.4, _hz(notes[i]), 0.2)
	_pad(buf, 0.48, 1.6, _hz(50), 0.08)
	return buf


func _sfx_defeat() -> PackedFloat32Array:
	var buf := _buffer(2.4)
	var notes := [57, 53, 50, 45]
	for i in notes.size():
		_horn(buf, i * 0.35, 0.6 if i < 3 else 1.3, _hz(notes[i]), 0.18)
	_tone(buf, 0, 2.2, _hz(33), 0.12, 0.3, 1.0, [1.0, 0.5])
	return buf


# --- Синтез ----------------------------------------------------------------------

func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Тон с гармониками и огибающей атака/спад; хвост заворачивается в начало (для лупов).
func _tone(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float,
		attack: float, release: float, harmonics: Array) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := maxi(1, int(attack * RATE))
	var r := maxi(1, int(release * RATE))
	var w := TAU * freq / RATE
	for i in len:
		var env := 1.0
		if i < a:
			env = float(i) / a
		elif i > len - r:
			env = maxf(0.0, float(len - i) / r)
		var v := 0.0
		for h in harmonics.size():
			v += harmonics[h] * sin(w * (h + 1) * i)
		_add(buf, s0 + i, v * env * amp)


## Мягкий пэд: две слегка расстроенные копии тона с медленной атакой.
func _pad(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float) -> void:
	_tone(buf, start, dur, freq * 0.9985, amp, 1.0, 1.4, [1.0, 0.45, 0.2, 0.08])
	_tone(buf, start, dur, freq * 1.0015, amp, 1.0, 1.4, [1.0, 0.45, 0.2, 0.08])


## Колокольчик: негармонические обертоны с экспоненциальным затуханием.
func _bell(buf: PackedFloat32Array, start: float, freq: float, amp: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(2.2 * RATE)
	var partials := [[1.0, 1.0, 2.2], [2.76, 0.45, 1.2], [5.4, 0.25, 0.6], [8.9, 0.1, 0.3]]
	for p: Array in partials:
		var w := TAU * freq * float(p[0]) / RATE
		var decay := float(p[2]) * RATE
		for i in len:
			_add(buf, s0 + i, sin(w * i) * float(p[1]) * amp * exp(-i / decay) * minf(1.0, i / 40.0))


## Щипок струны (Karplus–Strong).
func _pluck(buf: PackedFloat32Array, start: float, freq: float, amp: float, dur: float) -> void:
	var n := buf.size()
	var period := maxi(2, int(RATE / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1.0, 1.0)
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	for i in len:
		var j := i % period
		var v := ring[j]
		ring[j] = 0.5 * (v + ring[(j + 1) % period]) * 0.996
		_add(buf, s0 + i, v * amp * minf(1.0, float(len - i) / 400.0))


## Рог: «пилообразные» гармоники с плавной атакой и лёгким вибрато.
func _horn(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := int(0.06 * RATE)
	var r := int(0.15 * RATE)
	for i in len:
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		var f := freq * (1.0 + 0.004 * sin(TAU * 5.0 * i / RATE))
		var v := 0.0
		for h in 6:
			v += sin(TAU * f * (h + 1) * i / RATE) / (h + 1.5)
		_add(buf, s0 + i, v * env * amp)


## Бочка: синус с падающей высотой.
func _kick(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(0.3 * RATE)
	var phase := 0.0
	for i in len:
		var f := 50.0 + 90.0 * exp(-i / (0.03 * RATE))
		phase += TAU * f / RATE
		_add(buf, s0 + i, sin(phase) * amp * exp(-i / (0.09 * RATE)))


func _snare(buf: PackedFloat32Array, start: float, amp: float) -> void:
	_noise(buf, start, 0.18, amp, 0.05, 0.55)
	_tone(buf, start, 0.08, 190, amp * 0.6, 0.001, 0.07, [1.0])


## Шум с затуханием decay (0 — без затухания) и однополюсным фильтром: brightness 0..1.
## swell — плавное нарастание и спад (как вдох/взмах), иначе — резкая атака.
func _noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, brightness: float, swell: bool = false) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var lp := 0.0
	var k := clampf(brightness, 0.01, 1.0)
	for i in len:
		lp += k * (rng.randf_range(-1.0, 1.0) - lp)
		var env: float
		if swell:
			env = sin(PI * i / len)
		elif decay > 0.0:
			env = exp(-i / (decay * RATE))
		else:
			env = 1.0
		_add(buf, s0 + i, lp * env * amp)


## Тон с плавным изменением высоты (glide).
func _sweep(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var phase := 0.0
	for i in len:
		var t := float(i) / len
		phase += TAU * lerpf(f0, f1, t) / RATE
		var env := minf(1.0, i / 200.0) * (1.0 - t)
		_add(buf, s0 + i, (sin(phase) + 0.3 * sin(phase * 2.0)) * env * amp)


## Эхо с заворачиванием — подходит и для лупов.
func _echo(buf: PackedFloat32Array, delay: float, gain: float) -> void:
	var n := buf.size()
	var d := int(delay * RATE)
	var src := buf.duplicate()
	for i in n:
		_add(buf, i + d, src[i] * gain)


func _lowpass(buf: PackedFloat32Array, k: float) -> void:
	var lp := 0.0
	# Два прохода, чтобы начало лупа не «щёлкало».
	for pass_i in 2:
		for i in buf.size():
			lp += k * (buf[i] - lp)
			if pass_i == 1:
				buf[i] = lp


func _add(buf: PackedFloat32Array, idx: int, v: float) -> void:
	var n := buf.size()
	if idx < n:
		buf[idx] += v
	elif _wrap:
		buf[idx % n] += v


# --- Сохранение ------------------------------------------------------------------

func _save(path: String, buf: PackedFloat32Array, loop: bool) -> void:
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := PEAK / peak
	if not loop:
		# Короткое затухание в конце эффекта, чтобы не было щелчка.
		var fade := mini(buf.size(), int(0.015 * RATE))
		for i in fade:
			buf[buf.size() - 1 - i] *= float(i) / fade
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		# Мягкое ограничение на всякий случай.
		var s := tanh(buf[i] * gain * 1.1) / tanh(1.1)
		bytes.encode_s16(i * 2, clampi(int(s * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	print("%s: %.1f с, %s" % [path, float(buf.size()) / RATE, "OK" if err == OK else error_string(err)])
