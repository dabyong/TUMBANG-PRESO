extends "res://tests/ui_test_harness.gd"

const BootScript = preload("res://scripts/app/boot.gd")
const Progress = preload("res://scripts/domain/campaign_progress.gd")
var _clip_dir := ""
var _clip_index := 0

class SplashPreview extends BootScript:
    func _ready() -> void:
        _layout_splash()

func suite_name() -> String:
    return "Navigation and presentation"

func run_checks() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--clip-dir="):
            _clip_dir = arg.trim_prefix("--clip-dir=")
    if not capture_dir.is_empty():
        var splash := Boot.instantiate()
        splash.set_script(SplashPreview)
        viewport.add_child(splash)
        await capture("01-splash")
        splash.free()
    await _test_journey()
    await _test_other_province()
    await _test_compact_trajectory()

func _test_journey() -> void:
    var repo := repository("journey")
    var game := boot_game(repo)
    var store_id: int = game._store.get_instance_id()
    check(screen_visible(game, "Menu") and game.get_node(PANELS + "Menu/Actions/Continue").disabled, "fresh boot opens the main menu and explains unavailable Continue")
    await capture("02-main-menu")
    press(game, PANELS + "Menu/Actions/Credits")
    check(screen_visible(game, "Credits"), "credits opens as a reusable screen")
    press(game, PANELS + "Credits/Back")
    var initial: Dictionary = game.snapshot()
    press(game, PANELS + "Menu/Actions/Play")
    check(screen_visible(game, "Map") and game.snapshot() == initial, "Play opens the map without mutating progress")
    check(game.get_node(MAP_NODES + "cagayan").disabled and game.get_node(MAP_NODES + "isabela").disabled, "locked provinces disable map selection")
    press(game, MAP_NODES + "cagayan")
    check(screen_visible(game, "Map"), "a locked province cannot lead to gameplay")
    await capture("03-map-before")
    press(game, PANELS + "Map/Actions/Progress")
    check(game.get_node(PANELS + "Progress/Details").text.contains("Northern Luzon"), "progress lists chapter and province records")
    press(game, PANELS + "Progress/Back")
    press(game, MAP_NODES + "batanes")
    check(screen_visible(game, "Entry") and game.get_node(PANELS + "Entry/Progress").text.contains("Question topics:"), "discovery shows its region and approved question categories")
    await capture("04-province-discovery")
    press(game, PANELS + "Entry/New")
    check(screen_visible(game, "Difficulty") and game.get_node(PANELS + "Difficulty/Normal").text.contains("Hint after one miss"), "difficulty screen displays the hint rule and best-record field")
    await capture("05-difficulty")
    press(game, PANELS + "Difficulty/Normal")
    check(session(game).provinceId == "batanes" and session(game).difficulty == "normal" and game._store.get_instance_id() == store_id, "selected options reach the original store")
    await capture("06-gameplay-idle")

    var shown: Array[String] = []
    game.answer_presented.connect(func(outcome: String, _question: String, _option: String): shown.append(outcome))
    var hud: Label = game.get_node(HUD + "Status")
    var score_before := hud.text
    var correct_id: String = question(game).correctOptionId
    var answer_button: Control = game.get_node(ANSWERS).button_for(correct_id)
    await process_frame
    await process_frame
    _touch_with_mouse_emulation(answer_button.get_global_rect().get_center())
    var fx := game.get_node("Effects")
    check(game.presentation_state() == "throw" and fx.source == answer_button and fx.target == game.get_node(HUD + "TinCan"), "throw starts at the selected rendered tsinela and targets the can")
    check(session(game).score == 100 and session(game).processedSubmissions.size() == 1 and shown.is_empty(), "touch and its emulated mouse events commit exactly once before presentation")
    check(hud.text == score_before and not game.get_node(PANELS + "Play/Feedback").visible, "HUD and feedback remain gated during the throw")
    tap(game, correct_id)
    tap(game, wrong_options(game)[0])
    press(game, ACK)
    check(session(game).questionIndex == 0 and session(game).processedSubmissions.size() == 1 and game.get_node(ACK).disabled, "rapid taps and acknowledgement cannot bypass the gate")
    step(game, 0.08)
    await capture("07a-throw-launch")
    step(game, 0.12)
    await capture("07-throw-parabola")
    press(game, HUD + "Pause")
    var elapsed: float = fx.elapsed
    step(game, 1.0)
    check(game.presentation_state() == "paused" and fx.elapsed == elapsed and shown.is_empty(), "pause suspends the active throw")
    press(game, PANELS + "Pause/Resume")
    step(game, 0.26)
    check(game.presentation_state() == "impact" and session(game).processedSubmissions.size() == 1, "resume continues the throw without resubmission")
    step(game, 0.39)
    var can := game.get_node(HUD + "TinCan")
    check(is_equal_approx(can.spin_radians, TAU * 2.0) and hud.text == score_before, "normal impact completes a 720-degree spin while the HUD is gated")
    await capture("08-correct-impact")
    step(game, 0.20)
    check(game.presentation_state() == "feedback" and shown == ["correct"] and hud.text.contains("Score 100"), "finished impact reveals exactly one committed score and feedback")
    await capture("09-correct-feedback")
    press(game, ACK)
    check(session(game).questionIndex == 1, "explicit acknowledgement advances the question")

    var wrong: String = wrong_options(game)[0]
    tap(game, wrong)
    check(not fx.correct and session(game).misses == 1 and shown.size() == 1, "wrong answer commits one miss and selects a visibly missed trajectory")
    step(game, 0.49)
    check(game.presentation_state() == "miss" and can.spin_radians == 0.0, "miss reaction leaves the can upright")
    step(game, 0.30)
    check(shown == ["correct", "incorrect"] and game.get_node(PANELS + "Play/Feedback/Message").text == "Miss. Try another answer.", "incorrect feedback stays neutral and appears once")
    await capture("10-incorrect-feedback")
    press(game, ACK)
    check(session(game).questionIndex == 1 and game.get_node(PANELS + "Play/Hint").visible and game.get_node(ANSWERS).button_for(wrong).disabled, "miss retains the question and unlocks the normal hint")

    for _index in range(3):
        finish_correct(game)
    tap(game, question(game).correctOptionId)
    step(game, 2.0)
    press(game, ACK)
    var victory := session(game)
    check(game.presentation_state() == "victory" and victory.state == Session.VICTORY and victory.score == 475 and victory.stars == 3, "final acknowledgement commits the only victory")
    check(game.get_node(PANELS + "Result/Return").disabled and game.get_node(PANELS + "Result/Stars").text.is_empty(), "victory reveals reward stars before enabling navigation")
    step(game, 0.36)
    await capture("11-stars-revealing")
    step(game, 1.0)
    var win_snapshot: Dictionary = game.snapshot()
    check(game.get_node(PANELS + "Result/Stars").text == "★★★" and game.snapshot().progress.records["batanes/normal"].bestStars == 3, "revealed stars match committed records")
    await capture("12-victory")
    press(game, PANELS + "Result/Return")
    check(screen_visible(game, "Map") and game.get_node(PANELS + "Map/Highlight").text.contains("Cagayan"), "Continue highlights Cagayan on the map")
    check(game.get_node(MAP_NODES + "batanes").text.contains("Completed") and not game.get_node(MAP_NODES + "cagayan").disabled and game.get_node(MAP_NODES + "isabela").disabled, "map projects completed, unlocked and locked independently")
    await capture("13-map-after")
    press(game, MAP_NODES + "cagayan")
    check(screen_visible(game, "Entry") and game.get_node(PANELS + "Entry/New").disabled, "unlocked Cagayan is inspectable while its empty pools block Play")
    game.get_parent().free()
    game = boot_game(repo)
    check(game.get_node(PANELS + "Menu/Resume").text.begins_with("View saved result"), "main menu offers a saved-result action independently of Continue")
    press(game, PANELS + "Menu/Actions/Continue")
    check(game.get_node(MAP_NODES + "cagayan").text.begins_with("  ▸") and game.snapshot() == win_snapshot, "Continue restores the most recently selected accessible province without modifying saves")
    press(game, MAP_NODES + "batanes")
    press(game, PANELS + "Entry/Resume")
    check(screen_visible(game, "Result") and game.snapshot() == win_snapshot, "viewing saved results leaves rewards and progression unchanged")
    press(game, PANELS + "Result/Replay")
    await _test_interruption_and_failure(game, repo)

