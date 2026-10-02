class_name HexGrid
extends RefCounted
## Геометрия гексагональной сетки: pointy-top, offset-координаты odd-r.
## Клетка задаётся Vector2i(col, row); нечётные строки сдвинуты вправо на полгекса.

const SQRT3 := 1.7320508075688772

# Смещения соседей для чётных и нечётных строк, по часовой стрелке начиная с востока.
const _EVEN_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1),
]
const _ODD_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]

var width: int
var height: int


func _init(w: int = 11, h: int = 9) -> void:
	width = w
	height = h


func in_bounds(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < width and hex.y >= 0 and hex.y < height


func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in (_ODD_DIRS if hex.y & 1 else _EVEN_DIRS):
		var n := hex + d
		if in_bounds(n):
			result.append(n)
	return result


func all_hexes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in height:
		for col in width:
			result.append(Vector2i(col, row))
	return result


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return distance(a, b) == 1


static func to_cube(hex: Vector2i) -> Vector3i:
	var q := hex.x - (hex.y - (hex.y & 1)) / 2
	var r := hex.y
	return Vector3i(q, r, -q - r)


static func from_cube(c: Vector3i) -> Vector2i:
	var row := c.y
	var col := c.x + (row - (row & 1)) / 2
	return Vector2i(col, row)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := to_cube(a)
	var cb := to_cube(b)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))


## Центр клетки в пикселях; size — радиус описанной окружности.
static func to_pixel(hex: Vector2i, size: float) -> Vector2:
	var x := size * SQRT3 * (hex.x + 0.5 * (hex.y & 1))
	var y := size * 1.5 * hex.y
	return Vector2(x, y)


static func from_pixel(p: Vector2, size: float) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - 1.0 / 3.0 * p.y) / size
	var r := (2.0 / 3.0 * p.y) / size
	return from_cube(_cube_round(q, r, -q - r))


static func corners(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * size)
	return pts


static func _cube_round(fq: float, fr: float, fs: float) -> Vector3i:
	var q := roundi(fq)
	var r := roundi(fr)
	var s := roundi(fs)
	var dq := absf(q - fq)
	var dr := absf(r - fr)
	var ds := absf(s - fs)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	else:
		s = -q - r
	return Vector3i(q, r, s)
