class_name AudioSynth
extends RefCounted
## Процедурный синтез звука (tools/gen_audio.gd, SPEC_SPRINT9 12): инструменты, треки и эффекты.
## Всё синтезируется здесь же (синусы, Karplus–Strong, шум, формантные фильтры), без внешних файлов и лицензий.
## Детерминирован: одинаковый сид — одинаковые буферы (проверяется тестом).

const RATE := 22050
const PEAK := 0.85

var rng := RandomNumberGenerator.new()
## Заворачивать хвосты в начало буфера: да для музыкальных лупов, нет для эффектов.
var _wrap := true


func _init(seed_value: int = 1337) -> void:
	rng.seed = seed_value


# --- Музыка ----------------------------------------------------------------------

## Меню: медленный эмбиент в ре миноре — пэд, бас-гул, редкие колокольчики. 8 аккордов × 4 с.
func music_menu() -> PackedFloat32Array:
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
func music_battle() -> PackedFloat32Array:
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


## «Затопленные хранилища»: ре дорийский, медленно — низкий пэд, мягкие колокола, «капли».
## 16 аккордов × 5,5 с ≈ 88 с.
func music_act2() -> PackedFloat32Array:
	var chord_len := 5.5
	var chords := [
		[38, [57, 62, 65]], [43, [59, 62, 67]], [36, [55, 60, 64]], [38, [57, 62, 65]],
		[34, [58, 62, 65]], [36, [55, 60, 64]], [43, [59, 62, 67]], [45, [57, 61, 64]],
		[38, [57, 62, 65]], [41, [57, 60, 65]], [43, [59, 62, 67]], [36, [55, 60, 64]],
		[34, [58, 62, 65]], [41, [60, 65, 69]], [43, [59, 62, 67]], [45, [57, 61, 64]],
	]
	var buf := _buffer(chord_len * chords.size())
	for i in chords.size():
		var t := i * chord_len
		var bass: int = chords[i][0]
		_tone(buf, t, chord_len + 1.5, _hz(bass - 12), 0.12, 1.5, 2.0, [1.0, 0.3, 0.05])
		# Медленный пульс баса — как вода в трубах.
		_tone(buf, t + chord_len * 0.5, 1.2, _hz(bass), 0.05, 0.2, 0.9, [1.0, 0.2])
		for note: int in chords[i][1]:
			_pad(buf, t, chord_len + 1.5, _hz(note - 12), 0.04)
		if rng.randf() < 0.7:
			var notes: Array = chords[i][1]
			_bell(buf, t + rng.randf_range(0.5, 2.5), _hz(notes[rng.randi_range(0, notes.size() - 1)] + 12), 0.045)
		# Капли: короткие высокие ноты со случайной паузой.
		var drops := rng.randi_range(2, 5)
		for d in drops:
			var notes: Array = chords[i][1]
			var f := _hz(notes[rng.randi_range(0, notes.size() - 1)] + 24)
			_tone(buf, t + rng.randf_range(0.0, chord_len), 0.18, f, 0.03, 0.002, 0.16, [1.0, 0.15])
	_echo(buf, 0.43, 0.4)
	_echo(buf, 0.71, 0.3)
	_lowpass(buf, 0.3)
	_lowpass(buf, 0.35)
	return buf


## «Хозяин Глубин»: ми фригийский, 110 уд/мин, 32 такта ≈ 70 с — бас-остинато и нарастающий пэд.
## dense — вторая фаза: та же гармония и длина (для кроссфейда), но плотнее — малый, щипки октавой выше, «тарелки».
func music_boss(dense: bool) -> PackedFloat32Array:
	var beat := 60.0 / 110.0
	var bar := beat * 4
	var roots := [40, 41, 40, 38, 40, 41, 43, 41]  # E F E D E F G F
	var pads := [[52, 55, 59], [53, 57, 60], [52, 55, 59], [50, 53, 57], [52, 55, 59], [53, 57, 60], [55, 59, 62], [53, 57, 60]]
	var bars_per_chord := 4
	var buf := _buffer(bar * bars_per_chord * roots.size())
	var ostinato := [0, 0, 12, 0, 1, 0, 7, 0]
	for c in roots.size():
		var start := c * bar * bars_per_chord
		var root: int = roots[c]
		var swell := 0.025 + 0.012 * c / roots.size()
		for p: int in pads[c]:
			_pad(buf, start, bar * bars_per_chord + 0.8, _hz(p), swell)
		for e in bars_per_chord * 8:
			var note := root - 12 + int(ostinato[e % ostinato.size()])
			_pluck(buf, start + e * beat * 0.5, _hz(note), 0.16, 0.4)
			if dense and e % 2 == 1:
				_pluck(buf, start + e * beat * 0.5, _hz(note + 24), 0.06, 0.25)
	for b in bars_per_chord * roots.size():
		var t := b * bar
		_kick(buf, t, 0.55)
		_kick(buf, t + beat * 2.5, 0.35)
		if dense:
			_kick(buf, t + beat * 1.5, 0.3)
			_snare(buf, t + beat, 0.14)
			_snare(buf, t + beat * 3, 0.17)
			for h in 8:
				_noise(buf, t + h * beat * 0.5, 0.05, 0.025, 0.02, 0.9)
		elif b % 2 == 1:
			_snare(buf, t + beat * 3, 0.12)
		if b % 8 == 7:
			_noise(buf, t + beat * 2, beat * 2, 0.05, 0.0, 0.5, true)
	# Тяжёлый рог: мотив из полутона, каждые 8 тактов.
	for k in roots.size() / 2:
		var t0 := k * bar * 8
		_horn(buf, t0 + bar * 4, beat * 2, _hz(52), 0.07)
		_horn(buf, t0 + bar * 4 + beat * 2, beat * 2, _hz(53), 0.07)
		_horn(buf, t0 + bar * 5, beat * 4, _hz(52), 0.07)
	_echo(buf, 0.27, 0.22)
	_lowpass(buf, 0.45)
	return buf


