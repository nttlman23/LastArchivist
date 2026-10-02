class_name RiftRule
extends RefCounted
## Правило разлома «Стирание» (SPEC_SPRINT3 6.2): в раундах 3, 7, 11… помечается сильнейший
## стек игрока, в раундах 4, 8, 12… помеченный (если жив) стирается из боя и из Кодекса.
## Гибель Хранителя закрывает разлом — это победа.

const PERIOD := 4
const MARK_PHASE := 3
const ERASE_PHASE := 0


static func on_round_start(state: BattleState, events: Array[BattleEvent]) -> void:
	var phase := state.round_number % PERIOD
	if phase == ERASE_PHASE:
		for u in state.alive(UnitState.Side.PLAYER):
			if u.has_status(UnitState.STATUS_RIFT_MARKED):
				u.count = 0
				u.top_hp = 0
				u.statuses.clear()
				if u.card_index >= 0:
					state.erased_cards.append(u.card_index)
				events.append(BattleEvent.new(BattleEvent.ERASED, {"uid": u.uid}))
	elif phase == MARK_PHASE:
		var target := strongest(state)
		if target:
			target.statuses[UnitState.STATUS_RIFT_MARKED] = UnitState.PERMANENT
			events.append(BattleEvent.new(BattleEvent.RIFT_MARKED, {"uid": target.uid}))


## Сильнейший живой стек игрока: наибольшие суммарные ОЗ, при равенстве — меньший uid.
static func strongest(state: BattleState) -> UnitState:
	var best: UnitState = null
	for u in state.alive(UnitState.Side.PLAYER):
		if best == null or u.total_hp() > best.total_hp():
			best = u
	return best
