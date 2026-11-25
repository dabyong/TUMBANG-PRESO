class_name CampaignGraph
extends RefCounted

static func validate(campaign: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if campaign.get("schemaVersion") != 1:
        errors.append("unsupported campaign schemaVersion")
    var provinces = campaign.get("provinces", [])
    var routes = campaign.get("routes", [])
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
        if not id is String or id.strip_edges().is_empty() or ids.has(id):
            errors.append("invalid or duplicate provinceId: %s" % [id])
            continue
        ids[id] = true
    var route_ids := {}
    var valid_routes: Array[Dictionary] = []
    for route in routes:
        if not route is Dictionary:
            errors.append("route must be an object")
            continue
        var route_id: Variant = route.get("routeId")
        if not route_id is String or route_id.strip_edges().is_empty() or route_ids.has(route_id):
            errors.append("invalid or duplicate routeId: %s" % [route_id])
            continue
        route_ids[route_id] = true
        var from: Variant = route.get("fromProvinceId")
        var to: Variant = route.get("toProvinceId")
        if not ids.has(from) or not ids.has(to):
            errors.append("%s references an unknown endpoint" % route_id)
            continue
        if from == to:
            errors.append("%s cannot point to itself" % route_id)
            continue
        var unlock: Variant = route.get("unlock")
        if not unlock is Dictionary or unlock.size() != 1 or not unlock.get("allCompletedProvinceIds") is Array:
            errors.append("%s requires unlock.allCompletedProvinceIds" % route_id)
            continue
        var prerequisites: Array = unlock.allCompletedProvinceIds
        var seen := {}
        for prerequisite in prerequisites:
            if not ids.has(prerequisite) or seen.has(prerequisite):
                errors.append("%s has invalid or duplicate unlock reference: %s" % [route_id, prerequisite])
            else:
                seen[prerequisite] = true
        if seen.size() == prerequisites.size():
            valid_routes.append(route)
    var start: Variant = campaign.get("startProvinceId")
    if not ids.has(start):
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