# --- Звуковые эффекты -----------------------------------------------------------

func sfx_click() -> PackedFloat32Array:
	var buf := _buffer(0.08)
	_tone(buf, 0, 0.05, 1800, 0.3, 0.002, 0.04, [1.0])
	_noise(buf, 0, 0.02, 0.2, 0.01, 0.2)
	return buf


func sfx_move() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_noise(buf, 0, 0.3, 0.35, 0.12, 0.08, true)
	_tone(buf, 0.02, 0.15, 90, 0.2, 0.01, 0.12, [1.0])
	return buf


func sfx_melee() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_kick(buf, 0, 0.9)
	_noise(buf, 0, 0.12, 0.6, 0.06, 0.4)
	_tone(buf, 0, 0.08, 640, 0.15, 0.001, 0.07, [1.0, 0.7, 0.4])  # лязг
	return buf


func sfx_shoot() -> PackedFloat32Array:
	var buf := _buffer(0.4)
	_pluck(buf, 0, 220, 0.6, 0.25)
	_noise(buf, 0.03, 0.25, 0.25, 0.1, 0.5, true)
	return buf


func sfx_impact() -> PackedFloat32Array:
	var buf := _buffer(0.25)
	_noise(buf, 0, 0.15, 0.6, 0.05, 0.25)
	_kick(buf, 0, 0.5)
	return buf


func sfx_death() -> PackedFloat32Array:
	var buf := _buffer(0.9)
	_sweep(buf, 0, 0.8, 320, 70, 0.35)
	_noise(buf, 0, 0.5, 0.2, 0.3, 0.15)
	return buf


func sfx_ability() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	for i in 4:
		_bell(buf, i * 0.07, _hz(72 + [0, 4, 7, 12][i]), 0.18)
	_noise(buf, 0, 0.4, 0.08, 0.2, 0.8, true)
	return buf


func sfx_spell() -> PackedFloat32Array:
	var buf := _buffer(1.2)
	_noise(buf, 0, 0.6, 0.25, 0.25, 0.5, true)
	_sweep(buf, 0, 0.5, 200, 900, 0.12)
	for n in [62, 66, 69, 74]:
		_bell(buf, 0.35, _hz(n), 0.12)
	_echo(buf, 0.18, 0.3)
	return buf


func sfx_order() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	_horn(buf, 0, 0.25, _hz(57), 0.3)
	_horn(buf, 0.22, 0.45, _hz(64), 0.3)
	return buf


func sfx_heal() -> PackedFloat32Array:
	var buf := _buffer(1.0)
	for i in 3:
		_bell(buf, i * 0.12, _hz([84, 88, 91][i]), 0.2)
	return buf


func sfx_wall() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	_noise(buf, 0, 0.6, 0.6, 0.3, 0.04)
	_kick(buf, 0.05, 0.7)
	return buf


func sfx_push() -> PackedFloat32Array:
	var buf := _buffer(0.4)
	_kick(buf, 0, 0.7)
	_noise(buf, 0.03, 0.25, 0.3, 0.1, 0.3, true)
	return buf


func sfx_turn() -> PackedFloat32Array:
	var buf := _buffer(0.6)
	_bell(buf, 0, _hz(81), 0.18)
	return buf


func sfx_card() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_noise(buf, 0, 0.1, 0.3, 0.04, 0.9)
	_bell(buf, 0.05, _hz(88), 0.08)
	return buf


func sfx_transform() -> PackedFloat32Array:
	var buf := _buffer(1.4)
	_sweep(buf, 0, 0.9, 150, 600, 0.1)
	_noise(buf, 0, 0.9, 0.15, 0.4, 0.4, true)
	for i in 5:
		_bell(buf, 0.5 + i * 0.08, _hz(74 + [0, 3, 7, 10, 12][i]), 0.12)
	_echo(buf, 0.21, 0.3)
	return buf


