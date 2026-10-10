class_name PageDef
extends Resource
## Страница памяти (SPEC_SPRINT10 6): фрагмент истории, находится по условию в открытой главе.
## Условия проверяет Story по ключу.

@export var id: StringName
## Глава (1–4): страница доступна, когда глава открыта.
@export var chapter: int = 1
## Порядок внутри главы.
@export var order: int = 0
## Ключ условия (Story.COND_*), аргумент (id события) и порог.
@export var condition: StringName
@export var arg: StringName
@export var count: int = 0
