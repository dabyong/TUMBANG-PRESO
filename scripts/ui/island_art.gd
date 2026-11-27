extends Control

@export var small := false

func _draw() -> void:
    var origin := Vector2.ZERO if small else Vector2(0, size.y - 152)
    var area := size if small else Vector2(size.x, 152)
    if small:
        draw_rect(Rect2(origin, area), Color("#315967"))
        draw_rect(Rect2(origin + Vector2(area.x * 0.76, 8), Vector2(15, 15)), Color("#f2c14e"))
    var terrain := PackedVector2Array([
        origin + area * Vector2(0, 0.7), origin + area * Vector2(0.18, 0.37),
        origin + area * Vector2(0.38, 0.56), origin + area * Vector2(0.66, 0.2),
        origin + area * Vector2(0.81, 0.46), origin + area * Vector2(1, 0.33),
        origin + area, origin + area * Vector2(0, 1),
    ])
    draw_colored_polygon(terrain, Color("#648b50") if small else Color("#203e33"))
    draw_rect(Rect2(origin + Vector2(0, area.y - 6), Vector2(area.x, 6)), Color("#a87746") if small else Color("#315646"))
