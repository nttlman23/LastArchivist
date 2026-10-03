class_name EventResolver
extends RefCounted
## Применение вариантов событий (SPEC_SPRINT3 5.3). Случайность — от сида острова.


class Result:
	var text_key: String
	var success := true
	## Бой, начатый событием: уровень (0 — боя нет) и карта-награда за победу.
	var battle_tier := 0
	var battle_reward: StringName
	## Карты, угасшие или убранные эффектами.
	var gone: Array[StringName] = []
	## Изменения ресурсов — для текста итога.
	var resources: Dictionary[StringName, int] = {}


## Ключ причины, почему вариант недоступен, или "".
static func option_reason(db: DefsDB, run: RunState, option: EventOptionDef) -> String:
	if option.requires_resource != &"" and not run.can_afford(option.requires_resource, option.requires_amount):
		return "REASON_NO_" + String(option.requires_resource).to_upper()
	if option.needs_card and not run.codex.has_unit_cards(db):
		return "REASON_NO_CARDS"
	if option.needs_spell and run.hero.spells.is_empty():
		return "REASON_NO_SPELLS"
	return ""


## chosen_card — индекс выбранной карты отряда для вариантов с needs_card, иначе -1.
static func apply(db: DefsDB, run: RunState, node_id: int, event: EventDef, option_index: int, chosen_card: int = -1) -> Result:
	var option: EventOptionDef = event.options[option_index]
	assert(option_reason(db, run, option) == "")
	assert(not option.needs_card or db.memory(run.codex.cards[chosen_card].memory_id).is_unit())
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node_id, "event:%d" % option_index)
	var result := Result.new()
	result.success = option.chance >= 1.0 or rng.randf() < option.chance
	result.text_key = option.result_key if result.success else option.fail_result_key
	var chosen: CodexState.Card = run.codex.cards[chosen_card] if chosen_card >= 0 else null
	for e: EventEffect in (option.effects if result.success else option.fail_effects):
		_apply_effect(db, run, e, chosen, rng, result)
	# Карты с нулевой прочностью угасают, как при распаде.
	for c in run.codex.cards.duplicate():
		if c.durability <= 0:
			result.gone.append(c.memory_id)
			run.codex.cards.erase(c)
	return result


## Встреча для боя, начатого событием: шаблон уровня tier по сиду острова.
static func battle_encounter(db: DefsDB, run: RunState, node_id: int, tier: int) -> StringName:
	var pool := db.encounter_pool(tier, false, 2 if tier >= 4 else 1)
	return pool[posmod(run.node_seed(node_id, "event_battle"), pool.size())]


static func _apply_effect(db: DefsDB, run: RunState, e: EventEffect, chosen: CodexState.Card, rng: RandomNumberGenerator, result: Result) -> void:
	match e.kind:
		EventEffect.Kind.RESOURCE:
			var before: int = run.resources.get(e.resource, 0)
			run.gain(e.resource, e.amount)
			result.resources[e.resource] = result.resources.get(e.resource, 0) + run.resources[e.resource] - before
		EventEffect.Kind.DURABILITY_CHOSEN:
			_change_durability(db, chosen, e.amount)
		EventEffect.Kind.DURABILITY_RANDOM:
			var cards := run.codex.cards.duplicate()
			for i in mini(e.count, cards.size()):
				var idx := rng.randi_range(0, cards.size() - 1)
				_change_durability(db, cards[idx], e.amount)
				cards.remove_at(idx)
		EventEffect.Kind.DURABILITY_STRONGEST:
			var best: CodexState.Card = null
			for c in run.codex.cards:
				if best == null or c.durability > best.durability:
					best = c
			if best:
				_change_durability(db, best, e.amount)
		EventEffect.Kind.ADD_CARD:
			for i in e.count:
				if run.codex.is_full():
					break
				var id := e.memory_id
				if id == &"":
					var units := run.pool_unique().filter(func(m: StringName) -> bool: return db.memory(m).is_unit())
					id = units[rng.randi_range(0, units.size() - 1)]
				var card := run.gain_card(db, id)
				if e.durability > 0:
					card.durability = e.durability
		EventEffect.Kind.REMOVE_CHOSEN:
			if chosen:
				result.gone.append(chosen.memory_id)
				run.codex.cards.erase(chosen)
		EventEffect.Kind.SPELL_CHARGES_ALL:
			var charges: Array[int] = []
			for s in run.hero.spells:
				charges.append(s.charges + e.amount)
			run.apply_spell_charges(charges)
		EventEffect.Kind.UPGRADE_RANDOM:
			var ids: Array = db.upgrades.keys()
			ids.sort()
			run.hero.upgrades.append(ids[rng.randi_range(0, ids.size() - 1)])
		EventEffect.Kind.BATTLE:
			result.battle_tier = e.tier
			result.battle_reward = e.memory_id
		EventEffect.Kind.RELIC:
			var free := RelicOps.available(db, run)
			if not free.is_empty():
				RelicOps.take(db, run, free[rng.randi_range(0, free.size() - 1)], rng.randi())
		EventEffect.Kind.SCOUT_NEXT:
			var from := run.map.current_layer() + 1
			for layer in range(from, from + e.count):
				for n in run.map.layer_nodes(layer):
					n.scouted = true


static func _change_durability(db: DefsDB, card: CodexState.Card, amount: int) -> void:
	if card == null:
		return
	card.durability = mini(db.memory(card.memory_id).max_durability, card.durability + amount)
