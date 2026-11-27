extends RefCounted

const Repository = preload("res://scripts/domain/save_repository.gd")
const VERSION := 1
const DEFAULTS := {"version": VERSION, "music": 0.8, "effects": 0.8, "reduced_motion": false, "province": ""}
const AUDIO_BUSES := {"music": "Music", "effects": "SFX"}

var values: Dictionary = DEFAULTS.duplicate()
var _directory: String

func _init(save_directory: String) -> void:
    _directory = save_directory.path_join("preferences")
    var loaded := Repository.new(_directory).load_latest()
    var payload: Variant = loaded.snapshot.get("payload")
    if _valid(payload):
        values = payload.duplicate()
    apply_audio()

func update(key: String, value: Variant) -> bool:
    var candidate := values.duplicate()
    candidate[key] = value
    if not _valid(candidate):
        return false
    if candidate == values:
        return true
    if DirAccess.make_dir_recursive_absolute(_directory) != OK or not Repository.new(_directory).save(candidate):
        return false
    values = candidate
    apply_audio()
    return true

func apply_audio() -> void:
    for key in AUDIO_BUSES:
        var bus := AudioServer.get_bus_index(AUDIO_BUSES[key])
        if bus < 0:
            AudioServer.add_bus()
            bus = AudioServer.bus_count - 1
            AudioServer.set_bus_name(bus, AUDIO_BUSES[key])
        AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(values[key], 0.001)))
        AudioServer.set_bus_mute(bus, values[key] == 0.0)

func _valid(payload: Variant) -> bool:
    if not payload is Dictionary or payload.size() != DEFAULTS.size() or payload.get("version") != VERSION:
        return false
    if not payload.get("reduced_motion") is bool or not payload.get("province") is String:
        return false
    for key in AUDIO_BUSES:
        var volume: Variant = payload.get(key)
        if not (volume is int or volume is float) or volume < 0.0 or volume > 1.0:
            return false
    return true
