class_name Story
extends RefCounted
## Метасюжет (SPEC_SPRINT10 2–7): главы, страницы памяти, сценки, реплики врагов, сюжетные события.
## Сюжет на бой не влияет; прогресс — в ProfileState.story_*. Повторная попытка ежедневного забега
## историю не двигает (как достижения).

## События забега, на которых проверяются условия страниц.
enum Event { RIFT_CLOSED, BATTLE_WON, RUN_WON, RELIC, HAVEN, CARD_FADED, STORY_EVENT, DAILY, BOSS_PHASE2, CHAPTER }

const MAX_CHAPTER := 4
## Истинный финал (глава IV): столько полных побед и все страницы глав I–III.
const TRUE_ENDING_WINS := 3

# Условия страниц.
const RIFT_CLOSED := &"rift_closed"
const ELITE_WON := &"elite_won"
const COMMANDER_WON := &"commander_won"
const STORY_EVENT := &"story_event"
const HAVEN := &"haven"
const CARD_FADED := &"card_faded"
const ACT2_BATTLE := &"act2_battle"
const RELIC := &"relic"
const BOSS_PHASE2 := &"boss_phase2"
const ELITE2_WON := &"elite2_won"
const RUN_WON := &"run_won"
const SCHOOLS_WON := &"schools_won"
const DAILY_COUNTED := &"daily_counted"
const RIFT_HARD := &"rift_hard"
const CHAPTER_OPEN := &"chapter_open"

const EVENTS := {
	RIFT_CLOSED: [Event.RIFT_CLOSED],
	ELITE_WON: [Event.BATTLE_WON],
	COMMANDER_WON: [Event.BATTLE_WON],
	STORY_EVENT: [Event.STORY_EVENT],
	HAVEN: [Event.HAVEN],
	CARD_FADED: [Event.CARD_FADED],
	ACT2_BATTLE: [Event.BATTLE_WON],
	RELIC: [Event.RELIC],
	BOSS_PHASE2: [Event.BOSS_PHASE2],
	ELITE2_WON: [Event.BATTLE_WON],
	RUN_WON: [Event.RUN_WON],
	SCHOOLS_WON: [Event.RUN_WON],
	DAILY_COUNTED: [Event.DAILY],
	RIFT_HARD: [Event.RIFT_CLOSED],
	CHAPTER_OPEN: [Event.CHAPTER],
}

# Сценки (SPEC_SPRINT10 4): текст — ключи SCENE_<ID>_1…N.
const PROLOGUE := &"prologue"
const TRUE_FINALE := &"true_finale"
const SCENES: Array[StringName] = [&"prologue", &"chapter_2", &"chapter_3", &"chapter_4", &"rift_1", &"rift_2", &"rift_3", &"rift_4",
		&"finale_2", &"finale_3", &"true_finale"]
## Реплики (SPEC_SPRINT10 5): ключи LINE_<ГОВОРЯЩИЙ>_<ГЛАВА>_<N>; смена фазы босса — говорящий abyss_lord_phase.
const PHASE_SPEAKER := &"abyss_lord_phase"
const MAX_LINES := 3

## Последняя реплика каждого говорящего — повторы не подряд.
static var _last_line: Dictionary = {}


## Проверяет страницы события event и продвигает главу. Возвращает {"pages": Array[StringName], "chapter": новая глава или 0}.
## ctx — подробности: для боя — Achievements.battle_context (+ "commander"), для сюжетного события — {"event": id}.
static func on_event(db: DefsDB, profile: ProfileState, run: RunState, event: Event, ctx: Dictionary = {}) -> Dictionary:
	var result := {"pages": [] as Array[StringName], "chapter": 0}
	if profile == null or not counts(run):
		return result
	_check_pages(db, profile, run, event, ctx, result)
	_advance(db, profile, run, event, ctx, result)
	return result


## Повторная попытка ежедневного забега историю не двигает.
static func counts(run: RunState) -> bool:
	return Achievements.counts(run)


static func _check_pages(db: DefsDB, profile: ProfileState, run: RunState, event: Event, ctx: Dictionary, result: Dictionary) -> void:
	for p in db.pages_sorted():
		if p.chapter > profile.story_chapter or profile.story_pages.has(p.id) or not EVENTS.get(p.condition, []).has(event):
			continue
		if _met(profile, run, p, ctx):
			profile.story_pages[p.id] = Achievements.today()
			result["pages"].append(p.id)


## Главы: I → II при закрытии Разлома, → III при первой полной победе, → IV — 3 победы и все страницы I–III.
static func _advance(db: DefsDB, profile: ProfileState, run: RunState, event: Event, ctx: Dictionary, result: Dictionary) -> void:
	var next := profile.story_chapter
	if next == 1 and event == Event.RIFT_CLOSED:
		next = 2
	if next <= 2 and event == Event.RUN_WON:
		next = 3
	if next == 3 and profile.wins >= TRUE_ENDING_WINS and pages_done(db, profile, 3):
		next = 4
	if next == profile.story_chapter:
		return
	profile.story_chapter = next
	result["chapter"] = next
	# То же событие — уже в новой главе (первая победа даёт страницу главы III). Глава IV — только за дела в ней.
	if next < MAX_CHAPTER:
		_check_pages(db, profile, run, event, ctx, result)
	_check_pages(db, profile, run, Event.CHAPTER, {}, result)


