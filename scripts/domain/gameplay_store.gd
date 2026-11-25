class_name GameplayStore
extends RefCounted

const Graph = preload("res://scripts/domain/campaign_graph.gd")
const Content = preload("res://scripts/domain/content_validator.gd")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const Progress = preload("res://scripts/domain/campaign_progress.gd")
const Payload = preload("res://scripts/domain/gameplay_payload.gd")

var _repository: Repository
var _campaign: Dictionary
var _questions := {}
var _version: String
var _content_valid: bool
var _payload := {}
var _generation := 0
var _error := "restore_required"

func _init(repository: Repository, campaign: Dictionary, catalog: Dictionary) -> void:
    _repository = repository
    _campaign = campaign.duplicate(true)
    _content_valid = Graph.validate(_campaign).is_empty() and Content.validate_catalog(catalog, _campaign).is_empty()
    if _content_valid:
        _version = JSON.stringify([_campaign, catalog], "", true, true).sha256_text()
        for question in catalog.questions:
            _questions[question.questionId] = question.duplicate(true)

func restore() -> Dictionary:
    var loaded := _repository.load_latest()
    _payload = {}
    _generation = 0
    _error = ""
    if not _content_valid:
        _error = "invalid_content"
    elif loaded.status == Repository.Status.UNREADABLE:
        _error = "unreadable_save"
    elif loaded.writeBlocked:
        _error = "unsupported_save_schema"
    elif loaded.status == Repository.Status.FIRST_LAUNCH:
        _payload = {"gameplayVersion": Payload.VERSION, "session": null, "usedSessionIds": [], "progress": Progress.initial(_campaign)}
    elif loaded.snapshot.is_empty():
        _error = "save_recovery_required"
    else:
        _error = Payload.validate(loaded.snapshot.payload, _campaign, _questions, _version)
        if _error.is_empty():
            _generation = int(loaded.snapshot.generation)
            _payload = loaded.snapshot.payload
            Payload.normalize_validated(_payload)
    return {"error": _error, "stagedGeneration": loaded.stagedGeneration, "status": loaded.status, "issues": loaded.issues}

func recover_staged(generation: int) -> String:
    if not _content_valid:
        return "invalid_content"
    if generation <= 0 or _repository.load_latest().stagedGeneration != generation:
        return "ineligible_stage"
    var staged := _repository.read_staged(generation)
    if staged.has("error"):
        return staged.error
    var error := Payload.validate(staged.payload, _campaign, _questions, _version)
    if not error.is_empty():
        return error
    if not _repository.recover_staged(generation):
        return "commit_failed"
    return restore().error

func snapshot() -> Dictionary:
    return _payload.duplicate(true)

func start_session(session_id: String, province: String, difficulty: String, selection: Dictionary = {}) -> String:
    if not _error.is_empty():
        return _error
    if not Content.valid_id(session_id):
        return "invalid_session_id"
    if session_id in _payload.usedSessionIds:
        return "duplicate_session"
    if province not in _payload.progress.unlockedProvinceIds:
        return "locked_province"
    var pool := Payload.question_pool(_campaign, province, difficulty)
    if pool.size() < Session.QUESTION_COUNT:
        return "content_unavailable"
    var ids: Variant
    var options: Variant
    if selection.is_empty():
        var seed := JSON.stringify([session_id, province, difficulty, _version])
        ids = Session.ordered_ids(pool, seed, "questions").slice(0, Session.QUESTION_COUNT)
        options = {}
        for id in ids:
            options[id] = Session.ordered_ids(Payload.option_ids(_questions[id]), seed, id)
    else:
        ids = selection.get("questionIds")
        options = selection.get("optionOrderByQuestion")
    if not Payload.valid_selection(ids, options, pool, _questions):
        return "invalid_selection"
    var candidate := snapshot()
    candidate.usedSessionIds.append(session_id)
    candidate.session = Session.create(session_id, province, difficulty, _version, ids, options)
    return _commit(candidate)

func submit_answer(session_id: Variant, question_id: Variant, option_id: Variant, command_id: Variant) -> String:
    if not _error.is_empty():
        return _error
    if _payload.session == null:
        return "no_session"
    var candidate := snapshot()
    var error := Session.submit(candidate.session, _questions, session_id, question_id, option_id, command_id)
    return _commit(candidate) if error.is_empty() else error

func acknowledge_feedback(session_id: Variant, command_id: Variant) -> String:
    if not _error.is_empty():
        return _error
    var candidate := snapshot()
    var session: Variant = candidate.session
    if session == null or not Session.acknowledge(session, session_id, command_id):
        return "no_matching_feedback"
    if session.state == Session.VICTORY:
        Progress.merge_success(candidate.progress, _campaign, session.provinceId, session.difficulty, session.score, session.stars)
    return _commit(candidate)

func _commit(candidate: Dictionary) -> String:
    var error := Payload.validate(candidate, _campaign, _questions, _version)
    if not error.is_empty():
        return error
    var generation := _repository.publish(candidate, _generation)
    if generation == 0:
        return "commit_failed"
    _generation = generation
    _payload = candidate
    return ""
