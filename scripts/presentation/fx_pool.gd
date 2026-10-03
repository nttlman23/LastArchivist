class_name FxPool
extends Node2D
## Пул всплесков частиц (SPEC_SPRINT6 3): пепел, искры, лечение, магия, стекло.
## CPUParticles2D — без компиляции шейдеров частиц и без рывка на первом эффекте.
## Не больше MAX_EMITTERS одновременно; в упрощённом режиме частиц нет.

const MAX_EMITTERS := 12

const ASH := &"ash"
const SPARK := &"spark"
const HEAL := &"heal"
const MAGIC := &"magic"
const GLASS := &"glass"
const RIPPLE := &"ripple"

static var _dot: Texture2D

var _emitters: Array[CPUParticles2D] = []


## Мягкая круглая точка для всех частиц (рисуется один раз).
static func dot_texture() -> Texture2D:
	if _dot == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot


## Всплеск вида kind в точке pos; color — основной цвет (для магии и ряби).
## Возвращает false, если эффекты упрощены или все эмиттеры заняты.
func burst(kind: StringName, pos: Vector2, color: Color = Color.WHITE) -> bool:
	if not Settings.effects_full:
		return false
	var p := _free_emitter()
	if p == null:
		return false
	_configure(p, kind, color)
	p.position = pos
	p.restart()
	p.emitting = true
	return true


## Сколько эмиттеров сейчас работает (для тестов и профилировщика).
func active_count() -> int:
	var n := 0
	for p in _emitters:
		if p.emitting:
			n += 1
	return n


func _free_emitter() -> CPUParticles2D:
	for p in _emitters:
		if not p.emitting:
			return p
	if _emitters.size() >= MAX_EMITTERS:
		return null
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.texture = dot_texture()
	p.local_coords = false
	add_child(p)
	_emitters.append(p)
	return p


func _configure(p: CPUParticles2D, kind: StringName, color: Color) -> void:
	var speed := Settings.anim_speed
	p.speed_scale = speed
	p.explosiveness = 0.9
	p.randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.gravity = Vector2.ZERO
	p.direction = Vector2.UP
	p.spread = 180.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var ramp := Gradient.new()
	match kind:
		ASH:
			p.amount = 28
			p.lifetime = 1.1
			p.spread = 70.0
			p.emission_sphere_radius = 22.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 110.0
			p.gravity = Vector2(25, -30)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.6
			ramp.set_color(0, Color(0.55, 0.52, 0.5, 0.9))
			ramp.set_color(1, Color(0.25, 0.24, 0.24, 0.0))
		SPARK:
			p.amount = 14
			p.lifetime = 0.35
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 230.0
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.35
			ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
			ramp.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
		HEAL:
			p.amount = 16
			p.lifetime = 0.9
			p.spread = 25.0
			p.explosiveness = 0.5
			p.emission_sphere_radius = 24.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			ramp.set_color(0, Color(0.5, 1.0, 0.55, 0.95))
			ramp.set_color(1, Color(0.3, 0.9, 0.4, 0.0))
		MAGIC:
			p.amount = 22
			p.lifetime = 0.6
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 150.0
			ramp.set_color(0, Color(color.lightened(0.3), 1.0))
			ramp.set_color(1, Color(color, 0.0))
		GLASS:
			p.amount = 18
			p.lifetime = 0.7
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 170.0
			p.gravity = Vector2(0, 260)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.45
			ramp.set_color(0, Color(0.85, 0.92, 1.0, 1.0))
			ramp.set_color(1, Color(0.6, 0.7, 1.0, 0.0))
		RIPPLE:
			p.amount = 10
			p.lifetime = 0.8
			p.emission_sphere_radius = 30.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 20.0
			ramp.set_color(0, Color(color.lightened(0.4), 0.8))
			ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
