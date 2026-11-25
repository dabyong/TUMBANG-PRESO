class_name GameplayPayload
extends RefCounted

const Session = preload("res://scripts/domain/gameplay_session.gd")
const Progress = preload("res://scripts/domain/campaign_progress.gd")
const Content = preload("res://scripts/domain/content_validator.gd")
const VERSION := 1

static func validate(payload: Dictionary, campaign: Dictionary, questions: Dictionary, version: String) -> String:
    if not Progress.is_integer(payload.get("gameplayVersion"), VERSION, VERSION) or not payload.has("session"):
        return "unsupported_gameplay_payload"
    var progress: Variant = payload.get("progress")
    if not Progress.is_valid(progress, campaign):
        return "invalid_progress"
    var session: Variant = payload.session
    var session_ids: Variant = payload.get("usedSessionIds")
    if not session_ids is Array:
        return "invalid_session_ids"
    var seen := {}
    for id in session_ids:
        if not Content.valid_id(id) or seen.has(id):
            return "invalid_session_ids"
        seen[id] = true
    if session == null:
        return "" if session_ids.is_empty() else "invalid_session_ids"
    if not session is Dictionary or not Content.valid_id(session.get("catalogVersion")):
        return "invalid_session"
    if session.catalogVersion != version:
        return "catalog_version_mismatch"
    var province: Variant = session.get("provinceId")
    var difficulty: Variant = session.get("difficulty")
    var pool := question_pool(campaign, province, difficulty)
    if session_ids.is_empty() or session.get("sessionId") != session_ids.back() or province not in progress.unlockedProvinceIds:
        return "invalid_session"
    if not valid_selection(session.get("questionIds"), session.get("optionOrderByQuestion"), pool, questions):
        return "invalid_selection"
    if not Progress.is_integer(session.get("questionIndex"), 0, Session.QUESTION_COUNT) or not Progress.is_integer(session.get("score"), 0, 500) or not Progress.is_integer(session.get("misses"), 0, Session.MISS_LIMIT) or not Progress.is_integer(session.get("stars"), 0, 3):
        return "invalid_session"
    var commands: Variant = session.get("processedSubmissions")
    if not commands is Array or commands.size() > Session.QUESTION_COUNT + Session.MISS_LIMIT - 1:
        return "invalid_submissions"
    var replay := Session.create(session.sessionId, province, difficulty, version, session.questionIds, session.optionOrderByQuestion)
    for command in commands:
        if not command is Dictionary or not command.get("acknowledged") is bool:
            return "invalid_submissions"
        if Session.submit(replay, questions, session.sessionId, command.get("questionId"), command.get("optionId"), command.get("commandId")) != "":
            return "invalid_submissions"
        if command.acknowledged and not Session.acknowledge(replay, session.sessionId, command.commandId):
            return "invalid_feedback"
    if not _same_json(replay, session):
        return "inconsistent_session"
    if replay.state == Session.VICTORY:
        var record: Dictionary = progress.records.get(province + "/" + difficulty, {})
        if record.get("bestScore", 0) < replay.score or record.get("bestStars", 0) < replay.stars:
            return "missing_victory_record"
    return ""

static func _same_json(left: Dictionary, right: Dictionary) -> bool:
    # Godot reads JSON numbers as floats. Compare the normalized persisted forms.
    return JSON.parse_string(JSON.stringify(left, "", true, true)) == JSON.parse_string(JSON.stringify(right, "", true, true))

static func normalize_validated(payload: Dictionary) -> void:
    # Call only after validation. Give restored callers the same types as a live session.
    payload.gameplayVersion = int(payload.gameplayVersion)
    for record in payload.progress.records.values():
        record.bestScore = int(record.bestScore)
        record.bestStars = int(record.bestStars)
    var session: Variant = payload.session
    if session == null:
        return
    for field in ["questionIndex", "misses", "score", "stars"]:
        session[field] = int(session[field])
    for id in session.incorrectAttemptsByQuestion:
        session.incorrectAttemptsByQuestion[id] = int(session.incorrectAttemptsByQuestion[id])

static func question_pool(campaign: Dictionary, province: Variant, difficulty: Variant) -> Array:
    if not Content.valid_id(province) or not Session.HINT_THRESHOLDS.has(difficulty):
        return []
    for entry in campaign.provinces:
        if entry.provinceId == province:
            return entry.questionPools[difficulty]
    return []

static func valid_selection(ids: Variant, orders: Variant, pool: Array, questions: Dictionary) -> bool:
    if not ids is Array or ids.size() != Session.QUESTION_COUNT or not orders is Dictionary or orders.size() != ids.size():
        return false
    var seen := {}
    for id in ids:
        if not Content.valid_id(id) or seen.has(id) or id not in pool:
            return false
        seen[id] = true
        var order: Variant = orders.get(id)
        var options := option_ids(questions[id])
        if not order is Array or order.size() != options.size():
            return false
        for option in options:
            if option not in order:
                return false
    return true

static func option_ids(question: Dictionary) -> Array:
    var ids := []
    for option in question.options:
        ids.append(option.optionId)
    return ids
