class_name CampaignGraph
extends RefCounted

static func validate(campaign: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
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
        var id := str(province.get("provinceId", ""))
        if id.is_empty() or ids.has(id):
            errors.append("missing or duplicate provinceId: " + id)
        ids[id] = true
    var adjacency := {}
    for route in routes:
        if not route is Dictionary:
            errors.append("route must be an object")
            continue
        var from := str(route.get("fromProvinceId", ""))
        var to := str(route.get("toProvinceId", ""))
        if not ids.has(from) or not ids.has(to):
            errors.append("route references an unknown province")
        if from == to:
            errors.append("route cannot point to itself")
        if not adjacency.has(from):
            adjacency[from] = []
        adjacency[from].append(to)
    var start := str(campaign.get("startProvinceId", ""))
    if not ids.has(start):
        errors.append("startProvinceId is invalid")
        return errors
    var reachable := {start: true}
    var pending := [start]
    while not pending.is_empty():
        var current = pending.pop_front()
        for destination in adjacency.get(current, []):
            if not reachable.has(destination):
                reachable[destination] = true
                pending.append(destination)
    for id in ids:
        if not reachable.has(id):
            errors.append("province is unreachable from start: " + id)
    return errors

