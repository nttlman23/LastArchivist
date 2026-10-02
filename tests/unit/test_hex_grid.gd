extends GutTest

var grid := HexGrid.new(11, 9)


func test_neighbors_even_row() -> void:
	var n := grid.neighbors(Vector2i(5, 4))
	assert_eq(n.size(), 6)
	for h in [Vector2i(6, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 5), Vector2i(5, 5)]:
		assert_has(n, h)


func test_neighbors_odd_row() -> void:
	var n := grid.neighbors(Vector2i(5, 3))
	assert_eq(n.size(), 6)
	for h in [Vector2i(6, 3), Vector2i(4, 3), Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 4), Vector2i(6, 4)]:
		assert_has(n, h)


func test_neighbors_are_distance_one() -> void:
	for hex in grid.all_hexes():
		for n in grid.neighbors(hex):
			assert_eq(HexGrid.distance(hex, n), 1, "%s -> %s" % [hex, n])


func test_corner_neighbors_clipped() -> void:
	assert_eq(grid.neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(grid.neighbors(Vector2i(10, 8)).size(), 3)


func test_distance() -> void:
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(10, 0)), 10)
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 8)), 8)
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(4, 8)), 8)
	assert_eq(HexGrid.distance(Vector2i(3, 3), Vector2i(3, 3)), 0)


func test_bounds() -> void:
	assert_true(grid.in_bounds(Vector2i(10, 8)))
	assert_false(grid.in_bounds(Vector2i(11, 0)))
	assert_false(grid.in_bounds(Vector2i(0, -1)))


func test_pixel_roundtrip() -> void:
	for hex in grid.all_hexes():
		var p := HexGrid.to_pixel(hex, 40.0)
		assert_eq(HexGrid.from_pixel(p, 40.0), hex)
		assert_eq(HexGrid.from_pixel(p + Vector2(15, -10), 40.0), hex)
