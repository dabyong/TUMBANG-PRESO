extends SceneTree

const Graph = preload("res://scripts/domain/campaign_graph.gd")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Store = preload("res://scripts/domain/gameplay_store.gd")

class FailingRepository extends Repository:
    var deny_save := false
    var deny_cleanup := false
    var cleanup_attempts := 0

    func publish(payload: Dictionary, expected_generation: int = -1, validate_payload: Callable = Callable()) -> int:
        return 0 if deny_save else super.publish(payload, expected_generation, validate_payload)

    func _remove_committed(dir: DirAccess, filename: String) -> Error:
        cleanup_attempts += 1
        return ERR_UNAUTHORIZED if deny_cleanup else super._remove_committed(dir, filename)

var _checks := 0
var _failures := 0
var _root: String
var _campaign: Dictionary
var _catalog := {"schemaVersion": 1, "mode": "playable", "questions": []}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _root = "user://gameplay-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    if DirAccess.make_dir_recursive_absolute(_root) != OK:
        push_error("Cannot create test directory")
        quit(1)
        return
    _campaign = JSON.parse_string(FileAccess.get_file_as_string("res://content/campaign/campaign.json"))
    _test_graph()
    _make_catalog()
    _test_session()
    _test_payload()
    _test_committed_recovery()
    _test_pending_recovery()
    _test_retention()
    _cleanup()
    print("Gameplay checks: %d passed, %d failed" % [_checks - _failures, _failures])
    quit(0 if _failures == 0 else 1)

func _test_graph() -> void:
    var invalid := [
        ["unsupported campaign schemaVersion", func(c): c.schemaVersion = true],
        ["campaignVersion", func(c): c.erase("campaignVersion")],
        ["contain chapters", func(c): c.chapters = []],
        ["contain chapters", func(c): c.erase("chapters")],
        ["chapter object", func(c): c.chapters = [42]],
        ["chapter object", func(c): c.chapters[0].displayName = ""],
        ["duplicate chapterId", func(c): c.chapters.append(c.chapters[0])],
        ["contain provinces", func(c): c.erase("provinces")],
        ["province must be an object", func(c): c.provinces[1] = "cagayan"],
        ["duplicate provinceId", func(c): c.provinces.append(c.provinces[0])],
        ["requires displayName and regionName", func(c): c.provinces[0].erase("regionName")],
        ["unknown chapter", func(c): c.provinces[0].chapterId = "missing"],
        ["define easy, normal and hard", func(c): c.provinces[0].questionPools.expert = []],
        ["pool must be an array", func(c): c.provinces[0].questionPools.normal = false],
        ["pool must be an array", func(c): c.provinces[0].questionPools = {"easy": [], "normal": [], "other": []}],
        ["invalid or duplicate question ID", func(c): c.provinces[0].questionPools.normal = ["q1", "q1"]],
        ["routes must be an array", func(c): c.erase("routes")],
        ["route must be an object", func(c): c.routes[0] = []],
        ["invalid or duplicate routeId", func(c): c.routes[0].erase("routeId")],
        ["duplicate routeId", func(c): c.routes[1].routeId = c.routes[0].routeId],
        ["unknown endpoint", func(c): c.routes[0].fromProvinceId = 1],
        ["unknown endpoint", func(c): c.routes[0].toProvinceId = "missing"],
        ["cannot point to itself", func(c): c.routes[0].toProvinceId = "batanes"],
        ["invalid travelMode", func(c): c.routes[0].erase("travelMode")],
        ["invalid travelMode", func(c): c.routes[0].travelMode = "teleport"],
        ["requires unlock.allCompletedProvinceIds", func(c): c.routes[0].unlock = {"allCompletedProvinceIds": [], "any": []}],
        ["requires unlock.allCompletedProvinceIds", func(c): c.routes[0].unlock.allCompletedProvinceIds = "batanes"],
        ["invalid or duplicate unlock reference", func(c): c.routes[0].unlock.allCompletedProvinceIds = [4]],
        ["invalid or duplicate unlock reference", func(c): c.routes[0].unlock.allCompletedProvinceIds = ["batanes", "batanes"]],
        ["unreachable under unlock requirements: isabela", func(c): c.routes.pop_back()],
        ["unreachable under unlock requirements: cagayan", func(c): c.routes[0].unlock.allCompletedProvinceIds = ["isabela"]],
        ["startProvinceId is invalid", func(c): c.erase("startProvinceId")],
    ]
    for entry in invalid:
        var graph := _campaign.duplicate(true)
        entry[1].call(graph)
        _check("\n".join(Graph.validate(graph)).contains(entry[0]), "campaign rejects " + entry[0])

