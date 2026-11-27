extends VBoxContainer

signal selected(question_id: String, option_id: String)

const Tsinela = preload("res://scenes/gameplay/tsinela.tscn")

func _ready() -> void:
    for index in range(5):
        var answer := Tsinela.instantiate()
        answer.name = "Tsinela%d" % (index + 1)
        add_child(answer)
        answer.selected.connect(selected.emit)

func display_answers(question: Dictionary, order: Array, rejected: Array, accepting: bool) -> void:
    var labels := {}
    for option in question.options:
        labels[option.optionId] = option.text
    for index in range(order.size()):
        var id: String = order[index]
        get_child(index).display_answer(question.questionId, id, labels[id], id in rejected, accepting)
