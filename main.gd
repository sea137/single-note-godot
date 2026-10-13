extends Control

const GREEN = Color("284e3e")
const MUTED = Color("778078")
const CREAM = Color("f5f4ed")
const LINE = Color("e0e5d9")
const NOTES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const LABELS = {"Db":"C♯ / D♭", "Eb":"D♯ / E♭", "Gb":"F♯ / G♭", "Ab":"G♯ / A♭", "Bb":"A♯ / B♭"}
const PRESETS = [["C","D","E"], ["C","D","E","F","G"], ["C","D","E","F","G","A","B"], NOTES]
const SAVE_PATH = "user://practice.json"
var settings = {"preset":0, "notes":["C","D","E"], "limit":0, "octave":0, "auto":false, "volume":70.0}
var history: Array = []
var samples: Dictionary = {}
var session: Dictionary = {}
var page = "setup"
var content: VBoxContainer
var scroll: ScrollContainer
var player: AudioStreamPlayer
var advance_timer: Timer
var audio_timer: Timer
var stats_label: Label
var progress_label: Label
var feedback: Label
var next_button: Button
var choices: Dictionary = {}
var custom_buttons: Dictionary = {}
var custom_notes: Array = []
var font: Font
var strong_font: Font
var preview_label: Label
var audio_fade: Tween
var rng = RandomNumberGenerator.new()

func _ready():
	font = load("res://assets/NotoSansSC.ttf")
	strong_font = load("res://assets/NotoSansSC-Bold.ttf")
	rng.randomize()
	_load_saved()
	for note in NOTES:
		for octave in [3,4,5]:
			var key = note + str(octave)
			samples[key] = load("res://assets/audio/" + key + ".mp3")
	player = AudioStreamPlayer.new()
	add_child(player)
	advance_timer = Timer.new()
	advance_timer.one_shot = true
	advance_timer.timeout.connect(_next_question)
	add_child(advance_timer)
	audio_timer = Timer.new()
	audio_timer.one_shot = true
	audio_timer.timeout.connect(_fade_audio)
	add_child(audio_timer)
	var app_theme = Theme.new()
	app_theme.default_font = font
	app_theme.default_font_size = 18
	for type in ["OptionButton", "SpinBox", "LineEdit", "CheckButton"]:
		app_theme.set_color("font_color", type, GREEN)
		app_theme.set_color("font_hover_color", type, GREEN)
		app_theme.set_color("font_pressed_color", type, GREEN)
		app_theme.set_font_size("font_size", type, 18)
	for type in ["OptionButton", "LineEdit"]:
		app_theme.set_stylebox("normal", type, _style(Color("f3f5ec"), LINE))
		app_theme.set_stylebox("hover", type, _style(Color("e9efe0"), LINE))
		app_theme.set_stylebox("pressed", type, _style(Color("e1ebd8"), LINE))
		app_theme.set_stylebox("focus", type, _style(Color.TRANSPARENT, Color("8caa75")))
	app_theme.set_color("font_selected_color", "LineEdit", Color.WHITE)
	app_theme.set_color("selection_color", "LineEdit", GREEN)
	theme = app_theme
	_show_setup()
	get_tree().auto_accept_quit = false

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if page == "practice":
			_end_session()
		elif page != "setup":
			_show_setup()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if player:
			player.stop()
		if audio_timer:
			audio_timer.stop()
		if advance_timer:
			advance_timer.stop()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _text(text: String, size: int = 18, color: Color = GREEN, centered: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if size >= 25:
		label.add_theme_font_override("font", strong_font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _button(text: String, action: Callable, primary: bool = false, height: int = 62) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_font_override("font", strong_font)
	button.add_theme_color_override("font_color", Color.WHITE if primary else GREEN)
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else GREEN)
	button.add_theme_color_override("font_pressed_color", Color.WHITE if primary else GREEN)
	button.add_theme_stylebox_override("normal", _style(GREEN if primary else Color("fffef9"), Color.TRANSPARENT if primary else LINE))
	button.add_theme_stylebox_override("hover", _style(Color("365f4c") if primary else Color("edf2e5"), LINE))
	button.add_theme_stylebox_override("pressed", _style(Color("214433") if primary else Color("dce9d0"), LINE))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("8caa75")))
	button.pressed.connect(action)
	return button

func _space(parent: Control, height: int):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _base(new_page: String):
	page = new_page
	for child in get_children():
		if child is Control:
			remove_child(child)
			child.queue_free()
	var background = ColorRect.new()
	background.color = CREAM
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	var header = HBoxContainer.new()
	content.add_child(header)
	header.add_child(_text("♩ 单音", 25))
	var badge = _text("钢琴 · 离线", 13, MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(badge)
	_space(content, 22)

func _card(parent: Control) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("fffef9"), LINE, 22))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _footer():
	_space(content, 12)
	content.add_child(_text("只听一个音，只专注此刻。", 13, MUTED, true))

