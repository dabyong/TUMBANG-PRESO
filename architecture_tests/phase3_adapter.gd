extends SceneTree

const Repository = preload("res://scripts/domain/save_repository.gd")
const Store = preload("res://scripts/domain/gameplay_store.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const Progress = preload("res://scripts/domain/campaign_progress.gd")
const Payload = preload("res://scripts/domain/gameplay_payload.gd")

class InterruptibleRepository extends Repository:
    var interrupt_write := false

    func _commit(generation: int, validate_payload: Callable) -> bool:
        if not interrupt_write:
            return super._commit(generation, validate_payload)
        interrupt_write = false
        var file := FileAccess.open(_directory.path_join(_filename(generation, true)), FileAccess.WRITE)
        if file != null:
            file.store_string("{interrupted")
            file.close()
        return false

var _repository: InterruptibleRepository
var _store: Store
var _campaign: Dictionary
var _catalog := {"schemaVersion": 1, "mode": "foundation", "questions": []}
var _checkpoints := {}
var _corrupted := {}
var _directory: String
var _recovery_error := ""
var _interrupted := false
var _last_write_base := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2:
        _fail("request and response paths are required")
        return
    var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    if not request is Dictionary or request.get("protocolVersion") != 1 or not request.get("operations") is Array:
        _fail("invalid protocol request")
        return
    _directory = args[0].get_base_dir()
    _repository = InterruptibleRepository.new(_directory)
    _campaign = JSON.parse_string(FileAccess.get_file_as_string("res://content/campaign/campaign.json"))
    _load_fixture_content(request.operations)
    _restart()
    if not _recovery_error.is_empty():
        _fail(_recovery_error)
        return
    for operation in request.operations:
        var generation := _committed_generation()
        var error := _operate(operation)
        if not error.is_empty():
            _fail("%s: %s" % [operation, error])
            return
        if _committed_generation() > generation:
            _last_write_base = generation
    var output := FileAccess.open(args[1], FileAccess.WRITE)
    if output == null:
        _fail("cannot open response file")
        return
    output.store_string(JSON.stringify({"protocolVersion": 1, "checkpoints": _checkpoints}))
    output.close()
    quit()

func _load_fixture_content(operations: Array) -> void:
    var by_id := {}
    for operation in operations:
        if operation.op != "start":
            continue
        _catalog.mode = "playable"
        for item in operation.questions:
            var id := _question_id(operation.provinceId, operation.difficulty, item.questionId)
            if by_id.has(id):
                continue
            by_id[id] = true
            var options := []
            for option_id in item.answerOptionIds:
                options.append({"optionId": option_id, "text": option_id})
            _catalog.questions.append({
                "questionId": id, "provinceId": operation.provinceId, "difficulty": operation.difficulty,
                "category": "fixture", "prompt": "Fixture question " + item.questionId, "languageId": "en",
                "contentVersion": "phase3-1", "source": {"title": "Fixture", "reference": "Acceptance tests"},
                "options": options, "correctOptionId": item.correctOptionId, "verificationStatus": "approved",
                "hint": item.hint, "explanation": "Fixture explanation",
            })
            for province in _campaign.provinces:
                if province.provinceId == operation.provinceId:
                    province.questionPools[operation.difficulty].append(id)

func _operate(operation: Dictionary) -> String:
    match operation.op:
        "start":
            var ids := []
            var orders := {}
            for item in operation.questions:
                var id := _question_id(operation.provinceId, operation.difficulty, item.questionId)
                ids.append(id)
                orders[id] = item.answerOptionIds
            return _store.start_session(operation.sessionId, operation.provinceId, operation.difficulty,
                {"questionIds": ids, "optionOrderByQuestion": orders})
        "answer":
            return _answer(operation)
        "acknowledgeFeedback":
            return _acknowledge()
        "restart":
            _restart()
            _interrupted = false
            if _recovery_error.is_empty() and not operation.get("holdFeedback", false):
                return _acknowledge()
        "corruptNewestSlot", "corruptBothSlots":
            return _corrupt(operation.op == "corruptBothSlots")
        "recordSuccessfulRun":
            var candidate := _store.snapshot()
            Progress.merge_success(candidate.progress, _campaign, operation.provinceId, operation.difficulty, operation.score, operation.stars)
            if _repository.publish(candidate, -1, Payload.validate.bind(_campaign, {}, "")) == 0:
                return "record commit failed"
            _restart()
            return _recovery_error
        "capture":
            _checkpoints[operation.name] = _capture()
        _:
            return "unknown operation"
    return ""

func _answer(operation: Dictionary) -> String:
    if _interrupted:
        return "restart required after interruption"
    var session: Variant = _store.snapshot().get("session")
    if session == null:
        return "answer without an active session"
    var interruption: String = operation.get("interruptAt", "")
    _repository.interrupt_write = interruption == "midTempWrite"
    var id := _question_id(session.provinceId, session.difficulty, operation.questionId)
    var error := _store.submit_answer(operation.get("sessionId", session.sessionId), id, operation.optionId, operation.commandId)
    if interruption == "midTempWrite":
        _interrupted = true
        return "" if error == "commit_failed" and not _repository.interrupt_write else "write was not interrupted"
    if error in ["duplicate_command", "rejected_option", "stale_question", "state_blocks_answer", "wrong_session", "invalid_option"]:
        return ""
    if not error.is_empty():
        return error
    if interruption == "afterSlotWriteBeforeFeedback":
        _interrupted = true
        return ""
    var feedback_error := _acknowledge()
    if interruption == "afterTerminalCommitBeforeResults":
        _interrupted = true
        if _store.snapshot().session.state not in [Session.VICTORY, Session.FAILURE]:
            return "expected a terminal commit"
    return feedback_error

func _acknowledge() -> String:
    var session: Variant = _store.snapshot().get("session")
    if session != null and session.state == Session.FEEDBACK:
        return _store.acknowledge_feedback(session.sessionId, session.processedSubmissions.back().commandId)
    return ""

func _restart() -> void:
    _store = Store.new(_repository, _campaign, _catalog)
    _recovery_error = _store.restore().error

func _corrupt(all: bool) -> String:
    var loaded := _repository.load_latest()
    var generations: Array = loaded.verifiedCommitted
    if not all:
        # A fixture slot represented one logical answer, including automatic
        # feedback acknowledgement. Damage all writes for that answer.
        generations = generations.filter(func(generation: int) -> bool: return generation > _last_write_base)
    if generations.is_empty():
        return "no committed snapshot to corrupt"
    for generation in generations:
        var path := _directory.path_join("tp-save-%d.json" % generation)
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null or generation == 0:
            return "no committed snapshot to corrupt"
        file.store_string("{damaged")
        file.close()
        _corrupted[path] = "{damaged"
    return ""

func _committed_generation() -> int:
    return int(_repository.load_latest().snapshot.get("generation", 0))

func _capture() -> Dictionary:
    if not _recovery_error.is_empty():
        var preserved := not _corrupted.is_empty()
        for path in _corrupted:
            preserved = preserved and FileAccess.get_file_as_string(path) == _corrupted[path]
        return {"state": "RecoveryRequired", "filesPreserved": preserved, "error": _recovery_error}
    var snapshot := _store.snapshot()
    if snapshot.session == null:
        return {"records": snapshot.progress.records, "progress": snapshot.progress}
    var session: Dictionary = snapshot.session
    session.hintAvailable = Session.hint_available(session)
    session.progress = snapshot.progress
    for field in ["optionOrderByQuestion", "rejectedOptionIdsByQuestion", "incorrectAttemptsByQuestion", "resolvedAnswerIds"]:
        var mapped := {}
        for id in session[field]:
            mapped[_fixture_id(id)] = session[field][id]
        session[field] = mapped
    for index in range(session.questionIds.size()):
        session.questionIds[index] = _fixture_id(session.questionIds[index])
    for command in session.processedSubmissions:
        command.questionId = _fixture_id(command.questionId)
    return session

func _question_id(province: String, difficulty: String, id: String) -> String:
    return "%s:%s:%s" % [province, difficulty, id]

func _fixture_id(id: String) -> String:
    return id.split(":", true, 2)[2]

func _fail(message: String) -> void:
    printerr(message)
    quit(1)
