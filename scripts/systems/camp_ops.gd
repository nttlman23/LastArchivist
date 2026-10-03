class_name CampOps
extends RefCounted
## Привал между актами (SPEC_SPRINT7 3): полный ремонт Кодекса или один из трёх даров —
## геройская карта, редкая карта отряда второго акта, пассивка на остаток забега.

const REPAIR := &"repair"
const HERO := &"hero"
const UNIT := &"unit"
const GIFT := &"gift"

const HERO_CARD := &"drowned_crown"
const UNIT_CARD := &"abyss_wardens"

## Дары-пассивки: действуют во всех боях до конца забега.
const GIFT_INITIATIVE := &"gift_initiative"
const GIFT_VIGOR := &"gift_vigor"
const GIFT_SPELLS := &"gift_spells"
const GIFTS: Array[StringName] = [GIFT_INITIATIVE, GIFT_VIGOR, GIFT_SPELLS]
const INITIATIVE_BONUS := 1
const VIGOR_SHARE := 0.15
const SPELL_CHARGES := 1


## Варианты привала: [{"kind", "id"}] — ремонт и три дара (пассивка выбирается по сиду забега).
static func options(run: RunState) -> Array[Dictionary]:
	var gift := GIFTS[absi(hash("camp:%d" % run.run_seed)) % GIFTS.size()]
	return [
		{"kind": REPAIR, "id": &""},
		{"kind": HERO, "id": HERO_CARD},
		{"kind": UNIT, "id": UNIT_CARD},
		{"kind": GIFT, "id": gift},
	]


## Почему вариант недоступен (ключ перевода) или "".
static func reason(db: DefsDB, run: RunState, option: Dictionary) -> String:
	match option["kind"]:
		REPAIR:
			for card in run.codex.cards:
				if card.durability < db.memory(card.memory_id).max_durability:
					return ""
			return "CAMP_REASON_NOTHING_TO_REPAIR"
		HERO, UNIT:
			return "CAMP_REASON_CODEX_FULL" if run.codex.is_full() else ""
	return ""


static func apply(db: DefsDB, run: RunState, option: Dictionary) -> void:
	match option["kind"]:
		REPAIR:
			for card in run.codex.cards:
				card.durability = db.memory(card.memory_id).max_durability
		HERO, UNIT:
			run.gain_card(db, option["id"])
		GIFT:
			run.gifts.append(option["id"])
			if option["id"] == GIFT_SPELLS:
				for slot in run.hero.spells:
					slot.charges += SPELL_CHARGES


## Пассивки даров в бою — для стеков игрока (кроме объектов цели).
static func apply_gifts(run: RunState, state: BattleState) -> void:
	for u in state.alive(UnitState.Side.PLAYER):
		if u.inert:
			continue
		if run.gifts.has(GIFT_INITIATIVE):
			u.initiative += INITIATIVE_BONUS
		if run.gifts.has(GIFT_VIGOR):
			var bonus := ceili(u.hp * VIGOR_SHARE)
			u.hp += bonus
			u.top_hp += bonus
