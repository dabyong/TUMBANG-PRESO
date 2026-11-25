class_name ContentValidator
extends RefCounted

static func validate_catalog(catalog: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if catalog.get("schemaVersion") != 1:
        errors.append("unsupported question schemaVersion")
    var questions = catalog.get("questions", [])
    if not questions is Array:
        return PackedStringArray(["questions must be an array"])
    var seen := {}
    for question in questions:
        if not question is Dictionary:
            errors.append("question must be an object")
            continue
        var id := str(question.get("questionId", ""))
        if id.is_empty():
            errors.append("questionId is required")
        elif seen.has(id):
            errors.append("duplicate questionId: " + id)
        seen[id] = true
        var options = question.get("options", [])
        if not options is Array or options.size() != 5:
            errors.append("%s must have exactly five options" % id)
            continue
        var option_ids := {}
        for option in options:
            if not option is Dictionary:
                errors.append("%s has a non-object option" % id)
                continue
            var option_id := str(option.get("optionId", ""))
            if option_id.is_empty() or option_ids.has(option_id):
                errors.append("%s has invalid or duplicate option IDs" % id)
            option_ids[option_id] = true
        var correct := str(question.get("correctOptionId", ""))
        if not option_ids.has(correct):
            errors.append("%s correctOptionId is not one of its options" % id)
        for required in ["provinceId", "difficulty", "languageId", "contentVersion", "prompt", "hint", "explanation", "category", "verificationStatus"]:
            if str(question.get(required, "")).is_empty():
                errors.append("%s missing %s" % [id, required])
    return errors

