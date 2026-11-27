extends Control

var _knocked := false
var spin_radians := 0.0
var _lean := 0.0
var _nudge := 0.0
var _idle := 0.0

func set_knocked(knocked: bool) -> void:
    _knocked = knocked
    spin_radians = 0.0
    _lean = PI / 2.0 if knocked else 0.0
    _nudge = 0.0
    _idle = 0.0
    queue_redraw()

func impact(ratio: float, correct: bool, reduced: bool) -> void:
    spin_radians = TAU * 2.0 * minf(ratio / 0.8, 1.0) if correct and not reduced else 0.0
    _lean = PI / 2.0 * (ratio if reduced else remap(clampf(ratio, 0.8, 1.0), 0.8, 1.0, 0.0, 1.0)) if correct else 0.0
    _nudge = sin(ratio * TAU * 2.0) * (1.0 - ratio) * 7.0 if not correct and not reduced else 0.0
    queue_redraw()

func idle(seconds: float) -> void:
    if not _knocked:
        _idle = sin(seconds * 2.4) * 2.0
        queue_redraw()

func stop_idle() -> void:
    _idle = 0.0
    queue_redraw()

func _draw() -> void:
    draw_set_transform(size * 0.5 + Vector2(_nudge, _idle), spin_radians + _lean)
    draw_rect(Rect2(-15, -18, 30, 36), Color("#638a9c"))
    draw_rect(Rect2(-16, -19, 32, 5), Color("#c1d8df"))
    draw_rect(Rect2(-16, 14, 32, 5), Color("#c1d8df"))
    draw_rect(Rect2(-15, -4, 30, 8), Color("#efc66e"))
