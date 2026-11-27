extends SceneTree

const Boot = preload("res://scenes/boot.tscn")
const Gameplay = preload("res://scenes/gameplay/gameplay.tscn")
const Repository = preload("res://scripts/domain/save_repository.gd")
const Store = preload("res://scripts/domain/gameplay_store.gd")
const Session = preload("res://scripts/domain/gameplay_session.gd")
const PANELS := "Margin/Frame/Scroll/Panels/"
const MAP_NODES := PANELS + "Map/Body/Provinces/"
const HUD := "Margin/Frame/HUD/"
const ACK := PANELS + "Play/Feedback/Acknowledge"
const ANSWERS := PANELS + "Play/Answers"

var campaign: Dictionary
var catalog: Dictionary
var questions := {}
var viewport: SubViewport
var capture_dir := ""
var _counts := [0, 0]
var _folders: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    campaign = JSON.parse_string(FileAccess.get_file_as_string("res://content/campaign/campaign.json"))
    catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/questions/catalog.json"))
    for question in catalog.questions:
        questions[question.questionId] = question
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="):
            capture_dir = arg.trim_prefix("--capture-dir=")
    viewport = SubViewport.new()
    viewport.size = Vector2i(960, 540)
    if not capture_dir.is_empty():
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    await run_checks()
    viewport.free()
    for folder in _folders:
        var directory := DirAccess.open(folder)
        var prefs := DirAccess.open(folder.path_join("preferences"))
        if prefs != null:
            for filename in prefs.get_files():
                prefs.remove(filename)
            directory.remove("preferences")
        if directory != null:
            for filename in directory.get_files():
                directory.remove(filename)
            DirAccess.remove_absolute(folder)
    print("%s checks: %d passed, %d failed" % [suite_name(), _counts[0], _counts[1]])
    quit(0 if _counts[1] == 0 else 1)

func suite_name() -> String:
    return "UI"

func run_checks() -> void:
    pass

func check(ok: bool, message: String) -> void:
    _counts[0 if ok else 1] += 1
    if not ok:
        push_error("FAIL: " + message)

func repository(label: String) -> Repository:
    var directory := "user://ui-%d-%d-%s" % [OS.get_process_id(), Time.get_ticks_usec(), label]
    check(DirAccess.make_dir_absolute(directory) == OK, "isolated directory for " + label)
    _folders.append(directory)
    return Repository.new(directory)

func boot_game(repo: Repository) -> Control:
    var boot := Boot.instantiate()
    boot.save_directory = repo._directory
    viewport.add_child(boot)
    var game := boot.get_node("Gameplay") as Control
    game.get_node("Effects").manual = true
    return game

func press(game: Control, path: String) -> void:
    game.get_node(path).pressed.emit()

func screen_visible(game: Control, panel: String) -> bool:
    return game.get_node(PANELS + panel).visible

func choose(game: Control, province: String, difficulty: String) -> void:
    if screen_visible(game, "Menu"):
        press(game, PANELS + "Menu/Actions/Play")
    press(game, MAP_NODES + province)
    press(game, PANELS + "Entry/New")
    press(game, PANELS + "Difficulty/" + difficulty.capitalize())

func session(game: Control) -> Dictionary:
    return game.snapshot().session

func question(game: Control) -> Dictionary:
    var active := session(game)
    return questions[active.questionIds[active.questionIndex]]

func tap(game: Control, choice: String) -> void:
    var button: Button = game.get_node(ANSWERS).button_for(choice)
    button.pressed.emit()

func wrong_options(game: Control) -> Array:
    var current := question(game)
    return current.options.map(func(option): return option.optionId).filter(func(id): return id != current.correctOptionId)

func step(game: Control, seconds: float) -> void:
    var effects := game.get_node("Effects")
    effects.advance(seconds, effects.token)

func finish_correct(game: Control) -> void:
    tap(game, question(game).correctOptionId)
    step(game, 2.0)
    press(game, ACK)
    step(game, 2.0)

func resume_saved(game: Control, province: String = "batanes") -> void:
    press(game, PANELS + "Menu/Actions/Continue")
    press(game, MAP_NODES + province)
    press(game, PANELS + "Entry/Resume")

func capture(filename: String) -> void:
    if capture_dir.is_empty():
        return
    await RenderingServer.frame_post_draw
    var frame := viewport.get_texture().get_image()
    check(frame != null and frame.save_png(capture_dir.path_join(filename + ".png")) == OK, "rendered capture " + filename)

func write_generation(repo: Repository, generation: int, suffix: String, payload: Dictionary, schema: int = Repository.SCHEMA_VERSION) -> void:
    var body := JSON.stringify({"generation": generation, "schemaVersion": schema, "payload": payload})
    var file := FileAccess.open(repo._directory.path_join("tp-save-%d.%s" % [generation, suffix]), FileAccess.WRITE)
    if file == null:
        check(false, "fixture generation opens")
        return
    file.store_string(JSON.stringify({"body": body, "sha256": body.sha256_text()}))
    file.close()
