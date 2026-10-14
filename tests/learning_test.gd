extends SceneTree
var failed = false
var checks = 0
var app

func check(ok: bool, message: String):
	checks += 1
	if not ok: failed = true; printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _initialize(): call_deferred("run")

func run():
	var memory = load("res://learning_state.gd").new()
	var now = 1000000
	memory.record("C4",true,false,"C",now)
	check(memory.items.C4.due_at == now+86400 and memory.items.C4.stage == 1,"first independent recall schedules one day")
	memory.record("C4",true,false,"C",now+60)
	check(memory.items.C4.stage == 1 and memory.items.C4.due_at == now+86400,"early repetition does not inflate memory stage")
	memory.record("C4",true,false,"C",now+86400)
	check(memory.items.C4.stage == 2 and memory.items.C4.due_at == now+4*86400,"due independent recall increases spacing")
	memory.record("D4",true,true,"D",now)
	check(memory.items.D4.stage == 0 and memory.items.D4.due_at == now+3600,"assisted answer gets short review interval")
	memory.record("E5",false,false,"D",now)
	check(memory.items.E5.stage == 0 and memory.items.E5.due_at == now+600,"wrong note schedules ten-minute review")
	check(memory.items.E5.confusions.D == 1,"specific confusion retained")
	check(memory.due_keys(now+600) == ["E5"],"due queue excludes future reviews")
	memory.import_items({"Q4":{},"C9":{},"F3":{"stage":999,"due_at":-10}})
	check(memory.items.size() == 1 and memory.items.F3.stage == 4 and memory.items.F3.due_at == 0,"stored progress validates keys and clamps stages")
	app = load("res://main.tscn").instantiate()
	app.save_path = "user://learning_test.json"
	root.add_child(app)
	await process_frame
	app.settings.notes = ["E","C","D"]
	app.settings.octave = 0
	app.settings.reference = 1
	app.settings.octave_challenge = false
	app.settings.auto = false
	app.learning.items.clear()
	check(app._selected_keys() == ["C3","D3","E3","C4","D4","E4","C5","D5","E5"],"reference sequence sorts all nine pitches by octave and note")
	app._start_session()
	check(app.page == "reference" and app.reference_label.text == "C3 · 低音区","default session begins with low C reference")
	app._toggle_reference()
	check(not app.reference_active and app.reference_timer.is_stopped(),"reference pause cancels next sample")
	app._reference_single("E4")
	check(app.reference_index == 5 and app.reference_label.text == "E4 · 中音区","single-note reference updates highlight and resume position")
	app._finish_reference()
	check(app.page == "practice" and app.session.assisted,"round warmup marks practice as assisted")
	app._answer(app.session.note)
	check(app.detail_label.visible and app.detail_label.text == app._key_label(str(app.session.note)+str(app.session.octave)),"answer reveals actual note and register")
	check(app.session.guided_correct == 1 and app.session.blind_correct == 0,"guided accuracy is distinct from independent accuracy")
	app._end_session()
	app._start_session(1)
	check(app.page == "practice" and app.session.limit == 5 and not app.session.assisted,"cold check bypasses warmup and has five questions")
	app._answer(app.session.note)
	check(not app.detail_label.visible and not app.feedback.text.contains("答对"),"cold check does not leak correctness or pitch labels")
	app._reveal()
	check(not app.detail_label.visible,"cold check blocks reveal action")
	app._end_session()
	app.settings.reference = 2
	app.settings.limit = 2
	app._start_session()
	check(app.page == "reference" and app.session.number == 1,"per-question reference preserves pending question")
	app._finish_reference()
	app._answer(app.session.note)
	app._next_question()
	check(app.page == "reference" and app.session.number == 2 and app.session.attempts == 1,"next-question reference does not count a phantom answer")
	app._end_session()
	app.settings.reference = 0
	app.settings.octave_challenge = true
	app.settings.limit = 1
	app._start_session()
	app._answer(app.session.note)
	check(app.challenge_box.visible and not app.detail_label.visible and not app.session.solved,"octave challenge conceals register until answered")
	app._answer_octave(int(app.session.octave))
	check(app.session.octave_correct == 1 and app.detail_label.visible and app.session.solved,"register score and label after challenge")
	app._end_session()
	app.learning.items.clear()
	var actual_now = int(Time.get_unix_time_from_system())
	app.learning.record("C3",false,false,"D",actual_now-700)
	app.learning.record("D4",true,false,"D",actual_now)
	app._start_session(2)
	check(app.session.note == "C" and app.session.octave == 3 and app.session.limit == 1,"daily review chooses due item only")
	app._answer("C")
	app._next_question()
	check(app.page == "result", "daily review completes finite queue")
	app.settings.reference = 0
	app.settings.octave_challenge = false
	app._start_session()
	app.session.number = 6
	app.session.review_queue = [{"key":"E5","after":5}]
	check(app._choose_question() == "E5","wrong-note return occurs after intervening questions")
	app._end_session()
	app.settings.notes = ["C"]
	app.learning.items.clear()
	app._start_session()
	app._answer("C")
	check(app.session.assisted and app.learning.items[str(app.session.note)+str(app.session.octave)].stage == 0,"one-option quiz cannot establish independent memory mastery")
	app._end_session()
	app.settings.notes = ["C","D","E"]
	var saved_history = app.history.duplicate(true)
	var saved_learning = app.learning.items.duplicate(true)
	app._save()
	app._save()
	app.history.clear()
	app.learning.items.clear()
	app._load_saved()
	check(app.learning.items == saved_learning and app.history.size() == saved_history.size(),"progress and history persist across repeated atomic saves")
	var legacy = FileAccess.open(app.save_path,FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"settings":{"notes":["C","D","E"],"octave":2},"history":[{"date":"old","attempts":3,"correct":2,"notes":["C"],"stats":{}}]}))
	legacy.close()
	app.history.clear()
	app.learning.items.clear()
	app._load_saved()
	check(app.history.size() == 1 and app.settings.octave == 2 and app.settings.reference == 1,"v1.0 records migrate without invented memory progress")
	app._stop_reference()
	app._stop_sound()
	await create_timer(0.3).timeout
	print("CHECKS: %d FAILED: %s" % [checks,failed])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
