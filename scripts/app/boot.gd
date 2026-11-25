extends Control

const CampaignGraph = preload("res://scripts/domain/campaign_graph.gd")
const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")

@onready var status_label: Label = $Content/Status

func _ready() -> void:
    var campaign := _read_json("res://content/campaign/campaign.json")
    var campaign_errors := CampaignGraph.validate(campaign)
    var question_errors := ContentValidator.validate_catalog(_read_json("res://content/questions/catalog.json"), campaign)
    if campaign_errors.is_empty() and question_errors.is_empty():
        var save := SaveRepository.new().load_latest()
        match save.status:
            SaveRepository.Status.UNREADABLE, SaveRepository.Status.RECOVERY_REQUIRED:
                status_label.text = "Local save needs recovery. Existing files were kept."
            SaveRepository.Status.RECOVERED:
                status_label.text = "Offline foundation ready. A verified save was loaded."
                AppState.set_offline_ready(true)
            _:
                status_label.text = "Offline foundation ready"
                AppState.set_offline_ready(true)
    else:
        status_label.text = "Content validation error"
        push_error("Campaign: %s | Questions: %s" % [campaign_errors, question_errors])

func _read_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