func _make_catalog() -> void:
    for number in range(7):
        var id := "q%d" % number
        var options := []
        for option in ["a", "b", "c", "d", "e"]:
            options.append({"optionId": option, "text": "Fixture " + option})
        _catalog.questions.append({
            "questionId": id, "provinceId": "batanes", "difficulty": "normal", "category": "fixture",
            "languageId": "en", "contentVersion": "test-1", "prompt": "Fixture prompt", "hint": "Fixture hint",
            "explanation": "Fixture explanation", "verificationStatus": "approved",
            "source": {"title": "Fixture", "reference": "Test only"}, "correctOptionId": "a", "options": options,
        })
        _campaign.provinces[0].questionPools.normal.append(id)

func _test_session() -> void:
    var repo := FailingRepository.new(_directory("session"))
    var store := Store.new(repo, _campaign, _catalog)
    _check(store.restore().error == "", "fresh gameplay payload initializes")
    _check(store.start_session("session", "cagayan", "normal") == "locked_province", "locked province blocks start")
    _check(store.start_session("session", "batanes", "easy") == "content_unavailable", "empty difficulty blocks start")
    _check(store.start_session("session", "batanes", "normal") == "", "approved game starts")
    var original: Dictionary = store.snapshot().get("session", {})
    if original.is_empty():
        return
    var independent := Store.new(Repository.new(_directory("independent")), _campaign, _catalog)
    independent.restore()
    independent.start_session("session", "batanes", "normal")
    _check(independent.snapshot().get("session") == original, "same seed produces the same five questions and option mapping")
    _check(original.questionIds.size() == 5 and original.optionOrderByQuestion.size() == 5, "selection contains five distinct questions")
    var ids: Array = original.questionIds
    _check(store.submit_answer("stale", ids[0], "b", "miss") == "wrong_session", "stale session identity")
    _check(store.submit_answer("session", ids[1], "b", "miss") == "stale_question", "stale question identity")
    _check(store.submit_answer("session", ids[0], "missing", "miss") == "invalid_option", "invalid option identity")
    _check(store.submit_answer("session", ids[0], "b", "") == "invalid_command", "empty command identity")
    repo.deny_save = true
    _check(store.submit_answer("session", ids[0], "b", "miss") == "commit_failed", "failed save propagates to command")
    _check(store.snapshot().session == original, "failed save leaves in-memory state intact")
    repo.deny_save = false
    _check(store.submit_answer("session", ids[0], "b", "miss") == "", "failed command can be retried")
    _check(store.submit_answer("session", ids[0], "c", "tap") == "state_blocks_answer", "feedback blocks a different rapid tap")
    _check(store.acknowledge_feedback("session", "stale") == "no_matching_feedback", "acknowledgement must refer to current answer")
    _check(store.acknowledge_feedback("session", "miss") == "", "incorrect feedback acknowledgement stays on current question")
    var restored := Store.new(repo, _campaign, _catalog)
    _check(restored.restore().error == "", "session validates after restart")
    _check(restored.snapshot().session.optionOrderByQuestion == original.optionOrderByQuestion, "recovery keeps displayed option mapping")
    _check(restored.submit_answer("session", ids[0], "c", "miss") == "duplicate_command", "stored command ID cannot target a new option")
    _check(restored.submit_answer("session", ids[0], "b", "retry") == "rejected_option", "new command cannot replay a rejected option")
    for id in ids:
        _check(restored.submit_answer("session", id, "a", "correct-" + id) == "", "correct answer commits feedback")
        _check(restored.acknowledge_feedback("session", "correct-" + id) == "", "correct acknowledgement commits advance")
    var win := restored.snapshot()
    _check(win.session.state == "Victory" and win.session.score == 475 and win.session.stars == 3, "weighted score and victory stars")
    _check(win.progress.records["batanes/normal"].bestScore == 475 and "cagayan" in win.progress.unlockedProvinceIds, "victory commits record and route access atomically")
    _check(restored.start_session("next", "cagayan", "normal") == "content_unavailable", "unlocked province still requires approved content")
    var terminal_generation: int = repo.load_latest().snapshot.generation
    _check(restored.submit_answer("session", ids[4], "a", "correct-" + ids[4]) == "duplicate_command", "terminal command replay is ignored")
    _check(restored.submit_answer("session", ids[4], "a", "new-tap") == "state_blocks_answer", "terminal state blocks new commands")
    _check(restored.acknowledge_feedback("session", "correct-" + ids[4]) == "no_matching_feedback", "terminal acknowledgement replay is ignored")
    _check(repo.load_latest().snapshot.generation == terminal_generation and restored.snapshot() == win, "terminal retries leave payload and generation intact")
    _check(store.start_session("stale-view", "batanes", "normal") == "commit_failed", "stale writer cannot replace newer state")
    _check(restored.start_session("second", "batanes", "normal") == "", "new session replaces completed attempt")
    _check(restored.restore().error == "" and restored.start_session("session", "batanes", "normal") == "duplicate_session", "historical session ID cannot be reused after restart")
    _test_failure(restored, repo, win.progress)

