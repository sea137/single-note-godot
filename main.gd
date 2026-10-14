extends Control

const GREEN = Color("284e3e")
const MUTED = Color("778078")
const CREAM = Color("f5f4ed")
const LINE = Color("e0e5d9")
const NOTES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const LABELS = {"Db":"C♯ / D♭", "Eb":"D♯ / E♭", "Gb":"F♯ / G♭", "Ab":"G♯ / A♭", "Bb":"A♯ / B♭"}
const PRESETS = [["C","D","E"], ["C","D","E","F","G"], ["C","D","E","F","G","A","B"], NOTES]
const SAVE_PATH = "user://practice.json"
var save_path = SAVE_PATH
var settings = {"preset":0, "notes":["C","D","E"], "limit":0, "octave":0, "auto":false, "volume":70.0, "reference":1, "mode":0, "octave_challenge":false}
var learning = preload("res://learning_state.gd").new()
var reference_timer: Timer
var reference_keys: Array = []
var reference_buttons: Dictionary = {}
var reference_index = -1
var reference_active = false
var reference_marks_assisted = false
var reference_callback: Callable
var reference_label: Label
var reference_pause: Button
var sequence_override: Array = []
var octave_buttons: Array = []
var detail_label: Label
var reveal_button: Button
var contrast_button: Button
var challenge_box: VBoxContainer
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
	reference_timer = Timer.new()
	reference_timer.one_shot = true
	reference_timer.timeout.connect(_reference_step)
	add_child(reference_timer)
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
		if page in ["practice","reference"] and not session.is_empty():
			_end_session()
		elif page != "setup":
			_show_setup()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_stop_reference()
		if page == "reference" and is_instance_valid(reference_pause): reference_pause.text = "继续试听"
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
	_stop_reference()
	_stop_sound()
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
	preview.text = _selection_summary()
	preset.item_selected.connect(func(index):
		settings.preset = index
		custom.visible = index == 4
		settings.notes = custom_notes.duplicate() if index == 4 else PRESETS[index].duplicate()
		preview.text = _selection_summary()
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
	octave.item_selected.connect(func(_index): preview.text = _selection_summary())
	advanced.add_child(_text("参考试听", 17))
	var ref = OptionButton.new()
	for title in ["不试听，直接辨认", "每轮开始前试听（推荐）", "每道题前试听（辅助练习）"]: ref.add_item(title)
	ref.select(int(settings.get("reference",1)))
	ref.custom_minimum_size.y = 54
	ref.item_selected.connect(func(index): settings.reference = index; _save())
	advanced.add_child(ref)
	var challenge = CheckButton.new()
	challenge.text = "音区挑战：选音名后再选八度"
	challenge.button_pressed = settings.get("octave_challenge",false)
	challenge.custom_minimum_size.y = 54
	challenge.toggled.connect(func(value): settings.octave_challenge = value; _save())
	advanced.add_child(challenge)
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
	card.add_child(_text("默认先试听本组声音，再开始练习。", 13, MUTED, true))
	content.add_child(_button("试听本组声音  ♩", func(): _show_reference(_show_setup), false, 52))
	var daily = _card(content)
	daily.add_child(_text("每日记忆练习", 22))
	daily.add_child(_text("先做无参考检查，再复习当前音名范围的到期音。\n少量多次，建议每次先练 5–10 分钟。", 15, MUTED))
	daily.add_child(_button("无参考检查  ·  5 题", _start_session.bind(1), false, 54))
	daily.add_child(_button("今日待复习  ·  %d 个音" % _selected_due().size(), _start_session.bind(2), true, 54))
	daily.add_child(_button("查看音符记忆", _show_memory, false, 48))
	content.add_child(_button("练习记录  ·  " + str(history.size()) + " 次", _show_history, false, 48))
	content.add_child(_button("关于单音", _show_about, false, 44))
	_footer()

func _toggle_note(note: String):
	if note in custom_notes: custom_notes.erase(note)
	else: custom_notes.append(note)
	settings.notes = custom_notes.duplicate()
	preview_label.text = _selection_summary()
	_save()

func _start_session(mode_override: int = 0):
	if settings.notes.is_empty(): return
	_stop_reference()
	advance_timer.stop()
	var due = _selected_due()
	if mode_override == 2 and due.is_empty():
		_show_memory()
		return
	_save()
	session = {"notes":settings.notes.duplicate(), "limit":int(settings.limit), "auto":bool(settings.auto), "octaves":[3,4,5] if int(settings.octave) == 0 else [int(settings.octave)+2], "number":0, "attempts":0, "correct":0, "streak":0, "best_streak":0, "stats":{}, "note":"", "octave":4, "answered":false, "solved":false, "start_time":Time.get_unix_time_from_system()}
	session.merge({"mode":mode_override,"assisted":false,"round_reference":false,"name_solved":false,"wrong_choices":[],"review_queue":[],"due_queue":due,"exact_stats":{},"blind_attempts":0,"blind_correct":0,"guided_attempts":0,"guided_correct":0,"octave_attempts":0,"octave_correct":0,"responses":[],"replays":0,"response_started":0})
	if mode_override == 1: session.limit = 5
	if mode_override == 2: session.limit = due.size()
	if mode_override == 0 and int(settings.get("reference",1)) == 1:
		_show_reference(func(): _show_practice(true), [], true)
	else: _show_practice(true)

func _show_practice(begin: bool):
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
	detail_label = _text("", 19, GREEN, true)
	detail_label.visible = false
	content.add_child(detail_label)
	challenge_box = VBoxContainer.new()
	challenge_box.visible = false
	challenge_box.add_child(_text("这个音在哪个音区？", 18, GREEN, true))
	var octave_row = HBoxContainer.new()
	challenge_box.add_child(octave_row)
	octave_buttons.clear()
	for o in [3,4,5]:
		var b = _button(_octave_name(o), _answer_octave.bind(o), false, 56)
		octave_row.add_child(b)
		octave_buttons.append(b)
	content.add_child(challenge_box)
	var help_row = HBoxContainer.new()
	reveal_button = _button("查看答案", _reveal, false, 48)
	contrast_button = _button("对比错音", _contrast, false, 48)
	contrast_button.visible = false
	help_row.add_child(reveal_button)
	help_row.add_child(contrast_button)
	help_row.visible = session.mode != 1
	content.add_child(help_row)
	next_button = _button("", _next_question, true)
	content.add_child(next_button)
	_footer()
	if begin: _next_question()
	else: _refresh_question(); _play_note()

func _update_stats():
	var rate = "—" if int(session.attempts) == 0 else str(roundi(float(session.correct) / session.attempts * 100)) + "%"
	stats_label.text = "首答正确  %d     已作答  %d     正确率  %s" % [session.correct, session.attempts, rate]

func _next_question():
	advance_timer.stop()
	if session.is_empty() or page != "practice": return
	if session.note != "" and not session.answered: _record(false)
	if session.name_solved and not session.solved: session.octave_attempts += 1
	if int(session.limit) > 0 and int(session.number) >= int(session.limit):
		_end_session()
		return
	session.number += 1
	session.answered = false
	session.solved = false
	session.name_solved = false
	session.wrong_choices = []
	session.guess = ""
	session.assisted = bool(session.round_reference) or session.notes.size() < 2
	session.replays = -1
	var key = _choose_question()
	session.note = key.left(key.length()-1)
	session.octave = int(key.right(1))
	if session.mode == 0 and int(settings.get("reference",1)) == 2:
		_show_reference(func(): _show_practice(false), [], true)
		return
	_refresh_question()
	_play_note()

func _refresh_question():
	progress_label.text = "第 %d 题" % session.number + (" / %d" % session.limit if int(session.limit) > 0 else " · 自由练习")
	if session.mode == 1: progress_label.text += " · 无参考"
	elif session.mode == 2: progress_label.text += " · 到期复习"
	feedback.text = "听完后，选一个音名。"
	if session.notes.size() < 2: feedback.text = "只有一个音名：熟悉声音，不用于判断记忆掌握。"
	feedback.add_theme_color_override("font_color", MUTED)
	next_button.text = "跳过，下一题  →"
	detail_label.visible = false
	challenge_box.visible = false
	reveal_button.disabled = false
	contrast_button.visible = not session.wrong_choices.is_empty()
	for note in choices:
		var button = choices[note]
		button.disabled = session.solved or session.name_solved or note in session.wrong_choices
		button.add_theme_stylebox_override("normal", _style(Color("fffef9"), LINE))
		button.add_theme_stylebox_override("disabled", _style(Color("fffef9"), LINE))
		button.add_theme_color_override("font_disabled_color", GREEN)
	_update_stats()
	session.response_started = Time.get_ticks_msec()
	if session.solved:
		if session.mode != 1: _show_answer_detail()
		feedback.text = "已记录，结束后查看结果。" if session.mode == 1 else "再听一遍，然后继续练习。"
		_ready_next()
	elif session.name_solved:
		challenge_box.visible = true
		feedback.text = "音名正确，再判断它的音区。"

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
	var key = str(session.note) + str(session.octave)
	var guess = str(session.get("guess",""))
	var assisted = bool(session.assisted)
	var bucket = "guided" if assisted else "blind"
	session[bucket + "_attempts"] += 1
	if correct: session[bucket + "_correct"] += 1
	if not session.exact_stats.has(key): session.exact_stats[key] = {"heard":0,"correct":0}
	session.exact_stats[key].heard += 1
	if correct: session.exact_stats[key].correct += 1
	session.responses.append({"key":key,"guess":guess,"correct":correct,"assisted":assisted,"seconds":maxf(0.0,(Time.get_ticks_msec()-int(session.response_started))/1000.0),"replays":session.replays})
	learning.record(key,correct,assisted,guess,int(Time.get_unix_time_from_system()))
	if not correct and session.mode != 1:
		var already_queued = false
		for review in session.review_queue:
			if review.key == key: already_queued = true
		if not already_queued: session.review_queue.append({"key":key,"after":int(session.number)+4})
	_save()
	_update_stats()

func _answer(note: String):
	if page != "practice" or session.solved or session.name_solved: return
	session.guess = note
	var correct = note == session.note
	if not session.answered: _record(correct)
	if session.mode == 1:
		session.solved = true
		for b in choices.values(): b.disabled = true
		feedback.text = "已记录，结束后统一查看结果。"
		_ready_next()
		return
	var button = choices[note]
	if not correct:
		button.disabled = true
		session.wrong_choices.append(note)
		contrast_button.visible = true
		button.add_theme_stylebox_override("disabled", _style(Color("fae8df"), Color("d7a993")))
		button.add_theme_color_override("font_disabled_color", Color("a35439"))
		feedback.text = "还差一点，再听一次试试。"
		feedback.add_theme_color_override("font_color", Color("a35439"))
		return
	session.name_solved = true
	session.solved = true
	for b in choices.values(): b.disabled = true
	button.add_theme_stylebox_override("disabled", _style(Color("dcebcf"), Color("90ad7c")))
	feedback.text = "答对了，是 " + str(LABELS.get(note, note)) + "！"
	feedback.add_theme_color_override("font_color", Color("477134"))
	if settings.get("octave_challenge",false):
		session.solved = false
		challenge_box.visible = true
		for b in octave_buttons: b.disabled = false
		feedback.text = "音名正确，再判断它的音区。"
		next_button.text = "跳过音区，下一题  →"
		return
	_show_answer_detail()
	_ready_next()

func _ready_next():
	next_button.text = "查看练习结果  →" if int(session.limit) > 0 and session.number >= session.limit else "下一题  →"
	if session.auto: advance_timer.start(1.1)

func _play_note():
	if session.is_empty() or page != "practice": return
	session.replays += 1
	_stop_sound()
	var key = str(session.note) + str(session.octave)
	_play_key(key)

func _play_key(key: String):
	_stop_sound()
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
	_stop_reference()
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
	for bucket in ["blind","guided"]:
		var total = int(result.get(bucket+"_attempts",0))
		if total > 0: card.add_child(_text(("未用试听" if bucket == "blind" else "辅助练习") + "：%d / %d 首答正确" % [int(result.get(bucket+"_correct",0)),total],16,MUTED,true))
	if int(result.get("octave_attempts",0)) > 0: card.add_child(_text("音区判断：%d / %d 正确" % [result.octave_correct,result.octave_attempts],16,MUTED,true))
	for note in NOTES:
		if result.stats.has(note):
			var stat = result.stats[note]
			card.add_child(_text("%s     %d / %d 首答正确" % [LABELS.get(note,note),stat.correct,stat.heard], 18))
	for key in result.get("exact_stats",{}):
		var stat = result.exact_stats[key]
		card.add_child(_text(_key_label(key) + "：%d / %d 首答正确" % [stat.correct,stat.heard],15,MUTED))
	if result.get("mode",0) == 1:
		for response in result.get("responses",[]):
			card.add_child(_text(_key_label(response.key) + " · 你的答案 " + (str(response.guess) if response.guess != "" else "跳过"),15,MUTED))
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
	content.add_child(_text("单音  1.1.0", 34))
	var card = _card(content)
	card.add_child(_text("为每天几分钟的单音练习而制作。", 20))
	card.add_child(_text("新增：顺序试听、音区标签、错音对比、\n无参考检查、音区挑战和到期复习。\n复习间隔是可调整的初始规则，不是统一的记忆曲线。",16,MUTED))
	card.add_child(_text("• 钢琴音色，36 个音符，C3–B5\n• 答案只需选音名，不要求识别八度\n• 完全离线，无账号、广告或联网权限\n• 设置和记录仅存于设备本地\n\n音频采样来源：TonedEar\nhttps://tonedear.com\n\n引擎：Godot Engine（MIT）\n字体：Noto Sans SC（SIL OFL 1.1）\n\n本版本供个人练习使用。", 17, MUTED))
	content.add_child(_button("返回练习", _show_setup, true))
	_footer()

func _save():
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify({"schema":2,"settings":settings,"history":history,"learning":learning.items}))
	file.flush()
	file.close()
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path + ".bak"): DirAccess.remove_absolute(save_path + ".bak")
		if DirAccess.rename_absolute(save_path,save_path + ".bak") != OK: return
	DirAccess.rename_absolute(save_path + ".tmp",save_path)

