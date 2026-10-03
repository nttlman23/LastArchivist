class_name HeroAi
extends RefCounted
## Простой AI Архивариуса — только для симуляции баланса (tools/sim_balance.gd).
## Каждый раунд выбирает одно действие с лучшей оценкой или ничего.

const MIN_SPELL_DAMAGE := 40
const CLOSE_RANKS_SCORE := 20.0
const ADVANCE_SCORE := 25.0
const ROYAL_SCORE := 30.0
const ALLY_HIT_WEIGHT := 1.5


static func choose(state: BattleState) -> BattleAction:
	if not state.can_hero_act():
		return null
	var best: BattleAction = null
	var best_score := 0.0
	for slot in state.hero_spells.size():
		var id := StringName(state.hero_spells[slot]["spell_id"])
		for a in HeroActions.options(state, id, slot):
			var s := _spell_score(state, a)
			if s > best_score:
				best_score = s
				best = a
	for id in state.hero_orders:
		for a in HeroActions.options(state, id, -1):
			var s := _order_score(state, a)
			if s > best_score:
				best_score = s
				best = a
	return best


static func _spell_score(state: BattleState, a: BattleAction) -> float:
	var power := int(state.hero_spells[a.slot]["power"])
	var t := state.get_unit(a.target_uid)
	match a.ref_id:
		HeroActions.ASH_RECORD, HeroActions.CHAIN_SPELL:
			if power >= t.total_hp() or power >= MIN_SPELL_DAMAGE:
				return AiController.value(power, t)
		HeroActions.HUNGER:
			var missing := t.start_count * t.hp - t.total_hp()
			if missing >= power * 0.6:
				return minf(power, missing)
		HeroActions.SHARD_RAIN:
			var score := 0.0
			var victims := state.neighbors_of(a.dest)
			var center := state.unit_at(a.dest)
			if center:
				victims.append(center)
			for v in victims:
				var val := AiController.value(power, v)
				score += val if v.side == UnitState.Side.ENEMY else -ALLY_HIT_WEIGHT * val
			if score >= MIN_SPELL_DAMAGE:
				return score
	return 0.0


static func _order_score(state: BattleState, a: BattleAction) -> float:
	var t := state.get_unit(a.target_uid)
	match a.ref_id:
		HeroActions.CLOSE_RANKS:
			var adjacent_enemies := state.neighbors_of(t.hex).filter(func(o: UnitState) -> bool: return o.side != t.side).size()
			if adjacent_enemies >= 2:
				return CLOSE_RANKS_SCORE
		HeroActions.ADVANCE:
			# Рывок активному стеку, если без него он не дотягивается до врага, а с ним — да.
			if t.uid == state.active_uid and not AiController.can_attack_now(state, t):
				t.statuses[UnitState.STATUS_ADVANCE] = UnitState.PERMANENT
				var reaches := AiController.can_attack_now(state, t)
				t.statuses.erase(UnitState.STATUS_ADVANCE)
				if reaches:
					return ADVANCE_SCORE
		HeroActions.DEEP_BLESSING:
			var missing := t.start_count * t.hp - t.total_hp()
			if missing >= HeroActions.BLESSING_HEAL * 0.75:
				return float(mini(missing, HeroActions.BLESSING_HEAL))
		HeroActions.ROYAL:
			if AiController.can_attack_now(state, t):
				return ROYAL_SCORE
	return 0.0