func _show_setup():
	_stop_sound()
	advance_timer.stop()
	_base("setup")
	content.add_child(_text("每天一点，听见进步", 14, MUTED))
	content.add_child(_text("听一个音，\n认识它的名字。", 38))
	content.add_child(_text("凭听觉选出音名，慢慢建立音高记忆。\n钢琴音色已内置，随时随地离线练习。", 17, MUTED))
	_space(content, 8)
	var card = _card(content)
	card.add_child(_text("练习哪些音？", 18))
	var preset = OptionButton.new()
	preset.custom_minimum_size.y = 56
	for title in ["入门 · C、D、E", "进阶 · C、D、E、F、G", "自然音 · 七个自然音", "全部 · 十二个半音", "自定义 · 选择音名"]:
		preset.add_item(title)
	preset.select(int(settings.preset))
	card.add_child(preset)
	var preview = _text("", 17, MUTED)
	preview_label = preview
	card.add_child(preview)
	var custom = GridContainer.new()
	custom.columns = 4
	card.add_child(custom)
	custom_buttons.clear()
	custom_notes = settings.notes.duplicate()
	for note in NOTES:
		var b = _button(note, _toggle_note.bind(note), false, 50)
		b.toggle_mode = true
		b.button_pressed = note in custom_notes
		custom.add_child(b)
		custom_buttons[note] = b
	custom.visible = int(settings.preset) == 4
	preview.text = "  ·  ".join(settings.notes)
	preset.item_selected.connect(func(index):
		settings.preset = index
		custom.visible = index == 4
		settings.notes = custom_notes.duplicate() if index == 4 else PRESETS[index].duplicate()
		preview.text = "  ·  ".join(settings.notes)
		_save()
	)
	card.add_child(_text("这次练多少题？", 18))
	var number_row = HBoxContainer.new()
	card.add_child(number_row)
	var count = SpinBox.new()
	count.min_value = 0
	count.max_value = 999
	count.step = 1
	count.value = settings.limit
	count.custom_minimum_size = Vector2(110, 52)
	count.value_changed.connect(func(value): settings.limit = int(value); _save())
	number_row.add_child(count)
	number_row.add_child(_text("0 = 自由练习\n不限制题数", 15, MUTED))
	var advanced = VBoxContainer.new()
	advanced.add_theme_constant_override("separation", 12)
	advanced.visible = false
	var expand = _button("更多设置  ＋", func(): advanced.visible = not advanced.visible, false, 48)
	card.add_child(expand)
	card.add_child(advanced)
	var auto = CheckButton.new()
	auto.text = "答对后自动下一题"
	auto.custom_minimum_size.y = 54
	auto.button_pressed = settings.auto
	auto.toggled.connect(func(value): settings.auto = value; _save())
	advanced.add_child(auto)
	advanced.add_child(_text("音高范围", 17))
	var octave = OptionButton.new()
	for title in ["随机八度 · C3–B5", "低音区 · 第 3 八度", "中音区 · 第 4 八度", "高音区 · 第 5 八度"]:
		octave.add_item(title)
	octave.select(int(settings.octave))
	octave.custom_minimum_size.y = 52
	octave.item_selected.connect(func(index): settings.octave = index; _save())
	advanced.add_child(octave)
	var volume_label = _text("音量  " + str(int(settings.volume)) + "%", 17)
	advanced.add_child(volume_label)
	var volume = HSlider.new()
	volume.max_value = 100
	volume.value = settings.volume
	volume.custom_minimum_size.y = 38
	volume.value_changed.connect(func(value): settings.volume = value; volume_label.text = "音量  " + str(int(value)) + "%"; _save())
	advanced.add_child(volume)
	var warning = _text("请至少选一个音名。", 15, Color("a35439"))
	warning.visible = false
	card.add_child(warning)
	card.add_child(_button("开始练习  →", func():
		if settings.notes.is_empty(): warning.visible = true
		else: _start_session()
	, true))
	card.add_child(_text("开始后播放第一题，请先调整手机音量。", 13, MUTED, true))
	content.add_child(_button("练习记录  ·  " + str(history.size()) + " 次", _show_history, false, 48))
	content.add_child(_button("关于单音", _show_about, false, 44))
	_footer()

func _toggle_note(note: String):
	if note in custom_notes: custom_notes.erase(note)
	else: custom_notes.append(note)
	settings.notes = custom_notes.duplicate()
	preview_label.text = "  ·  ".join(settings.notes)
	_save()