func _test_failure(store: Store, repo: Repository, previous_progress: Dictionary) -> void:
    var ids: Array = store.snapshot().session.questionIds
    for wrong in ["b", "c", "d", "e"]:
        _check(store.submit_answer("second", ids[0], wrong, wrong) == "" and store.acknowledge_feedback("second", wrong) == "", "wrong answer keeps the first question active")
    _check(store.submit_answer("second", ids[1], "b", "future") == "stale_question", "four misses do not advance the question")
    _check(store.submit_answer("second", ids[0], "a", "correct") == "" and store.acknowledge_feedback("second", "correct") == "", "correct answer advances with four accumulated misses")
    _check(store.submit_answer("second", ids[1], "b", "fifth") == "", "fifth valid miss commits failure")
    var failed := store.snapshot()
    _check(failed.session.state == "Failure" and failed.session.misses == 5 and failed.session.score == 10 and failed.session.stars == 0, "failure retains score and awards no stars")
    _check(failed.progress == previous_progress, "failure preserves existing successful records")
    var generation: int = repo.load_latest().snapshot.generation
    _check(store.restore().error == "" and store.submit_answer("second", ids[1], "b", "fifth") == "duplicate_command", "failure command remains idempotent after restart")
    _check(store.submit_answer("second", ids[1], "a", "new") == "state_blocks_answer" and repo.load_latest().snapshot.generation == generation, "failure blocks new commands")

