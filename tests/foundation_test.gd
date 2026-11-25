extends SceneTree

const CampaignGraph = preload("res://scripts/domain/campaign_graph.gd")
const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")

func _init() -> void:
    var campaign = _read_json("res://content/campaign/campaign.json")
    var questions = _read_json("res://content/questions/catalog.json")
    _assert(CampaignGraph.validate(campaign).is_empty(), "campaign fixture validates")
    _assert(ContentValidator.validate_catalog(questions).is_empty(), "empty foundation catalog validates")
    var save := SaveRepository.new()
    var loaded := save.load_latest()
    _assert(int(loaded.get("schemaVersion", -1)) == SaveRepository.SCHEMA_VERSION, "save schema loads")
    _assert(save.save({"offline": true}), "save write and reload")
    print("Foundation tests passed")
    quit()

func _read_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)

