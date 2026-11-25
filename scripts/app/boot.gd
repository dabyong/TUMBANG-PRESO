extends Control

const CampaignGraph = preload("res://scripts/domain/campaign_graph.gd")
const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")
const GameplayStore = preload("res://scripts/domain/gameplay_store.gd")

@onready var status_label: Label = $Content/Status

func _ready() -> void:
    var campaign := _read_json("res://content/campaign/campaign.json")
    var catalog := _read_json("res://content/questions/catalog.json")
    var campaign_errors := CampaignGraph.validate(campaign)
    var question_errors := ContentValidator.validate_catalog(catalog, campaign)
    if campaign_errors.is_empty() and question_errors.is_empty():
        var loaded := GameplayStore.new(SaveRepository.new(), campaign, catalog).restore()
        AppState.set_offline_ready(loaded.error.is_empty() and loaded.stagedGeneration == 0)
        if not AppState.offline_ready:
            status_label.text = "Local save needs recovery. Existing files were kept."
        elif loaded.status == SaveRepository.Status.RECOVERED:
            status_label.text = "Offline foundation ready. A verified save was loaded."
        else:
            status_label.text = "Offline foundation ready"
    else:
        status_label.text = "Content validation error"
        push_error("Campaign: %s | Questions: %s" % [campaign_errors, question_errors])

func _read_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
