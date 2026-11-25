extends SceneTree

const CampaignGraph = preload("res://scripts/domain/campaign_graph.gd")
const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var campaign := _read_json("res://content/campaign/campaign.json")
    var questions := _read_json("res://content/questions/catalog.json")
    _assert(CampaignGraph.validate(campaign).is_empty(), "campaign fixture validates")
    _assert(ContentValidator.validate_catalog(questions, campaign).is_empty(), "empty foundation catalog validates")
    _test_campaign(campaign)
    _test_content(campaign)
    _test_save()
    _boot_smoke()
    if "--self-test-failure" in OS.get_cmdline_user_args():
        _assert(false, "intentional exit-code probe")
    print("Foundation checks: %d passed, %d failed" % [checks - failures, failures])
    quit(0 if failures == 0 else 1)

func _boot_smoke() -> void:
    var scene: Node = load("res://scenes/boot.tscn").instantiate()
    root.add_child(scene)
    _assert(scene.get_node("Content/Status").text.begins_with("Offline foundation ready"), "bundled content boots offline")
    scene.free()

func _test_campaign(campaign: Dictionary) -> void:
    var graph := campaign.duplicate(true)
    graph.routes[0].unlock.allCompletedProvinceIds = ["isabela"]
    _contains(CampaignGraph.validate(graph), "unreachable under unlock requirements: cagayan")
    _contains(CampaignGraph.validate(graph), "unreachable under unlock requirements: isabela")
    graph.routes[0].unlock.allCompletedProvinceIds = ["cagayan"]
    _contains(CampaignGraph.validate(graph), "unreachable under unlock requirements: cagayan")
    graph.routes[0].unlock.allCompletedProvinceIds = ["unknown"]
    _contains(CampaignGraph.validate(graph), "invalid or duplicate unlock reference")
    graph.routes[0].unlock.allCompletedProvinceIds = ["batanes", "batanes"]
    _contains(CampaignGraph.validate(graph), "invalid or duplicate unlock reference")
    graph.routes[0].unlock = {}
    _contains(CampaignGraph.validate(graph), "requires unlock.allCompletedProvinceIds")
    graph.routes[0].unlock.allCompletedProvinceIds = ["isabela"]
    graph.routes.append({"routeId": "alternate", "fromProvinceId": "batanes", "toProvinceId": "cagayan", "unlock": {"allCompletedProvinceIds": []}})
    _assert(CampaignGraph.validate(graph).is_empty(), "alternative route resolves deadlock")
    graph.routes[2].routeId = graph.routes[0].routeId
    _contains(CampaignGraph.validate(graph), "duplicate routeId")

func _test_content(campaign: Dictionary) -> void:
    var graph := campaign.duplicate(true)
    var catalog := {"schemaVersion": 1, "mode": "playable", "questions": []}
    for index in range(5):
        var id := "q%d" % index
        var options := []
        for option_index in range(5):
            options.append({"optionId": str(option_index), "text": "Answer %d" % option_index})
        catalog.questions.append({
            "questionId": id, "provinceId": "batanes", "difficulty": "easy", "category": "fixture",
            "prompt": "Synthetic test prompt", "languageId": "en", "contentVersion": "test-1",
            "verificationStatus": "approved", "source": {"title": "Fixture", "reference": "Test only"},
            "correctOptionId": "0", "hint": "Synthetic hint", "explanation": "Synthetic explanation",
            "options": options,
        })
        graph.provinces[0].questionPools.easy.append(id)
    _assert(ContentValidator.validate_catalog(catalog, graph).is_empty(), "five approved linked questions validate")
    catalog.questions[0].source.reference = " "
    catalog.questions[0].verificationStatus = "draft"
    catalog.questions[0].difficulty = "expert"
    catalog.questions[0].provinceId = "unknown"
    catalog.questions[0].options[1] = {"optionId": "0", "text": " ANSWER  0 "}
    catalog.questions[0].correctOptionId = "missing"
    graph.provinces[0].questionPools.easy = ["q0", "q0", "missing"]
    var errors := ContentValidator.validate_catalog(catalog, graph)
    for expected in [
        "unknown province", "invalid difficulty", "must be approved", "source title and reference",
        "duplicate option IDs", "duplicate visible answers", "correctOptionId",
        "at least five", "mismatched or unapproved question", "duplicate or unknown question ID",
    ]:
        _contains(errors, expected)
    _contains(ContentValidator.validate_catalog({"schemaVersion": 1, "mode": "playable", "questions": []}, campaign), "starting province pool")

