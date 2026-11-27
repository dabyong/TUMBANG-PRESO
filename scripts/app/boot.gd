extends Control

const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SaveRepository = preload("res://scripts/domain/save_repository.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const AppModes = preload("res://scripts/state/app_state.gd")
const Gameplay = preload("res://scenes/gameplay/gameplay.tscn")
const SafeLayout = preload("res://scripts/ui/safe_layout.gd")

@onready var status_label: Label = $Content/Status
@onready var _app_state = get_node("/root/AppState")

var save_directory := "user://"
var _gameplay

func _ready() -> void:
    resized.connect(_layout_splash)
    _layout_splash()
    # Draw the real splash once before doing synchronous local initialization.
    if get_parent() == get_tree().root and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
    var campaign := _read_json("res://content/campaign/campaign.json")
    var catalog := _read_json("res://content/questions/catalog.json")
    var content_errors := ContentValidator.validate_production(catalog, campaign)
    if content_errors.is_empty():
        _gameplay = Gameplay.instantiate()
        add_child(_gameplay)
        _gameplay.readiness_changed.connect(_app_state.set_offline_ready)
        _gameplay.view_changed.connect(_update_mode)
        _app_state.content_version = catalog.contentVersion
        if _gameplay.configure(SaveRepository.new(save_directory), campaign, catalog):
            status_label.text = "Offline play available"
        $Content.hide()
    else:
        _app_state.set_offline_ready(false)
        status_label.text = "Content validation error"
        $Content/Play.show()
        push_warning("Content validation error: %s" % [content_errors])

func _layout_splash() -> void:
    $Backdrop.queue_redraw()
    SafeLayout.apply($Content, 0.0, Vector4(24, -90, 24, -90))

func _update_mode(view: String) -> void:
    if not _gameplay.visible:
        return
    match view:
        "menu":
            _app_state.mode = AppModes.AppMode.MENU
        "map":
            _app_state.mode = AppModes.AppMode.MAP
        "settings":
            _app_state.mode = AppModes.AppMode.SETTINGS
        "pause":
            _app_state.mode = AppModes.AppMode.PAUSED
        "progress":
            _app_state.mode = AppModes.AppMode.PROGRESS
        "credits":
            _app_state.mode = AppModes.AppMode.CREDITS
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