func _load_saved():
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	if not parsed is Dictionary and FileAccess.file_exists(save_path + ".bak"): parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
	if not parsed is Dictionary: return
	var saved = parsed.get("settings", {})
	if saved is Dictionary:
		settings.preset = clampi(int(saved.get("preset",0)),0,4)
		settings.limit = clampi(int(saved.get("limit",0)),0,999)
		settings.octave = clampi(int(saved.get("octave",0)),0,3)
		settings.auto = bool(saved.get("auto",false))
		settings.volume = clampf(float(saved.get("volume",70)),0,100)
		settings.reference = clampi(int(saved.get("reference",1)),0,2)
		settings.octave_challenge = bool(saved.get("octave_challenge",false))
		var valid: Array = []
		for note in saved.get("notes", ["C","D","E"]):
			if note in NOTES and note not in valid: valid.append(note)
		settings.notes = valid if not valid.is_empty() else ["C","D","E"]
	var saved_history = parsed.get("history", [])
	if saved_history is Array:
		for entry in saved_history:
			if entry is Dictionary and entry.has_all(["date","attempts","correct","notes","stats"]): history.append(entry)
		history.resize(mini(history.size(),100))
	learning.import_items(parsed.get("learning",{}))

func _octave_name(o: int) -> String:
	return {3:"低音区",4:"中音区",5:"高音区"}.get(o,"")

