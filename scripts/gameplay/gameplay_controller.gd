extends Control

signal answer_presented(outcome: String, question_id: String, option_id: String)
signal view_changed(view: String)
signal readiness_changed(ready: bool)

const Store = preload("res://scripts/domain/gameplay_store.gd")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const Payload = preload("res://scripts/domain/gameplay_payload.gd")
const Content = preload("res://scripts/domain/content_validator.gd")
const DIFFICULTY_LABELS := {
    "easy": "Easy  ·  Hint available right away",
    "normal": "Normal  ·  Hint after one miss",
    "hard": "Hard  ·  Hint after two misses",
}

@onready var _hud: HBoxContainer = $Margin/Frame/HUD
@onready var _scroll: ScrollContainer = $Margin/Frame/Scroll
@onready var _panels: VBoxContainer = $Margin/Frame/Scroll/Panels
@onready var _error_label: Label = _panels.get_node("Error")
@onready var _entry: VBoxContainer = _panels.get_node("Entry")
@onready var _difficulty: VBoxContainer = _panels.get_node("Difficulty")
@onready var _play: VBoxContainer = _panels.get_node("Play")
@onready var _pause: VBoxContainer = _panels.get_node("Pause")
@onready var _result: VBoxContainer = _panels.get_node("Result")
@onready var _diagnostic: VBoxContainer = _panels.get_node("Diagnostic")
@onready var _answers = _play.get_node("Answers")
@onready var _hint: Label = _play.get_node("Hint")
@onready var _feedback: VBoxContainer = _play.get_node("Feedback")

var _store: Store
var _campaign: Dictionary
var _questions := {}
var _province_names := {}
var _province_id: String
var _view := ""
var _committing := false
var _recovery_required := false

func _ready() -> void:
    _entry.get_node("Resume").pressed.connect(_show_session)
    _entry.get_node("New").pressed.connect(_show_difficulty)
    _difficulty.get_node("Back").pressed.connect(_show_entry)
    for difficulty: String in Content.DIFFICULTIES:
        _difficulty.get_node(difficulty.capitalize()).pressed.connect(_start_selected.bind(difficulty))
    _answers.selected.connect(_submit_answer)
    _hud.get_node("Pause").pressed.connect(_show_pause)
    _feedback.get_node("Acknowledge").pressed.connect(_acknowledge)
    _pause.get_node("Resume").pressed.connect(_show_session)
    _pause.get_node("Restart").pressed.connect(_replay)
    _pause.get_node("Return").pressed.connect(_show_entry)
    _result.get_node("Replay").pressed.connect(_replay)
    _result.get_node("Return").pressed.connect(_show_entry)
    _diagnostic.get_node("Retry").pressed.connect(_restore)

func configure(repository: Repository, campaign: Dictionary, catalog: Dictionary) -> bool:
    if _store != null:
        return false
    _campaign = campaign.duplicate(true)
    _province_id = campaign.startProvinceId
    for province in campaign.provinces:
        _province_names[province.provinceId] = province.displayName
    for question in catalog.questions:
        _questions[question.questionId] = question.duplicate(true)
    _store = Store.new(repository, _campaign, catalog)
    return _restore()

func snapshot() -> Dictionary:
    return _store.snapshot()

func province_availability(province_id: String) -> Dictionary:
    var progress: Dictionary = snapshot().get("progress", {})
    var available := []
    for difficulty: String in Content.DIFFICULTIES:
        if Payload.question_pool(_campaign, province_id, difficulty).size() >= Content.MIN_POOL_SIZE:
            available.append(difficulty)
    return {"unlocked": province_id in progress.get("unlockedProvinceIds", []), "difficulties": available}

func _restore() -> bool:
    return _show_restore(_store.restore())

func _show_restore(loaded: Dictionary) -> bool:
    var ready: bool = loaded.error.is_empty()
    _recovery_required = not ready
    readiness_changed.emit(ready)
    if ready:
        _show_entry()
    else:
        var details: PackedStringArray = ["Gameplay is paused. Save files have been preserved.", "Reason: " + loaded.error.replace("_", " ")]
        if loaded.committedGeneration > 0:
            details.append("Committed generation: %d" % loaded.committedGeneration)
        if loaded.stagedGeneration > 0:
            details.append("Pending generation: %d" % loaded.stagedGeneration)
        if not loaded.stagedError.is_empty():
            details.append("Pending save: " + loaded.stagedError.replace("_", " "))
        if not loaded.recoveryCandidates.is_empty():
            var generations := PackedStringArray()
            for generation in loaded.recoveryCandidates:
                generations.append(str(generation))
            details.append("Available recovery generations: " + ", ".join(generations))
        _diagnostic.get_node("Details").text = "\n".join(details)
        _show("diagnostic", _diagnostic)
    return ready

func _show_entry() -> void:
    if _committing or _recovery_required:
        return
    var saved: Variant = snapshot().session
    _entry.get_node("Title").text = _province_names[_province_id]
    _entry.get_node("Progress").text = _route_summary()
    _entry.get_node("Resume").visible = saved != null
    if saved != null:
        var action := "View saved result" if saved.state in [Session.VICTORY, Session.FAILURE] else "Resume saved attempt"
        _entry.get_node("Resume").text = "%s · %s" % [action, saved.difficulty.capitalize()]
    _show("entry", _entry)

