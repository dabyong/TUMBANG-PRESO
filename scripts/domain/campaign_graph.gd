class_name CampaignGraph
extends RefCounted

const ContentValidator = preload("res://scripts/domain/content_validator.gd")
const TRAVEL_MODES := ["land", "sea"]

static func validate(campaign: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not _positive_integer(campaign.get("schemaVersion")) or campaign.schemaVersion != 1:
        errors.append("unsupported campaign schemaVersion")
    if not _positive_integer(campaign.get("campaignVersion")):
        errors.append("campaignVersion must be a positive integer")
    var chapters: Variant = campaign.get("chapters")
    var chapter_ids := {}
    if not chapters is Array or chapters.is_empty():
        errors.append("campaign must contain chapters")
    else:
        for chapter in chapters:
            if not chapter is Dictionary or not _identifier(chapter.get("chapterId")) or not _non_blank(chapter.get("displayName")):
                errors.append("invalid chapter object")
            elif chapter_ids.has(chapter.chapterId):
                errors.append("duplicate chapterId: " + chapter.chapterId)
            else:
                chapter_ids[chapter.chapterId] = true
    var provinces = campaign.get("provinces")
    var routes = campaign.get("routes")
    if not provinces is Array or provinces.is_empty():
        errors.append("campaign must contain provinces")
        return errors
    if not routes is Array:
        errors.append("routes must be an array")
        return errors
    var ids := {}
    for province in provinces:
        if not province is Dictionary:
            errors.append("province must be an object")
            continue
        var id: Variant = province.get("provinceId")
        if not _identifier(id) or ids.has(id):
            errors.append("invalid or duplicate provinceId: %s" % [id])
            continue
        ids[id] = true
        if not _non_blank(province.get("displayName")) or not _non_blank(province.get("regionName")):
            errors.append("%s requires displayName and regionName" % id)
        if not _identifier(province.get("chapterId")) or not chapter_ids.has(province.chapterId):
            errors.append("%s references an unknown chapter" % id)
        var pools: Variant = province.get("questionPools")
        if not pools is Dictionary or pools.size() != ContentValidator.DIFFICULTIES.size():
            errors.append("%s must define easy, normal and hard pools" % id)
        else:
            for difficulty in ContentValidator.DIFFICULTIES:
                var pool: Variant = pools.get(difficulty)
                if not pool is Array:
                    errors.append("%s/%s pool must be an array" % [id, difficulty])
                else:
                    var question_ids := {}
                    for question_id in pool:
                        if not _identifier(question_id) or question_ids.has(question_id):
                            errors.append("%s/%s contains an invalid or duplicate question ID" % [id, difficulty])
                        else:
                            question_ids[question_id] = true
    var route_ids := {}
    var valid_routes: Array[Dictionary] = []
    for route in routes:
        if not route is Dictionary:
            errors.append("route must be an object")
            continue
        var route_id: Variant = route.get("routeId")
        if not _identifier(route_id) or route_ids.has(route_id):
            errors.append("invalid or duplicate routeId: %s" % [route_id])
            continue
        route_ids[route_id] = true
        var from: Variant = route.get("fromProvinceId")
        var to: Variant = route.get("toProvinceId")
        if not _identifier(from) or not _identifier(to) or not ids.has(from) or not ids.has(to):
            errors.append("%s references an unknown endpoint" % route_id)
            continue
        if from == to:
            errors.append("%s cannot point to itself" % route_id)
            continue
        if route.get("travelMode") not in TRAVEL_MODES:
            errors.append("%s has invalid travelMode" % route_id)
        var unlock: Variant = route.get("unlock")
        if not unlock is Dictionary or unlock.size() != 1 or not unlock.get("allCompletedProvinceIds") is Array:
            errors.append("%s requires unlock.allCompletedProvinceIds" % route_id)
            continue
        var prerequisites: Array = unlock.allCompletedProvinceIds
        var seen := {}
        for prerequisite in prerequisites:
            if not _identifier(prerequisite) or not ids.has(prerequisite) or seen.has(prerequisite):
                errors.append("%s has invalid or duplicate unlock reference: %s" % [route_id, prerequisite])
            else:
                seen[prerequisite] = true
        if seen.size() == prerequisites.size():
            valid_routes.append(route)
    var start: Variant = campaign.get("startProvinceId")
    if not _identifier(start) or not ids.has(start):
        errors.append("startProvinceId is invalid")
        return errors
    var reachable := {start: true}
    # Any reachable province can eventually be completed. Keep simulating
    # until no route can unlock anything new, including alternate routes.
    var changed := true
    while changed:
        changed = false
        for route in valid_routes:
            if not reachable.has(route.fromProvinceId) or reachable.has(route.toProvinceId):
                continue
            var eligible := true
            for prerequisite in route.unlock.allCompletedProvinceIds:
                if not reachable.has(prerequisite):
                    eligible = false
                    break
            if eligible:
                reachable[route.toProvinceId] = true
                changed = true
    for id in ids:
        if not reachable.has(id):
            errors.append("province is unreachable under unlock requirements: " + id)
    return errors

static func _non_blank(value: Variant) -> bool:
    return value is String and not value.strip_edges().is_empty()

static func _identifier(value: Variant) -> bool:
    return ContentValidator.valid_id(value) and not value.contains("/")

static func _positive_integer(value: Variant) -> bool:
    return (value is int or value is float) and value >= 1 and value <= 9007199254740991 and value == floor(value)