func _test_interruption_and_failure(game: Control, repo: Repository) -> void:
    var initial := session(game)
    tap(game, wrong_options(game)[0])
    var fx := game.get_node("Effects")
    var token: int = fx.token
    game.notification(NOTIFICATION_APPLICATION_PAUSED)
    step(game, 1.0)
    check(fx.elapsed == 0.0 and session(game).misses == 1, "background notification suspends an already committed throw")
    game.notification(NOTIFICATION_APPLICATION_RESUMED)
    press(game, HUD + "Pause")
    press(game, PANELS + "Pause/Restart")
    check(screen_visible(game, "Confirm") and initial.sessionId == session(game).sessionId, "restart asks for confirmation before replacing the active attempt")
    press(game, PANELS + "Confirm/Cancel")
    check(screen_visible(game, "Pause") and fx.token == token, "cancel keeps the paused presentation")
    press(game, PANELS + "Pause/Restart")
    press(game, PANELS + "Confirm/Accept")
    var fresh := session(game)
    fx.phase_finished.emit("failure", token, initial.sessionId)
    check(fresh.sessionId != initial.sessionId and fresh == session(game) and game.presentation_state() == "idle", "restart invalidates old presentation callbacks")
    tap(game, wrong_options(game)[0])
    var committed := session(game)
    game.get_parent().free()
    game = boot_game(repo)
    press(game, PANELS + "Menu/Resume")
    check(session(game) == committed and game.presentation_state() == "feedback", "interrupted presentation restores committed feedback without replay")
    press(game, ACK)
    var rejected: Array = committed.rejectedOptionIdsByQuestion[committed.questionIds[0]]
    for option in wrong_options(game):
        if option not in rejected:
            tap(game, option)
            step(game, 2.0)
            press(game, ACK)
    finish_correct(game)
    viewport.size = Vector2i(640, 360)
    await process_frame
    await process_frame
    tap(game, wrong_options(game)[0])
    check(session(game).state == Session.FAILURE and not screen_visible(game, "Result"), "the fifth miss commits failure while results remain hidden")
    step(game, 0.68)
    check(game.presentation_state() == "failure" and not screen_visible(game, "Result"), "miss reaction runs before the terminal overlay")
    await capture("14-failure-overlay")
    press(game, ACK)
    step(game, 1.0)
    check(screen_visible(game, "Result") and session(game).misses == 5 and session(game).stars == 0, "the failure screen appears after the overlay with no extra acknowledgement")
    await capture("15-failure")
    game.get_parent().free()