## Стирание разломом: обратное «всасывание» — нарастающий шум и падающий тон.
func sfx_erase() -> PackedFloat32Array:
	var buf := _buffer(1.4)
	_noise(buf, 0, 1.1, 0.5, 0.0, 0.3, true)
	_sweep(buf, 0.1, 1.1, 700, 40, 0.3)
	for n in [61, 62, 67]:
		_bell(buf, 0.0, _hz(n), 0.05)
	return buf


func sfx_victory() -> PackedFloat32Array:
	var buf := _buffer(2.2)
	var notes := [62, 66, 69, 74]
	for i in notes.size():
		_horn(buf, i * 0.16, 0.5 if i < 3 else 1.4, _hz(notes[i]), 0.2)
	_pad(buf, 0.48, 1.6, _hz(50), 0.08)
	return buf


func sfx_defeat() -> PackedFloat32Array:
	var buf := _buffer(2.4)
	var notes := [57, 53, 50, 45]
	for i in notes.size():
		_horn(buf, i * 0.35, 0.6 if i < 3 else 1.3, _hz(notes[i]), 0.18)
	_tone(buf, 0, 2.2, _hz(33), 0.12, 0.3, 1.0, [1.0, 0.5])
	return buf


# --- Этап B (SPEC_SPRINT9 12): слои напряжения, окружение, удары по классам ------------

## Слой «напряжение» к бою первого акта: та же длина, темп и гармония, что у music_battle —
## низкие смычковые с тремоло и стаккато, томы, лютня арпеджио, нарастающие тарелки.
func music_battle_tension() -> PackedFloat32Array:
	var beat := 0.6
	var bar := beat * 4
	var progression := [45, 41, 43, 40, 45, 41, 38, 40]
	var pads := [[57, 60, 64], [57, 60, 65], [55, 59, 62], [56, 59, 64], [57, 60, 64], [57, 60, 65], [57, 62, 65], [56, 59, 64]]
	var buf := _buffer(bar * 16)
	for c in progression.size():
		var start := c * bar * 2
		var root: int = progression[c]
		_bowed(buf, start, bar * 2 + 0.3, _hz(root - 12), 0.07, 0.25, 6.0)
		_bowed(buf, start, bar * 2 + 0.3, _hz(root - 5), 0.035, 0.6, 0.0)
		# Стаккато восьмыми: корень и октава — подгоняет.
		for e in 16:
			if e % 4 != 3:
				_bowed(buf, start + e * beat * 0.5, beat * 0.4, _hz(root + (12 if e % 2 == 1 else 0) - 12), 0.04, 0.02, 0.0)
		# Лютня: арпеджио по звукам аккорда октавой выше.
		var notes: Array = pads[c]
		for e in 8:
			_lute(buf, start + e * beat, _hz(int(notes[e % notes.size()]) + 12), 0.06, 0.9)
	for b in 16:
		var t := b * bar
		for hit: Array in [[0.0, 0.5], [0.5, 0.25], [1.5, 0.35], [2.0, 0.45], [2.5, 0.25], [3.5, 0.4]]:
			_tom(buf, t + float(hit[0]) * beat, 110.0 if float(hit[0]) < 2.0 else 92.0, float(hit[1]))
		if b % 4 == 3:
			_noise(buf, t, bar, 0.06, 0.0, 0.7, true)
	_echo(buf, 0.3, 0.2)
	_lowpass(buf, 0.55)
	return buf


## Слой «напряжение» ко второму акту: та же длина и аккорды, что у music_act2 —
## «хор» на звуках аккорда, бас смычком с тремоло, литавры каждую четверть аккорда.
func music_act2_tension() -> PackedFloat32Array:
	var chord_len := 5.5
	var chords := [
		[38, [57, 62, 65]], [43, [59, 62, 67]], [36, [55, 60, 64]], [38, [57, 62, 65]],
		[34, [58, 62, 65]], [36, [55, 60, 64]], [43, [59, 62, 67]], [45, [57, 61, 64]],
		[38, [57, 62, 65]], [41, [57, 60, 65]], [43, [59, 62, 67]], [36, [55, 60, 64]],
		[34, [58, 62, 65]], [41, [60, 65, 69]], [43, [59, 62, 67]], [45, [57, 61, 64]],
	]
	var buf := _buffer(chord_len * chords.size())
	var pulse := [0.5, 0.18, 0.3, 0.18]
	for i in chords.size():
		var t := i * chord_len
		var bass: int = chords[i][0]
		_bowed(buf, t, chord_len + 0.4, _hz(bass), 0.07, 0.5, 7.0)
		for note: int in chords[i][1]:
			_choir(buf, t, chord_len + 0.8, _hz(note - 12), 0.025, &"o" if i % 2 == 0 else &"u")
		for k in 4:
			_tom(buf, t + k * chord_len / 4.0, 70.0, float(pulse[k]))
	_echo(buf, 0.43, 0.35)
	_lowpass(buf, 0.4)
	return buf