## Найдены ли все страницы глав 1…up_to.
static func pages_done(db: DefsDB, profile: ProfileState, up_to: int) -> bool:
	for p in db.pages.values():
		if p.chapter <= up_to and not profile.story_pages.has(p.id):
			return false
	return true


static func _met(profile: ProfileState, run: RunState, p: PageDef, ctx: Dictionary) -> bool:
	match p.condition:
		ELITE_WON:
			return bool(ctx.get("elite", false))
		COMMANDER_WON:
			return bool(ctx.get("commander", false))
		ACT2_BATTLE:
			return int(ctx.get("act", 1)) >= 2
		ELITE2_WON:
			return bool(ctx.get("elite", false)) and int(ctx.get("act", 1)) >= 2
		STORY_EVENT:
			return StringName(ctx.get("event", &"")) == p.arg
		SCHOOLS_WON:
			var n := 0
			for id in profile.school_stats:
				if int(profile.school_stats[id].get("wins", 0)) > 0:
					n += 1
			return n >= p.count
		RIFT_HARD:
			return run != null and run.difficulty == Difficulty.HARD
	# Условия-события без подробностей: закрыт Разлом, победа, реликвия, гавань, угасание, вторая фаза, день, глава.
	return true


# --- Сценки ---------------------------------------------------------------------------------

## Сценка, которую пора показать (ещё не просмотренная); trigger — start, rift, win. &"" — нет.
## Для rift и win вызывается ДО продвижения главы этим событием: сценка — о главе, в которой оно случилось.
static func pending_scene(profile: ProfileState, trigger: StringName, run: RunState = null) -> StringName:
	if profile == null or not counts(run):
		return &""
	var ch := profile.story_chapter
	var id := &""
	match trigger:
		&"start":
			id = StringName("chapter_%d" % ch) if ch >= 2 else &""
		&"rift":
			id = StringName("rift_%d" % ch)
		&"win":
			id = TRUE_FINALE if ch >= MAX_CHAPTER else StringName("finale_%d" % maxi(2, ch))
	if id == &"" or profile.story_seen.has(id):
		return &""
	return id


static func mark_seen(profile: ProfileState, id: StringName) -> void:
	if not profile.story_seen.has(id):
		profile.story_seen.append(id)


## Абзацы сценки: ключи SCENE_<ID>_1…N, пока ключ есть в переводе.
static func paragraphs(id: StringName) -> Array[String]:
	var result: Array[String] = []
	for n in range(1, 10):
		var key := "SCENE_%s_%d" % [String(id).to_upper(), n]
		var text := TranslationServer.translate(key)
		if text == key:
			break
		result.append(text)
	return result


# --- Реплики --------------------------------------------------------------------------------

## Ключ реплики говорящего (командир, босс) в текущей главе или "" — если реплик нет.
static func line_key(profile: ProfileState, speaker: StringName, seed_value: int) -> String:
	var ch := profile.story_chapter if profile else 1
	var keys: Array[String] = []
	for n in range(1, MAX_LINES + 1):
		var key := "LINE_%s_%d_%d" % [String(speaker).to_upper(), ch, n]
		if TranslationServer.translate(key) != key:
			keys.append(key)
	if keys.is_empty():
		return ""
	var i := absi(seed_value) % keys.size()
	if keys.size() > 1 and keys[i] == _last_line.get(speaker, ""):
		i = (i + 1) % keys.size()
	_last_line[speaker] = keys[i]
	return keys[i]


# --- Сюжетные события -----------------------------------------------------------------------

## Ставит сюжетное событие на остров-событие текущего акта (не больше одного за забег): первое непройденное
## событие этого акта из открытых глав; остров — по сиду забега, со второго слоя.
static func place_event(db: DefsDB, run: RunState, profile: ProfileState) -> void:
	if profile == null or not counts(run) or run.story_event != &"":
		return
	var candidates: Array[EventDef] = []
	for e in db.story_events.values():
		if e.act == run.act and e.story_chapter <= profile.story_chapter and not profile.story_events.has(e.id):
			candidates.append(e)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: EventDef, b: EventDef) -> bool:
		return a.story_chapter < b.story_chapter if a.story_chapter != b.story_chapter else String(a.id) < String(b.id))
	var nodes: Array[MapState.MapNode] = []
	for n in run.map.nodes:
		if n.type == MapState.NodeType.EVENT and n.layer >= 2:
			nodes.append(n)
	if nodes.is_empty():
		return
	var node := nodes[absi(hash("story:%d:%d" % [run.run_seed, run.act])) % nodes.size()]
	node.content = candidates[0].id
	run.story_event = candidates[0].id


static func is_story_event(db: DefsDB, id: StringName) -> bool:
	return db.story_events.has(id)


# --- Тексты экранов -------------------------------------------------------------------------

static func chapter_name(ch: int) -> String:
	return TranslationServer.translate("STORY_CHAPTER_%d" % ch)


## Текст итога забега по главе chapter (полная победа — о Хозяине Глубин, а не о Разломе).
static func run_end_key(chapter: int, won: bool) -> String:
	var ch := chapter
	return ("RUN_WON_TEXT_%d" if won else "RUN_LOST_TEXT_%d") % clampi(ch, 1, MAX_CHAPTER)
