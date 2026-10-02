class_name HeroState
extends RefCounted
## Архивариус: улучшения армии и заклинания, накопленные за забег.


class SpellSlot:
	var spell_id: StringName
	var charges: int
	## Из какой карты получено — для подписи в UI.
	var source_memory_id: StringName

	func _init(id: StringName = &"", p_charges: int = 0, source: StringName = &"") -> void:
		spell_id = id
		charges = p_charges
		source_memory_id = source


var upgrades: Array[StringName] = []
var spells: Array[SpellSlot] = []


## Приказы: базовые плюс открытые геройскими картами Кодекса.
func available_orders(db: DefsDB, codex: CodexState) -> Array[StringName]:
	var result := db.base_orders.duplicate()
	for card in codex.cards:
		var mem := db.memory(card.memory_id)
		if not mem.is_unit() and mem.order_id != &"" and not result.has(mem.order_id):
			result.append(mem.order_id)
	return result


## Все действующие улучшения: полученные и пассивные от геройских карт.
func active_upgrades(db: DefsDB, codex: CodexState) -> Array[StringName]:
	var result := upgrades.duplicate()
	for card in codex.cards:
		var mem := db.memory(card.memory_id)
		if not mem.is_unit() and mem.passive_upgrade_id != &"":
			result.append(mem.passive_upgrade_id)
	return result


## Применяет улучшения к стеку игрока при создании боя.
static func apply_upgrades(db: DefsDB, ids: Array[StringName], u: UnitState) -> void:
	for id in ids:
		var up := db.upgrade(id)
		if up.ranged_only and not u.is_ranged:
			continue
		match up.stat:
			&"attack":
				u.attack += up.amount
			&"defense":
				u.defense += up.amount
			&"initiative":
				u.initiative += up.amount
			&"speed":
				u.speed += up.amount
			&"shots":
				u.shots_left += up.amount
			&"hp_pct":
				var bonus := maxi(1, u.hp * up.amount / 100)
				u.hp += bonus
				u.top_hp += bonus


func to_dict() -> Dictionary:
	var sp: Array = []
	for s in spells:
		sp.append({"spell_id": String(s.spell_id), "charges": s.charges, "source": String(s.source_memory_id)})
	var ups: Array = []
	for id in upgrades:
		ups.append(String(id))
	return {"upgrades": ups, "spells": sp}


static func from_dict(d: Dictionary) -> HeroState:
	var h := HeroState.new()
	for id: String in d["upgrades"]:
		h.upgrades.append(StringName(id))
	for s: Dictionary in d["spells"]:
		h.spells.append(SpellSlot.new(StringName(s["spell_id"]), int(s["charges"]), StringName(s["source"])))
	return h
