class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION := 1
const SLOT_A := "user://save-a.json"
const SLOT_B := "user://save-b.json"
const TEMP := "user://save-next.tmp"

func load_latest() -> Dictionary:
    var candidates: Array[Dictionary] = []
    for path in [SLOT_A, SLOT_B]:
        var snapshot = _read_valid(path)
        if not snapshot.is_empty():
            candidates.append(snapshot)
    if candidates.is_empty():
        return {"schemaVersion": SCHEMA_VERSION, "generation": 0, "payload": {}}
    candidates.sort_custom(func(a, b): return int(a.get("generation", 0)) > int(b.get("generation", 0)))
    return candidates[0]

func save(payload: Dictionary) -> bool:
    var current := load_latest()
    var next := {"schemaVersion": SCHEMA_VERSION, "generation": int(current.get("generation", 0)) + 1, "payload": payload}
    var file := FileAccess.open(TEMP, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(next))
    file.flush()
    file.close()
    var target := SLOT_B if int(current.get("generation", 0)) % 2 == 1 else SLOT_A
    var dir := DirAccess.open("user://")
    if dir == null or dir.rename(TEMP.get_file(), target.get_file()) != OK:
        return false
    return not _read_valid(target).is_empty()

func _read_valid(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or int(parsed.get("schemaVersion", -1)) != SCHEMA_VERSION:
        return {}
    if not parsed.has("generation") or not parsed.has("payload"):
        return {}
    return parsed

