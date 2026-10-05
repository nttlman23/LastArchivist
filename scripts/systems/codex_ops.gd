class_name CodexOps
extends RefCounted
## Превращения карт после победы (SPEC_SPRINT2 3.4–3.6).

enum Form { SPELL, UPGRADE, SACRIFICE, FUSE }

const ALL_FORMS: Array[Form] = [Form.SPELL, Form.UPGRADE, Form.SACRIFICE, Form.FUSE]


## Ключ перевода причины, по которой форма недоступна, или "" если доступна.
static func unavailable_reason(db: DefsDB, run: RunState, index: int, form: Form) -> String:
	var card := run.codex.cards[index]
	var mem := db.memory(card.memory_id)
	if not mem.is_unit():
		return "REASON_HERO_CARD"
	match form:
		Form.SPELL:
			if mem.spell_id == &"":
				return "REASON_NO_SPELL"
		Form.UPGRADE:
			if mem.upgrade_id == &"":
				return "REASON_NO_UPGRADE"
		Form.SACRIFICE:
			if sacrifice_repairs(db, run.codex, index) == 0:
				return "REASON_NOTHING_TO_REPAIR"
		Form.FUSE:
			if card.level >= CodexState.MAX_LEVEL:
				return "REASON_MAX_LEVEL"
			if fuse_partner(run.codex, index) < 0:
				return "REASON_NO_PAIR"
	return ""


static func can_apply(db: DefsDB, run: RunState, index: int, form: Form) -> bool:
	return unavailable_reason(db, run, index, form) == ""


## Пара для слияния: другая карта того же воспоминания с наибольшим уровнем, затем прочностью.
static func fuse_partner(codex: CodexState, index: int) -> int:
	var card := codex.cards[index]
	var best := -1
	for i in codex.cards.size():
		var other := codex.cards[i]
		if i == index or other.memory_id != card.memory_id or other.level >= CodexState.MAX_LEVEL:
			continue
		if best < 0 or other.level > codex.cards[best].level \
				or (other.level == codex.cards[best].level and other.durability > codex.cards[best].durability):
			best = i
	return best


## Число зарядов заклинания, которое даст карта.
static func spell_charges(card: CodexState.Card) -> int:
	return maxi(1, card.durability)


## Результат слияния: [уровень, прочность].
static func fuse_result(codex: CodexState, index: int) -> Array[int]:
	var a := codex.cards[index]
	var b := codex.cards[fuse_partner(codex, index)]
	return [mini(CodexState.MAX_LEVEL, maxi(a.level, b.level) + 1), maxi(a.durability, b.durability)]


## Сколько карт получит +1 прочности при жертве (не на максимуме).
static func sacrifice_repairs(db: DefsDB, codex: CodexState, index: int) -> int:
	var n := 0
	for i in codex.cards.size():
		var c := codex.cards[i]
		if i != index and c.durability < db.memory(c.memory_id).max_durability:
			n += 1
	return n


static func apply(db: DefsDB, run: RunState, index: int, form: Form) -> void:
	assert(can_apply(db, run, index, form))
	var codex := run.codex
	var card := codex.cards[index]
	var mem := db.memory(card.memory_id)
	# Способы переработки за забег — для достижения «Алхимик памяти» (SPEC_SPRINT9 6).
	var form_id := StringName(String(Form.keys()[form]).to_lower())
	if not run.reworks.has(form_id):
		run.reworks.append(form_id)
	match form:
		Form.SPELL:
			var charges := spell_charges(card)
			if DailyRun.has(run, DailyRun.FULL_INKWELLS) and not run.inkwell_used:
				charges += DailyRun.INKWELL_CHARGES
				run.inkwell_used = true
			run.hero.spells.append(HeroState.SpellSlot.new(mem.spell_id, charges, mem.id))
			codex.remove_at(index)
		Form.UPGRADE:
			run.hero.upgrades.append(mem.upgrade_id)
			codex.remove_at(index)
		Form.SACRIFICE:
			codex.remove_at(index)
			for c in codex.cards:
				c.durability = mini(db.memory(c.memory_id).max_durability, c.durability + 1)
		Form.FUSE:
			var partner := fuse_partner(codex, index)
			var result := fuse_result(codex, index)
			var keep := mini(index, partner)
			codex.cards[keep].level = result[0]
			codex.cards[keep].durability = result[1]
			codex.remove_at(maxi(index, partner))