## Окружение первого акта — «пыль архива»: тихий гул зала, шорох страниц, скрип полок.
func ambience_archive() -> PackedFloat32Array:
	var buf := _buffer(24.0)
	_noise(buf, 0.0, 24.0, 0.25, 0.0, 0.02)
	for i in 12:
		_noise(buf, rng.randf_range(0.0, 23.5), rng.randf_range(0.25, 0.5), 0.09, 0.0, 0.6, true)
	for i in 3:
		_sweep(buf, rng.randf_range(0.0, 23.0), 0.7, rng.randf_range(80.0, 110.0), rng.randf_range(60.0, 75.0), 0.03)
	_bell(buf, rng.randf_range(4.0, 20.0), _hz(50), 0.02)
	_lowpass(buf, 0.5)
	return buf


## Окружение второго акта — «капель и вода»: низкий гул воды, мягкий плеск, редкие негромкие капли и пузыри.
## Капли — низкие, короткие и тише гула: высокие чистые тоны на фоне звучали как писк.
func ambience_water() -> PackedFloat32Array:
	var buf := _buffer(20.0)
	_noise(buf, 0.0, 20.0, 0.3, 0.0, 0.015)
	for i in 8:
		_noise(buf, rng.randf_range(0.0, 19.0), rng.randf_range(1.0, 2.0), 0.08, 0.0, 0.12, true)
	for i in 12:
		_ping(buf, rng.randf_range(0.0, 19.8), rng.randf_range(450.0, 900.0), rng.randf_range(0.02, 0.035), 0.035, 0.12)
	for i in 4:
		_sweep(buf, rng.randf_range(0.0, 19.8), 0.08, 250.0, 600.0, 0.012)
	_lowpass(buf, 0.45)
	return buf


## Удар металлом: короткий звон негармонических обертонов поверх тупого удара.
func sfx_hit_metal() -> PackedFloat32Array:
	var buf := _buffer(0.5)
	_kick(buf, 0, 0.4)
	for p: Array in [[1.0, 0.25, 0.22], [2.41, 0.18, 0.12], [3.95, 0.12, 0.07], [5.6, 0.08, 0.04]]:
		_ping(buf, 0.0, 520.0 * float(p[0]), float(p[1]), float(p[2]))
	_noise(buf, 0, 0.05, 0.3, 0.02, 0.9)
	return buf


## Когти и плоть: два быстрых взмаха шума и глухой удар.
func sfx_hit_claw() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_noise(buf, 0.0, 0.09, 0.5, 0.0, 0.7, true)
	_noise(buf, 0.07, 0.09, 0.4, 0.0, 0.6, true)
	_tone(buf, 0.05, 0.12, 110, 0.3, 0.002, 0.1, [1.0, 0.3])
	_noise(buf, 0.05, 0.15, 0.35, 0.05, 0.1)
	return buf


## Магия: мерцание, восходящий тон и короткий аккорд колокольчиков.
func sfx_hit_magic() -> PackedFloat32Array:
	var buf := _buffer(0.8)
	_noise(buf, 0, 0.3, 0.15, 0.0, 0.3, true)
	_sweep(buf, 0, 0.22, 400, 1200, 0.12)
	for n in [74, 78, 81]:
		_bell(buf, 0.08, _hz(n), 0.07)
	return buf


## Стрелы и осколки: свист и звон стекла.
func sfx_hit_shard() -> PackedFloat32Array:
	var buf := _buffer(0.45)
	_noise(buf, 0, 0.12, 0.3, 0.0, 0.8, true)
	for i in 5:
		_ping(buf, rng.randf_range(0.03, 0.14), rng.randf_range(2000.0, 4500.0), 0.08, 0.05)
	return buf


## Крупные: низкий тяжёлый удар с гулом.
func sfx_hit_heavy() -> PackedFloat32Array:
	var buf := _buffer(0.7)
	var phase := 0.0
	for i in int(0.5 * RATE):
		phase += TAU * (38.0 + 60.0 * exp(-i / (0.05 * RATE))) / RATE
		_add(buf, i, sin(phase) * exp(-i / (0.2 * RATE)))
	_noise(buf, 0, 0.4, 0.5, 0.2, 0.08)
	_noise(buf, 0.02, 0.1, 0.3, 0.04, 0.5)
	return buf


# --- Инструменты этапа B --------------------------------------------------------------

## Лютня: щипок (короткий фильтрованный шум) и затухающие гармоники с лёгкой негармоничностью.
func _lute(buf: PackedFloat32Array, start: float, freq: float, amp: float, dur: float = 1.2) -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var pluck_len := int(0.012 * RATE)
	var lp := 0.0
	for i in len:
		var t := float(i) / RATE
		var v := 0.0
		for h in 5:
			var hf := freq * (h + 1) * (1.0 + 0.0008 * h * h)
			v += sin(TAU * hf * t) * exp(-t * (2.5 + h * 1.6)) / (h + 1.0)
		if i < pluck_len:
			lp += 0.35 * (rng.randf_range(-1.0, 1.0) - lp)
			v += lp * 0.6 * (1.0 - float(i) / pluck_len)
		_add(buf, s0 + i, v * amp * minf(1.0, float(len - i) / 300.0))


