extends Control

signal answer_presented(outcome: String, question_id: String, option_id: String)
signal view_changed(view: String)
signal readiness_changed(ready: bool)

const Store = preload("res://scripts/domain/gameplay_store.gd")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const Payload = preload("res://scripts/domain/gameplay_payload.gd")
const Content = preload("res://scripts/domain/content_validator.gd")
const Preferences = preload("res://scripts/ui/preferences.gd")
const SafeLayout = preload("res://scripts/ui/safe_layout.gd")
const DIFFICULTY_LABELS := {
    "easy": "Easy · Introductory · Hint right away",
    "normal": "Normal · Province knowledge · Hint after one miss",
    "hard": "Hard · Detailed facts · Hint after two misses",
}

@onready var _hud: HBoxContainer = $Margin/Frame/HUD
@onready var _scroll: ScrollContainer = $Margin/Frame/Scroll
@onready var _panels: VBoxContainer = $Margin/Frame/Scroll/Panels
@onready var _error_label: Label = _panels.get_node("Error")
@onready var _menu: VBoxContainer = _panels.get_node("Menu")
@onready var _map: VBoxContainer = _panels.get_node("Map")
@onready var _entry: VBoxContainer = _panels.get_node("Entry")
@onready var _difficulty: VBoxContainer = _panels.get_node("Difficulty")
@onready var _play: VBoxContainer = _panels.get_node("Play")
@onready var _pause: VBoxContainer = _panels.get_node("Pause")
@onready var _result: VBoxContainer = _panels.get_node("Result")
@onready var _diagnostic: VBoxContainer = _panels.get_node("Diagnostic")
@onready var _settings: VBoxContainer = _panels.get_node("Settings")
@onready var _confirm: VBoxContainer = _panels.get_node("Confirm")
@onready var _answers = _play.get_node("Answers")
@onready var _can = _hud.get_node("TinCan")
@onready var _hint: Label = _play.get_node("Hint")
@onready var _feedback: VBoxContainer = _play.get_node("Feedback")
@onready var _effects = $Effects

var _store: Store
var _preferences: Preferences
var _save_directory: String
var _campaign: Dictionary
var _questions := {}
var _provinces := {}
var _chapters := {}
var _province_id: String
var _view := ""
var _settings_origin := "menu"
var _decision := {}
var _recovery := {}
var _highlight: Array = []
var _committing := false
var _recovery_required := false
var _backgrounded := false
var _presentation_token := 0
var _presented_session := ""
var _pending_answer := {}
var _idle_time := 0.0
var _paused_scroll := 0
var _restoring_play_scroll := false

func _ready() -> void:
    _button(_menu, "Actions/Play", _show_map.bind(""))
    _button(_menu, "Actions/Continue", _continue_map)
    _button(_menu, "Actions/Settings", _show_settings.bind("menu"))
    _button(_menu, "Actions/Credits", _show_named.bind("credits", "Credits"))
    _button(_menu, "Resume", _resume_from_menu)
    _button(_panels.get_node("Credits"), "Back", _show_menu)
    _button(_map, "Actions/Menu", _show_menu)
    _button(_map, "Actions/Progress", _show_progress)
    _button(_panels.get_node("Progress"), "Back", _show_map.bind(""))
    _button(_entry, "Resume", _resume_saved)
    _button(_entry, "New", _show_difficulty)
    _button(_entry, "Back", _show_map.bind(""))
    _button(_difficulty, "Back", _show_entry)
    for difficulty: String in Content.DIFFICULTIES:
        _button(_difficulty, difficulty.capitalize(), _start_selected.bind(difficulty))
    _answers.selected.connect(_submit_answer)
    _button(_hud, "Pause", _show_pause)
    _button(_feedback, "Acknowledge", _acknowledge)
    _button(_pause, "Resume", _resume_pause)
    _button(_pause, "Restart", _replay)
    _button(_pause, "Settings", _show_settings.bind("pause"))
    _button(_pause, "Return", _show_map.bind(""))
    _button(_result, "Replay", _replay)
    _button(_result, "Return", _continue_result)
    _button(_diagnostic, "Retry", _restore)
    _button(_confirm, "Accept", _confirm_decision)
    _button(_confirm, "Cancel", _cancel_decision)
    _button(_settings, "Back", _back_from_settings)
    _settings.get_node("Music").value_changed.connect(_change_preference.bind("music"))
    _settings.get_node("Effects").value_changed.connect(_change_preference.bind("effects"))
    _settings.get_node("Motion").toggled.connect(_change_preference.bind("reduced_motion"))
    _effects.phase_finished.connect(_phase_finished)
    _effects.frame_changed.connect(_presentation_frame)
    resized.connect(_apply_layout)
    _apply_layout()

