extends RefCounted

const Repository = preload("res://scripts/domain/save_repository.gd")
const VERSION := 1
const DEFAULTS := {"version": VERSION, "music": 0.8, "effects": 0.8, "reduced_motion": false, "province": ""}
const AUDIO_BUSES := {"music": "Music", "effects": "SFX"}

var values: Dictionary = DEFAULTS.duplicate()
var storage_error := ""
var _directory: String
var _repository: Repository

func _init(save_directory: String) -> void:
    _directory = save_directory.path_join("preferences")
    _repository = Repository.new(_directory)
    _load()

func update(key: String, value: Variant) -> bool:
    var loaded := _load()
    if not storage_error.is_empty():
        return false
    var candidate := values.duplicate()
    candidate[key] = value
    if not _valid(candidate):
        return false
    if candidate == values:
        return true
    if loaded.status == Repository.Status.RECOVERY_REQUIRED or (not loaded.snapshot.is_empty() and not _valid(loaded.snapshot.get("payload"))):
        if not _preserve_unusable_directory():
            storage_error = "could not preserve damaged preferences"
            return false
    if DirAccess.make_dir_recursive_absolute(_directory) != OK or _repository.publish(candidate, -1, _validation_error) == 0:
        storage_error = "could not publish preferences"
        return false
    values = candidate
    apply_audio()
    return true

func _load() -> Dictionary:
    storage_error = ""
    var loaded := _repository.load_latest()
    if loaded.writeBlocked and loaded.status != Repository.Status.UNREADABLE:
        storage_error = "unsupported preference save schema"
    elif loaded.status == Repository.Status.UNREADABLE and (DirAccess.dir_exists_absolute(_directory) or FileAccess.file_exists(_directory)):
        storage_error = "preferences storage is unreadable"
    elif _unsupported_version(loaded.snapshot.get("payload")):
        storage_error = "unsupported preferences version"
    elif loaded.stagedGeneration > 0:
        var generation: int = loaded.stagedGeneration
        var staged := _repository.read_staged(generation)
        if _valid(staged.get("payload")):
            if not _repository.recover_staged(generation, _validation_error):
                storage_error = "could not recover interrupted preferences"
        elif not _repository.defer_staged(generation):
            storage_error = "could not preserve interrupted preferences"
        loaded = _repository.load_latest()
    var payload: Variant = loaded.snapshot.get("payload")
    if not storage_error.is_empty() and not _valid(payload):
        for generation in loaded.verifiedCommitted:
            var prior: Variant = _repository.read_committed(generation).get("payload")
            if _valid(prior):
                payload = prior
                break
    values = payload.duplicate() if _valid(payload) else DEFAULTS.duplicate()
    apply_audio()
    return loaded

func _preserve_unusable_directory() -> bool:
    # This directory contains only settings. Start a new settings namespace
    # after an explicit edit when the old one has no usable current snapshot.
    var archive := _directory + "-preserved-" + Crypto.new().generate_random_bytes(12).hex_encode()
    return DirAccess.rename_absolute(_directory, archive) == OK

func _validation_error(payload: Variant) -> String:
    return "" if _valid(payload) else "invalid_preferences"

func _unsupported_version(payload: Variant) -> bool:
    if not payload is Dictionary:
        return false
    var version: Variant = payload.get("version")
    return (version is int or version is float) and version != VERSION

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
        if not (volume is int or volume is float) or not is_finite(volume) or volume < 0.0 or volume > 1.0:
            return false
    return true