## Смычковые: сглаженная пила с вибрато и шумом смычка; tremolo — частота тремоло (0 — без).
func _bowed(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, attack: float = 0.4, tremolo: float = 0.0) -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := maxi(1, int(attack * RATE))
	var r := maxi(1, int(minf(0.5, dur * 0.4) * RATE))
	var phase := 0.0
	var lp := 0.0
	var hiss := 0.0
	for i in len:
		var t := float(i) / RATE
		phase = fmod(phase + freq * (1.0 + 0.005 * sin(TAU * 5.2 * t)) / RATE, 1.0)
		hiss += 0.05 * (rng.randf_range(-1.0, 1.0) - hiss)
		lp += 0.18 * ((2.0 * phase - 1.0) + hiss * 0.3 - lp)
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		if tremolo > 0.0:
			env *= 0.65 + 0.35 * sin(TAU * tremolo * t)
		_add(buf, s0 + i, lp * env * amp)


## Форманты гласных «хора»: [частота, вес].
const VOWELS := {
	&"a": [[800.0, 1.0], [1150.0, 0.5], [2900.0, 0.15]],
	&"o": [[450.0, 1.0], [800.0, 0.45], [2830.0, 0.1]],
	&"u": [[325.0, 1.0], [700.0, 0.3], [2530.0, 0.08]],
}


## «Хор»: две слегка расстроенные пилы через полосовые фильтры формант гласной.
func _choir(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, vowel: StringName = &"o") -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := int(0.6 * RATE)
	var r := maxi(1, int(minf(0.8, dur * 0.4) * RATE))
	var formants: Array = VOWELS[vowel]
	var coefs: Array = []
	var states: Array = []
	for fm: Array in formants:
		coefs.append(_bandpass(float(fm[0]), 6.0))
		states.append([0.0, 0.0, 0.0, 0.0])
	var p1 := 0.0
	var p2 := 0.0
	for i in len:
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 4.6 * t + 1.3)
		p1 = fmod(p1 + freq * 0.997 * vib / RATE, 1.0)
		p2 = fmod(p2 + freq * 1.003 * vib / RATE, 1.0)
		var x := (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0)
		var y := 0.0
		for k in formants.size():
			y += _biquad(x, coefs[k], states[k]) * float(formants[k][1])
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		_add(buf, s0 + i, y * env * amp)


## Коэффициенты полосового фильтра (RBJ, усиление 0 дБ в центре): [b0, b2, a1, a2] (b1 = 0).
static func _bandpass(f0: float, q: float) -> Array:
	var w0 := TAU * f0 / RATE
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, -alpha / a0, -2.0 * cos(w0) / a0, (1.0 - alpha) / a0]


## Шаг фильтра; s — состояние [x1, x2, y1, y2].
static func _biquad(x: float, c: Array, s: Array) -> float:
	var y: float = c[0] * x + c[1] * s[1] - c[2] * s[2] - c[3] * s[3]
	s[1] = s[0]
	s[0] = x
	s[3] = s[2]
	s[2] = y
	return y


## Том / литавра: синус с падающей высотой от base × 1,6 к base.
func _tom(buf: PackedFloat32Array, start: float, base: float, amp: float) -> void:
	var s0 := int(start * RATE)
	var phase := 0.0
	for i in int(0.35 * RATE):
		phase += TAU * (base + base * 0.6 * exp(-i / (0.04 * RATE))) / RATE
		_add(buf, s0 + i, sin(phase) * amp * exp(-i / (0.12 * RATE)))


## Короткий звон или капля: синус с экспоненциальным спадом; glide — подъём высоты (доля).
func _ping(buf: PackedFloat32Array, start: float, freq: float, amp: float, decay: float, glide: float = 0.0) -> void:
	var s0 := int(start * RATE)
	var len := int(decay * 6.0 * RATE)
	var phase := 0.0
	for i in len:
		var t := float(i) / RATE
		phase += TAU * freq * (1.0 + glide * (1.0 - exp(-t / 0.02))) / RATE
		_add(buf, s0 + i, sin(phase) * amp * exp(-t / decay) * minf(1.0, i / 20.0))


# --- Варианты после плейтеста (SPEC_SPRINT9 21) -----------------------------------------
# Автору не понравились музыка боя (дёшево звучит, надоедает, не то настроение), звук победы
# и звук передачи хода. Ниже — варианты на выбор; инструменты ансамблевые: несколько слегка
# расстроенных голосов на ноту вместо одиночных «голых» тонов.