func _button(panel: Node, path: String, action: Callable) -> void:
    panel.get_node(path).pressed.connect(action)

func configure(repository: Repository, campaign: Dictionary, catalog: Dictionary) -> bool:
    if _store != null:
        return false
    _campaign = campaign.duplicate(true)
    _save_directory = repository._directory
    _preferences = Preferences.new(_save_directory)
    _province_id = campaign.startProvinceId
    for province in _campaign.provinces:
        _provinces[province.provinceId] = province
    for chapter in _campaign.chapters:
        _chapters[chapter.chapterId] = chapter.displayName
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
    _cancel_presentation()
    _highlight.clear()
    _recovery = loaded
    var ready: bool = loaded.error.is_empty()
    _recovery_required = not ready
    readiness_changed.emit(ready)
    if ready:
        _show_menu()
    else:
        _show_recovery()
    return ready

func _show_recovery() -> void:
    var details := PackedStringArray(["Reason: " + _recovery.error.replace("_", " "),
        "Committed generation: %d" % _recovery.committedGeneration])
    var inspected := snapshot()
    if _recovery.snapshotGeneration > 0:
        var saved: Variant = inspected.session
        var overview := "%d completed" % inspected.progress.completedProvinceIds.size()
        if saved != null:
            overview += " · %s / %s · %s · %d points" % [_name(saved.provinceId), saved.difficulty.capitalize(), saved.state, saved.score]
        details.append("Inspection snapshot %d: %s" % [_recovery.snapshotGeneration, overview])
    else:
        details.append("Inspection snapshot unavailable.")
    var actions: VBoxContainer = _diagnostic.get_node("Actions")
    _clear_children(actions)
    if _recovery.error == "pending_recovery":
        details.append("Pending generation: %d" % _recovery.stagedGeneration)
        if _recovery.stagedError.is_empty():
            _add_action(actions, "Promote", "Promote staged save", _ask_recovery.bind("promote", int(_recovery.stagedGeneration)))
        else:
            details.append("Pending save: " + _recovery.stagedError.replace("_", " "))
        _add_action(actions, "Defer", "Defer and preserve staged save", _ask_recovery.bind("defer", int(_recovery.stagedGeneration)))
    elif not _recovery.recoveryCandidates.is_empty() and _recovery.error not in ["unsupported_save_schema", "unreadable_save", "invalid_content"]:
        details.append("Restoring an earlier save may roll back questions, scores and unlocks.")
        for generation in _recovery.recoveryCandidates:
            _add_action(actions, "Restore%d" % generation, "Review restore of generation %d" % generation, _ask_recovery.bind("committed", int(generation)))
    else:
        details.append("No compatible recovery action is available. Keep the files for support or compatible content.")
    details.append("Save files are preserved in " + ProjectSettings.globalize_path(_save_directory))
    if OS.has_feature("pc"):
        _add_action(actions, "OpenFolder", "Open save folder", _open_save_folder)
    _diagnostic.get_node("Details").text = "\n".join(details)
    _show("diagnostic", _diagnostic)

func _ask_recovery(action: String, generation: int) -> void:
    if _view != "diagnostic":
        return
    var message: String
    match action:
        "committed":
            message = "Restore generation %d? Progress after this checkpoint may be rolled back. Newer artifacts will be preserved." % generation
        "promote":
            message = "Publish staged generation %d as the committed save?" % generation
        _:
            message = "Archive staged generation %d without publishing it? The original bytes will be kept." % generation
    _ask(message, {"action": action, "origin": "diagnostic", "generation": generation, "latest": int(_recovery.committedGeneration)})

func _open_save_folder() -> void:
    if _view == "diagnostic":
        var error := OS.shell_open(ProjectSettings.globalize_path(_save_directory))
        if error != OK:
            _show_error("The save folder could not be opened.")

