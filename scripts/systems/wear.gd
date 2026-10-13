class_name Wear
extends RefCounted
## Износ карт от потерь в бою (SPEC_SPRINT12 2): чем больше существ стека погибло, тем сильнее угасает
## карта. Меньше 10 % — карта цела, до половины — −1 прочности, больше — −2; стек погиб целиком — −2 и карта
## «надломлена» (прочность не выше 1 до ремонта). Геройские карты — как раньше, −1 после победы.

const LIGHT := 0.1
const HEAVY := 0.5
const WIPED_WEAR := 2


## Износ по стартовой и итоговой численности стека.
static func amount(start: int, left: int) -> int:
	if start <= 0:
		return 0
	if left <= 0:
		return WIPED_WEAR
	var lost := float(start - left) / start
	if lost < LIGHT - 0.0001:
		return 0
	if lost <= HEAVY + 0.0001:
		return 1
	return 2


## Сколько существ ещё может погибнуть, пока износ не вырастет (для подсказок в бою); 0 — следующая потеря
## уже повысит износ, -1 — выше уже некуда.
static func free_losses(start: int, left: int) -> int:
	var now := amount(start, left)
	if now >= WIPED_WEAR:
		return -1
	var n := 0
	while left - n - 1 >= 0 and amount(start, left - n - 1) == now:
		n += 1
	return n


## Итоги законченного боя по картам: индекс карты -> {start, left, wear, wiped}. Иллюзии и призванные
## (без карты) не считаются; у стека, поднятого лечением, потери меньше.
static func from_battle(state: BattleState) -> Dictionary:
	var result := {}
	for u in state.units:
		if u.side != UnitState.Side.PLAYER or u.card_index < 0 or u.illusion or u.inert:
			continue
		var left := u.count if u.is_alive() else 0
		result[u.card_index] = {"start": u.start_count, "left": left, "wear": amount(u.start_count, left), "wiped": left <= 0}
	return result
