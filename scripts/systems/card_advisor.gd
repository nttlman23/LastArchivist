class_name CardAdvisor
extends RefCounted
## Подсказки для решений (SPEC_SPRINT5 4–5): роль карты, какую дыру Кодекса она закрывает,
## сила армии и риск боя. Только читает данные; ничего не меняет.

enum Role { MELEE, RANGED, SUPPORT, FLYER, HERO }
enum Risk { LOW, EVEN, HIGH }

## Способности, делающие отряд поддержкой.
const SUPPORT_ABILITIES: Array[StringName] = [&"restore", &"tinker", &"reflect", &"flood", &"cover", &"echo"]
## Пороги риска: сила врага / сила армии. Подобраны по стартовым Кодексам школ:
## обычные бои уровня 1 — ниже, элита и сильные шаблоны — выше. Способности и герой
## игрока в силу не входят, поэтому пороги ниже единицы.
const RISK_LOW := 0.5
const RISK_HIGH := 0.7
## Множители силы для стрелков и летунов.
const RANGED_POWER := 1.3
const FLYER_POWER := 1.1


static func role_of_unit(def: UnitDef) -> Role:
	if def.is_ranged:
		return Role.RANGED
	if SUPPORT_ABILITIES.has(def.ability_id):
		return Role.SUPPORT
	if def.is_flying:
		return Role.FLYER
	return Role.MELEE


static func role(db: DefsDB, memory_id: StringName) -> Role:
	var mem := db.memory(memory_id)
	if not mem.is_unit():
		return Role.HERO
	return role_of_unit(db.unit(mem.unit_id))


## Роли, которые уже есть среди годных карт Кодекса.
static func codex_roles(db: DefsDB, codex: CodexState) -> Dictionary[Role, int]:
	var result: Dictionary[Role, int] = {}
	for card in codex.cards:
		if card.durability > 0:
			var r := role(db, card.memory_id)
			result[r] = result.get(r, 0) + 1
	return result


## Почему стоит взять карту: [[значок, короткий текст, ключ подсказки]]. Первая — роль.
static func reasons(db: DefsDB, codex: CodexState, memory_id: StringName) -> Array:
	var r := role(db, memory_id)
	var have := codex_roles(db, codex)
	var list: Array = [[ROLE_ICONS[r], TranslationServer.translate(ROLE_KEYS[r]), ROLE_KEYS[r] + "_TIP"]]
	if r != Role.HERO and not have.has(r):
		list.append([UnitGlyphs.ICON_ORDER, TranslationServer.translate("ADVICE_GAP") % TranslationServer.translate(ROLE_KEYS[r]).to_lower(), "ADVICE_GAP_TIP"])
	if r != Role.HERO and codex.unit_indices(db).size() < 4:
		list.append([UnitGlyphs.ICON_HP, TranslationServer.translate("ADVICE_MORE_UNITS"), "ADVICE_MORE_UNITS_TIP"])
	for card in codex.cards:
		if card.memory_id == memory_id:
			list.append([UnitGlyphs.ICON_RETALIATION, TranslationServer.translate("ADVICE_FUSE"), "ADVICE_FUSE_TIP"])
			break
	return list


## Похожая карта Кодекса (та же роль) с наибольшей силой: индекс или -1.
static func similar_card(db: DefsDB, codex: CodexState, memory_id: StringName) -> int:
	var r := role(db, memory_id)
	var best := -1
	var best_power := -1.0
	for i in codex.cards.size():
		var card := codex.cards[i]
		if role(db, card.memory_id) != r or not db.memory(card.memory_id).is_unit():
			continue
		var p := card_power(db, card.memory_id, card.level)
		if p > best_power:
			best_power = p
			best = i
	return best


# --- Сила и риск -------------------------------------------------------------------

## Боевая сила стека: численность × √(живучесть × урон) — так сила складывается по стекам.
static func stack_power(def: UnitDef, count: int) -> float:
	var hp_eff := def.hp * (1.0 + 0.05 * def.defense)
	var dmg_eff := (def.dmg_min + def.dmg_max) * 0.5 * (1.0 + 0.05 * def.attack)
	if def.is_ranged:
		dmg_eff *= RANGED_POWER
	if def.is_flying:
		dmg_eff *= FLYER_POWER
	return count * sqrt(hp_eff * dmg_eff)