func _show_menu() -> void:
    if _committing or _recovery_required:
        return
    _cancel_presentation()
    var state := snapshot()
    var saved: Variant = state.session
    _menu.get_node("Actions/Continue").disabled = saved == null and _preferences.values.province not in state.progress.unlockedProvinceIds
    _menu.get_node("Saved").text = "Discover the first destination to begin." if saved == null else "Saved in %s · %s" % [_name(saved.provinceId), saved.difficulty.capitalize()]
    var resume: Button = _menu.get_node("Resume")
    resume.visible = saved != null
    if saved != null:
        resume.text = _resume_label(saved)
    _show("menu", _menu)

func _resume_from_menu() -> void:
    var saved: Variant = snapshot().session
    if _view == "menu" and saved != null:
        _province_id = saved.provinceId
        _show_session()

func _continue_map() -> void:
    if _view != "menu":
        return
    var saved: Variant = snapshot().session
    var id: String = _preferences.values.province
    if not province_availability(id).unlocked and saved != null:
        id = saved.provinceId
    _show_map(id)

func _show_map(focus: String) -> void:
    if _committing or _recovery_required:
        return
    _cancel_presentation()
    if not focus.is_empty() and province_availability(focus).unlocked:
        _province_id = focus
    elif not province_availability(_province_id).unlocked:
        _province_id = _campaign.startProvinceId
    var nodes: VBoxContainer = _map.get_node("Body/Provinces")
    _clear_children(nodes)
    var routes := PackedStringArray()
    for route in _campaign.routes:
        routes.append("%s  →  %s  ·  %s" % [_name(route.fromProvinceId), _name(route.toProvinceId), route.travelMode.capitalize()])
    for province in _campaign.provinces:
        var id: String = province.provinceId
        var access := province_availability(id)
        var availability := "Questions available" if not access.difficulties.is_empty() else "No playable questions"
        var focus_mark := "  ▸ " if id == _province_id else ""
        var button := _add_action(nodes, id, "%s%s  ·  %s\n%s  ·  %s" % [focus_mark, _name(id), _province_state(id), _chapters[province.chapterId], availability], _select_province.bind(id))
        button.disabled = not access.unlocked
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 58
    _map.get_node("Body/Chart").display(_campaign.provinces, _campaign.routes, _province_id)
    _map.get_node("Routes").text = "\n".join(routes)
    _map.get_node("Highlight").text = "Newly unlocked: " + _province_list(_highlight) if not _highlight.is_empty() else ""
    _map.get_node("Highlight").visible = not _highlight.is_empty()
    _show("map", _map)

func _select_province(id: String) -> void:
    if _view != "map" or not province_availability(id).unlocked:
        return
    _province_id = id
    var saved := _preferences.update("province", id)
    _show_entry()
    if not saved:
        _show_error("This map selection could not be saved for next time.")

func _show_entry() -> void:
    if _committing or _recovery_required:
        return
    var province: Dictionary = _provinces[_province_id]
    var access := province_availability(_province_id)
    var saved: Variant = snapshot().session
    var categories := PackedStringArray()
    for difficulty in access.difficulties:
        for id in province.questionPools[difficulty]:
            var category: String = _questions[id].category.capitalize()
            if category not in categories:
                categories.append(category)
    categories.sort()
    var intro := "%s is a province in %s." % [province.displayName, province.regionName]
    if _province_id == "batanes":
        intro = "Explore the island province of Batanes. Basco Lighthouse overlooks the capital, with Mount Iraya nearby."
    _entry.get_node("Title").text = province.displayName
    _entry.get_node("Progress").text = "%s · %s · %s\n%s\n%s\n%s" % [
        province.regionName, _chapters[province.chapterId], _province_state(_province_id), intro,
        "Question topics: " + ", ".join(categories) if not categories.is_empty() else "This destination has no approved question pools.",
        _records_for(_province_id),
    ]
    _entry.get_node("New").disabled = not access.unlocked or access.difficulties.is_empty()
    _entry.get_node("Resume").visible = saved != null and saved.provinceId == _province_id
    if _entry.get_node("Resume").visible:
        _entry.get_node("Resume").text = _resume_label(saved)
    _show("entry", _entry)

