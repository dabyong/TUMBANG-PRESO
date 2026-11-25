class_name ContentValidator
extends RefCounted

const DIFFICULTIES := ["easy", "normal", "hard"]
const MIN_POOL_SIZE := 5

static func validate_catalog(catalog: Dictionary, campaign: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if catalog.get("schemaVersion") != 1:
        errors.append("unsupported question schemaVersion")
    var questions: Variant = catalog.get("questions")
    if not questions is Array:
        errors.append("questions must be an array")
        return errors
    var mode: Variant = catalog.get("mode")
    if mode not in ["foundation", "playable"]:
        errors.append("catalog mode must be foundation or playable")
    if mode == "foundation" and not questions.is_empty():
        errors.append("foundation catalog must be empty")
    var provinces: Variant = campaign.get("provinces")
    if not provinces is Array:
        errors.append("campaign provinces must be an array")
        return errors
    var province_ids := {}
    for province in provinces:
        if province is Dictionary and _non_blank(province.get("provinceId")):
            province_ids[province.provinceId] = true
    var by_id := {}
    for question in questions:
        if not question is Dictionary:
            errors.append("question must be an object")
            continue
        var id: Variant = question.get("questionId")
        if not _non_blank(id):
            errors.append("questionId is required")
            continue
        if by_id.has(id):
            errors.append("duplicate questionId: " + id)
            continue
        by_id[id] = question
        if not province_ids.has(question.get("provinceId")):
            errors.append("%s references an unknown province" % id)
        if question.get("difficulty") not in DIFFICULTIES:
            errors.append("%s has invalid difficulty" % id)
        if question.get("verificationStatus") != "approved":
            errors.append("%s must be approved" % id)
        var source: Variant = question.get("source")
        if not source is Dictionary or not _non_blank(source.get("title")) or not _non_blank(source.get("reference")):
            errors.append("%s requires source title and reference" % id)
        for required in ["languageId", "contentVersion", "prompt", "hint", "explanation", "category"]:
            if not _non_blank(question.get(required)):
                errors.append("%s missing %s" % [id, required])
        var options: Variant = question.get("options")
        if not options is Array or options.size() != 5:
            errors.append("%s must have exactly five options" % id)
            continue
        var option_ids := {}
        var labels := {}
        for option in options:
            if not option is Dictionary:
                errors.append("%s has a non-object option" % id)
                continue
            var option_id: Variant = option.get("optionId")
            if not _non_blank(option_id) or option_ids.has(option_id):
                errors.append("%s has invalid or duplicate option IDs" % id)
            else:
                option_ids[option_id] = true
            var label: Variant = option.get("text")
            if not _non_blank(label):
                errors.append("%s has an empty answer label" % id)
                continue
            var normalized := " ".join(label.replace("\t", " ").replace("\r", " ").replace("\n", " ").split(" ", false)).to_lower()
            if labels.has(normalized):
                errors.append("%s has duplicate visible answers" % id)
            labels[normalized] = true
        if not option_ids.has(question.get("correctOptionId")):
            errors.append("%s correctOptionId is not one of its options" % id)
    var has_start_pool := false
    for province in provinces:
        if not province is Dictionary:
            continue
        var province_id: Variant = province.get("provinceId")
        var pools: Variant = province.get("questionPools")
        if not pools is Dictionary or pools.size() != DIFFICULTIES.size():
            errors.append("%s must define easy, normal and hard pools" % [province_id])
            continue
        for difficulty in DIFFICULTIES:
            var pool: Variant = pools.get(difficulty)
            var context := "%s/%s" % [province_id, difficulty]
            if not pool is Array:
                errors.append("%s pool must be an array" % context)
                continue
            if pool.is_empty():
                continue
            if mode == "foundation" or pool.size() < MIN_POOL_SIZE:
                errors.append("%s requires at least five questions in playable mode" % context)
            elif province_id == campaign.get("startProvinceId"):
                has_start_pool = true
            var used := {}
            for question_id in pool:
                if not _non_blank(question_id) or used.has(question_id) or not by_id.has(question_id):
                    errors.append("%s has an invalid, duplicate or unknown question ID: %s" % [context, question_id])
                    continue
                used[question_id] = true
                var question: Dictionary = by_id[question_id]
                if question.get("provinceId") != province_id or question.get("difficulty") != difficulty or question.get("verificationStatus") != "approved":
                    errors.append("%s has mismatched or unapproved question: %s" % [context, question_id])
    if mode == "playable" and not has_start_pool:
        errors.append("playable catalog requires a starting province pool")
    return errors

static func _non_blank(value: Variant) -> bool:
    return value is String and not value.strip_edges().is_empty()