func _key_label(key: String) -> String:
	return key + " · " + _octave_name(int(key.right(1)))

func _selected_keys() -> Array:
	var keys: Array = []
	var octaves = [3,4,5] if int(settings.octave) == 0 else [int(settings.octave)+2]
	for o in octaves:
		for note in NOTES:
			if note in settings.notes: keys.append(note + str(o))
	return keys

func _selection_summary() -> String:
	return "%d 个音名 × %d 个八度 = %d 个声音\n" % [settings.notes.size(),3 if int(settings.octave) == 0 else 1,_selected_keys().size()] + "  ·  ".join(settings.notes)

func _selected_due() -> Array:
	var selected = _selected_keys()
	return learning.due_keys(int(Time.get_unix_time_from_system())).filter(func(key): return key in selected)

func _choose_question() -> String:
	if session.mode == 2 and not session.due_queue.is_empty(): return session.due_queue.pop_front()
	if session.mode != 1 and int(session.number) % 3 == 0:
		for i in session.review_queue.size():
			if int(session.review_queue[i].after) <= int(session.number):
				var key = str(session.review_queue[i].key)
				session.review_queue.remove_at(i)
				return key
	return str(session.notes[rng.randi_range(0,session.notes.size()-1)]) + str(session.octaves[rng.randi_range(0,session.octaves.size()-1)])

