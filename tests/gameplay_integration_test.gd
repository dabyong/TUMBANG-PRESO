extends SceneTree

const Boot = preload("res://scenes/boot.tscn")
const BootScript = preload("res://scripts/app/boot.gd")
const Gameplay = preload("res://scenes/gameplay/gameplay.tscn")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Store = preload("res://scripts/domain/gameplay_store.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const PANELS := "Margin/Frame/Scroll/Panels/"
const HUD := "Margin/Frame/HUD/"
const ANSWERS := PANELS + "Play/Answers"
const FEEDBACK := PANELS + "Play/Feedback/"
const HINT := PANELS + "Play/Hint"

class InvalidCampaignBoot extends BootScript:
    func _read_json(path: String) -> Dictionary:
        var data := super._read_json(path)
        if path == "res://content/campaign/campaign.json":
            data.provinces[1] = null
        return data

class ControlledRepository extends Repository:
    var block_write := false

    func publish(payload: Dictionary, expected_generation: int = -1, validate_payload: Callable = Callable()) -> int:
        if block_write:
            return 0
        return super.publish(payload, expected_generation, validate_payload)

var _counts := [0, 0]
var _campaign: Dictionary
var _catalog: Dictionary
var _questions := {}
var _paths: Array[String] = []
var _capture_dir := ""

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _campaign = JSON.parse_string(FileAccess.get_file_as_string("res://content/campaign/campaign.json"))
    _catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/questions/catalog.json"))
    for question in _catalog.questions:
        _questions[question.questionId] = question
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="):
            _capture_dir = arg.trim_prefix("--capture-dir=")
    var viewport := SubViewport.new()
    viewport.size = Vector2i(960, 540)
    if not _capture_dir.is_empty():
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    await _test_journey(viewport)
    await _test_write_failure(viewport)
    _test_recovery(viewport)
    _test_invalid_content(viewport)
    viewport.free()
    for path in _paths:
        var directory := DirAccess.open(path)
        if directory != null:
            for filename in directory.get_files():
                directory.remove(filename)
            DirAccess.remove_absolute(path)
    print("Gameplay integration checks: %d passed, %d failed" % _counts)
    quit(0 if _counts[1] == 0 else 1)

func _test_journey(viewport: SubViewport) -> void:
    var folder := _folder("journey")
    var boot := _boot(viewport, folder)
    await process_frame
    await process_frame
    var play_button: Button = boot.get_node("Content/Play")
    _check(not play_button.disabled, "production boot enables entry")
    var game: Control = boot.get_node("Gameplay")
    var center := play_button.get_global_rect().get_center()
    _pointer_click(viewport, center)
    _check(game.visible and game.get_node(PANELS + "Entry").visible, "a mouse click opens the province entry")
    _choose(game, "Normal")
    var initial := _session(game)
    if initial.is_empty():
        _check(false, "difficulty selection starts a committed session")
        return
    _check(initial.difficulty == "normal" and initial.questionIds.size() == 5, "normal session contains five questions")
    _check(not game.get_node(HINT).visible, "normal opens without a hint")
    _assert_mapping(game, initial)
    await _capture(viewport, "batanes-question.png")
    var wrong_options := _incorrect(initial)
    var wrong: String = wrong_options[0]
    var presentations: Array[String] = []
    game.answer_presented.connect(func(outcome: String, _question: String, _option: String): presentations.append(outcome))
    await process_frame
    await process_frame
    var first_answer := _option(game, wrong)
    _pointer_click(viewport, first_answer.get_global_rect().get_center())
    _answer(game, wrong_options[1])
    _answer(game, wrong)
    var missed := _session(game)
    _check(missed.state == Session.FEEDBACK and missed.misses == 1 and presentations == ["incorrect"] and missed.processedSubmissions.size() == 1, "rapid taps commit and present only once")
    _check(game.get_node(FEEDBACK + "Message").text == "Miss. Try another answer.", "incorrect feedback discloses no answer")
    boot.free()

    boot = _boot(viewport, folder)
    game = _enter_saved(boot)
    _check(_session(game) == missed and game.get_node(FEEDBACK + "Message").text == "Miss. Try another answer.", "restores pending incorrect feedback")
    _assert_mapping(game, missed)
    _press(game, FEEDBACK + "Acknowledge")
    var retry := _session(game)
    _check(retry.questionIndex == 0 and game.get_node(HINT).visible, "normal hint unlocks after one miss and stays on the question")
    var rejected := _option(game, wrong)
    _check(rejected != null and rejected.disabled and rejected.text.ends_with("(tried)"), "rejected tsinela is labelled and disabled")
    _answer(game, wrong)
    _check(_session(game) == retry, "a rejected retry does not mutate the snapshot")
    _answer(game, _correct(retry))
    var correct_feedback := _session(game)
    _check(correct_feedback.state == Session.FEEDBACK and correct_feedback.questionIndex == 0 and correct_feedback.score == 75, "correct score commits before acknowledgement")
    _check(game.get_node(FEEDBACK + "Message").text == "Correct. " + _question(retry).explanation, "correct feedback shows the sourced explanation")
    await _capture(viewport, "batanes-feedback.png")
    boot.free()

    viewport.size = Vector2i(640, 360)
    boot = _boot(viewport, folder)
    game = _enter_saved(boot)
    _check(_session(game) == correct_feedback and game.get_node(FEEDBACK + "Message").text.begins_with("Correct."), "restores pending correct feedback and its mapping")
    _press(game, FEEDBACK + "Acknowledge")
    _check(_session(game).questionIndex == 1 and not game.get_node(HINT).visible, "acknowledgement advances and resets the hint")
    await process_frame
    await process_frame
    var scroll: ScrollContainer = game.get_node("Margin/Frame/Scroll")
    var buttons: VBoxContainer = game.get_node(ANSWERS)
    _check(scroll.size.x <= viewport.size.x and buttons.get_combined_minimum_size().x <= scroll.size.x and scroll.get_v_scroll_bar().visible, "compact landscape layout fits width and scrolls")
    scroll.ensure_control_visible(buttons.get_child(4))
    await process_frame
    _check(scroll.scroll_vertical > 0 and scroll.get_global_rect().intersects(buttons.get_child(4).get_global_rect()), "compact layout can reach the fifth tsinela")
    var hud: Label = game.get_node(HUD + "Status")
    _check(hud.is_visible_in_tree() and hud.get_global_rect().end.y <= scroll.get_global_rect().position.y, "score and misses remain visible while compact answers scroll")
    await _capture(viewport, "batanes-compact.png")
    for _index in range(4):
        _correct_and_continue(game)
    var victory := _session(game)
    _check(game.get_node(PANELS + "Result").visible and victory.state == Session.VICTORY and victory.score == 475 and victory.stars == 3, "victory presents committed score and stars")
    _check(game.province_availability("cagayan") == {"unlocked": true, "difficulties": []} and game.get_node(PANELS + "Result/Progress").text.contains("Cagayan — Unlocked"), "Cagayan unlocks and remains unavailable for play")
    await _capture(viewport, "batanes-victory.png")
    boot.free()

    boot = _boot(viewport, folder)
    game = _enter_saved(boot)
    _check(_session(game) == victory and game.get_node(PANELS + "Result").visible, "terminal victory restores")
    _press(game, PANELS + "Result/Replay")
    _check(_session(game).sessionId != victory.sessionId and _session(game).difficulty == "normal", "replay creates a fresh session with the same difficulty")
    for option in _incorrect(_session(game)):
        _answer(game, option)
        _press(game, FEEDBACK + "Acknowledge")
    _correct_and_continue(game)
    _answer(game, _incorrect(_session(game))[0])
    var failure := _session(game)
    _check(failure.state == Session.FAILURE and failure.misses == 5 and failure.stars == 0 and failure.score == 10, "fifth miss presents terminal failure")
    _check(game.snapshot().progress.records["batanes/normal"].bestScore == 475, "failure preserves the earlier win")
    boot.free()

    boot = _boot(viewport, folder)
    game = _enter_saved(boot)
    _check(_session(game) == failure and game.get_node(PANELS + "Result/Replay").text == "Retry", "terminal failure restores with a Retry control")
    _press(game, PANELS + "Result/Replay")
    var fresh := _session(game)
    _check(fresh.sessionId != failure.sessionId and fresh.misses == 0, "retry starts with a new ID and zero misses")
    _press(game, HUD + "Pause")
    _check(game.get_node(PANELS + "Pause").visible, "pause presents usable controls")
    _press(game, PANELS + "Pause/Resume")
    _check(_session(game) == fresh and game.get_node(PANELS + "Play").visible, "pause and resume leave the snapshot unchanged")
    _press(game, HUD + "Pause")
    _press(game, PANELS + "Pause/Return")
    _press(game, PANELS + "Entry/New")
    _check(game.get_node(PANELS + "Difficulty/Notice").text.contains("replaces the active attempt") and _session(game) == fresh, "leaving an active session requires a deliberate new difficulty selection")
    _press(game, PANELS + "Difficulty/Easy")
    _check(_session(game).difficulty == "easy" and game.get_node(HINT).visible, "easy starts with a hint")
    for _index in range(5):
        _correct_and_continue(game)
    var records: Dictionary = game.snapshot().progress.records
    _check(records["batanes/easy"] == {"bestScore": 500, "bestStars": 3} and records["batanes/normal"] == {"bestScore": 475, "bestStars": 3}, "best records are independent by difficulty")
    _press(game, PANELS + "Result/Return")
    _choose(game, "Hard")
    _check(_session(game).difficulty == "hard" and not game.get_node(HINT).visible, "hard starts without a hint")
    var hard_wrong := _incorrect(_session(game))
    _answer(game, hard_wrong[0])
    _press(game, FEEDBACK + "Acknowledge")
    _check(not game.get_node(HINT).visible, "hard stays without a hint after one miss")
    _answer(game, hard_wrong[1])
    _press(game, FEEDBACK + "Acknowledge")
    _check(game.get_node(HINT).visible, "hard reveals the hint after two misses")
    var active := _session(game)
    boot.free()
    boot = _boot(viewport, folder)
    game = _enter_saved(boot)
    _check(_session(game) == active and game.get_node(HINT).visible, "interrupted awaiting-answer session restores its active hint and misses")
    _assert_mapping(game, active)
    boot.free()

func _test_write_failure(viewport: SubViewport) -> void:
    var repository := ControlledRepository.new(_folder("failed-write"))
    var game := Gameplay.instantiate()
    viewport.add_child(game)
    game.configure(repository, _campaign, _catalog)
    _choose(game, "Easy")
    var initial := _session(game)
    if initial.is_empty():
        _check(false, "write failure fixture starts")
        return
    var events: Array[String] = []
    game.answer_presented.connect(func(outcome: String, _question: String, _option: String): events.append(outcome))
    repository.block_write = true
    _answer(game, _correct(initial))
    _check(_session(game) == initial and events.is_empty() and not game.get_node(PANELS + "Play/Feedback").visible, "failed write shows no score or feedback")
    _check(game.get_node(PANELS + "Error").visible, "failed write displays a retry message")
    repository.block_write = false
    _answer(game, _correct(initial))
    var feedback := _session(game)
    var question_id: String = initial.questionIds[0]
    var stable_command := JSON.stringify([initial.sessionId, question_id, _correct(initial)]).sha256_text()
    _check(feedback.processedSubmissions.size() == 1 and feedback.processedSubmissions[0].commandId == stable_command and events == ["correct"], "retry uses its stable command and emits only after commit")
    repository.block_write = true
    _press(game, FEEDBACK + "Acknowledge")
    _check(_session(game) == feedback and game.get_node(PANELS + "Play/Feedback").visible, "failed acknowledgement keeps committed feedback and question index")
    repository.block_write = false
    _press(game, FEEDBACK + "Acknowledge")
    _check(_session(game).questionIndex == 1, "successful acknowledgement retry advances")
    game.free()
    await process_frame

func _test_recovery(viewport: SubViewport) -> void:
    var variant_catalog := _catalog.duplicate(true)
    variant_catalog.contentVersion = "pre-production-test"
    for reason in ["pending recovery", "unsupported save schema", "catalog version mismatch", "unsupported gameplay payload"]:
        var folder := _folder("recovery")
        var repo := Repository.new(folder)
        var store := Store.new(repo, _campaign, variant_catalog if reason == "catalog version mismatch" else _catalog)
        store.restore()
        _check(store.start_session("existing", "batanes", "easy") == "", "recovery fixture has a committed session")
        match reason:
            "pending recovery":
                _write_stage(folder, Repository.SCHEMA_VERSION, store.snapshot())
            "unsupported save schema":
                _write_stage(folder, Repository.SCHEMA_VERSION + 1, {})
            "unsupported gameplay payload":
                repo.save({})
        var reported: Dictionary = repo.load_latest()
        var boot := _boot(viewport, folder)
        var game: Control = boot.get_node("Gameplay")
        _check(game.visible and game.get_node(PANELS + "Diagnostic").visible and game.get_node(PANELS + "Diagnostic/Details").text.contains(reason), "boot displays " + reason)
        _press(game, PANELS + "Entry/New")
        _press(game, PANELS + "Difficulty/Easy")
        _press(game, PANELS + "Diagnostic/Retry")
        _check(not game.get_node(PANELS + "Play").visible and repo.load_latest().highestGeneration == reported.highestGeneration, "diagnostic recheck blocks gameplay and preserves files")
        boot.free()

func _test_invalid_content(viewport: SubViewport) -> void:
    var folder := _folder("invalid-content")
    var store := Store.new(Repository.new(folder), _campaign, _catalog)
    store.restore()
    _check(store.start_session("existing", "batanes", "easy") == "", "content error fixture has a committed save")
    _write_stage(folder, Repository.SCHEMA_VERSION, store.snapshot())
    var files := DirAccess.get_files_at(folder)
    var contents := {}
    for filename in files:
        contents[filename] = FileAccess.get_file_as_bytes(folder.path_join(filename))

    var boot := Boot.instantiate()
    boot.set_script(InvalidCampaignBoot)
    boot.save_directory = folder
    viewport.add_child(boot)
    _check(boot.get_node("Content/Status").text == "Content validation error", "malformed campaign shows the boot content error")
    _check(boot.get_node("Content/Play").disabled and not boot.has_node("Gameplay") and not root.get_node("AppState").offline_ready, "content error blocks gameplay before save recovery")
    var intact := files.size() == 2 and DirAccess.get_files_at(folder) == files
    for filename in files:
        intact = intact and FileAccess.get_file_as_bytes(folder.path_join(filename)) == contents[filename]
    _check(intact, "content error preserves committed and staged save bytes")
    boot.free()

func _assert_mapping(game: Control, session: Dictionary) -> void:
    var question := _question(session)
    var answers: VBoxContainer = game.get_node(ANSWERS)
    var labels := {}
    for option in question.options:
        labels[option.optionId] = option.text
    var mapped := []
    var text_matches := true
    for button in answers.get_children():
        mapped.append(button.option_id)
        text_matches = text_matches and button.question_id == question.questionId and button.text.strip_edges().trim_suffix(" (tried)") == labels.get(button.option_id)
    _check(answers.get_child_count() == 5 and mapped == session.optionOrderByQuestion[question.questionId] and text_matches, "five tsinelas present exact saved order, labels, and option IDs")

func _boot(viewport: SubViewport, folder: String) -> Control:
    var boot := Boot.instantiate()
    boot.save_directory = folder
    viewport.add_child(boot)
    return boot

func _enter_saved(boot: Control) -> Control:
    _press(boot, "Content/Play")
    var game: Control = boot.get_node("Gameplay")
    _press(game, PANELS + "Entry/Resume")
    return game

func _choose(game: Control, difficulty: String) -> void:
    _press(game, PANELS + "Entry/New")
    _press(game, PANELS + "Difficulty/" + difficulty)

func _session(game: Control) -> Dictionary:
    var session: Variant = game.snapshot().get("session")
    return session if session is Dictionary else {}

func _question(session: Dictionary) -> Dictionary:
    return _questions[session.questionIds[session.questionIndex]]

func _correct(session: Dictionary) -> String:
    return _question(session).correctOptionId

func _incorrect(session: Dictionary) -> Array:
    var question := _question(session)
    return session.optionOrderByQuestion[question.questionId].filter(func(id: String) -> bool: return id != question.correctOptionId)

func _option(game: Control, option_id: String) -> Button:
    for button in game.get_node(ANSWERS).get_children():
        if button.option_id == option_id:
            return button
    return null

func _answer(game: Control, option_id: String) -> void:
    var button := _option(game, option_id)
    if button != null:
        button.pressed.emit()

func _correct_and_continue(game: Control) -> void:
    _answer(game, _correct(_session(game)))
    _press(game, FEEDBACK + "Acknowledge")

func _press(game: Control, path: String) -> void:
    game.get_node(path).pressed.emit()

func _pointer_click(viewport: SubViewport, position: Vector2) -> void:
    var motion := InputEventMouseMotion.new()
    motion.position = position
    viewport.push_input(motion, true)
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.position = position
        event.pressed = pressed
        viewport.push_input(event, true)

func _capture(viewport: SubViewport, filename: String) -> void:
    if _capture_dir.is_empty():
        return
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    _check(screenshot != null and screenshot.save_png(_capture_dir.path_join(filename)) == OK, "capture " + filename)

func _write_stage(folder: String, schema: int, payload: Dictionary) -> void:
    var body := JSON.stringify({"generation": 2, "schemaVersion": schema, "payload": payload})
    var file := FileAccess.open(folder.path_join("tp-save-2.pending"), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"body": body, "sha256": body.sha256_text()}))
        file.close()
    else:
        _check(false, "staged fixture file opens")

func _folder(tag: String) -> String:
    var folder := "user://gameplay-integration-%d-%d-%s" % [OS.get_process_id(), _paths.size(), tag]
    _check(DirAccess.make_dir_absolute(folder) == OK, "isolated " + tag + " directory")
    _paths.append(folder)
    return folder

func _check(ok: bool, message: String) -> void:
    _counts[0 if ok else 1] += 1
    if not ok:
        push_error("FAIL: " + message)