## Музыка боя A «Мрачная тактика»: ре минор, 70 уд/мин, 44 такта ≈ 2,5 мин.
## Вступление (тихие струнные и хор) → тема виолончели с арфой → светлая середина с хором → возврат.
func music_battle_dark() -> PackedFloat32Array:
	var bar := 60.0 / 70.0 * 4.0
	var beat := bar / 4.0
	var dark := [[38, [50, 53, 57]], [34, [50, 53, 58]], [31, [50, 55, 58]], [33, [49, 52, 57]]]   # Dm Bb Gm A
	var light := [[41, [53, 57, 60]], [36, [52, 55, 60]], [38, [50, 53, 57]], [34, [50, 53, 58]]]  # F C Dm Bb
	var plan: Array = []
	for i in 8:
		plan.append([dark[i % 4], 0])
	for i in 16:
		plan.append([dark[i % 4], 1])
	for i in 12:
		plan.append([light[i % 4], 2])
	for i in 8:
		plan.append([dark[i % 4], 3])
	var buf := _buffer(bar * plan.size())
	for b in plan.size():
		var t := b * bar
		var chord: Array = plan[b][0]
		var part: int = plan[b][1]
		var notes: Array = chord[1]
		var pad := 0.02 if part == 0 else 0.028
		_strings(buf, t, bar + 0.6, _hz(int(chord[0]) - 12), pad * 1.4, 0.8, 0.9)
		for n: int in notes:
			_strings(buf, t, bar + 0.6, _hz(n), pad, 0.9, 0.9)
		if part == 0 or part == 3:
			_choir(buf, t, bar + 0.8, _hz(int(notes[0])), 0.012, &"u")
		if part == 1 or part == 3:
			for e in 8:
				_harp(buf, t + e * beat * 0.5, _hz(int(notes[[0, 1, 2, 1][e % 4]]) + 12), 0.05 if part == 1 else 0.035)
		elif part == 2:
			for e in 4:
				_harp(buf, t + e * beat, _hz(int(notes[e % 3]) + 12), 0.04)
		if part == 1 or part == 2:
			_taiko(buf, t, 0.35)
			_taiko(buf, t + beat * 2, 0.22)
			if b % 4 == 3:
				_taiko(buf, t + beat * 3.5, 0.18)
		elif part == 0 and b % 2 == 0:
			_taiko(buf, t, 0.2)
	# Тема виолончели (4 такта): A Bb A G F | G F E — над Dm Bb Gm A.
	var theme := [[0, 57, 2], [2, 58, 1], [3, 57, 1], [4, 55, 2], [6, 53, 2], [8, 55, 3], [11, 53, 1], [12, 52, 4]]
	for start_bar in [8, 16, 36]:
		for m: Array in theme:
			_cello(buf, start_bar * bar + float(m[0]) * beat, float(m[2]) * beat + 0.15, _hz(int(m[1])), 0.07)
	# Мелодия хора в светлой середине: F E D D C — над F C Dm Bb.
	var hymn := [[0, 65, 4], [4, 64, 4], [8, 62, 4], [12, 62, 2], [14, 60, 2]]
	for start_bar in [24, 28, 32]:
		for m: Array in hymn:
			_choir(buf, start_bar * bar + float(m[0]) * beat, float(m[2]) * beat + 0.4, _hz(int(m[1])), 0.03, &"a")
	_echo(buf, 0.43, 0.3)
	_echo(buf, 0.71, 0.2)
	_lowpass(buf, 0.42)
	return buf


## Музыка боя B «Поход»: ля дорийский, 84 уд/мин, 52 такта ≈ 2,5 мин.
## Остинато лютни и арфы, рамочный барабан, струнные; в середине — тема валторн.
func music_battle_march() -> PackedFloat32Array:
	var bar := 60.0 / 84.0 * 4.0
	var beat := bar / 4.0
	var prog_a := [[45, [57, 60, 64]], [43, [55, 59, 62]], [38, [54, 57, 62]], [45, [57, 60, 64]]]  # Am G D Am
	var prog_b := [[41, [53, 57, 60]], [43, [55, 59, 62]], [45, [57, 60, 64]], [40, [56, 59, 64]]]  # F G Am E
	var plan: Array = []
	for i in 4:
		plan.append([prog_a[i % 4], 0])
	for i in 16:
		plan.append([prog_a[i % 4], 1])
	for i in 16:
		plan.append([prog_b[i % 4], 2])
	for i in 12:
		plan.append([prog_a[i % 4], 3])
	for i in 4:
		plan.append([prog_a[i % 4], 0])
	var buf := _buffer(bar * plan.size())
	for b in plan.size():
		var t := b * bar
		var chord: Array = plan[b][0]
		var part: int = plan[b][1]
		var notes: Array = chord[1]
		_strings(buf, t, bar + 0.5, _hz(int(chord[0]) - 12), 0.035, 0.5, 0.7)
		if part != 0:
			for n: int in notes:
				_strings(buf, t, bar + 0.5, _hz(n), 0.022, 0.6, 0.7)
		# Лютня: восьмые по звукам аккорда; во вступлении и коде — одна.
		for e in 8:
			var idx: int = [0, 2, 1, 2, 0, 2, 1, 2][e]
			_lute(buf, t + e * beat * 0.5, _hz(int(notes[idx])), 0.06 if e % 2 == 0 else 0.045, 0.8)
		if part == 1 or part == 3:
			for e in 4:
				_harp(buf, t + e * beat + beat * 0.5, _hz(int(notes[(e + 1) % 3]) + 12), 0.03)
		if part != 0:
			for hit: Array in [[0.0, 0.32], [1.5, 0.18], [2.0, 0.26], [3.0, 0.16], [3.5, 0.12]]:
				_frame_drum(buf, t + float(hit[0]) * beat, float(hit[1]))
	# Тема валторн (4 такта): A G A B C B A G# — над F G Am E.
	var motif := [[0, 69, 2], [2, 67, 1], [3, 69, 1], [4, 71, 2], [6, 72, 2], [8, 71, 2], [10, 69, 2], [12, 68, 4]]
	for start_bar in [20, 24, 28, 32]:
		var amp := 0.05 if start_bar % 8 == 4 else 0.04
		for m: Array in motif:
			_brass(buf, start_bar * bar + float(m[0]) * beat, float(m[2]) * beat + 0.1, _hz(int(m[1]) - 12), amp)
	_echo(buf, 0.36, 0.25)
	_lowpass(buf, 0.45)
	return buf


