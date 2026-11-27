extends Control

var _knocked := false

func set_knocked(knocked: bool) -> void:
    _knocked = knocked
    queue_redraw()

func _draw() -> void:
    draw_set_transform(size * 0.5, PI / 2.0 if _knocked else 0.0)
    draw_rect(Rect2(-15, -18, 30, 36), Color("#638a9c"))
    draw_rect(Rect2(-16, -19, 32, 5), Color("#c1d8df"))
    draw_rect(Rect2(-16, 14, 32, 5), Color("#c1d8df"))
    draw_rect(Rect2(-15, -4, 30, 8), Color("#efc66e"))