func _answer_octave(o: int):
	if session.is_empty() or not session.name_solved or session.solved: return
	session.octave_attempts += 1
	if o == int(session.octave): session.octave_correct += 1
	session.solved = true
	for b in octave_buttons: b.disabled = true
	feedback.text = "音区也正确！" if o == int(session.octave) else "音名认对了，音区再巩固一下。"
	_show_answer_detail()
	_ready_next()

func _show_answer_detail():
	detail_label.visible = true
	detail_label.text = _key_label(str(session.note)+str(session.octave))
	reveal_button.disabled = true

func _reveal():
	if session.is_empty() or session.mode == 1: return
	advance_timer.stop()
	if not session.answered:
		session.guess = ""
		_record(false)
	session.assisted = true
	session.solved = true
	for b in choices.values(): b.disabled = true
	for b in octave_buttons: b.disabled = true
	feedback.text = "先记住它，稍后再尝试。"
	_show_answer_detail()
	_ready_next()

func _contrast():
	if session.is_empty() or session.mode == 1 or session.wrong_choices.is_empty(): return
	advance_timer.stop()
	var target = str(session.note)+str(session.octave)
	var wrong = str(session.wrong_choices.back())+str(session.octave)
	_show_reference(func(): _show_practice(false), [wrong,target], true, "对比这两个音")

