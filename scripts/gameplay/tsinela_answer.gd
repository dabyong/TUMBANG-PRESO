extends Button

signal selected(question_id: String, option_id: String)

var question_id := ""
var option_id := ""

func _ready() -> void:
    pressed.connect(_select)

func display_answer(question: String, option: String, label: String, rejected: bool, accepting: bool) -> void:
    question_id = question
    option_id = option
    text = "      " + label + (" (tried)" if rejected else "")
    disabled = rejected or not accepting
    queue_redraw()

func _draw() -> void:
    var sole := Color("#546a72") if disabled else Color("#c99054")
    var strap := Color("#818c87") if disabled else Color("#ffe0a3")
    draw_set_transform(Vector2(23, size.y * 0.5), -0.42)
    draw_rect(Rect2(-6, -7, 12, 15), sole)
    draw_circle(Vector2(0, -7), 6, sole)
    draw_circle(Vector2(0, 8), 6, sole)
    draw_polyline(PackedVector2Array([Vector2(-6, -2), Vector2(0, -7), Vector2(6, -2)]), strap, 2.0, true)

func _select() -> void:
    if not disabled and not option_id.is_empty():
        selected.emit(question_id, option_id)