func _test_payload() -> void:
    var repo := Repository.new(_directory("payload"))
    var store := Store.new(repo, _campaign, _catalog)
    store.restore()
    store.start_session("payload", "batanes", "normal")
    var initial := store.snapshot()
    if initial.get("session") == null:
        _check(false, "payload fixture started")
        return
    var first: String = initial.session.questionIds[0]
    store.submit_answer("payload", first, "b", "wrong")
    store.acknowledge_feedback("payload", "wrong")
    store.submit_answer("payload", first, "a", "right")
    var feedback := store.snapshot()
    var mutations := [
        ["gameplay version", func(p): p.gameplayVersion = 99],
        ["session identity", func(p): p.session.sessionId = ""],
        ["reused session identity", func(p): p.usedSessionIds.append(p.session.sessionId)],
        ["province identity", func(p): p.session.provinceId = "missing"],
        ["difficulty identity", func(p): p.session.difficulty = "expert"],
        ["question count", func(p): p.session.questionIds.pop_back()],
        ["unique question order", func(p): p.session.questionIds[1] = first],
        ["option mapping", func(p): p.session.optionOrderByQuestion[first][0] = "missing"],
        ["index bounds", func(p): p.session.questionIndex = 6],
        ["incorrect attempts", func(p): p.session.incorrectAttemptsByQuestion[first] = 4],
        ["rejected options", func(p): p.session.rejectedOptionIdsByQuestion[first] = ["a"]],
        ["cumulative misses", func(p): p.session.misses = 0],
        ["score", func(p): p.session.score = 100],
        ["resolved answer", func(p): p.session.resolvedAnswerIds[first] = "b"],
        ["duplicate processed command", func(p): p.session.processedSubmissions[1].commandId = "wrong"],
        ["invalid processed command", func(p): p.session.processedSubmissions[1].commandId = null],
        ["feedback outcome", func(p): p.session.feedbackOutcome = "incorrect"],
        ["feedback flag", func(p): p.session.feedbackRequiresAcknowledgement = false],
        ["premature terminal state", func(p): p.session.state = "Victory"],
        ["progress route", func(p): p.progress.unlockedProvinceIds.append("isabela")],
        ["progress record", func(p): p.progress.records["batanes/normal"] = {"bestScore": 501, "bestStars": 3}],
        ["impossible progress score", func(p): p.progress.records["batanes/normal"] = {"bestScore": 499, "bestStars": 3}],
    ]
    for entry in mutations:
        var invalid := feedback.duplicate(true)
        entry[1].call(invalid)
        _check(repo.save(invalid) and store.restore().error != "", "payload rejects " + entry[0])
    _check(repo.save(feedback), "valid feedback checkpoint can be restored")
    var changed_catalog := _catalog.duplicate(true)
    changed_catalog.questions[0].contentVersion = "test-2"
    var changed_store := Store.new(repo, _campaign, changed_catalog)
    var compatible_generation: int = repo.load_latest().snapshot.generation
    _check(changed_store.restore().error == "catalog_version_mismatch", "catalog mismatch gives explicit recovery error")
    _check(changed_store.start_session("new", "batanes", "normal") == "catalog_version_mismatch" and repo.load_latest().snapshot.generation == compatible_generation, "catalog mismatch preserves compatible files")
    _check(store.restore().error == "" and store.snapshot().session.state == "Feedback", "compatible catalog restores original feedback")
    var invalid_stage := feedback.duplicate(true)
    invalid_stage.session.score = 99
    _stage(repo, compatible_generation + 1, Repository.SCHEMA_VERSION, invalid_stage)
    _check(changed_store.recover_staged(compatible_generation + 1) == "catalog_version_mismatch", "stage cannot be recovered using incompatible content")
    _check(store.recover_staged(compatible_generation + 1) == "inconsistent_session", "invalid staged gameplay cannot replace valid committed data")
    _stage(repo, compatible_generation + 2, Repository.SCHEMA_VERSION, feedback)
    _check(store.recover_staged(compatible_generation + 2) == "" and store.snapshot() == feedback, "valid staged gameplay recovers session and progression together")