func _resume_label(session: Dictionary) -> String:
    var action := "Resume saved attempt" if _has_active_attempt(session) else "View saved result"
    return "%s · %s" % [action, session.difficulty.capitalize()]

func _resume_saved() -> void:
    var saved: Variant = snapshot().session
    if _view == "entry" and saved != null and saved.provinceId == _province_id:
        _show_session()

func _show_progress() -> void:
    if _view != "map":
        return
    var lines := PackedStringArray()
    for chapter in _campaign.chapters:
        var chapter_provinces := PackedStringArray()
        var completed := 0
        for province in _campaign.provinces:
            if province.chapterId == chapter.chapterId:
                var state := _province_state(province.provinceId)
                chapter_provinces.append("%s · %s\n%s" % [province.displayName, state, _records_for(province.provinceId)])
                if state in ["Completed", "Mastered"]:
                    completed += 1
        lines.append("%s · %d of %d completed" % [chapter.displayName, completed, chapter_provinces.size()])
        lines.append_array(chapter_provinces)
        lines.append("")
    _panels.get_node("Progress/Details").text = "\n".join(lines)
    _show_named("progress", "Progress")

func _show_named(view: String, node: String) -> void:
    if not _recovery_required:
        _show(view, _panels.get_node(node))

func _province_state(id: String) -> String:
    var progress: Dictionary = snapshot().progress
    if id not in progress.unlockedProvinceIds:
        return "Locked"
    if id not in progress.completedProvinceIds:
        return "Unlocked"
    for difficulty in Content.DIFFICULTIES:
        if progress.records.get(id + "/" + difficulty, {}).get("bestStars", 0) < 3:
            return "Completed"
    return "Mastered"

func _records_for(id: String) -> String:
    var records: Dictionary = snapshot().progress.records
    var parts := PackedStringArray()
    for difficulty: String in Content.DIFFICULTIES:
        var record: Dictionary = records.get(id + "/" + difficulty, {})
        if not record.is_empty():
            parts.append("%s %d pts / %d stars" % [difficulty.capitalize(), record.bestScore, record.bestStars])
    return "Best: " + "  ·  ".join(parts) if not parts.is_empty() else "No best record yet"

func _name(id: String) -> String:
    return _provinces.get(id, {}).get("displayName", id)

func _province_list(ids: Array) -> String:
    return ", ".join(PackedStringArray(ids.map(_name)))

func _show_difficulty() -> void:
    if _view != "entry" and _view != "confirm":
        return
    var state := snapshot()
    var active := _has_active_attempt(state.session)
    _difficulty.get_node("Title").text = "%s · Difficulty" % _name(_province_id)
    _difficulty.get_node("Notice").text = "Starting a new game replaces the active attempt. Best records are kept." if active else "Choose how much help you want during the five questions."
    var access := province_availability(_province_id)
    for difficulty: String in Content.DIFFICULTIES:
        var button: Button = _difficulty.get_node(difficulty.capitalize())
        var record: Dictionary = state.progress.records.get(_province_id + "/" + difficulty, {})
        button.disabled = not access.unlocked or difficulty not in access.difficulties
        var record_text := "No best record" if record.is_empty() else "Best %d pts / %d stars" % [record.bestScore, record.bestStars]
        button.text = "%s\n%s" % [DIFFICULTY_LABELS[difficulty], "Unavailable" if button.disabled else record_text]
    _show("difficulty", _difficulty)

func _start_selected(difficulty: String) -> void:
    if _view == "difficulty":
        _request_start(_province_id, difficulty)

func _request_start(province: String, difficulty: String) -> void:
    var access := province_availability(province)
    if not access.unlocked or difficulty not in access.difficulties:
        return
    if _has_active_attempt(snapshot().session):
        _ask("Replace the active attempt? Your historical best records will be kept.",
            {"action": "start", "origin": _view, "province": province, "difficulty": difficulty})
    else:
        _start(province, difficulty)

func _has_active_attempt(session: Variant) -> bool:
    return session != null and session.state in [Session.AWAITING, Session.FEEDBACK]

func _start(province: String, difficulty: String) -> void:
    if _committing or _recovery_required:
        return
    _committing = true
    var error := _store.start_session(Crypto.new().generate_random_bytes(16).hex_encode(), province, difficulty)
    _committing = false
    if error.is_empty():
        _cancel_presentation()
        _highlight.clear()
        _province_id = province
        _show_session()
    else:
        _show_write_error(error)

