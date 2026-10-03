class_name EventEffect
extends Resource
## Один эффект варианта события (SPEC_SPRINT3 5.3).

enum Kind {
	RESOURCE,            ## resource ± amount
	DURABILITY_CHOSEN,   ## выбранной карте ± amount (не выше максимума)
	DURABILITY_RANDOM,   ## count случайным картам ± amount
	DURABILITY_STRONGEST,  ## самой прочной карте ± amount
	ADD_CARD,            ## карта memory_id (пусто — случайная) × count с прочностью durability (0 — максимум)
	REMOVE_CHOSEN,       ## убрать выбранную карту
	SPELL_CHARGES_ALL,   ## всем заклинаниям ± amount
	UPGRADE_RANDOM,      ## случайное улучшение героя
	BATTLE,              ## бой уровня tier; после победы — карта memory_id (если задана)
	RELIC,               ## случайная реликвия, которой ещё нет (SPEC_SPRINT7 12)
}

@export var kind: Kind = Kind.RESOURCE
@export var resource: StringName
@export var amount: int = 0
@export var count: int = 1
@export var memory_id: StringName
@export var durability: int = 0
@export var tier: int = 1