## Победа 1 «Сдержанный аккорд»: тёплый аккорд струнных, арпеджио арфы, колокол.
func sfx_victory_chord() -> PackedFloat32Array:
	var buf := _buffer(3.0)
	for n in [50, 57, 62, 66]:
		_strings(buf, 0.0, 2.6, _hz(n), 0.05, 0.12, 1.2)
	for i in 4:
		_harp(buf, i * 0.08, _hz([62, 66, 69, 74][i]), 0.08)
	_bell(buf, 0.15, _hz(86), 0.05)
	_echo(buf, 0.3, 0.25)
	return buf


## Победа 2 «Фанфары»: дробь литавр, удар, медь и тарелка, аккорд струнных под ними.
func sfx_victory_fanfare() -> PackedFloat32Array:
	var buf := _buffer(3.0)
	for i in 8:
		_taiko(buf, i * 0.05, 0.1 + 0.03 * i)
	_taiko(buf, 0.4, 0.6)
	_brass(buf, 0.0, 0.18, _hz(62), 0.12)
	_brass(buf, 0.2, 0.18, _hz(62), 0.12)
	for n in [57, 62, 66, 69]:
		_brass(buf, 0.4, 1.1, _hz(n), 0.08)
	_noise(buf, 0.4, 1.4, 0.12, 0.5, 0.8)
	for n in [50, 57, 62, 66]:
		_strings(buf, 0.4, 2.0, _hz(n), 0.03, 0.1, 1.0)
	_echo(buf, 0.25, 0.2)
	return buf


## Победа 3 «Память возвращена»: глиссандо арфы вверх, хор, мерцание колокольчиков.
func sfx_victory_memory() -> PackedFloat32Array:
	var buf := _buffer(3.2)
	var gliss := [62, 64, 66, 69, 71, 74, 76, 78]
	for i in gliss.size():
		_harp(buf, i * 0.06, _hz(int(gliss[i])), 0.07)
	for n in [62, 66, 69]:
		_choir(buf, 0.45, 2.2, _hz(n), 0.03, &"a")
	for i in 3:
		_bell(buf, 0.5 + i * 0.1, _hz([86, 90, 93][i]), 0.025)
	_echo(buf, 0.37, 0.3)
	return buf


## Ход 1 «Деревянный стук»: короткий отфильтрованный щелчок и глухой корпус.
func sfx_turn_knock() -> PackedFloat32Array:
	var buf := _buffer(0.2)
	var c := _bandpass(900.0, 3.0)
	var st := [0.0, 0.0, 0.0, 0.0]
	for i in int(0.03 * RATE):
		_add(buf, i, _biquad(rng.randf_range(-1.0, 1.0), c, st) * 0.6 * exp(-i / (0.006 * RATE)))
	_tone(buf, 0.0, 0.08, 180, 0.3, 0.001, 0.07, [1.0, 0.25])
	return buf


## Ход 2 «Страница»: шелест перелистнутого листа.
func sfx_turn_page() -> PackedFloat32Array:
	var buf := _buffer(0.18)
	_noise(buf, 0.0, 0.11, 0.35, 0.0, 0.75, true)
	_noise(buf, 0.0, 0.012, 0.2, 0.004, 1.0)
	return buf


## Ход 3 «Струна»: короткий приглушённый щипок.
func sfx_turn_string() -> PackedFloat32Array:
	var buf := _buffer(0.35)
	_harp(buf, 0.0, _hz(57), 0.5, 0.3, 0.99)
	return buf


# --- Ансамблевые инструменты (после плейтеста) ---------------------------------------------