func _ask(message: String, decision: Dictionary) -> void:
    _decision = decision
    _confirm.get_node("Details").text = message
    _show("confirm", _confirm)

func _cancel_decision() -> void:
    if _view != "confirm":
        return
    var origin: String = _decision.origin
    _decision = {}
    if origin == "diagnostic":
        _restore()
    elif origin == "pause":
        _show("pause", _pause)
    else:
        _show_difficulty()

func _confirm_decision() -> void:
    if _view != "confirm" or _decision.is_empty() or _committing:
        return
    var decision := _decision
    if decision.action == "start":
        _cancel_decision()
        _start(decision.province, decision.difficulty)
        return
    _decision = {}
    _committing = true
    # Store recovery methods refresh eligibility using the captured generation.
    var error := ""
    match decision.action:
        "promote":
            error = _store.recover_staged(decision.generation)
        "defer":
            error = _store.defer_staged(decision.generation)
        "committed":
            error = _store.recover_committed(decision.generation, decision.latest)
    _committing = false
    _restore()
    if not error.is_empty():
        _show_error("Recovery decision could not be applied: " + error.replace("_", " "))

func _show_settings(origin: String) -> void:
    if _view != origin:
        return
    _settings_origin = origin
    _sync_settings()
    _show("settings", _settings)
    if not _preferences.storage_error.is_empty():
        _show_error("Preferences are unavailable: " + _preferences.storage_error)

func _sync_settings() -> void:
    for key in ["music", "effects"]:
        var volume: float = _preferences.values[key]
        _settings.get_node(key.capitalize()).set_value_no_signal(volume)
        _settings.get_node(key.capitalize() + "Label").text = "%s volume · %d%%" % ["Music" if key == "music" else "Sound effects", roundi(volume * 100.0)]
    _settings.get_node("Motion").set_pressed_no_signal(_preferences.values.reduced_motion)

func _change_preference(value: Variant, key: String) -> void:
    if _view != "settings":
        return
    var saved := _preferences.update(key, value)
    if saved and key == "reduced_motion":
        _effects.update_motion(value)
    _sync_settings()
    _error_label.visible = false
    if not saved:
        _show_error("The preference could not be saved. " + _preferences.storage_error)

func _back_from_settings() -> void:
    if _view == "settings":
        if _settings_origin == "pause":
            _show("pause", _pause)
        else:
            _show_menu()

func _show_session(restore_scroll: bool = false) -> void:
    if _recovery_required:
        return
    var session: Variant = snapshot().session
    if session == null:
        return
    if session.state in [Session.VICTORY, Session.FAILURE]:
        _show_result(session)
        return
    var id: String = session.questionIds[session.questionIndex]
    var question: Dictionary = _questions[id]
    var accepting: bool = session.state == Session.AWAITING
    var correct: bool = session.feedbackOutcome == "correct"
    _update_hud(session)
    _play.get_node("PromptRow/Question/Context").text = "%s  ·  %s" % [_name(session.provinceId), session.difficulty.capitalize()]
    _play.get_node("PromptRow/Question/Prompt").text = question.prompt
    _can.set_knocked(correct)
    _answers.display_answers(question, session.optionOrderByQuestion[id], session.rejectedOptionIdsByQuestion.get(id, []), accepting)
    _hint.visible = Session.hint_available(session)
    _hint.text = "Hint: " + question.hint if _hint.visible else ""
    _feedback.visible = session.state == Session.FEEDBACK
    _feedback.get_node("Acknowledge").disabled = not _feedback.visible
    _feedback.get_node("Message").text = ""
    if _feedback.visible:
        _feedback.get_node("Message").text = "Correct. " + question.explanation if correct else "Miss. Try another answer."
        _feedback.get_node("Acknowledge").text = "Continue" if correct else "Try again"
    _show("play", _play, restore_scroll)

func _update_hud(session: Dictionary) -> void:
    _hud.get_node("Status").text = "Question %d of %d     Score %d     Misses %d / %d" % [
        session.questionIndex + 1, Session.QUESTION_COUNT, session.score, session.misses, Session.MISS_LIMIT,
    ]

