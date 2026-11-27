extends Button

signal selected(question_id: String, option_id: String)

const ICON_CENTER_X := 23.0

var question_id := ""
var option_id := ""
var _caption: Label

func _ready() -> void:
    pressed.connect(_select)
    clip_text = true
    for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
        add_theme_color_override(state, Color.TRANSPARENT)
    _caption = Label.new()
    _caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _caption.add_theme_font_size_override("font_size", 20)
    add_child(_caption)
    _caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _caption.offset_left = 55
    _caption.offset_right = -14
    _caption.offset_top = 6
    _caption.offset_bottom = -6
    _caption.minimum_size_changed.connect(_fit_caption)
    resized.connect(_fit_caption)

func display_answer(question: String, option: String, label: String, rejected: bool, accepting: bool) -> void:
    question_id = question
    option_id = option
    text = "      " + label + (" (tried)" if rejected else "")
    disabled = rejected or not accepting
    _caption.text = text.strip_edges()
    refresh_appearance()

func _fit_caption() -> void:
    custom_minimum_size.y = maxf(54.0, _caption.get_minimum_size().y + 12.0)

func refresh_appearance() -> void:
    _caption.modulate = Color("#afbbc1") if disabled else Color.WHITE
    queue_redraw()

func throw_origin() -> Vector2:
    return get_global_transform_with_canvas() * Vector2(ICON_CENTER_X, size.y * 0.5)

func _draw() -> void:
    var sole := Color("#546a72") if disabled else Color("#c99054")
    var strap := Color("#818c87") if disabled else Color("#ffe0a3")
    draw_set_transform(Vector2(ICON_CENTER_X, size.y * 0.5), -0.42)
    draw_rect(Rect2(-6, -7, 12, 15), sole)
    draw_circle(Vector2(0, -7), 6, sole)
    draw_circle(Vector2(0, 8), 6, sole)
    draw_polyline(PackedVector2Array([Vector2(-6, -2), Vector2(0, -7), Vector2(6, -2)]), strap, 2.0, true)

func _select() -> void:
    if not disabled and not option_id.is_empty():
        selected.emit(question_id, option_id)
