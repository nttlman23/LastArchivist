class_name ShopOps
extends RefCounted
## Архив-лавка и Тихая гавань (SPEC_SPRINT3 5.1–5.2).

const CARD_PRICE := 3
const HERO_CARD_PRICE := 6
const REPAIR_COST := 1
const RECHARGE_COST := 1
const REWORK_COST := 2
const OFFER_SIZE := 3

enum HavenChoice { REPAIR_ALL, REWRITE, MEDITATE }


## Визит в лавку: предложение и что уже сделано.
class Visit:
	var offer: Array[StringName] = []
	var bought: Array[bool] = []
	var rework_used := false


static func open(db: DefsDB, run: RunState, node_id: int) -> Visit:
	var v := Visit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node_id, "shop")
	var pool := run.pool_unique()
	for i in mini(offer_size(run), pool.size()):
		var idx := rng.randi_range(0, pool.size() - 1)
		v.offer.append(pool[idx])
		v.bought.append(false)
		pool.remove_at(idx)
	return v


## Товаров в лавке: +1 с «Сундуком с двойным дном».
static func offer_size(run: RunState) -> int:
	return OFFER_SIZE + (1 if run.relics.has(RelicOps.CHEST) else 0)


## Цена карты: «Скидка у знакомых» −1 (не ниже 1), Испытание 8 +1.
static func price(db: DefsDB, memory_id: StringName, run: RunState = null) -> int:
	return adjust_price(run, CARD_PRICE if db.memory(memory_id).is_unit() else HERO_CARD_PRICE)


static func adjust_price(run: RunState, base: int) -> int:
	var p := base
	if MetaUpgrades.has(run, MetaUpgrades.DISCOUNT):
		p = maxi(1, p - 1)
	if Trials.has(run, Trials.PRICES):
		p += 1
	return p


## Ключ причины, почему нельзя купить, или "".
static func buy_reason(db: DefsDB, run: RunState, visit: Visit, index: int) -> String:
	if visit.bought[index]:
		return "REASON_SOLD"
	if run.codex.is_full():
		return "REASON_CODEX_FULL"
	if not run.can_afford(RunState.PARCHMENT, price(db, visit.offer[index], run)):
		return "REASON_NO_PARCHMENT"
	return ""


static func buy(db: DefsDB, run: RunState, visit: Visit, index: int) -> bool:
	if buy_reason(db, run, visit, index) != "":
		return false
	run.spend(RunState.PARCHMENT, price(db, visit.offer[index], run))
	run.gain_card(db, visit.offer[index])
	visit.bought[index] = true
	return true


## Цена ремонта с учётом реликвий и Испытания 3.
static func repair_cost(run: RunState) -> int:
	return REPAIR_COST * RelicOps.repair_multiplier(run) + (1 if Trials.has(run, Trials.REPAIR) else 0)


## Цена переработки: первая в акте бесплатна с «Опытным переписчиком».
static func rework_cost(run: RunState) -> int:
	if MetaUpgrades.has(run, MetaUpgrades.COPYIST) and run.free_rework_act != run.act:
		return 0
	return REWORK_COST


static func repair_reason(db: DefsDB, run: RunState, card_index: int) -> String:
	var card := run.codex.cards[card_index]
	if card.durability >= db.memory(card.memory_id).max_durability:
		return "REASON_FULL_DURABILITY"
	if not run.can_afford(RunState.INK, repair_cost(run)):
		return "REASON_NO_INK"
	return ""


static func repair(db: DefsDB, run: RunState, card_index: int) -> bool:
	if repair_reason(db, run, card_index) != "":
		return false
	run.spend(RunState.INK, repair_cost(run))
	run.codex.cards[card_index].durability += 1
	return true


static func recharge_reason(run: RunState, slot: int) -> String:
	if slot >= run.hero.spells.size():
		return "REASON_NO_SPELLS"
	if not run.can_afford(RunState.AETHER, RECHARGE_COST):
		return "REASON_NO_AETHER"
	return ""


static func recharge(run: RunState, slot: int) -> bool:
	if recharge_reason(run, slot) != "":
		return false
	run.spend(RunState.AETHER, RECHARGE_COST)
	run.hero.spells[slot].charges += 1
	return true


static func rework_reason(db: DefsDB, run: RunState, visit: Visit, card_index: int, form: CodexOps.Form) -> String:
	if visit.rework_used:
		return "REASON_REWORK_USED"
	if not run.can_afford(RunState.PARCHMENT, rework_cost(run)):
		return "REASON_NO_PARCHMENT"
	return CodexOps.unavailable_reason(db, run, card_index, form)


static func rework(db: DefsDB, run: RunState, visit: Visit, card_index: int, form: CodexOps.Form) -> bool:
	if rework_reason(db, run, visit, card_index, form) != "":
		return false
	var cost := rework_cost(run)
	if cost == 0:
		run.free_rework_act = run.act
	run.spend(RunState.PARCHMENT, cost)
	CodexOps.apply(db, run, card_index, form)
	visit.rework_used = true
	return true


# --- Тихая гавань --------------------------------------------------------------

## Сколько карт починит «Починить» (не на максимуме).
static func haven_repairs(db: DefsDB, run: RunState) -> int:
	var n := 0
	for c in run.codex.cards:
		if c.durability < db.memory(c.memory_id).max_durability:
			n += 1
	return n


## Сколько прочности чинит «Починить»: +2 с «Крепким переплётом».
static func haven_repair_amount(run: RunState) -> int:
	return MetaUpgrades.BINDING_REPAIR if MetaUpgrades.has(run, MetaUpgrades.BINDING) else 1


static func haven_repair_all(db: DefsDB, run: RunState) -> void:
	for c in run.codex.cards:
		c.durability = mini(db.memory(c.memory_id).max_durability, c.durability + haven_repair_amount(run))


static func haven_meditate(run: RunState) -> void:
	for s in run.hero.spells:
		s.charges += 1
