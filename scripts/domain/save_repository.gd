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
    var highest_published := 0
    var filename := dir.get_next()
    while not filename.is_empty():
        if LEGACY.has(filename):
            result.issues[filename] = "legacy_unverified"
        elif filename.begins_with(PREFIX):
            var pending := filename.ends_with(".pending")
            var generation := _generation_from_name(filename)
            result.highestGeneration = maxi(result.highestGeneration, generation)
            if not pending:
                highest_published = maxi(highest_published, generation)
            if generation == 0 or dir.current_is_dir():
                result.issues[filename] = "invalid_entry"
            else:
                var entry := _read_snapshot(filename, generation)
                if entry.has("error"):
                    result.issues[filename] = entry.error
                    if entry.error == "unsupported_schema":
                        result.writeBlocked = true
                elif pending:
                    staged = maxi(staged, generation)
                else:
                    result.verifiedCommitted.append(generation)
                    if generation > latest:
                        latest = generation
                        result.snapshot = entry
        filename = dir.get_next()
    dir.list_dir_end()
    if staged > highest_published:
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
func publish(payload: Dictionary, expected_generation: int = -1) -> int:
    var current := load_latest()
    if current.writeBlocked or current.status == Status.RECOVERY_REQUIRED or current.stagedGeneration > 0:
        return 0
    if expected_generation >= 0 and current.snapshot.get("generation", 0) != expected_generation:
        return 0
    var generation := int(current.highestGeneration) + 1
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
    return generation if write_error == OK and _commit(generation) else 0

func recover_staged(generation: int) -> bool:
    var current := load_latest()
    return not current.writeBlocked and generation > 0 and generation == current.stagedGeneration and _commit(generation)

func _commit(generation: int) -> bool:
    var staged := _filename(generation, true)
    var committed := _filename(generation, false)
    var dir := DirAccess.open(_directory)
    if dir == null or dir.file_exists(committed) or dir.dir_exists(committed):
        return false
    if _read_snapshot(staged, generation).has("error") or dir.rename(staged, committed) != OK:
        return false
    if _read_snapshot(committed, generation).has("error"):
        return false
    _prune_committed(dir)
    return true

func _prune_committed(dir: DirAccess) -> void:
    var current := load_latest()
    if current.writeBlocked:
        return
    var generations: Array = current.verifiedCommitted
    generations.sort()
    for index in range(generations.size() - RETAIN_COMMITTED):
        var generation: int = generations[index]
        var filename := _filename(generation, false)
        if not _read_snapshot(filename, generation).has("error"):
            _remove_committed(dir, filename)

func _remove_committed(dir: DirAccess, filename: String) -> Error:
    return dir.remove(filename)

func read_staged(generation: int) -> Dictionary:
    if generation <= 0:
        return {"error": "invalid_generation"}
    return _read_snapshot(_filename(generation, true), generation)

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
    if not snapshot.get("payload") is Dictionary:
        return {"error": "invalid_snapshot"}
    return snapshot

func _generation_from_name(filename: String) -> int:
    var suffix := filename.get_extension()
    if suffix not in ["json", "pending"]:
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
