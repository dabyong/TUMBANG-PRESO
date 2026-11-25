class_name CampaignProgress
extends RefCounted

const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const SUCCESSFUL_SCORES := [400, 410, 425, 450, 475, 500]

static func initial(campaign: Dictionary) -> Dictionary:
    return {"completedProvinceIds": [], "unlockedProvinceIds": [campaign.startProvinceId], "records": {}}

static func merge_success(progress: Dictionary, campaign: Dictionary, province: String, difficulty: String, score: int, stars: int) -> void:
    var key := province + "/" + difficulty
    var previous: Dictionary = progress.records.get(key, {"bestScore": 0, "bestStars": 0})
    progress.records[key] = {"bestScore": maxi(previous.bestScore, score), "bestStars": maxi(previous.bestStars, stars)}
    if province not in progress.completedProvinceIds:
        progress.completedProvinceIds.append(province)
        progress.completedProvinceIds.sort()
    progress.unlockedProvinceIds = _unlocked(campaign, progress.completedProvinceIds)

static func is_valid(progress: Variant, campaign: Dictionary) -> bool:
    if not progress is Dictionary or not progress.get("records") is Dictionary:
        return false
    var known := {}
    for province in campaign.provinces:
        known[province.provinceId] = true
    var completed := []
    for key in progress.records:
        if not key is String:
            return false
        var parts: PackedStringArray = key.split("/")
        if parts.size() != 2 or not known.has(parts[0]) or parts[1] not in ContentValidator.DIFFICULTIES:
            return false
        var record: Variant = progress.records[key]
        if not record is Dictionary or record.size() != 2 or not is_integer(record.get("bestScore"), 400, 500) or not is_integer(record.get("bestStars"), 1, 3):
            return false
        if int(record.bestScore) not in SUCCESSFUL_SCORES:
            return false
        if parts[0] not in completed:
            completed.append(parts[0])
    completed.sort()
    var unlocked := _unlocked(campaign, completed)
    for province in completed:
        if province not in unlocked:
            return false
    return progress.get("completedProvinceIds") == completed and progress.get("unlockedProvinceIds") == unlocked

static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
    return (value is int or value is float) and value >= minimum and value <= maximum and value == floor(value)

static func _unlocked(campaign: Dictionary, completed: Array) -> Array:
    var unlocked := [campaign.startProvinceId]
    var changed := true
    while changed:
        changed = false
        for route in campaign.routes:
            if route.fromProvinceId not in unlocked or route.toProvinceId in unlocked:
                continue
            var eligible := true
            for prerequisite in route.unlock.allCompletedProvinceIds:
                if prerequisite not in unlocked or prerequisite not in completed:
                    eligible = false
                    break
            if eligible:
                unlocked.append(route.toProvinceId)
                changed = true
    unlocked.sort()
    return unlocked
