extends SceneTree

var app
var checks = 0
var failed = false

func check(ok: bool, message: String):
	checks += 1
	if not ok: failed = true; printerr("FAIL: "+message)
	else: print("PASS: "+message)

func _initialize():
	call_deferred("run")

func run():
	app = load("res://main.tscn").instantiate()
	app.save_path = "user://regression_v12.json"
	root.add_child(app)
	await process_frame
	app.settings.notes = ["C","D","E"]
	app.settings.octave = 2
	app.settings.reference = 0
	app.settings.auto = true
	app.settings.limit = 0
	app.settings.octave_challenge = false
	app._start_session()
	var target = app.session.note
	var wrong = "D" if target == "C" else "C"
	app._answer(wrong)
	check(app.session.solved and app.session.correct == 0 and app.session.attempts == 1,"wrong answer reveals solution without changing first-answer score")
	check(app.choices[target].text.ends_with("✓") and app.choices[wrong].text.ends_with("✕"),"correct and wrong choices have distinct visible symbols")
	check(app.advance_timer.is_stopped(),"wrong answer remains available for study despite auto mode")
	app._reveal()
	app._contrast()
	check(app.page == "compare" and app.compare_keys.size() == 2,"comparison opens manual multi-note selection")
	app.compare_checks["B5"].button_pressed = true
	check("B5" in app.compare_keys and app.compare_summary.text.contains("B5"),"manual selection adds the exact high note and updates summary")
	app.compare_checks["B5"].button_pressed = false
	check("B5" not in app.compare_keys,"manual removal updates comparison playlist")
	app.compare_keys = [target+"3",target+"4",target+"5"]
	app._show_reference(func(): app._show_compare_picker(),app.compare_keys,true,"多音对比 · 由低到高")
	check(app.reference_keys.size() == 3 and app.reference_keys[0].ends_with("3") and app.reference_keys[2].ends_with("5"),"same-note octave comparison retains three pitches")
	app._finish_reference()
	app._show_practice(false)
	check(app.choices[target].text.ends_with("✓") and app.choices[wrong].text.ends_with("✕"),"wrong and correct markings survive page reconstruction")
	check(app.session.attempts == 1 and app.session.responses[0].guess == wrong,"revealing and comparing preserve original wrong choice")
	app._answer(target)
	check(app.session.correct == 0 and app.session.attempts == 1,"clicking after answer reveal cannot inflate score")
	app._end_session()
	app.settings.auto = false
	app._start_session(1)
	var cold_wrong = "D" if app.session.note == "C" else "C"
	app._answer(cold_wrong)
	check(not app.detail_label.visible and not app.choices[app.session.note].text.contains("✓"),"cold check still conceals correct answer")
	app._end_session()
	app.history = [
		{"date":"new","notes":["C","D","E"],"octaves":[4],"attempts":10,"correct":8,"blind_attempts":0,"blind_correct":0,"guided_attempts":10,"guided_correct":8},
		{"date":"other","notes":["C"],"octaves":[4],"attempts":10,"correct":10},
		{"date":"old","notes":["E","D","C"],"octaves":[4],"attempts":5,"correct":2,"blind_attempts":5,"blind_correct":2},
		{"date":"legacy","notes":["C","D","E"],"attempts":2,"correct":1}
	]
	var pts = app._history_points("overall",true)
	check(pts.size() == 2 and pts[0].rate == 40 and pts[1].rate == 80,"trend filters exact note scope and orders oldest to newest")
	check(app._history_points("blind",true).size() == 1,"missing independent scores are omitted rather than zero")
	check(app._history_points("overall",false).size() == 4,"all-scope view includes legacy records")
	check(app._encouragement({"attempts":10,"correct":1}) != app._encouragement({"attempts":10,"correct":9}),"encouragement changes with achieved accuracy")
	check(app.audio_gains.size() == 36 and app.audio_gains.C4 > 20,"all samples have measured gain calibration")
	app.settings.volume = 0
	app._play_key("C4")
	check(app.player.volume_db <= -80,"zero volume stays muted after normalization")
	app._show_setup()
	await process_frame
	await process_frame
	var old_scroll = app.scroll.scroll_vertical
	var down = InputEventScreenTouch.new(); down.index = 0; down.position = Vector2(200,500); down.pressed = true
	app._input(down)
	var drag = InputEventScreenDrag.new(); drag.index = 0; drag.position = Vector2(200,250)
	app._input(drag)
	check(app.touch_dragging and app.scroll.scroll_vertical > old_scroll,"vertical raw touch scrolls before child controls consume it")
	var up = InputEventScreenTouch.new(); up.index = 0; up.position = drag.position; up.pressed = false
	app._input(up)
	check(app.touch_index == -1 and not app.touch_dragging and app.touch_block_until > Time.get_ticks_msec(),"drag release suppresses accidental button action and clears touch state")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		app.settings.volume = 0
		app._start_session()
		await process_frame
		await process_frame
		var pos = app.choices[app.session.note].get_global_rect().get_center()
		var press = InputEventScreenTouch.new(); press.index = 0; press.position = pos; press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		var move = InputEventScreenDrag.new(); move.index = 0; move.position = pos-Vector2(0,20); move.relative = Vector2(0,-20)
		Input.parse_input_event(move)
		await process_frame
		var release = InputEventScreenTouch.new(); release.index = 0; release.position = move.position; release.pressed = false
		Input.parse_input_event(release)
		await process_frame
		check(app.session.attempts == 0,"dragging from a real answer button does not submit an answer")
		await create_timer(0.2).timeout
		pos = app.choices[app.session.note].get_global_rect().get_center()
		press.position = pos; release.position = pos
		Input.parse_input_event(press)
		await process_frame
		Input.parse_input_event(release)
		await process_frame
		check(app.session.attempts == 1 and app.session.correct == 1,"normal touch tap still submits after a drag")
	app._stop_sound()
	print("CHECKS: %d FAILED: %s" % [checks,failed])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