func _test_committed_recovery() -> void:
    var repo := Repository.new(_directory("committed-recovery"))
    var store := Store.new(repo, _campaign, _catalog)
    store.restore()
    if store.start_session("recover", "batanes", "normal") != "":
        _check(false, "committed recovery fixture started")
        return
    var good := store.snapshot()
    var first: String = good.session.questionIds[0]
    var incompatible := good.duplicate(true)
    incompatible.session.catalogVersion = "older-catalog"
    _write_snapshot(repo, "json", 2, Repository.SCHEMA_VERSION, incompatible)
    _write_snapshot(repo, "json", 3, Repository.SCHEMA_VERSION, null)
    var malformed := good.duplicate(true)
    malformed.session.score = 100
    _write_snapshot(repo, "json", 4, Repository.SCHEMA_VERSION, malformed)
    var loaded := store.restore()
    _check(repo.load_latest().snapshot.generation == 4, "envelope verifies independently of the gameplay payload")
    _check(loaded.status == Repository.Status.RECOVERY_REQUIRED and loaded.error == "inconsistent_session", "invalid newest gameplay enters explicit recovery")
    _check(loaded.committedGeneration == 4 and loaded.snapshotGeneration == 1 and loaded.recoveryCandidates == [1], "finds the only compatible committed candidate behind three invalid payloads")
    _check(loaded.payloadIssues.get(2) == "catalog_version_mismatch" and loaded.payloadIssues.get(3) == "invalid_gameplay_payload", "diagnoses incompatible and non-object history")
    _check(store.snapshot() == good, "exposes the older snapshot for inspection during recovery")
    _check(store.start_session("blocked", "batanes", "normal") == "inconsistent_session", "committed recovery blocks start")
    _check(store.submit_answer("recover", first, "a", "blocked") == "inconsistent_session", "committed recovery blocks answer")
    _check(store.acknowledge_feedback("recover", "blocked") == "inconsistent_session", "committed recovery blocks acknowledgement")
    _check(store.recover_committed(1, 3) == "stale_recovery_decision", "stale committed recovery decision is rejected")
    _check(store.recover_committed(2, 4) == "ineligible_committed", "incompatible candidate cannot be selected")
    _check(repo.load_latest().highestGeneration == 4, "unresolved and rejected decisions leave generations intact")
    _check(store.recover_committed(1, 4) == "", "explicit selection republishes committed fallback")
    loaded = store.restore()
    _check(loaded.error == "" and loaded.committedGeneration == 5 and store.snapshot() == good, "explicit recovery publishes above invalid history")
    _check(repo.load_latest().verifiedCommitted == [5, 4, 3, 2, 1], "recovery retains the only original semantic fallback and invalid generations")
    _check(store.submit_answer("recover", first, "a", "right") == "", "gameplay resumes after committed recovery")
    _check(store.acknowledge_feedback("recover", "right") == "", "gameplay can advance after committed recovery")
    _check(repo.load_latest().verifiedCommitted == [7, 6, 5, 4, 3, 2], "retention counts three valid gameplay generations and leaves invalid or incompatible history")

    _write_snapshot(repo, "json", 8, Repository.SCHEMA_VERSION, incompatible)
    loaded = store.restore()
    _check(loaded.error == "catalog_version_mismatch" and loaded.recoveryCandidates == [7, 6, 5], "incompatible newest remains blocked and offers all compatible candidates newest first")
    _check(repo.load_latest().highestGeneration == 8, "incompatible newer snapshot remains on disk")
    _stage(repo, 9, Repository.SCHEMA_VERSION, store.snapshot())
    _check(store.restore().error == "pending_recovery" and store.defer_staged(9) == "", "staged decision precedes committed recovery")
    _check(store.restore().error == "catalog_version_mismatch" and repo.load_latest().snapshot.generation == 8, "deferring stage leaves unresolved committed recovery blocked")
    _stage(repo, 10, Repository.SCHEMA_VERSION + 1, {})
    _check(store.restore().error == "unsupported_save_schema", "future envelope schema takes priority over semantic recovery")
    _check(store.recover_committed(7, 8) == "unsupported_save_schema", "future envelope prevents committed recovery publication")
    _check(store.recover_staged(10) == "unsupported_save_schema" and store.defer_staged(10) == "unsupported_save_schema", "future envelope prevents staged decisions")
    _check(repo.load_latest().highestGeneration == 10, "future data is preserved")