func _test_other_province() -> void:
    var graph := campaign.duplicate(true)
    var bank := catalog.duplicate(true)
    for index in range(5):
        var item: Dictionary = bank.questions[index].duplicate(true)
        item.questionId = "fixture-cagayan-%d" % index
        item.provinceId = "cagayan"
        bank.questions.append(item)
        questions[item.questionId] = item
        graph.provinces[1].questionPools.easy.append(item.questionId)
    var repo := repository("second-province")
    var seed := Store.new(repo, graph, bank)
    seed.restore()
    var checkpoint := seed.snapshot()
    for difficulty in ["easy", "normal", "hard"]:
        Progress.merge_success(checkpoint.progress, graph, "batanes", difficulty, 500, 3)
    check(repo.save(checkpoint), "isolated fixture has three mastery records")
    seed = null
    viewport.size = Vector2i(844, 390)
    var game := Gameplay.instantiate()
    viewport.add_child(game)
    game.configure(repo, graph, bank)
    press(game, PANELS + "Menu/Actions/Play")
    check(game.get_node(MAP_NODES + "batanes").text.contains("Mastered"), "all three three-star records appear as mastery")
    choose(game, "cagayan", "easy")
    check(session(game).provinceId == "cagayan" and session(game).difficulty == "easy", "an eligible non-start province can launch through the real controller")
    check(not game.configure(repo, graph, bank), "controller refuses a second writable store")
    await process_frame
    await process_frame
    check(game.get_node(ANSWERS).get_child_count() == 5 and game.get_node(HUD + "Status").is_visible_in_tree(), "wide mobile aspect keeps the HUD and exactly five mapped answers")
    viewport.size = Vector2i(640, 360)
    var option: Button = game.get_node(ANSWERS).get_child(4)
    var long_label := "This deliberately long answer wraps across multiple lines and remains readable in a compact landscape viewport. ".repeat(2)
    option.display_answer(option.question_id, option.option_id, long_label.strip_edges(), false, true)
    await process_frame
    await process_frame
    var scroll: ScrollContainer = game.get_node("Margin/Frame/Scroll")
    scroll.ensure_control_visible(option)
    await process_frame
    check(option.custom_minimum_size.y > 54 and option.size.x <= scroll.size.x and scroll.scroll_vertical > 0, "long answer wraps inside its touch target and remains reachable")
    await capture("16-compact-layout")
    game.free()

