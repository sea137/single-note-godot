extends SceneTree

var app
var checks = 0
var failed = false

func check(value: bool, message: String):
	checks += 1
	if not value:
		failed = true
		printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _initialize():
	call_deferred("run")

func run():
	app = load("res://main.tscn").instantiate()
	app.save_path = "user://smoke_test.json"
	root.add_child(app)
	await process_frame
	# Keep the user's real history/settings untouched by restoring them at the end.
	var previous_settings = app.settings.duplicate(true)
	var previous_history = app.history.duplicate(true)
	var previous_learning = app.learning.items.duplicate(true)
	check(app.samples.size() == 36, "36 bundled piano samples")
	for key in app.samples:
		check(app.samples[key] is AudioStreamMP3 and app.samples[key].get_length() > 0.1, "decodable " + key)
	app.settings = {"preset":0,"notes":["C","D","E"],"limit":3,"octave":2,"auto":false,"volume":70.0}
	app.settings.reference = 0
	app.settings.octave_challenge = false
	app._start_session()
	check(app.session.number == 1 and app.session.octave == 4, "first question and fixed middle octave")
	var note = app.session.note
	var wrong = "D" if note == "C" else "C"
	app._answer(wrong)
	check(app.session.attempts == 1 and app.session.correct == 0, "wrong first answer counted once")
	app._answer(note)
	check(app.session.attempts == 1 and app.session.correct == 0 and app.session.solved, "retry solves without inflating accuracy")
	app._next_question()
	check(app.session.number == 2 and app.session.attempts == 1, "next after solved question")
	app._answer(app.session.note)
	check(app.session.correct == 1 and app.session.attempts == 2, "correct first answer")
	app._next_question()
	app._next_question()
	check(app.page == "result" and app.session.is_empty(), "fixed length quiz finishes after skip")
	var result = app.history[0]
	check(result.attempts == 3 and result.correct == 1, "skip counts wrong; total statistics")
	check(result.best_streak == 1, "best streak calculation")
	app.settings.limit = 0
	app.settings.octave = 0
	app.settings.notes = app.NOTES.duplicate()
	app._start_session()
	var seen = {}
	for i in 120:
		check(app.session.note in app.NOTES and app.session.octave in [3,4,5], "valid random question " + str(i))
		seen[app.session.octave] = true
		app._next_question()
	check(seen.size() == 3 and app.page == "practice", "unlimited quiz uses all three octaves")
	app._end_session()
	app.settings.auto = true
	app.settings.notes = ["C"]
	app.settings.limit = 1
	app._start_session()
	app._answer("C")
	check(not app.advance_timer.is_stopped(), "auto proceed timer armed")
	await create_timer(1.25).timeout
	check(app.page == "result", "auto proceed reaches result")
	app._start_session()
	app._answer("C")
	app._end_session()
	check(app.advance_timer.is_stopped(), "ending practice cancels pending auto advance")
	app.settings = previous_settings
	app.history = previous_history
	app.learning.items = previous_learning
	app._save()
	app._show_setup()
	await create_timer(0.3).timeout
	print("CHECKS: " + str(checks) + " FAILED: " + str(failed))
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
