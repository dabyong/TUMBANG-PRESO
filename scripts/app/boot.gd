extends Control

const CampaignGraph = preload("res://scripts/domain/campaign_graph.gd")
const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const AppModes = preload("res://scripts/state/app_state.gd")
const Gameplay = preload("res://scenes/gameplay/gameplay.tscn")

@onready var status_label: Label = $Content/Status
@onready var _play: Button = $Content/Play
@onready var _app_state = get_node("/root/AppState")

var save_directory := "user://"
var _gameplay

func _ready() -> void:
    var campaign := _read_json("res://content/campaign/campaign.json")
    var catalog := _read_json("res://content/questions/catalog.json")
    var campaign_errors := CampaignGraph.validate(campaign)
    var question_errors := ContentValidator.validate_production(catalog, campaign)
    if campaign_errors.is_empty() and question_errors.is_empty():
        _gameplay = Gameplay.instantiate()
        _gameplay.hide()
        add_child(_gameplay)
        _gameplay.readiness_changed.connect(_app_state.set_offline_ready)
        _gameplay.view_changed.connect(_update_mode)
        _app_state.content_version = catalog.contentVersion
        if _gameplay.configure(SaveRepository.new(save_directory), campaign, catalog):
            status_label.text = "Offline play available"
            _play.disabled = false
            _play.pressed.connect(_open_gameplay)
        else:
            _open_gameplay()
    else:
        _app_state.set_offline_ready(false)
        status_label.text = "Content validation error"
        push_error("Campaign: %s | Questions: %s" % [campaign_errors, question_errors])

func _open_gameplay() -> void:
    $Content.hide()
    _gameplay.show()
    if _app_state.offline_ready:
        _app_state.mode = AppModes.AppMode.DISCOVERY

func _update_mode(view: String) -> void:
    if not _gameplay.visible:
        return
    match view:
        "entry":
            _app_state.mode = AppModes.AppMode.DISCOVERY
        "difficulty":
            _app_state.mode = AppModes.AppMode.DIFFICULTY
        "play":
            var session: Dictionary = _gameplay.snapshot().session
            _app_state.mode = AppModes.AppMode.FEEDBACK if session.feedbackRequiresAcknowledgement else AppModes.AppMode.GAMEPLAY
        "result":
            var session: Dictionary = _gameplay.snapshot().session
            _app_state.mode = AppModes.AppMode.VICTORY if session.state == Session.VICTORY else AppModes.AppMode.FAILURE
        "diagnostic":
            _app_state.mode = AppModes.AppMode.RECOVERY_REQUIRED

func _read_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
