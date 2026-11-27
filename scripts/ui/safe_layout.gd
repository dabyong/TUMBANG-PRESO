extends RefCounted

static func apply(control: Control, shift: float = 0.0, padding: Vector4 = Vector4.ZERO) -> void:
    var insets := Vector4.ZERO
    if OS.has_feature("mobile"):
        var screen := DisplayServer.window_get_current_screen()
        var display := Rect2(Vector2(DisplayServer.screen_get_position(screen)), Vector2(DisplayServer.screen_get_size(screen)))
        var safe := Rect2(DisplayServer.get_display_safe_area()).intersection(display)
        if display.has_area() and safe.has_area():
            var scale := control.get_viewport_rect().size / display.size
            var near := (safe.position - display.position) * scale
            var far := (display.end - safe.end) * scale
            insets = Vector4(near.x, near.y, far.x, far.y)
    control.offset_left = insets.x + padding.x + shift
    control.offset_top = insets.y + padding.y
    control.offset_right = -insets.z - padding.z + shift
    control.offset_bottom = -insets.w - padding.w
