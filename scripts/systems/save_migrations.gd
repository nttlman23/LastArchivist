class_name SaveMigrations
extends RefCounted
## Миграция сохранений забега (SPEC_SPRINT6 13): цепочка vN → vN+1 до текущей версии.
## Версии ниже MIN_VERSION не читаются (до Спринта 6 формат не сохранял совместимость).

const MIN_VERSION := 5


## Переводит словарь сохранения в текущую версию; пустой словарь — версия не поддерживается.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < MIN_VERSION or v > RunState.SAVE_VERSION:
		return {}
	var out := d.duplicate(true)
	while v < RunState.SAVE_VERSION:
		match v:
			5:
				out = _v5_to_v6(out)
			6:
				out = _v6_to_v7(out)
			7:
				out = _v7_to_v8(out)
			8:
				out = _v8_to_v9(out)
		v += 1
		out["version"] = v
	return out


## v9: Зал Архива и Испытания (SPEC_SPRINT8) — старый забег без улучшений и Испытания.
static func _v8_to_v9(d: Dictionary) -> Dictionary:
	d["upgrades"] = []
	d["trial"] = 0
	d["reroll_act"] = 0
	d["free_rework_act"] = 0
	return d


## v8: реликвии — у старого забега их нет.
static func _v7_to_v8(d: Dictionary) -> Dictionary:
	d["relics"] = []
	return d


## v7: второй акт — забег из старого сохранения идёт в первом акте, даров нет.
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	d["act"] = 1
	d["at_camp"] = false
	d["gifts"] = []
	return d


## v6: счётчик потерянных карт (лучший Кодекс) — обязательное поле.
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	if not d.has("cards_lost"):
		d["cards_lost"] = 0
	return d