func _show_difficulty() -> void:
    if _view != "entry":
        return
    var state := snapshot()
    var active: bool = state.session != null and state.session.state in [Session.AWAITING, Session.FEEDBACK]
    _difficulty.get_node("Notice").text = "Starting a new game replaces the active attempt. Best records are kept." if active else "Choose how much help you want during the five questions."
    var access := province_availability(_province_id)
    for difficulty: String in Content.DIFFICULTIES:
        var button: Button = _difficulty.get_node(difficulty.capitalize())
        var record: Dictionary = state.progress.records.get(_province_id + "/" + difficulty, {})
        button.disabled = not access.unlocked or difficulty not in access.difficulties
        button.text = DIFFICULTY_LABELS[difficulty]
        if not record.is_empty():
            button.text += "  ·  Best %d pts / %d stars" % [record.bestScore, record.bestStars]
    _show("difficulty", _difficulty)

func _start_selected(difficulty: String) -> void:
    if _view == "difficulty":
        _start(_province_id, difficulty)

func _start(province: String, difficulty: String) -> void:
    if _committing:
        return
    _committing = true
    var error := _store.start_session(Crypto.new().generate_random_bytes(16).hex_encode(), province, difficulty)
    _committing = false
    if error.is_empty():
        _show_session()
    else:
        _show_write_error(error)

func _show_session() -> void:
    if _recovery_required:
        return
    var state := snapshot()
    var session: Variant = state.session
    if session == null:
        return
    if session.state in [Session.VICTORY, Session.FAILURE]:
        _show_result(session)
        return
    var id: String = session.questionIds[session.questionIndex]
    var question: Dictionary = _questions[id]
    var accepting: bool = session.state == Session.AWAITING
    var correct: bool = session.feedbackOutcome == "correct"
    _hud.get_node("Status").text = "Question %d of %d     Score %d     Misses %d / %d" % [
        session.questionIndex + 1, Session.QUESTION_COUNT, session.score, session.misses, Session.MISS_LIMIT,
    ]
    _play.get_node("PromptRow/Question/Context").text = "%s  ·  %s" % [_province_names[session.provinceId], session.difficulty.capitalize()]
    _play.get_node("PromptRow/Question/Prompt").text = question.prompt
    _play.get_node("PromptRow/TinCan").set_knocked(correct)
    _answers.display_answers(question, session.optionOrderByQuestion[id],
        session.rejectedOptionIdsByQuestion.get(id, []), accepting)
    _hint.visible = Session.hint_available(session)
    _hint.text = "Hint: " + question.hint if _hint.visible else ""
    _feedback.visible = session.state == Session.FEEDBACK
    _feedback.get_node("Message").text = ""
    if _feedback.visible:
        _feedback.get_node("Message").text = "Correct. " + question.explanation if correct else "Miss. Try another answer."
        _feedback.get_node("Acknowledge").text = "Continue" if correct else "Try again"
    _show("play", _play)

func _submit_answer(question_id: String, option_id: String) -> void:
    if _committing or _view != "play":
        return
    var session: Variant = snapshot().session
    if session == null or session.state != Session.AWAITING or session.questionIds[session.questionIndex] != question_id:
        return
    var command := JSON.stringify([session.sessionId, question_id, option_id]).sha256_text()
    _committing = true
    var error := _store.submit_answer(session.sessionId, question_id, option_id, command)
    if error.is_empty():
        # Render the verified snapshot and emit a presentation event while input is guarded.
        var outcome: String = snapshot().session.feedbackOutcome
        _show_session()
        answer_presented.emit(outcome, question_id, option_id)
    _committing = false
    if not error.is_empty():
        _show_write_error(error)

func _acknowledge() -> void:
    if _committing or _view != "play":
        return
    var session: Variant = snapshot().session
    if session == null or session.state != Session.FEEDBACK:
        return
    _committing = true
    var error := _store.acknowledge_feedback(session.sessionId, session.processedSubmissions.back().commandId)
    _committing = false
    if error.is_empty():
        _show_session()
    else:
        _show_write_error(error)

func _show_pause() -> void:
    if not _committing and _view == "play":
        _show("pause", _pause)

func _replay() -> void:
    if _view in ["pause", "result"]:
        var session: Dictionary = snapshot().session
        _start(session.provinceId, session.difficulty)

func _show_result(session: Dictionary) -> void:
    var victory: bool = session.state == Session.VICTORY
    _result.get_node("Title").text = "Province completed" if victory else "Out of attempts"
    _result.get_node("Summary").text = "%s  ·  %s\nScore %d    Misses %d / %d    Stars %d" % [
        _province_names[session.provinceId], session.difficulty.capitalize(), session.score, session.misses, Session.MISS_LIMIT, session.stars,
    ]
    _result.get_node("Progress").text = _route_summary()
    _result.get_node("Replay").text = "Replay" if victory else "Retry"
    _show("result", _result)

func _route_summary() -> String:
    var routes: PackedStringArray = []
    for province in _campaign.provinces:
        var id: String = province.provinceId
        if id == _province_id:
            continue
        var access := province_availability(id)
        var info := "Locked"
        if access.unlocked:
            info = "Unlocked. Questions coming later." if access.difficulties.is_empty() else "Unlocked"
        routes.append("%s — %s" % [_province_names[id], info])
    return "\n".join(routes)

func _show(view: String, panel: Control) -> void:
    _view = view
    _hud.visible = view == "play"
    for child in _panels.get_children():
        child.visible = child == panel
    _scroll.scroll_vertical = 0
    view_changed.emit(view)

func _show_write_error(error: String) -> void:
    # Recheck failed writes for a pending or invalid save. Keep the current
    # committed presentation when no recovery decision is required.
    if error == "commit_failed":
        var loaded := _store.restore()
        if not loaded.error.is_empty():
            _show_restore(loaded)
            return
        if _view == "play":
            if snapshot().session == null:
                _show_entry()
            else:
                _show_session()
    _error_label.text = "Action could not be saved. Try again. (%s)" % error.replace("_", " ")
    _error_label.visible = true