func _test_save() -> void:
    var directory := "user://foundation-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    _assert(DirAccess.make_dir_absolute(directory) == OK, "isolated save directory created")
    var save := SaveRepository.new(directory)
    _assert(save.load_latest().status == SaveRepository.Status.FIRST_LAUNCH, "first launch is explicit")
    _assert(SaveRepository.new(directory.path_join("missing")).load_latest().status == SaveRepository.Status.UNREADABLE, "unreadable directory is explicit")
    _write(directory, "tp-save-1.pending", "{truncated")
    _assert(save.load_latest().status == SaveRepository.Status.RECOVERY_REQUIRED, "interrupted first write is not a first launch")
    _assert(not save.save({"score": 0}), "unrecoverable save blocks destructive fallback")
    _assert(FileAccess.file_exists(directory.path_join("tp-save-1.pending")), "damaged initial data is retained")
    _stage(directory, 2, SaveRepository.SCHEMA_VERSION)
    _assert(save.load_latest().stagedGeneration == 2, "verified interrupted write is offered for recovery")
    _assert(not save.recover_staged(1), "invalid stage cannot be promoted")
    _assert(save.recover_staged(2), "verified stage can be explicitly committed")
    _assert(save.save({"score": 3}), "new generation commits without replacing backup")
    var loaded := save.load_latest()
    _assert(loaded.snapshot.get("generation") == 3 and loaded.snapshot.get("payload", {}).get("score") == 3, "newest committed payload round-trips")
    _stage(directory, 4, SaveRepository.SCHEMA_VERSION)
    loaded = save.load_latest()
    _assert(loaded.snapshot.get("generation") == 3 and loaded.stagedGeneration == 4, "staged write does not replace committed data")
    _assert(not save.save({"score": 0}), "pending recovery requires explicit decision")
    _assert(save.recover_staged(4), "interrupted publication is recoverable")
    var latest := directory.path_join("tp-save-4.json")
    var modified := FileAccess.get_file_as_string(latest).replace("score", "points")
    _write(directory, "tp-save-4.json", modified)
    loaded = save.load_latest()
    _assert(loaded.status == SaveRepository.Status.RECOVERED and loaded.snapshot.get("generation") == 3, "checksum failure falls back to verified backup")
    _assert(loaded.issues.get("tp-save-4.json") == "checksum_mismatch", "checksum failure has diagnostic")
    _assert(save.save({"score": 5}), "write after backup recovery skips damaged generation")
    _assert(FileAccess.get_file_as_string(latest) == modified, "damaged generation is retained")
    _stage(directory, 6, SaveRepository.SCHEMA_VERSION + 1)
    _assert(save.load_latest().writeBlocked and not save.save({}), "future schema blocks downgrade")
    _assert(FileAccess.file_exists(directory.path_join("tp-save-2.json")), "older committed generation remains intact")
    var dir := DirAccess.open(directory)
    if dir != null:
        for filename in dir.get_files():
            _assert(dir.remove(filename) == OK, "test fixture removed")
        _assert(DirAccess.remove_absolute(directory) == OK, "test directory removed")

func _stage(directory: String, generation: int, schema: int) -> void:
    var body := JSON.stringify({"schemaVersion": schema, "generation": generation, "payload": {"score": generation}})
    _write(directory, "tp-save-%d.pending" % generation, JSON.stringify({"body": body, "sha256": body.sha256_text()}))

func _write(directory: String, filename: String, content: String) -> void:
    var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
    _assert(file != null, "test fixture opens for write")
    if file != null:
        file.store_string(content)
        file.close()

func _read_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _assert(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + message)

func _contains(errors: PackedStringArray, expected: String) -> void:
    _assert("\n".join(errors).contains(expected), "expected validation error '%s' in %s" % [expected, errors])
