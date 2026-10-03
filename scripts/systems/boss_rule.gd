class_name BossRule
extends RefCounted
## Фазы Хозяина Глубин (SPEC_SPRINT7 6): при половине ОЗ — один раз — вторая фаза:
## половина свободных клеток становится постоянной водой, течения разворачиваются,
## босс получает +2 к защите.

const PHASE_SHARE := 0.5
const PHASE_DEFENSE := 2
const FLOOD_SHARE := 0.5


static func check(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.boss_phase != 1 or state.biome != &"flooded":
		return
	var boss := state.get_unit(state.boss_uid)
	if boss == null or not boss.is_alive() or boss.total_hp() > boss.start_count * boss.hp * state.boss_phase_share:
		return
	state.boss_phase = 2
	boss.defense += PHASE_DEFENSE
	var free: Array[Vector2i] = []
	for h in state.grid.all_hexes():
		if state.is_free(h) and not state.water.has(h):
			free.append(h)
	# Детерминированно: перемешивание генератором боя.
	for i in range(free.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp := free[i]
		free[i] = free[j]
		free[j] = tmp
	for i in floori(free.size() * FLOOD_SHARE):
		state.water[free[i]] = BattleState.WATER_PERMANENT
	for h in state.currents.keys():
		state.currents[h] = (state.currents[h] + 3) % 6
	events.append(BattleEvent.new(BattleEvent.PHASE_CHANGED, {"uid": boss.uid, "phase": 2}))