func _start_session():
	if settings.notes.is_empty(): return
	_save()
	session = {"notes":settings.notes.duplicate(), "limit":int(settings.limit), "auto":bool(settings.auto), "octaves":[3,4,5] if int(settings.octave) == 0 else [int(settings.octave)+2], "number":0, "attempts":0, "correct":0, "streak":0, "best_streak":0, "stats":{}, "note":"", "octave":4, "answered":false, "solved":false, "start_time":Time.get_unix_time_from_system()}
	_base("practice")
	var top = HBoxContainer.new()
	content.add_child(top)
	progress_label = _text("", 15, MUTED)
	top.add_child(progress_label)
	top.add_child(_button("结束练习", _end_session, false, 44))
	stats_label = _text("", 17, GREEN, true)
	var stats_card = _card(content)
	stats_card.add_child(stats_label)
	_space(content, 14)
	content.add_child(_text("专注这一颗音", 14, MUTED, true))
	content.add_child(_text("你听到的是？", 32, GREEN, true))
	content.add_child(_button("▶  重听这一颗音", _play_note, true, 100))
	content.add_child(_text("不限重听次数 · 答案只需选音名", 14, MUTED, true))
	_space(content, 8)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	choices.clear()
	for note in session.notes:
		var button = _button(LABELS.get(note, note), _answer.bind(note), false, 70)
		button.add_theme_font_size_override("font_size", 23 if note.length() == 1 else 17)
		grid.add_child(button)
		choices[note] = button
	feedback = _text("", 17, MUTED, true)
	feedback.custom_minimum_size.y = 44
	content.add_child(feedback)
	next_button = _button("", _next_question, true)
	content.add_child(next_button)
	_footer()
	_next_question()

func _update_stats():
	var rate = "—" if int(session.attempts) == 0 else str(roundi(float(session.correct) / session.attempts * 100)) + "%"
	stats_label.text = "首答正确  %d     已作答  %d     正确率  %s" % [session.correct, session.attempts, rate]

func _next_question():
	advance_timer.stop()
	if session.is_empty() or page != "practice": return
	if session.note != "" and not session.answered: _record(false)
	if int(session.limit) > 0 and int(session.number) >= int(session.limit):
		_end_session()
		return
	session.number += 1
	session.answered = false
	session.solved = false
	session.note = session.notes[rng.randi_range(0, session.notes.size()-1)]
	session.octave = session.octaves[rng.randi_range(0, session.octaves.size()-1)]
	progress_label.text = "第 %d 题" % session.number + (" / %d" % session.limit if int(session.limit) > 0 else " · 自由练习")
	feedback.text = "听完后，选一个音名。"
	feedback.add_theme_color_override("font_color", MUTED)
	next_button.text = "跳过，下一题  →"
	for button in choices.values():
		button.disabled = false
		button.add_theme_stylebox_override("normal", _style(Color("fffef9"), LINE))
		button.add_theme_stylebox_override("disabled", _style(Color("fffef9"), LINE))
		button.add_theme_color_override("font_disabled_color", GREEN)
	_update_stats()
	_play_note()

func _record(correct: bool):
	session.answered = true
	session.attempts += 1
	if correct:
		session.correct += 1
		session.streak += 1
		session.best_streak = maxi(int(session.best_streak), int(session.streak))
	else: session.streak = 0
	if not session.stats.has(session.note): session.stats[session.note] = {"heard":0, "correct":0}
	session.stats[session.note].heard += 1
	if correct: session.stats[session.note].correct += 1
	_update_stats()

func _answer(note: String):
	if page != "practice" or session.solved: return
	var correct = note == session.note
	if not session.answered: _record(correct)
	var button = choices[note]
	if not correct:
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _style(Color("fae8df"), Color("d7a993")))
		button.add_theme_color_override("font_disabled_color", Color("a35439"))
		feedback.text = "还差一点，再听一次试试。"
		feedback.add_theme_color_override("font_color", Color("a35439"))
		return
	session.solved = true
	for b in choices.values(): b.disabled = true
	button.add_theme_stylebox_override("disabled", _style(Color("dcebcf"), Color("90ad7c")))
	feedback.text = "答对了，是 " + str(LABELS.get(note, note)) + "！"
	feedback.add_theme_color_override("font_color", Color("477134"))
	next_button.text = "查看练习结果  →" if int(session.limit) > 0 and session.number >= session.limit else "下一题  →"
	if session.auto: advance_timer.start(1.1)

func _play_note():
	if session.is_empty() or page != "practice": return
	_stop_sound()
	var key = str(session.note) + str(session.octave)
	player.stream = samples[key]
	player.volume_db = linear_to_db(maxf(float(settings.volume) / 100.0, 0.0001))
	player.play()
	audio_timer.start(1.4)

