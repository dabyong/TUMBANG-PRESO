class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION := 2
const MAX_GENERATION := 9007199254740991
const RETAIN_COMMITTED := 3
const PREFIX := "tp-save-"
const LEGACY := ["save-a.json", "save-b.json", "save-next.tmp"]
enum Status { FIRST_LAUNCH, READY, RECOVERED, RECOVERY_REQUIRED, UNREADABLE }

var _directory: String

func _init(directory: String = "user://") -> void:
    _directory = directory

# Only committed snapshots are returned for normal use. A staged generation
# requires an explicit recovery decision, even if its checksum is valid.
func load_latest() -> Dictionary:
    var result := {
        "status": Status.FIRST_LAUNCH, "snapshot": {}, "issues": {},
        "stagedGeneration": 0, "highestGeneration": 0, "writeBlocked": false,
        "verifiedCommitted": [],
    }
    var dir := DirAccess.open(_directory)
    if dir == null or dir.list_dir_begin() != OK:
        result.status = Status.UNREADABLE
        result.writeBlocked = true
        return result
    var latest := 0
    var staged := 0
    var stage_cutoff := 0
    var filename := dir.get_next()
    while not filename.is_empty():
        if LEGACY.has(filename):
            result.issues[filename] = "legacy_unverified"
        elif filename.begins_with(PREFIX):
            var suffix := filename.get_extension()
            var generation := _generation_from_name(filename)
            result.highestGeneration = maxi(result.highestGeneration, generation)
            if suffix == "json" or suffix == "deferred":
                stage_cutoff = maxi(stage_cutoff, generation)
            if generation == 0 or dir.current_is_dir():
                result.issues[filename] = "invalid_entry"
            else:
                var entry := _read_snapshot(filename, generation)
                if entry.has("error"):
                    result.issues[filename] = entry.error
                    if entry.error == "unsupported_schema":
                        result.writeBlocked = true
                elif suffix == "deferred":
                    result.issues[filename] = "deferred_stage"
                elif suffix == "pending":
                    staged = maxi(staged, generation)
                else:
                    result.verifiedCommitted.append(generation)
                    if generation > latest:
                        latest = generation
                        result.snapshot = entry
        filename = dir.get_next()
    dir.list_dir_end()
    result.verifiedCommitted.sort()
    result.verifiedCommitted.reverse()
    if staged > stage_cutoff:
        result.stagedGeneration = staged
    elif staged > 0:
        result.issues[_filename(staged, true)] = "stale_stage"
    if result.writeBlocked or (latest == 0 and (staged > 0 or not result.issues.is_empty())):
        result.status = Status.RECOVERY_REQUIRED
    elif latest > 0:
        result.status = Status.RECOVERED if result.stagedGeneration > 0 or not result.issues.is_empty() else Status.READY
    return result

# Caller serializes writes and submits one complete, JSON-compatible snapshot.
func save(payload: Dictionary, expected_generation: int = -1) -> bool:
    return publish(payload, expected_generation) > 0

# Returns the generation verified after publication, or zero on failure.
func publish(payload: Dictionary, expected_generation: int = -1, validate_payload: Callable = Callable()) -> int:
    var current := load_latest()
    if current.writeBlocked or current.status == Status.RECOVERY_REQUIRED or current.stagedGeneration > 0:
        return 0
    if expected_generation >= 0 and current.snapshot.get("generation", 0) != expected_generation:
        return 0
    if not current.snapshot.is_empty() and not _valid_payload(current.snapshot, validate_payload):
        return 0
    return _publish_next(payload, int(current.highestGeneration), validate_payload)

func _publish_next(payload: Dictionary, highest_generation: int, validate_payload: Callable) -> int:
    if validate_payload.is_valid() and not validate_payload.call(payload).is_empty():
        return 0
    var generation := highest_generation + 1
    if generation > MAX_GENERATION:
        return 0
    var body := JSON.stringify({"schemaVersion": SCHEMA_VERSION, "generation": generation, "payload": payload}, "", true, true)
    var filename := _filename(generation, true)
    if FileAccess.file_exists(_directory.path_join(filename)) or DirAccess.dir_exists_absolute(_directory.path_join(filename)):
        return 0
    var file := FileAccess.open(_directory.path_join(filename), FileAccess.WRITE)
    if file == null:
        return 0
    file.store_string(JSON.stringify({"body": body, "sha256": body.sha256_text()}))
    file.flush()
    var write_error := file.get_error()
    file.close()
    return generation if write_error == OK and _commit(generation, validate_payload) else 0

