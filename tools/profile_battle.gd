extends Node
## Профилировщик боя: FPS и время кадра в покое и при движении мыши.
## Запуск: godot --path . res://tools/profile_battle.tscn (нужно окно, не --headless).

var screen: Node
var frames := 0
var frame_us_total := 0
var frame_us_max := 0
var last := 0
var hover_us_total := 0
var hover_calls := 0
var phase := "idle"


func _ready() -> void:
	Game.run = RunState.create(Game.defs, 1)
	Game.selected = [0, 1, 2, 3]
	MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])
	screen = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(3.0).timeout
	_reset("idle")
	await get_tree().create_timer(3.0).timeout
	_report()
	_reset("mouse")
	var view: BattleView = screen.view
	var origin := view.get_global_transform_with_canvas()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		var k := (Time.get_ticks_msec() - t0) / 3000.0
		var pos := origin * Vector2(900 * k, 300 + 200 * sin(k * 20))
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		ev.relative = Vector2(5, 5)
		# Реальная мышь шлёт несколько событий за кадр.
		for i in 4:
			get_viewport().warp_mouse(pos)
			var u0 := Time.get_ticks_usec()
			screen._update_hover()
			hover_us_total += Time.get_ticks_usec() - u0
			hover_calls += 1
		await get_tree().process_frame
	_report()
	print("hover avg us: %.0f over %d calls" % [float(hover_us_total) / maxi(1, hover_calls), hover_calls])
	get_tree().quit()


func _reset(p: String) -> void:
	phase = p
	frames = 0
	frame_us_total = 0
	frame_us_max = 0
	last = Time.get_ticks_usec()


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := now - last
	last = now
	frames += 1
	frame_us_total += dt
	frame_us_max = maxi(frame_us_max, dt)


func _report() -> void:
	print("[%s] fps=%d avg_frame_ms=%.2f max_frame_ms=%.2f process_ms=%.2f draw_calls=%d objects=%d nodes=%d" % [
		phase, Engine.get_frames_per_second(), frame_us_total / 1000.0 / maxi(1, frames), frame_us_max / 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
