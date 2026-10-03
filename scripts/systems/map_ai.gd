class_name MapAi
extends RefCounted
## Простая политика экспедиции для симуляции и автопрогона (SPEC_SPRINT3 6.3). В игре не используется.

const LOW_DURABILITY := 0.5
const SHOP_PARCHMENT := 6
const ELITE_MIN_UNITS := 4


## Средняя доля прочности карт Кодекса (0..1).
static func durability_ratio(db: DefsDB, run: RunState) -> float:
	if run.codex.cards.is_empty():
		return 0.0
	var sum := 0.0
	for c in run.codex.cards:
		sum += float(c.durability) / db.memory(c.memory_id).max_durability
	return sum / run.codex.cards.size()


## Следующий остров: гавань при износе, лавка при запасе Пергамента, элита при сильном Кодексе, иначе бой.
static func choose_node(db: DefsDB, run: RunState, rng: RandomNumberGenerator) -> int:
	var options := MapActions.reachable(run)
	var score := func(id: int) -> float:
		var n := run.map.node(id)
		match n.type:
			MapState.NodeType.RIFT:
				return 100.0
			MapState.NodeType.HAVEN:
				return 10.0 if durability_ratio(db, run) < LOW_DURABILITY else 3.0
			MapState.NodeType.SHOP:
				return 8.0 if run.resources[RunState.PARCHMENT] >= SHOP_PARCHMENT else 2.0
			MapState.NodeType.ELITE:
				return 7.0 if run.codex.unit_indices(db).size() >= ELITE_MIN_UNITS else 0.5
			MapState.NodeType.BATTLE:
				return 5.0
			MapState.NodeType.EVENT:
				return 4.0
			MapState.NodeType.RELIQUARY:
				return 6.0
		return 1.0
	var best := options[0]
	var best_score := -1.0
	for id in options:
		var s: float = score.call(id) + rng.randf() * 0.5
		if s > best_score:
			best_score = s
			best = id
	return best


## Реликварий: первая предложенная реликвия, если её цену можно заплатить.
static func reliquary(db: DefsDB, run: RunState, node_id: int) -> void:
	var offer := RelicOps.offer(db, run, node_id)
	if not offer.is_empty():
		RelicOps.take(db, run, offer[0], run.node_seed(node_id, "relic_cost"))


static func shop(db: DefsDB, run: RunState, visit: ShopOps.Visit) -> void:
	for i in visit.offer.size():
		if db.memory(visit.offer[i]).is_unit():
			ShopOps.buy(db, run, visit, i)
	# Ремонт самых изношенных карт.
	var order := range(run.codex.cards.size())
	order.sort_custom(func(a: int, b: int) -> bool: return run.codex.cards[a].durability < run.codex.cards[b].durability)
	for i: int in order:
		while ShopOps.repair(db, run, i):
			pass
	for s in run.hero.spells.size():
		if run.resources[RunState.AETHER] > 2:
			ShopOps.recharge(run, s)


static func haven(db: DefsDB, run: RunState) -> void:
	if ShopOps.haven_repairs(db, run) > 0 and (durability_ratio(db, run) < 0.8 or run.hero.spells.is_empty()):
		ShopOps.haven_repair_all(db, run)
	elif not run.hero.spells.is_empty():
		ShopOps.haven_meditate(run)


## Случайный доступный вариант события; карта для needs_card — случайная карта отряда.
static func event(db: DefsDB, run: RunState, node_id: int, rng: RandomNumberGenerator) -> EventResolver.Result:
	var ev := db.event(run.map.node(node_id).content)
	var options: Array[int] = []
	for i in ev.options.size():
		if EventResolver.option_reason(db, run, ev.options[i]) == "":
			options.append(i)
	var pick := options[rng.randi_range(0, options.size() - 1)]
	var card := -1
	if (ev.options[pick] as EventOptionDef).needs_card:
		var units := run.codex.unit_indices(db)
		card = units[rng.randi_range(0, units.size() - 1)]
	return EventResolver.apply(db, run, node_id, ev, pick, card)


## После боя: 50% взять карту, иначе случайное превращение (не трогая последние 2 карты отрядов).
static func post_battle(db: DefsDB, run: RunState, rng: RandomNumberGenerator, guarantee_hero: bool) -> String:
	var offer := run.roll_rewards(db, guarantee_hero)
	if rng.randf() < 0.5 and not run.codex.is_full():
		run.codex.add(db, offer[rng.randi_range(0, offer.size() - 1)])
		return "card"
	var options: Array = []
	for i in run.codex.cards.size():
		for form in CodexOps.ALL_FORMS:
			if CodexOps.can_apply(db, run, i, form):
				options.append([i, form])
	if options.is_empty() or run.codex.unit_indices(db).size() <= 2:
		if not run.codex.is_full():
			run.codex.add(db, offer[0])
			return "card"
		return "skip"
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	CodexOps.apply(db, run, pick[0], pick[1])
	return CodexOps.Form.keys()[pick[1]].to_lower()