func _touch_with_mouse_emulation(point: Vector2) -> void:
    for pressed in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = point
        touch.pressed = pressed
        viewport.push_input(touch, true)
        var emulated := InputEventMouseButton.new()
        emulated.button_index = MOUSE_BUTTON_LEFT
        emulated.position = point
        emulated.pressed = pressed
        viewport.push_input(emulated, true)

func _test_compact_trajectory() -> void:
    viewport.size = Vector2i(640, 360)
    var repo := repository("compact-trajectory")
    var seed := Store.new(repo, campaign, catalog)
    seed.restore()
    var questions_in_order: Array = campaign.provinces[0].questionPools.normal.slice(0, 5)
    var options := {}
    for id in questions_in_order:
        var correct: String = questions[id].correctOptionId
        var order: Array = questions[id].options.map(func(option): return option.optionId)
        order.erase(correct)
        order.append(correct)
        options[id] = order
    check(seed.start_session("compact", "batanes", "normal", {"questionIds": questions_in_order, "optionOrderByQuestion": options}) == "", "fixture puts the correct answer in the fifth slot")
    seed = null
    var game := boot_game(repo)
    resume_saved(game)
    await process_frame
    await process_frame
    var scroll: ScrollContainer = game.get_node("Margin/Frame/Scroll")
    var fifth: Button = game.get_node(ANSWERS).get_child(4)
    scroll.ensure_control_visible(fifth)
    await process_frame
    var offset := scroll.scroll_vertical
    var target: Control = game.get_node(HUD + "TinCan")
    var prompt: Control = game.get_node(PANELS + "Play/PromptRow")
    check(offset > 0 and prompt.get_global_rect().position.y < scroll.get_global_rect().position.y and target.get_global_rect().end.y <= scroll.get_global_rect().position.y, "scrolling to the fifth answer clips the prompt while the target remains pinned")
    _touch_with_mouse_emulation(fifth.get_global_rect().get_center())
    var fx := game.get_node("Effects")
    var path: PackedVector2Array = fx.trajectory()
    var area := Rect2(Vector2.ZERO, Vector2(viewport.size))
    check(fx.source == fifth and fx.correct and path[0].is_equal_approx(fifth.throw_origin()) and area.has_point(path[1]), "fifth-answer launch starts at its visible icon and lands within the viewport")
    check(area.has_point(fx.projectile_position(0.5)) and fx.projectile_position(0.5).y < path[0].lerp(path[1], 0.5).y, "compact mid-flight stays visible on a parabolic path")
    await _step_with_clip(game, 0.11)
    await capture("19-compact-fifth-launch")
    var before_pause: Vector2 = fx.projectile_position(fx.elapsed / fx.DURATIONS.throw[0])
    press(game, HUD + "Pause")
    await capture("20-compact-paused")
    press(game, PANELS + "Pause/Settings")
    await capture("21-compact-pause-settings")
    press(game, PANELS + "Settings/Back")
    press(game, PANELS + "Pause/Resume")
    step(game, 1.0)
    check(is_equal_approx(fx.elapsed, 0.11) and fx.suspended, "presentation stays suspended while the compact scroll layout is restored")
    await process_frame
    await process_frame
    await process_frame
    check(scroll.scroll_vertical == offset and not fx.suspended and before_pause.is_equal_approx(fx.projectile_position(fx.elapsed / fx.DURATIONS.throw[0])), "pause, settings and resume restore the same scroll offset and flight position")
    await capture("22-compact-resumed-throw")
    viewport.size = Vector2i(844, 390)
    await process_frame
    await process_frame
    var wide := Rect2(Vector2.ZERO, Vector2(viewport.size))
    var wide_path: PackedVector2Array = fx.trajectory()
    check(game.presentation_state() == "throw" and wide.has_point(wide_path[0]) and wide.has_point(wide_path[1]) and wide.has_point(fx.projectile_position(0.5)), "resizing an active throw reprojects both endpoints and the arc")
    viewport.size = Vector2i(640, 360)
    await process_frame
    await process_frame
    press(game, ACK)
    check(session(game).processedSubmissions.size() == 1 and session(game).questionIndex == 0, "resumed flight still blocks a second submission or acknowledgement")
    await _step_with_clip(game, 0.40)
    check(game.presentation_state() == "impact" and target.is_visible_in_tree() and area.has_point(target.get_global_rect().get_center()), "compact correct impact remains visible on the fixed target")
    await capture("23-compact-impact")
    var impact_elapsed: float = fx.elapsed
    press(game, HUD + "Pause")
    step(game, 1.0)
    press(game, PANELS + "Pause/Resume")
    await process_frame
    await process_frame
    await process_frame
    check(game.presentation_state() == "impact" and is_equal_approx(impact_elapsed, fx.elapsed), "pause and resume preserve the suspended impact frame")
    viewport.size = Vector2i(844, 390)
    await process_frame
    await process_frame
    check(wide.has_point(target.get_global_rect().get_center()) and game.presentation_state() == "impact", "wider resize preserves visible impact and its phase")
    await capture("24-wide-impact")
    if not _clip_dir.is_empty():
        viewport.size = Vector2i(640, 360)
        await process_frame
        await process_frame
    await _step_with_clip(game, 1.0)
    viewport.size = Vector2i(844, 390)
    await process_frame
    await process_frame
    press(game, ACK)
    var wrong: String = wrong_options(game)[0]
    tap(game, wrong)
    var miss: PackedVector2Array = fx.trajectory()
    check(wide.has_point(miss[1]) and not miss[1].is_equal_approx(target.get_global_rect().get_center()), "wrong throw ends visibly away from the target on the wide layout")
    game.get_parent().free()

func _step_with_clip(game: Control, seconds: float) -> void:
    if _clip_dir.is_empty():
        step(game, seconds)
        return
    var frames := ceili(seconds * 30.0)
    for _frame in range(frames):
        step(game, seconds / frames)
        await RenderingServer.frame_post_draw
        var image := viewport.get_texture().get_image()
        var output := _clip_dir.path_join("frame-%03d.png" % _clip_index)
        if image == null or image.save_png(output) != OK:
            check(false, "could not record compact throw frame")
        _clip_index += 1