func _test_pending_recovery() -> void:
    var repo := Repository.new(_directory("pending-recovery"))
    var store := Store.new(repo, _campaign, _catalog)
    store.restore()
    if store.start_session("pending", "batanes", "normal") != "":
        _check(false, "pending recovery fixture started")
        return
    var first: String = store.snapshot().session.questionIds[0]
    if store.submit_answer("pending", first, "a", "right") != "":
        _check(false, "pending recovery fixture in feedback")
        return
    var feedback := store.snapshot()
    _stage(repo, 3, Repository.SCHEMA_VERSION, feedback)
    var loaded := store.restore()
    _check(loaded.status == Repository.Status.RECOVERY_REQUIRED and loaded.error == "pending_recovery", "eligible stage reports explicit recovery state")
    _check(loaded.stagedGeneration == 3 and loaded.stagedError == "" and loaded.snapshotGeneration == 2 and store.snapshot() == feedback, "pending recovery keeps committed feedback inspectable")
    _check(store.start_session("blocked", "batanes", "normal") == "pending_recovery", "pending recovery blocks session start")
    _check(store.submit_answer("pending", first, "b", "blocked") == "pending_recovery", "pending recovery blocks answer submission")
    _check(store.acknowledge_feedback("pending", "right") == "pending_recovery", "pending recovery blocks valid acknowledgement")
    _check(store.recover_committed(1, 2) == "pending_recovery", "pending stage must be resolved before committed rollback")
    _check(store.recover_staged(2) == "ineligible_stage" and store.defer_staged(2) == "ineligible_stage", "stale stage choices cannot change the active decision")
    _check(store.recover_staged(3) == "" and store.acknowledge_feedback("pending", "right") == "", "explicit promotion resumes gameplay")
    _check(repo.load_latest().snapshot.generation == 4, "promotion and feedback acknowledgement advance generations")

    _stage(repo, 5, Repository.SCHEMA_VERSION, store.snapshot())
    _stage(repo, 6, Repository.SCHEMA_VERSION, ["bad gameplay payload"])
    var path := repo._directory.path_join("tp-save-6.pending")
    var contents := FileAccess.get_file_as_bytes(path)
    loaded = store.restore()
    _check(loaded.error == "pending_recovery" and loaded.stagedError == "invalid_gameplay_payload", "checksum-valid malformed stage still requires a decision")
    _check(store.recover_staged(6) == "invalid_gameplay_payload" and FileAccess.get_file_as_bytes(path) == contents, "failed promotion preserves staged bytes")
    _check(store.defer_staged(6) == "", "explicit deferral archives the unpromotable stage")
    _check(store.restore().error == "" and repo.load_latest().stagedGeneration == 0, "deferral keeps committed data and does not offer a superseded stage")
    _check(FileAccess.get_file_as_bytes(repo._directory.path_join("tp-save-6.deferred")) == contents and FileAccess.file_exists(repo._directory.path_join("tp-save-5.pending")), "deferred and superseded staged files remain available")
    _check(store.start_session("next", "batanes", "normal") == "" and repo.load_latest().snapshot.generation == 7, "play resumes after deferral and numbering skips deferred generations")

    var orphan_repo := Repository.new(_directory("deferred-only"))
    var orphan := Store.new(orphan_repo, _campaign, _catalog)
    _stage(orphan_repo, 1, Repository.SCHEMA_VERSION, {})
    _check(orphan.restore().error == "pending_recovery" and orphan.snapshot().is_empty(), "staged-only recovery offers no fabricated initial progress")
    _check(orphan.defer_staged(1) == "" and orphan.restore().error == "save_recovery_required", "deferral without committed data still requires recovery")
    _check(orphan.start_session("blocked", "batanes", "normal") == "save_recovery_required", "deferred-only storage cannot be reset via gameplay")