func recover_staged(generation: int, validate_payload: Callable = Callable()) -> bool:
    var current := load_latest()
    return not current.writeBlocked and generation > 0 and generation == current.stagedGeneration and _commit(generation, validate_payload)

func recover_committed(generation: int, expected_latest: int, validate_payload: Callable) -> bool:
    var current := load_latest()
    if current.writeBlocked or current.stagedGeneration > 0 or not validate_payload.is_valid():
        return false
    if generation <= 0 or generation >= expected_latest or current.snapshot.get("generation", 0) != expected_latest:
        return false
    if _valid_payload(current.snapshot, validate_payload):
        return false
    var chosen := read_committed(generation)
    if not _valid_payload(chosen, validate_payload):
        return false
    return _publish_next(chosen.payload, int(current.highestGeneration), validate_payload) > 0

func defer_staged(generation: int) -> bool:
    var current := load_latest()
    if current.writeBlocked or generation <= 0 or generation != current.stagedGeneration:
        return false
    var dir := DirAccess.open(_directory)
    var deferred := PREFIX + str(generation) + ".deferred"
    if dir == null or dir.file_exists(deferred) or dir.dir_exists(deferred):
        return false
    return dir.rename(_filename(generation, true), deferred) == OK

func _commit(generation: int, validate_payload: Callable) -> bool:
    var staged := _filename(generation, true)
    var committed := _filename(generation, false)
    var dir := DirAccess.open(_directory)
    if dir == null or dir.file_exists(committed) or dir.dir_exists(committed):
        return false
    if not _valid_payload(_read_snapshot(staged, generation), validate_payload) or dir.rename(staged, committed) != OK:
        return false
    if not _valid_payload(_read_snapshot(committed, generation), validate_payload):
        return false
    _prune_committed(dir, validate_payload)
    return true

func _prune_committed(dir: DirAccess, validate_payload: Callable) -> void:
    var current := load_latest()
    if current.writeBlocked:
        return
    var retained := 0
    for generation: int in current.verifiedCommitted:
        var filename := _filename(generation, false)
        if not _valid_payload(_read_snapshot(filename, generation), validate_payload):
            continue
        if retained < RETAIN_COMMITTED:
            retained += 1
        else:
            _remove_committed(dir, filename)

func _valid_payload(snapshot: Dictionary, validate_payload: Callable) -> bool:
    var payload: Variant = snapshot.get("payload")
    return payload is Dictionary and (not validate_payload.is_valid() or validate_payload.call(payload).is_empty())

func _remove_committed(dir: DirAccess, filename: String) -> Error:
    return dir.remove(filename)

func read_staged(generation: int) -> Dictionary:
    if generation <= 0 or generation > MAX_GENERATION:
        return {"error": "invalid_generation"}
    return _read_snapshot(_filename(generation, true), generation)

func read_committed(generation: int) -> Dictionary:
    if generation <= 0 or generation > MAX_GENERATION:
        return {"error": "invalid_generation"}
    return _read_snapshot(_filename(generation, false), generation)

func _read_snapshot(filename: String, generation: int) -> Dictionary:
    var file := FileAccess.open(_directory.path_join(filename), FileAccess.READ)
    if file == null:
        return {"error": "unreadable"}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {"error": "invalid_envelope"}
    var envelope: Variant = parser.data
    if not envelope is Dictionary or not envelope.get("body") is String:
        return {"error": "invalid_envelope"}
    var body: String = envelope.body
    if envelope.get("sha256") != body.sha256_text():
        return {"error": "checksum_mismatch"}
    if parser.parse(body) != OK:
        return {"error": "invalid_snapshot"}
    var snapshot: Variant = parser.data
    if not snapshot is Dictionary or snapshot.get("generation") != generation:
        return {"error": "invalid_snapshot"}
    if snapshot.get("schemaVersion") != SCHEMA_VERSION:
        return {"error": "unsupported_schema"}
    return snapshot

func _generation_from_name(filename: String) -> int:
    var suffix := filename.get_extension()
    if suffix not in ["json", "pending", "deferred"]:
        return 0
    var digits := filename.get_basename().trim_prefix(PREFIX)
    if not digits.is_valid_int() or digits.length() > 16:
        return 0
    var generation := digits.to_int()
    if generation < 1 or generation > MAX_GENERATION or str(generation) != digits:
        return 0
    return generation

func _filename(generation: int, staged: bool) -> String:
    return PREFIX + str(generation) + (".pending" if staged else ".json")
