class_name Pathfinding
extends RefCounted
## Поиск пути по гекс-сетке. Препятствия и живые стеки непроходимы.
## Сетка мелкая (99 клеток), поэтому хватает BFS — A* не нужен.


class Result:
	var dist: Dictionary[Vector2i, int] = {}
	var prev: Dictionary[Vector2i, Vector2i] = {}

	func path_to(dest: Vector2i) -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		if not dist.has(dest):
			return path
		var cur := dest
		path.append(cur)
		while prev.has(cur):
			cur = prev[cur]
			path.append(cur)
		path.reverse()
		return path


## BFS от start; max_steps < 0 — без ограничения.
static func bfs(state: BattleState, start: Vector2i, max_steps: int = -1) -> Result:
	var res := Result.new()
	res.dist[start] = 0
	var frontier: Array[Vector2i] = [start]
	var head := 0
	while head < frontier.size():
		var cur := frontier[head]
		head += 1
		var d := res.dist[cur]
		if max_steps >= 0 and d >= max_steps:
			continue
		for n in state.grid.neighbors(cur):
			if res.dist.has(n) or not state.is_free(n):
				continue
			res.dist[n] = d + 1
			res.prev[n] = cur
			frontier.append(n)
	return res


## Клетки, куда стек может переместиться в этот ход (без стартовой), с расстоянием.
static func reachable(state: BattleState, u: UnitState) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	if u.is_flying:
		for h in state.grid.all_hexes():
			var d := HexGrid.distance(u.hex, h)
			if d > 0 and d <= u.move_speed() and state.is_free(h):
				result[h] = d
		return result
	var res := bfs(state, u.hex, u.move_speed())
	for h in res.dist:
		if h != u.hex:
			result[h] = res.dist[h]
	return result


## Путь для анимации перемещения (включая старт и финиш).
static func path(state: BattleState, u: UnitState, dest: Vector2i) -> Array[Vector2i]:
	if u.is_flying:
		return [u.hex, dest]
	return bfs(state, u.hex, u.move_speed()).path_to(dest)
