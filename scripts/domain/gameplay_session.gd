class_name GameplaySession
extends RefCounted

const Content = preload("res://scripts/domain/content_validator.gd")
const AWAITING := "AwaitingAnswer"
const FEEDBACK := "Feedback"
const VICTORY := "Victory"
const FAILURE := "Failure"
const POINTS := [100, 75, 50, 25, 10]
const STARS := [3, 3, 2, 2, 1]
const HINT_THRESHOLDS := {"easy": 0, "normal": 1, "hard": 2}
const QUESTION_COUNT := 5
const MISS_LIMIT := 5

static func create(session_id: String, province: String, difficulty: String, version: String, question_ids: Array, option_orders: Dictionary) -> Dictionary:
    return {
        "sessionId": session_id, "provinceId": province, "difficulty": difficulty, "catalogVersion": version,
        "questionIds": question_ids.duplicate(), "optionOrderByQuestion": option_orders.duplicate(true),
        "questionIndex": 0, "rejectedOptionIdsByQuestion": {}, "incorrectAttemptsByQuestion": {},
        "misses": 0, "score": 0, "stars": 0, "state": AWAITING, "resolvedAnswerIds": {},
        "processedSubmissions": [], "feedbackOutcome": "", "feedbackRequiresAcknowledgement": false,
    }

static func submit(session: Dictionary, questions: Dictionary, session_id: Variant, question_id: Variant, option_id: Variant, command_id: Variant) -> String:
    if not Content.valid_id(session_id) or session_id != session.sessionId:
        return "wrong_session"
    if not Content.valid_id(command_id):
        return "invalid_command"
    for command in session.processedSubmissions:
        if command.commandId == command_id:
            return "duplicate_command"
    if session.state != AWAITING:
        return "state_blocks_answer"
    if not Content.valid_id(question_id) or question_id != session.questionIds[int(session.questionIndex)]:
        return "stale_question"
    if not Content.valid_id(option_id) or option_id not in session.optionOrderByQuestion[question_id]:
        return "invalid_option"
    var rejected: Array = session.rejectedOptionIdsByQuestion.get(question_id, [])
    if option_id in rejected:
        return "rejected_option"
    session.processedSubmissions.append({
        "commandId": command_id, "questionId": question_id, "optionId": option_id, "acknowledged": false,
    })
    var correct: bool = option_id == questions[question_id].correctOptionId
    session.feedbackOutcome = "correct" if correct else "incorrect"
    if correct:
        session.resolvedAnswerIds[question_id] = option_id
        session.score += POINTS[rejected.size()]
    else:
        rejected.append(option_id)
        session.rejectedOptionIdsByQuestion[question_id] = rejected
        session.incorrectAttemptsByQuestion[question_id] = rejected.size()
        session.misses += 1
    if session.misses == MISS_LIMIT:
        session.state = FAILURE
    else:
        session.state = FEEDBACK
        session.feedbackRequiresAcknowledgement = true
    return ""

static func acknowledge(session: Dictionary, session_id: Variant, command_id: Variant) -> bool:
    if session.state != FEEDBACK or session_id != session.sessionId or command_id != session.processedSubmissions.back().commandId:
        return false
    session.processedSubmissions.back().acknowledged = true
    session.feedbackRequiresAcknowledgement = false
    if session.feedbackOutcome == "correct":
        session.questionIndex += 1
    session.feedbackOutcome = ""
    session.state = AWAITING
    if session.questionIndex == QUESTION_COUNT:
        session.state = VICTORY
        session.stars = STARS[int(session.misses)]
    return true

static func hint_available(session: Dictionary) -> bool:
    if session.state != AWAITING:
        return false
    var question_id: String = session.questionIds[int(session.questionIndex)]
    return session.incorrectAttemptsByQuestion.get(question_id, 0) >= HINT_THRESHOLDS[session.difficulty]

static func ordered_ids(ids: Array, seed: String, scope: String) -> Array:
    # Hash ranking is independent of input order and engine RNG implementation.
    var ranked := []
    for id in ids:
        ranked.append([JSON.stringify([seed, scope, id]).sha256_text(), id])
    ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] if a[0] == b[0] else a[0] < b[0])
    var ordered := []
    for entry in ranked:
        ordered.append(entry[1])
    return ordered