func presentation_state() -> String:
    if _committing:
        return "submitting"
    if _view == "pause" or _backgrounded:
        return "paused"
    if not _effects.phase.is_empty():
        return _effects.phase
    return "feedback" if _view == "play" and _feedback.visible else "idle"

func _submit_answer(question_id: String, option_id: String) -> void:
    if _view != "play" or presentation_state() != "idle":
        return
    var session: Variant = snapshot().session
    if session == null or session.state != Session.AWAITING or session.questionIds[session.questionIndex] != question_id:
        return
    var source: Control = _answers.button_for(option_id)
    if source == null or source.disabled:
        return
    var command := JSON.stringify([session.sessionId, question_id, option_id]).sha256_text()
    _committing = true
    _answers.lock_answers()
    _feedback.get_node("Acknowledge").disabled = true
    _error_label.hide()
    var error := _store.submit_answer(session.sessionId, question_id, option_id, command)
    _committing = false
    if not error.is_empty():
        _show_session()
        _show_write_error(error)
        return
    var committed: Dictionary = snapshot().session
    _presentation_token += 1
    _presented_session = committed.sessionId
    _pending_answer = {"outcome": committed.feedbackOutcome, "question": question_id, "option": option_id, "terminal": committed.state == Session.FAILURE}
    _effects.source = source
    _effects.target = _can
    _effects.correct = committed.feedbackOutcome == "correct"
    _effects.capture_launch(_scroll)
    _can.stop_idle()
    _begin_phase("throw")

func _begin_phase(phase: String) -> void:
    _effects.begin(phase, _presentation_token, _presented_session, _preferences.values.reduced_motion)

func _phase_finished(phase: String, token: int, session_id: String) -> void:
    if token != _presentation_token or session_id != _presented_session or _view not in ["play", "result"]:
        return
    var session: Variant = snapshot().session
    if session == null or session.sessionId != session_id:
        _cancel_presentation()
        return
    match phase:
        "throw":
            _begin_phase("impact" if _effects.correct else "miss")
        "miss":
            if _pending_answer.terminal:
                _update_hud(session)
                _begin_phase("failure")
            else:
                _finish_answer()
        "impact", "failure":
            _finish_answer()
        "victory":
            _set_result_locked(false)

func _finish_answer() -> void:
    var answered := _pending_answer
    _cancel_presentation()
    _show_session()
    _committing = true
    answer_presented.emit(answered.outcome, answered.question, answered.option)
    _committing = false

func _presentation_frame(phase: String, ratio: float) -> void:
    if phase in ["impact", "miss"]:
        _can.impact(ratio, phase == "impact", _effects.reduced)
    elif phase == "failure":
        var shift := 0.0 if _effects.reduced else sin(ratio * TAU * 6.0) * (1.0 - ratio) * 9.0
        SafeLayout.apply($Margin, shift)
    elif phase == "victory":
        _result.get_node("Stars").text = "★".repeat(floori(ratio * float(snapshot().session.stars)))

func _cancel_presentation() -> void:
    _presentation_token += 1
    _presented_session = ""
    _pending_answer = {}
    _effects.cancel()
    _apply_layout()

func _acknowledge() -> void:
    if _view != "play" or presentation_state() != "feedback":
        return
    var before := snapshot()
    var session: Dictionary = before.session
    _committing = true
    var error := _store.acknowledge_feedback(session.sessionId, session.processedSubmissions.back().commandId)
    _committing = false
    if not error.is_empty():
        _show_write_error(error)
        return
    var after := snapshot()
    if after.session.state == Session.VICTORY:
        _highlight = after.progress.unlockedProvinceIds.filter(func(id): return id not in before.progress.unlockedProvinceIds)
        _presentation_token += 1
        _presented_session = after.session.sessionId
        _show_result(after.session)
        _set_result_locked(true)
        _begin_phase("victory")
    else:
        _show_session()

func _show_pause() -> void:
    if not _committing and _view == "play":
        if not _restoring_play_scroll:
            _paused_scroll = _scroll.scroll_vertical
        _apply_layout()
        _show("pause", _pause)

func _resume_pause() -> void:
    if _view != "pause":
        return
    if _effects.phase.is_empty():
        _show_session(true)
    else:
        _show("play", _play, true)

func _replay() -> void:
    if _view in ["pause", "result"] and (_view == "pause" or _effects.phase.is_empty()):
        var session: Dictionary = snapshot().session
        _request_start(session.provinceId, session.difficulty)