static func card_power(db: DefsDB, memory_id: StringName, level: int = 1) -> float:
	var mem := db.memory(memory_id)
	if not mem.is_unit():
		return 0.0
	return stack_power(db.unit(mem.unit_id), floori(mem.count * (1.0 + 0.5 * (level - 1))))


## Сила армии: лучшие годные карты отрядов, сколько влезает в бой.
static func army_power(db: DefsDB, codex: CodexState) -> float:
	var powers: Array[float] = []
	for card in codex.cards:
		if card.durability > 0:
			var p := card_power(db, card.memory_id, card.level)
			if p > 0.0:
				powers.append(p)
	powers.sort()
	powers.reverse()
	var total := 0.0
	for i in mini(powers.size(), BattleState.MAX_STACKS):
		total += powers[i]
	return total


static func encounter_power(db: DefsDB, enc: EncounterDef) -> float:
	var total := 0.0
	for i in mini(enc.unit_ids.size(), BattleState.MAX_STACKS):
		total += stack_power(db.unit(enc.unit_ids[i]), enc.counts[i])
	return total


static func risk(db: DefsDB, codex: CodexState, enc: EncounterDef) -> Risk:
	var r := risk_of_power(db, codex, encounter_power(db, enc))
	# Разлом опаснее состава: стирание карт и особые правила — на уровень выше.
	if enc.boss:
		r = mini(r + 1, Risk.HIGH) as Risk
	return r


## Средняя сила встреч уровня tier (элитных или обычных) — для неразведанных островов.
static func expected_power(db: DefsDB, tier: int, elite: bool) -> float:
	var total := 0.0
	var n := 0
	for id in db.encounters:
		var e := db.encounters[id]
		if not e.boss and e.elite == elite and (elite or e.tier == tier):
			total += encounter_power(db, e)
			n += 1
	return total / n if n > 0 else 0.0


## Риск острова с боем: разведанный — по составу, иначе — по среднему уровня. Не бой — -1.
static func node_risk(db: DefsDB, run: RunState, n: MapState.MapNode) -> int:
	if not n.is_battle() or n.content == &"":
		return -1
	var enc := db.encounter(n.content)
	if n.scouted or enc.boss:
		return risk(db, run.codex, enc)
	return risk_of_power(db, run.codex, expected_power(db, enc.tier, enc.elite))


static func risk_of_power(db: DefsDB, codex: CodexState, power: float) -> Risk:
	var army := army_power(db, codex)
	if army <= 0.0:
		return Risk.HIGH
	var ratio := power / army
	if ratio < RISK_LOW:
		return Risk.LOW
	if ratio > RISK_HIGH:
		return Risk.HIGH
	return Risk.EVEN


const ROLE_ICONS := {
	Role.MELEE: UnitGlyphs.ICON_MELEE,
	Role.RANGED: UnitGlyphs.ICON_RANGED,
	Role.SUPPORT: UnitGlyphs.ICON_HEAL,
	Role.FLYER: UnitGlyphs.ICON_FLYING,
	Role.HERO: UnitGlyphs.ICON_SPELL,
}
const ROLE_KEYS := {
	Role.MELEE: "ROLE_MELEE",
	Role.RANGED: "ROLE_RANGED",
	Role.SUPPORT: "ROLE_SUPPORT",
	Role.FLYER: "ROLE_FLYER",
	Role.HERO: "ROLE_HERO",
}
const RISK_KEYS := {Risk.LOW: "RISK_LOW", Risk.EVEN: "RISK_EVEN", Risk.HIGH: "RISK_HIGH"}
const RISK_COLORS := {Risk.LOW: Color(0.45, 0.85, 0.5), Risk.EVEN: Color(0.95, 0.8, 0.35), Risk.HIGH: Color(1.0, 0.4, 0.35)}