func _test_retention() -> void:
    var repo := FailingRepository.new(_directory("retention"))
    for number in range(1, 8):
        _check(repo.save({"count": number}), "committed generation %d" % number)
    var retained: Array = repo.load_latest().verifiedCommitted
    retained.sort()
    _check(retained == [5, 6, 7], "retention keeps newest three committed generations")
    _write(repo, "tp-save-8.pending", "{partial")
    _check(repo.load_latest().snapshot.generation == 7, "interrupted write keeps latest commit")
    _check(repo.save({"count": 9}) and repo.load_latest().snapshot.generation == 9, "interrupted generation number is never reused")
    _stage(repo, 9, Repository.SCHEMA_VERSION, {"count": 0})
    _write(repo, "tp-save-9.json", "{damaged")
    var loaded := repo.load_latest()
    _check(loaded.snapshot.generation == 7 and loaded.stagedGeneration == 0, "damaged newest falls back without promoting stale stage")
    _check(not repo.recover_staged(9), "stale staged generation remains ineligible")
    _stage(repo, 10, Repository.SCHEMA_VERSION, {"count": 10})
    _check(not repo.save({}) and repo.load_latest().snapshot.generation == 7, "valid pending write awaits explicit recovery")
    _check(repo.recover_staged(10) and repo.load_latest().snapshot.generation == 10, "explicit staged recovery publishes next snapshot")
    repo.deny_cleanup = true
    _check(repo.save({"count": 11}) and repo.cleanup_attempts > 0 and repo.load_latest().snapshot.generation == 11, "cleanup failure cannot invalidate publication")
    _check(repo.load_latest().verifiedCommitted.size() == 4, "failed cleanup leaves extra history")
    repo.deny_cleanup = false
    _check(repo.save({"count": 12}) and repo.load_latest().verifiedCommitted.size() == 3, "next successful write retries retention")
    for artifact in ["tp-save-8.pending", "tp-save-9.pending", "tp-save-9.json"]:
        _check(FileAccess.file_exists(repo._directory.path_join(artifact)), "retention preserves " + artifact)
    _stage(repo, 13, Repository.SCHEMA_VERSION + 1, null)
    _check(repo.load_latest().writeBlocked and not repo.save({}) and not repo.recover_staged(13), "future schema blocks writes and recovery")
    _check(FileAccess.file_exists(repo._directory.path_join("tp-save-13.pending")), "future schema artifact remains present")
    var exhausted := Repository.new(_directory("exhaustion"))
    _stage(exhausted, Repository.MAX_GENERATION, Repository.SCHEMA_VERSION, {})
    _check(exhausted.recover_staged(Repository.MAX_GENERATION) and not exhausted.save({}), "generation exhaustion blocks reuse")

func _directory(name: String) -> String:
    var path := _root.path_join(name)
    _check(DirAccess.make_dir_absolute(path) == OK, "created " + name + " directory")
    return path

func _stage(repo: Repository, generation: int, schema: int, payload: Variant) -> void:
    _write_snapshot(repo, "pending", generation, schema, payload)

func _write_snapshot(repo: Repository, suffix: String, generation: int, schema: int, payload: Variant) -> void:
    var body := JSON.stringify({"schemaVersion": schema, "generation": generation, "payload": payload})
    _write(repo, "tp-save-%d.%s" % [generation, suffix], JSON.stringify({"body": body, "sha256": body.sha256_text()}))

func _write(repo: Repository, filename: String, contents: String) -> void:
    var file := FileAccess.open(repo._directory.path_join(filename), FileAccess.WRITE)
    _check(file != null, "opened fixture " + filename)
    if file != null:
        file.store_string(contents)
        file.close()

func _cleanup() -> void:
    for name in DirAccess.get_directories_at(_root):
        var directory := DirAccess.open(_root.path_join(name))
        if directory != null:
            for filename in directory.get_files():
                directory.remove(filename)
            DirAccess.remove_absolute(_root.path_join(name))
    DirAccess.remove_absolute(_root)

func _check(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error("FAIL: " + message)
