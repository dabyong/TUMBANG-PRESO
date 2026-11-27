extends Control

signal frame_changed(phase: String, ratio: float)
signal phase_finished(phase: String, token: int, session_id: String)

const DURATIONS := {"throw": [0.44, 0.12], "impact": [0.48, 0.10], "miss": [0.20, 0.10], "failure": [0.55, 0.22], "victory": [0.60, 0.15]}

var phase := ""
var token := 0
var session_id := ""
var elapsed := 0.0
var reduced := false
var suspended := false
var manual := false
var source: Control
var target: Control
var correct := false
var _launch_fraction := Vector2.ZERO

func capture_launch(clip: Control) -> void:
    var inverse := get_global_transform_with_canvas().affine_inverse()
    var clip_transform := inverse * clip.get_global_transform_with_canvas()
    var visible := Rect2(clip_transform.origin, clip_transform * clip.size - clip_transform.origin)
    var launch: Vector2 = inverse * source.throw_origin()
    _launch_fraction = launch.clamp(visible.position, visible.end) / size.max(Vector2.ONE)

func trajectory() -> PackedVector2Array:
    var padding := Vector2(18, 18)
    var lower_right := (size - padding).max(padding)
    var from := (_launch_fraction * size).clamp(padding, lower_right)
    var inverse := get_global_transform_with_canvas().affine_inverse()
    var to := inverse * (target.get_global_transform_with_canvas() * (target.size * 0.5))
    if not correct:
        to += Vector2(72, 32)
    return PackedVector2Array([from, to.clamp(padding, lower_right)])

func projectile_position(ratio: float) -> Vector2:
    var path := trajectory()
    if reduced:
        return path[0] if ratio < 0.5 else path[1]
    var position_on_arc := path[0].lerp(path[1], ratio)
    var height := clampf(minf(path[0].y, path[1].y) - 18.0, 0.0, 90.0)
    position_on_arc.y -= height * 4.0 * ratio * (1.0 - ratio)
    return position_on_arc

func begin(next_phase: String, next_token: int, id: String, reduced_motion: bool) -> void:
    phase = next_phase
    token = next_token
    session_id = id
    elapsed = 0.0
    reduced = reduced_motion
    frame_changed.emit(phase, 0.0)
    queue_redraw()

func cancel() -> void:
    phase = ""
    elapsed = 0.0
    suspended = false
    source = null
    target = null
    queue_redraw()

func update_motion(reduced_motion: bool) -> void:
    if phase.is_empty() or reduced == reduced_motion:
        return
    var ratio: float = elapsed / DURATIONS[phase][int(reduced)]
    reduced = reduced_motion
    elapsed = ratio * DURATIONS[phase][int(reduced)]
    frame_changed.emit(phase, ratio)
    queue_redraw()

func _process(delta: float) -> void:
    if not manual:
        advance(minf(delta, 0.10), token)

func advance(seconds: float, expected_token: int) -> void:
    while seconds > 0.0 and not phase.is_empty() and not suspended and token == expected_token:
        var duration: float = DURATIONS[phase][int(reduced)]
        var step := minf(seconds, duration - elapsed)
        elapsed += step
        seconds -= step
        frame_changed.emit(phase, elapsed / duration)
        queue_redraw()
        if elapsed >= duration:
            var completed := phase
            phase = ""
            phase_finished.emit(completed, token, session_id)

func _draw() -> void:
    if suspended or phase.is_empty():
        return
    var t: float = elapsed / DURATIONS[phase][int(reduced)]
    if phase == "throw" and is_instance_valid(source) and is_instance_valid(target):
        draw_set_transform(projectile_position(t), t * TAU if not reduced else 0.0)
        draw_rect(Rect2(-8, -13, 16, 26), Color("#a87746"))
        draw_polyline(PackedVector2Array([Vector2(-7, 0), Vector2(0, -8), Vector2(7, 0)]), Color("#f5e7c8"), 3.0)
    elif phase == "failure":
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.09, 0.06, 0.75))
        var font := ThemeDB.fallback_font
        var message := "FIVE MISSES"
        var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 38)
        draw_string(font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#f5e7c8"))
