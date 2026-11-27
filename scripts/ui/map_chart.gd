extends Control

var _provinces: Array = []
var _routes: Array = []
var _selected := ""

func display(provinces: Array, routes: Array, selected: String) -> void:
    _provinces = provinces
    _routes = routes
    _selected = selected
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#234457"))
    var points := {}
    for index in range(_provinces.size()):
        var ratio := float(index + 1) / (_provinces.size() + 1)
        points[_provinces[index].provinceId] = Vector2(size.x * (0.42 if index % 2 == 0 else 0.63), size.y * ratio)
    for index in range(12):
        var x := float(index % 3) * size.x / 3.0
        var y := float(index) * size.y / 12.0
        draw_line(Vector2(x, y), Vector2(x + 12, y), Color("#507487"), 1.0)
    for route in _routes:
        var from: Vector2 = points[route.fromProvinceId]
        var to: Vector2 = points[route.toProvinceId]
        if route.travelMode == "sea":
            draw_dashed_line(from, to, Color("#83bbd4"), 3.0, 6.0)
        else:
            draw_line(from, to, Color("#f5e7c8"), 3.0)
        var direction := (to - from).normalized()
        var tip := to - direction * 12.0
        var tail := tip - direction * 8.0
        draw_colored_polygon(PackedVector2Array([tip, tail + direction.orthogonal() * 4.0, tail - direction.orthogonal() * 4.0]), Color("#f5e7c8"))
    for id in points:
        var point: Vector2 = points[id]
        draw_rect(Rect2(point - Vector2(10, 8), Vector2(20, 16)), Color("#648b50"))
        draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color("#f2c14e") if id == _selected else Color("#f5e7c8"))