func _show_reference(on_done: Callable, keys: Array = [], mark_assisted: bool = false, title: String = "熟悉本组声音"):
	_base("reference")
	reference_keys = _selected_keys() if keys.is_empty() else keys.duplicate()
	reference_index = -1
	reference_callback = on_done
	reference_marks_assisted = mark_assisted
	reference_buttons.clear()
	content.add_child(_text(title,32))
	content.add_child(_text("按低到高播放，留意同一个音名在不同八度的声音。",16,MUTED))
	reference_label = _text("",28,GREEN,true)
	content.add_child(reference_label)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	content.add_child(grid)
	for key in reference_keys:
		var button = _button(key + "\n" + _octave_name(int(key.right(1))), _reference_single.bind(key), false, 64)
		button.add_theme_font_size_override("font_size",16)
		grid.add_child(button)
		reference_buttons[key] = button
	reference_pause = _button("暂停试听",_toggle_reference,true,54)
	content.add_child(reference_pause)
	content.add_child(_button("重新按顺序试听",_restart_reference,false,50))
	content.add_child(_button("继续练习  →" if not session.is_empty() else "返回设置",_finish_reference,false,54))
	_footer()
	_restart_reference()

func _mark_reference():
	if reference_marks_assisted and not session.is_empty():
		session.assisted = true
		if int(settings.get("reference",1)) == 1 and session.number == 0: session.round_reference = true

func _reference_single(key: String):
	_stop_reference()
	reference_index = reference_keys.find(key)
	_mark_reference()
	_reference_highlight(key)
	_play_key(key)
	reference_pause.text = "继续顺序试听"

func _reference_highlight(key: String):
	reference_label.text = _key_label(key)
	for k in reference_buttons:
		reference_buttons[k].add_theme_stylebox_override("normal",_style(Color("dcebcf") if k == key else Color("fffef9"),LINE))

func _reference_step():
	if page != "reference" or not reference_active: return
	reference_index += 1
	if reference_index >= reference_keys.size():
		reference_active = false
		reference_label.text = "本组试听完成"
		reference_pause.text = "再听一遍"
		return
	_mark_reference()
	var key = reference_keys[reference_index]
	_reference_highlight(key)
	_play_key(key)
	reference_timer.start(2.0)

func _restart_reference():
	_stop_reference()
	reference_index = -1
	reference_active = true
	reference_pause.text = "暂停试听"
	_reference_step()

func _toggle_reference():
	if reference_active:
		_stop_reference()
		_stop_sound()
		reference_pause.text = "继续试听"
	else:
		if reference_index >= reference_keys.size(): reference_index = -1
		reference_active = true
		reference_pause.text = "暂停试听"
		_reference_step()

func _stop_reference():
	reference_active = false
	if reference_timer: reference_timer.stop()

func _finish_reference():
	_stop_reference()
	_stop_sound()
	if reference_callback.is_valid(): reference_callback.call()

func _show_memory():
	_base("memory")
	content.add_child(_text("音符记忆",32))
	content.add_child(_text("当前范围待复习：%d 个音\n辅助答对不会按长期掌握来延长间隔。" % _selected_due().size(),16,MUTED))
	content.add_child(_button("返回练习",_show_setup,true,52))
	var now = int(Time.get_unix_time_from_system())
	for key in _selected_keys():
		var card = _card(content)
		card.add_child(_text(_key_label(key),21))
		if not learning.items.has(key):
			card.add_child(_text("尚未练习",15,MUTED))
			continue
		var item = learning.items[key]
		var remaining = maxi(0,int(item.get("due_at",0))-now)
		var due_text = "现在可复习" if remaining == 0 else ("约 %d 分钟后复习" % ceili(remaining/60.0) if remaining < 86400 else "约 %d 天后复习" % ceili(remaining/86400.0))
		card.add_child(_text(due_text,16,MUTED))
		card.add_child(_text("未用试听：%d / %d 首答正确" % [item.get("blind_correct",0),item.get("blind_attempts",0)],15,MUTED))
		var confusions = item.get("confusions",{})
		for guess in confusions: card.add_child(_text("曾误选 %s：%d 次" % [guess,confusions[guess]],14,MUTED))
	content.add_child(_text("初始间隔：答错 10 分钟；辅助答对约 1 小时；\n到期独立答对逐步间隔 1、3、7、14、30 天。\n提前重复答对不提升记忆阶段。",14,MUTED))
	_footer()