## Ансамбль струнных: три слегка расстроенные сглаженные пилы с вибрато в разных фазах;
## у высоких нот звук ярче.
func _strings(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, attack: float = 0.6, release: float = 0.8) -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := maxi(1, int(attack * RATE))
	var r := maxi(1, int(minf(release, dur * 0.5) * RATE))
	var k := clampf(freq / 2500.0, 0.06, 0.3)
	var p0 := 0.0
	var p1 := 0.33
	var p2 := 0.66
	var l0 := 0.0
	var l1 := 0.0
	var l2 := 0.0
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		p0 = fmod(p0 + freq * 0.997 * (1.0 + 0.004 * sin(TAU * 5.0 * t)) / RATE, 1.0)
		p1 = fmod(p1 + freq * (1.0 + 0.004 * sin(TAU * 5.4 * t + 2.1)) / RATE, 1.0)
		p2 = fmod(p2 + freq * 1.0035 * (1.0 + 0.004 * sin(TAU * 5.8 * t + 4.2)) / RATE, 1.0)
		l0 += k * ((2.0 * p0 - 1.0) - l0)
		l1 += k * ((2.0 * p1 - 1.0) - l1)
		l2 += k * ((2.0 * p2 - 1.0) - l2)
		_add(buf, s0 + i, (l0 + l1 + l2) * env * amp / 3.0)


## Виолончель: две расстроенные пилы, мягкая атака, вибрато вступает чуть позже начала ноты.
func _cello(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float) -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := maxi(1, int(0.1 * RATE))
	var r := maxi(1, int(minf(0.25, dur * 0.4) * RATE))
	var p0 := 0.0
	var p1 := 0.5
	var l0 := 0.0
	var l1 := 0.0
	for i in len:
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(1.0, maxf(0.0, t - 0.15) / 0.3)
		p0 = fmod(p0 + freq * 0.998 * vib / RATE, 1.0)
		p1 = fmod(p1 + freq * 1.002 * vib / RATE, 1.0)
		l0 += 0.1 * ((2.0 * p0 - 1.0) - l0)
		l1 += 0.1 * ((2.0 * p1 - 1.0) - l1)
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		_add(buf, s0 + i, (l0 + l1) * env * amp * 0.5)


## Медь: две расстроенные пилы, фильтр открывается вместе с атакой (звук «раскрывается»).
func _brass(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float) -> void:
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	var a := maxi(1, int(0.08 * RATE))
	var r := maxi(1, int(minf(0.15, dur * 0.4) * RATE))
	var p0 := 0.0
	var p1 := 0.4
	var l0 := 0.0
	var l1 := 0.0
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, float(i) / a) * minf(1.0, float(len - i) / r)
		var vib := 1.0 + 0.003 * sin(TAU * 4.8 * t)
		p0 = fmod(p0 + freq * 0.9985 * vib / RATE, 1.0)
		p1 = fmod(p1 + freq * 1.0015 * vib / RATE, 1.0)
		var k := 0.04 + 0.16 * env
		l0 += k * ((2.0 * p0 - 1.0) - l0)
		l1 += k * ((2.0 * p1 - 1.0) - l1)
		_add(buf, s0 + i, (l0 + l1) * env * amp * 0.5)


## Арфа: Karplus–Strong с мягким (сглаженным) возбуждением и долгим затуханием; damping < 1 глушит струну.
func _harp(buf: PackedFloat32Array, start: float, freq: float, amp: float, dur: float = 2.0, damping: float = 0.9985) -> void:
	var period := maxi(2, int(RATE / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	var lp := 0.0
	for i in period:
		lp += 0.5 * (rng.randf_range(-1.0, 1.0) - lp)
		ring[i] = lp
	var s0 := int(start * RATE)
	var len := int(dur * RATE)
	for i in len:
		var j := i % period
		var v := ring[j]
		ring[j] = 0.5 * (v + ring[(j + 1) % period]) * damping
		_add(buf, s0 + i, v * amp * minf(1.0, float(len - i) / 400.0))


## Глухой большой барабан: низкий синус с падающей высотой и мягкий шумовой удар.
func _taiko(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var s0 := int(start * RATE)
	var phase := 0.0
	var lp := 0.0
	for i in int(0.45 * RATE):
		phase += TAU * (52.0 + 48.0 * exp(-i / (0.03 * RATE))) / RATE
		lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)
		_add(buf, s0 + i, (sin(phase) * exp(-i / (0.25 * RATE)) + lp * 2.0 * exp(-i / (0.08 * RATE))) * amp)


## Рамочный барабан: выше и суше, с шорохом кожи.
func _frame_drum(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var s0 := int(start * RATE)
	var phase := 0.0
	var lp := 0.0
	for i in int(0.25 * RATE):
		phase += TAU * (150.0 + 60.0 * exp(-i / (0.02 * RATE))) / RATE
		lp += 0.3 * (rng.randf_range(-1.0, 1.0) - lp)
		_add(buf, s0 + i, (sin(phase) * exp(-i / (0.12 * RATE)) + lp * 0.5 * exp(-i / (0.03 * RATE))) * amp)


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

func save(path: String, buf: PackedFloat32Array, loop: bool) -> void:
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
