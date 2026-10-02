class_name EventDef
extends Resource
## Событие на острове карты: текст и варианты выбора.

@export var id: StringName
@export var title_key: String
@export var text_key: String
## Массив EventOptionDef.
@export var options: Array = []