func _fade_audio():
	audio_fade = create_tween()
	audio_fade.tween_property(player, "volume_db", -65.0, 0.22)
	audio_fade.tween_callback(player.stop)

func _stop_sound():
	if audio_fade and audio_fade.is_valid(): audio_fade.kill()
	if player:
		player.stop()
		player.stream = null
	if audio_timer: audio_timer.stop()

func _end_session():
	if session.is_empty(): return
	advance_timer.stop()
	_stop_sound()
	var result = session.duplicate(true)
	result.date = Time.get_datetime_string_from_system(false, true)
	result.duration = maxi(0, int(Time.get_unix_time_from_system() - float(session.start_time)))
	if result.attempts > 0:
		history.push_front(result)
		if history.size() > 100: history.resize(100)
		_save()
	session.clear()
	_show_result(result)

func _show_result(result: Dictionary):
	_base("result")
	content.add_child(_text("每一次聆听，都是积累", 14, MUTED))
	content.add_child(_text("今天又进步了一点。", 32))
	content.add_child(_text("共作答 %d 题，首答正确 %d 题。" % [result.attempts, result.correct], 18, MUTED))
	var card = _card(content)
	var rate = 0 if result.attempts == 0 else roundi(float(result.correct) / result.attempts * 100)
	card.add_child(_text(str(rate) + "%", 64, GREEN, true))
	card.add_child(_text("首答正确率", 16, MUTED, true))
	card.add_child(_text("最长连续首答正确：%d 题" % result.best_streak, 16, MUTED, true))
	for note in NOTES:
		if result.stats.has(note):
			var stat = result.stats[note]
			card.add_child(_text("%s     %d / %d 首答正确" % [LABELS.get(note,note),stat.correct,stat.heard], 18))
	card.add_child(_text("错题重试不重复计数；跳过计为错误。\n未作答便结束的当前题不计入统计。", 14, MUTED))
	card.add_child(_button("再练一组  →", _start_session, true))
	card.add_child(_button("调整练习设置", _show_setup))
	content.add_child(_button("查看练习记录", _show_history, false, 50))
	_footer()

func _show_history():
	_base("history")
	content.add_child(_text("你的练习记录", 32))
	content.add_child(_text("仅保存在这部设备上，最多保留最近 100 次。", 16, MUTED))
	content.add_child(_button("返回练习", _show_setup, true, 52))
	if history.is_empty(): content.add_child(_text("还没有记录。开始第一组练习吧。", 18, MUTED))
	for entry in history:
		var card = _card(content)
		card.add_child(_text(str(entry.get("date", "")), 15, MUTED))
		var rate = roundi(float(entry.correct) / maxi(1,int(entry.attempts)) * 100)
		card.add_child(_text("%d%%    ·    %d / %d 首答正确" % [rate, entry.correct,entry.attempts], 22))
		card.add_child(_text("音名：" + " · ".join(entry.notes), 15, MUTED))
	_footer()

func _show_about():
	_base("about")
	content.add_child(_text("单音  1.0.0", 34))
	var card = _card(content)
	card.add_child(_text("为每天几分钟的单音练习而制作。", 20))
	card.add_child(_text("• 钢琴音色，36 个音符，C3–B5\n• 答案只需选音名，不要求识别八度\n• 完全离线，无账号、广告或联网权限\n• 设置和记录仅存于设备本地\n\n音频采样来源：TonedEar\nhttps://tonedear.com\n\n引擎：Godot Engine（MIT）\n字体：Noto Sans SC（SIL OFL 1.1）\n\n本版本供个人练习使用。", 17, MUTED))
	content.add_child(_button("返回练习", _show_setup, true))
	_footer()

func _save():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"settings":settings, "history":history}))

func _load_saved():
	if not FileAccess.file_exists(SAVE_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary: return
	var saved = parsed.get("settings", {})
	if saved is Dictionary:
		settings.preset = clampi(int(saved.get("preset",0)),0,4)
		settings.limit = clampi(int(saved.get("limit",0)),0,999)
		settings.octave = clampi(int(saved.get("octave",0)),0,3)
		settings.auto = bool(saved.get("auto",false))
		settings.volume = clampf(float(saved.get("volume",70)),0,100)
		var valid: Array = []
		for note in saved.get("notes", ["C","D","E"]):
			if note in NOTES and note not in valid: valid.append(note)
		settings.notes = valid if not valid.is_empty() else ["C","D","E"]
	var saved_history = parsed.get("history", [])
	if saved_history is Array:
		for entry in saved_history:
			if entry is Dictionary and entry.has_all(["date","attempts","correct","notes","stats"]): history.append(entry)
		history.resize(mini(history.size(),100))