func _continue_result() -> void:
    if _view == "result" and _effects.phase.is_empty():
        var session: Dictionary = snapshot().session
        var focus: String = session.provinceId
        if not _highlight.is_empty():
            focus = _highlight[0]
        elif session.state == Session.VICTORY:
            for route in _campaign.routes:
                if route.fromProvinceId == session.provinceId and province_availability(route.toProvinceId).unlocked:
                    focus = route.toProvinceId
                    break
        _show_map(focus)

func _show_result(session: Dictionary) -> void:
    var victory: bool = session.state == Session.VICTORY
    _result.get_node("Title").text = "Province completed" if victory else "Out of attempts"
    _result.get_node("Summary").text = "%s  ·  %s\nScore %d    Misses %d / %d    Stars %d" % [
        _name(session.provinceId), session.difficulty.capitalize(), session.score, session.misses, Session.MISS_LIMIT, session.stars,
    ]
    _result.get_node("Stars").text = "★".repeat(session.stars)
    _result.get_node("Stars").visible = victory
    _result.get_node("Progress").text = _route_summary()
    _result.get_node("Replay").text = "Replay" if victory else "Retry"
    _set_result_locked(false)
    _show("result", _result)

func _set_result_locked(locked: bool) -> void:
    _result.get_node("Replay").disabled = locked
    _result.get_node("Return").disabled = locked

func _route_summary() -> String:
    var routes := PackedStringArray()
    if not _highlight.is_empty():
        routes.append("Newly unlocked: " + _province_list(_highlight))
    for province in _campaign.provinces:
        var id: String = province.provinceId
        if id == _province_id:
            continue
        var access := province_availability(id)
        var info := _province_state(id)
        if access.unlocked and access.difficulties.is_empty():
            info += ". Questions coming later."
        routes.append("%s — %s" % [_name(id), info])
    return "\n".join(routes)

func _show(view: String, panel: Control, restore_scroll: bool = false) -> void:
    _view = view
    _hud.visible = view == "play"
    for child in _panels.get_children():
        child.visible = child == panel
    _restoring_play_scroll = restore_scroll and _paused_scroll > 0
    if _restoring_play_scroll:
        _restore_play_scroll.call_deferred(_presentation_token)
    else:
        _scroll.scroll_vertical = 0
    _suspend_effects()
    view_changed.emit(view)

func _suspend_effects() -> void:
    _effects.suspended = _backgrounded or _restoring_play_scroll or _view not in ["play", "result"]
    _effects.queue_redraw()

func _restore_play_scroll(token: int) -> void:
    # The shared ScrollContainer must lay out the visible gameplay panel again
    # before it can clamp the old offset to the new content height.
    await get_tree().process_frame
    if _view != "play" or token != _presentation_token or not _restoring_play_scroll:
        return
    _scroll.scroll_vertical = _paused_scroll
    _restoring_play_scroll = false
    _suspend_effects()

func _notification(what: int) -> void:
    if not is_node_ready():
        return
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
        _backgrounded = what == NOTIFICATION_APPLICATION_PAUSED
        _suspend_effects()
        _apply_layout()

func _process(delta: float) -> void:
    if _preferences != null and not _preferences.values.reduced_motion and _view == "play" and not _backgrounded and _effects.phase.is_empty() and not _feedback.visible:
        _idle_time += delta
        _can.idle(_idle_time)

func _apply_layout() -> void:
    SafeLayout.apply($Margin)
    $Backdrop.queue_redraw()

func _show_write_error(error: String) -> void:
    if error == "commit_failed":
        var loaded := _store.restore()
        if not loaded.error.is_empty():
            _show_restore(loaded)
            return
        if _view == "play" and _effects.phase.is_empty():
            if snapshot().session == null:
                _show_menu()
            else:
                _show_session()
    _show_error("Action could not be saved. Try again. (%s)" % error.replace("_", " "))

func _show_error(message: String) -> void:
    _error_label.text = message
    _error_label.show()

func _add_action(parent: Container, key: String, label: String, action: Callable) -> Button:
    var button := Button.new()
    button.name = key
    button.custom_minimum_size.y = 48.0
    button.text = label
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _clear_children(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()
