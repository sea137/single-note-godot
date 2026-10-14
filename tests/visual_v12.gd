extends SceneTree

func _initialize(): call_deferred("run")

func capture(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../SingleNote-v12-"+name+".png"))

func run():
	var app = load("res://main.tscn").instantiate()
	app.save_path = "user://visual_v12.json"
	root.add_child(app)
	await process_frame
	app.settings.notes = ["C","D","E"]
	app.settings.octave = 2
	app.settings.auto = false
	app.settings.reference = 0
	app.settings.volume = 0
	app._start_session()
	app._answer("D" if app.session.note == "C" else "C")
	await capture("answer")
	app._contrast()
	await capture("compare")
	app._end_session()
	app.history.clear()
	for i in 8:
		app.history.push_front({"date":"2026-10-14 14:%02d:00" % i,"notes":["C","D","E"],"octaves":[4],"attempts":10,"correct":i+2,"stats":{},"responses":[],"blind_attempts":10,"blind_correct":i+2})
	app._show_history()
	await capture("trend")
	app.queue_free()
	await process_frame
	quit()
