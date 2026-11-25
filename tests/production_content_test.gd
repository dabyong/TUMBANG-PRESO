extends SceneTree

const Content = preload("res://scripts/domain/content_validator.gd")
const Graph = preload("res://scripts/domain/campaign_graph.gd")
const Payload = preload("res://scripts/domain/gameplay_payload.gd")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Store = preload("res://scripts/domain/gameplay_store.gd")
const Progress = preload("res://scripts/domain/campaign_progress.gd")

var _counts := [0, 0]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var campaign := _read("res://content/campaign/campaign.json")
    var catalog := _read("res://content/questions/catalog.json")
    _check(Graph.validate(campaign).is_empty(), "production campaign schema")
    _check(Content.validate_production(catalog, campaign).is_empty(), "production catalog and all three starting pools validate")
    _check(catalog.questions.size() == 45, "45 catalog records")
    var counted := {}
    var categories := {}
    var indexed := {}
    for question in catalog.questions:
        indexed[question.questionId] = question
        counted[question.difficulty] = counted.get(question.difficulty, 0) + 1
        categories[question.category] = true
        _check(question.verificationStatus == "approved" and question.languageId == "en" and question.contentVersion == catalog.contentVersion and question.source.reference.begins_with("https://"), "approved sourced English record " + question.questionId)
    for category in ["geography", "history", "culture", "traditions", "cuisine", "landmarks"]:
        _check(categories.has(category), "covers " + category)
    for difficulty in Content.DIFFICULTIES:
        _check(counted.get(difficulty) == 15 and Payload.question_pool(campaign, "batanes", difficulty).size() == 15, "15 approved %s questions linked" % difficulty)
        _check(Payload.question_pool(campaign, "cagayan", difficulty).is_empty() and Payload.question_pool(campaign, "isabela", difficulty).is_empty(), "unreleased content remains empty for " + difficulty)
    var incomplete := campaign.duplicate(true)
    incomplete.provinces[0].questionPools.hard.clear()
    _check(not Content.validate_production(catalog, incomplete).is_empty(), "production rejects missing hard content")
    var folder := "user://production-content-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    if DirAccess.make_dir_absolute(folder) == OK:
        _test_sessions(campaign, catalog, indexed, Repository.new(folder))
        var dir := DirAccess.open(folder)
        for file in dir.get_files():
            dir.remove(file)
        DirAccess.remove_absolute(folder)
    else:
        _check(false, "isolated save directory")
    print("Production content checks: %d passed, %d failed" % _counts)
    quit(0 if _counts[1] == 0 else 1)

func _test_sessions(campaign: Dictionary, catalog: Dictionary, indexed: Dictionary, repo: Repository) -> void:
    var prior_campaign := _read("res://tests/fixtures/foundation_campaign.json")
    var prior_catalog := _read("res://tests/fixtures/foundation_catalog.json")
    var old_store := Store.new(repo, prior_campaign, prior_catalog)
    old_store.restore()
    var old := old_store.snapshot()
    Progress.merge_success(old.progress, prior_campaign, "batanes", "normal", 475, 3)
    _check(repo.save(old), "foundation-format progression-only save fixture")
    var store := Store.new(repo, campaign, catalog)
    _check(store.restore().error == "" and store.snapshot() == old, "production preserves compatible progression-only saves")
    var selections := {}
    var orders := {}
    var varied_options := false
    for index in range(6):
        if store.start_session("production-seed-%d" % index, "batanes", "normal") != "":
            _check(false, "verified pool starts a seeded session")
            return
        var session: Dictionary = store.snapshot().session
        var unique := {}
        for id in session.questionIds:
            unique[id] = true
            var choices: Array = session.optionOrderByQuestion[id]
            _check(choices.size() == 5 and indexed[id].correctOptionId in choices, "five mapped options include correct ID for " + id)
            if orders.has(id) and orders[id] != choices:
                varied_options = true
            orders[id] = choices
        _check(unique.size() == 5 and session.questionIds.size() == 5, "five distinct approved questions")
        selections[JSON.stringify(session.questionIds)] = true
    _check(selections.size() > 1 and varied_options, "session seeds vary both selection and option order")
    var persisted := store.snapshot()
    var restored := Store.new(repo, campaign, catalog)
    _check(restored.restore().error == "" and restored.snapshot() == persisted, "restore preserves production selection and order")

func _read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _check(ok: bool, message: String) -> void:
    _counts[0 if ok else 1] += 1
    if not ok:
        push_error("FAIL: " + message)
