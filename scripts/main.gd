extends Node2D
const Catalog = preload("res://scripts/content_catalog.gd")
const Story = preload("res://scripts/story.gd")
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Music = preload("res://scripts/music.gd")
const Progress = preload("res://scripts/progress.gd")
var progress = Progress.new()
var world: Node2D
var camera: Camera2D
var light_counter: Label
var story: Node2D
var action_button: Button
var letter_slots: Array[Label] = []
var panel_open := false
var lesson_context := "bridge"
var voice: AudioStreamPlayer
var boss_announced := false
var bonus_read := false
var tutorial_played := false
var ui_time := 0.0
var celebration: Control
var focused := true
var saved_player_active := false
var player: CharacterBody2D
var gate: StaticBody2D
var ui: Control
var panel: Panel
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var audio: AudioStreamPlayer
var route_gates: Array[StaticBody2D] = []
var met_cards: Dictionary = {}
var active_card: Dictionary
var content: Dictionary
var opened := false
var finished := false
var lesson_seen := false
var left_down := false
var right_down := false
var letter_m: Label
var letter_a: Label
var blend: Tween
var status: Label
var route_marks: Array[Label] = []
var sorting_feedback: Label
var sorted_stations: Dictionary = {}
var sorting_active := false

func _ready() -> void:
	progress.load_progress()
	music = Music.new()
	music.enabled = progress.data.get("music_enabled", true)
	add_child(music)
	content = Catalog.read("res://content/level_01.json")
	if content.is_empty():
		get_tree().quit(1)
		return
	active_card = content.cards["МА"]
	RenderingServer.set_default_clear_color(Color("172336"))
	world = World.new()
	add_child(world)
	floor_body(Vector2(2304, 535), Vector2(4608, 70))
	floor_body(Vector2(690, 475), Vector2(140, 50))
	gate = floor_body(Vector2(1527, 397), Vector2(28, 206))
	player = Player.new()
	player.position = Vector2(110, 500)
	add_child(player)
	for point in content.checkpoints:
		route_gates.append(floor_body(Vector2(point.x+77,397),Vector2(28,206)))
	world.checkpoints = content.checkpoints
	world.hero = player
	story = Story.new()
	story.checkpoints = content.checkpoints
	story.hero = player
	story.glyphs = content.letters
	story.syllable = content.syllable
	add_child(story)
	player.active = false
	story.changed.connect(update_story)
	story.fragment_found.connect(found_fragment)
	story.route_fragment_found.connect(func(glyph):
		letter_slots[1].text = glyph
		show_cheer("Нашли %s! Соединим её с М." % glyph)
		effects.stream = load("res://assets/audio/light.wav")
		effects.play()
	)
	camera = Camera2D.new()
	camera.position = Vector2(576, 324)
	add_child(camera)
	audio = AudioStreamPlayer.new()
	audio.stream = load(content.audio)
	add_child(audio)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	voice.finished.connect(func(): music.set_quiet(panel_open))
	effects = AudioStreamPlayer.new()
	effects.volume_db = -15
	add_child(effects)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	ui_backdrop(Rect2(18, 16, 720, 89))
	ui_backdrop(Rect2(0, 543, 1152, 105))
	text_at("PIXWAVE   /   Потерянное письмо", Vector2(38, 24), 27)
	text_at("СЛОГИ",Vector2(760,16),14)
	light_counter = text_at("0 / 3", Vector2(760, 38), 26)
	status = text_at("Ой! Кляксы порвали письмо. Поможем почтальону!", Vector2(38, 66), 22)
	for i in range(2):
		ui_backdrop(Rect2(310+i*78,555,65,78))
		letter_slots.append(text_at("?",Vector2(328+i*78,566),38))
	action_button = button("Начать приключение  [E]",Vector2(490,555),Vector2(360,78),interact)
	ui_backdrop(Rect2(242,106,730,30))
	for i in range(6):
		var mark = text_at(["Мост", "Маяк", "Почта", "Фонари", "Посылка", "Хранитель"][i],Vector2(260+i*118,108),16)
		route_marks.append(mark)
	narrate("intro")
	story.intro_duration = voice.stream.get_length()+0.3
	button("?",Vector2(864,22),Vector2(48,54),repeat_hint)
	button("Для взрослых", Vector2(925, 22), Vector2(200, 54), show_parent_gate)
	var left = button("◀", Vector2(30, 555), Vector2(110, 78), func(): pass)
	left.button_down.connect(func(): left_down = true)
	left.button_up.connect(func(): left_down = false)
	var right = button("▶", Vector2(155, 555), Vector2(110, 78), func(): pass)
	right.button_down.connect(func(): right_down = true)
	right.button_up.connect(func(): right_down = false)
	button("Прыжок", Vector2(912, 555), Vector2(210, 78), func(): player.jump_requested = true)

func floor_body(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _process(_delta: float) -> void:
	if not focused:
		return
	light_counter.text = "%s / 3" % met_cards.size()
	var route_step = 0 if not opened else mini(5,story.route_index+1)
	for i in range(route_marks.size()):
		route_marks[i].modulate = Color("ffe3a2") if i<=route_step else Color("8293a9")
		route_marks[i].text = ("✓ " if i<route_step or finished else "● " if i==route_step else "· ") + ["Мост", "Маяк", "Почта", "Фонари", "Посылка", "Хранитель"][i]
	ui_time += _delta
	player.axis = float(right_down) - float(left_down)
	camera.position.x = lerpf(camera.position.x,clampf(player.position.x+250,576,4032),1.0-exp(-_delta*7.0))
	if story.stage == "collect":
		world.guide_target = 430 if not story.letters[0] else 980
		action_button.text = "✦  Свет  [E]"
	elif story.stage == "bridge":
		world.guide_target = 1410
		action_button.text = "Сложить письмо  [E]" if absf(player.position.x-1410)<140 else ("← К мостику" if player.position.x>1410 else "К мостику →")
	elif story.stage=="route":
		var point = content.checkpoints[story.route_index]
		var need_glyph = point.glyph!="" and not story.route_glyph
		world.guide_target = point.blob_x if need_glyph else point.x
		action_button.text = "✦  Свет  [E]" if need_glyph else "Прочитать письмо  [E]"
	elif story.stage == "guardian":
		world.guide_target = 4100
		action_button.text = "✦  Свет  [E]" if story.boss_cooldown<=0 else "✦  Огонёк зажигается…"
		if player.position.x>3900 and not boss_announced:
			boss_announced = true
			status.text = "Хранитель держит печать. Зажги два огонька!"
			narrate("boss")
	elif story.stage == "boss_read":
		world.guide_target = 4070
		action_button.text = "Прочитать обрывок  [E]"
	elif story.stage == "delivered":
		action_button.text = "Письмо восстановлено!"
	var ready_near = (story.stage=="route" and absf(player.position.x-world.guide_target)<145) or (story.stage=="collect" and player.position.distance_to(Vector2(world.guide_target,500))<145) or (story.stage=="bridge" and absf(player.position.x-1410)<140) or (story.stage in ["guardian","boss_read"] and absf(player.position.x-story.boss_pos.x)<265)
	action_button.modulate = Color(1.0,1.0,1.0).lerp(Color("ffe0a1"),(0.25+sin(ui_time*3)*0.15) if ready_near and not panel_open else 0.0)
	story.action_ready = ready_near and not panel_open

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		interact()

func narrate(name: String) -> void:
	voice.stream = load("res://assets/audio/%s.wav" % name)
	music.set_quiet(true)
	voice.play()

func found_fragment(index: int) -> void:
	letter_slots[index].text = content.letters[index]
	effects.stream = load("res://assets/audio/light.wav")
	effects.play()
	fly_fragment(index)
	show_cheer("Обрывок %s спасён!" % content.letters[index])
	status.text = "Есть первый обрывок! Найди второй." if not (story.letters[0] and story.letters[1]) else "М и А найдены. Починим мостик у письма!"

func repeat_hint() -> void:
	if panel_open or finished:
		return
	var hints = {"intro":"intro","collect":"tutorial","bridge":"bridge","guardian":"boss","boss_read":"final"}
	if story.stage=="route":
		narrate("route")
	elif hints.has(story.stage):
		narrate(hints[story.stage])

func show_cheer(message: String) -> void:
	if is_instance_valid(celebration):
		celebration.queue_free()
	celebration = Panel.new()
	celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration.position = Vector2(245,145)
	celebration.size = Vector2(662,55)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("20384a")
	style.border_color = Color("f1c485")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	celebration.add_theme_stylebox_override("panel",style)
	ui.add_child(celebration)
	var label = text_at(message,Vector2(0,9),27,celebration)
	label.size.x = 662
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celebration.modulate.a = 0
	var tween = celebration.create_tween()
	tween.tween_property(celebration,"modulate:a",1.0,0.18)
	tween.tween_interval(1.3)
	tween.tween_property(celebration,"modulate:a",0.0,0.35)
	tween.tween_callback(celebration.queue_free)

func fly_fragment(index: int) -> void:
	var card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = story.blob_positions[index]-camera.position+Vector2(576-24,324-125)
	card.size = Vector2(48,55)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("ffe5b1")
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel",style)
	ui.add_child(card)
	var label = text_at(content.letters[index],Vector2(9,2),36,card)
	label.add_theme_color_override("font_color",Color("244358"))
	var tween = card.create_tween()
	tween.tween_property(card,"position",Vector2(319+index*78,566),0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card,"modulate:a",0.0,0.18)
	tween.tween_callback(card.queue_free)

func update_story() -> void:
	if story.stage == "collect":
		status.text = "Подойди к кляксе. Прыгни или нажми «Свет»." if not tutorial_played else "Один обрывок у нас. Ищи второй!"
		if not tutorial_played:
			tutorial_played = true
			narrate("tutorial")
	elif story.stage == "bridge":
		status.text = "Оба обрывка у нас! Подойди к механизму мостика →"
		narrate("bridge")
	elif story.stage=="route":
		var point = content.checkpoints[story.route_index]
		status.text = "Найди обрывок %s у кляксы →" % point.glyph if point.glyph!="" and not story.route_glyph else point.title
		if point.glyph!="" and not story.route_glyph:
			letter_slots[1].text = "?"
		narrate("route")
	elif story.stage == "guardian":
		status.text = "Ещё один огонёк — и обрывок свободен!" if story.boss_hits>0 else "Посылки доставлены! Впереди хранитель писем →"
		if story.boss_hits>0:
			effects.stream = load("res://assets/audio/light.wav")
			effects.play()
	elif story.stage == "boss_read":
		show_cheer("Все обрывки у нас!")
		status.text = "Последний обрывок свободен. Подойди и прочитай его."
		narrate("final")
	elif story.stage == "delivered":
		status.text = "Письмо спасено! Почтальон благодарит тебя."

func interact() -> void:
	if panel_open or finished:
		return
	if story.stage == "intro":
		story.start_adventure()
	elif story.stage == "collect":
		story.pulse()
	elif story.stage == "bridge":
		if absf(player.position.x-1410)<140:
			show_lesson("bridge")
		else:
			status.text = "Обрывки готовы. Почтальон ждёт у мостика →"
	elif story.stage=="route":
		var point = content.checkpoints[story.route_index]
		if point.glyph!="" and not story.route_glyph:
			story.pulse()
		elif absf(player.position.x-point.x)<145:
			if point.has("choices") and not sorted_stations.has(story.route_index):
				show_sorting()
			else:
				show_lesson("route")
		else:
			status.text = "Подойди к почтовому механизму рядом с запиской."
	elif story.stage == "guardian":
		story.pulse()
	elif story.stage == "boss_read":
		if absf(player.position.x-story.boss_pos.x)<270:
			show_lesson("boss")
		else:
			status.text = "Подойди к хранителю, чтобы взять обрывок →"

func ui_backdrop(rect: Rect2) -> void:
	var backdrop = Panel.new()
	backdrop.position = rect.position
	backdrop.size = rect.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.13, 0.88)
	style.set_corner_radius_all(14)
	backdrop.add_theme_stylebox_override("panel", style)
	ui.add_child(backdrop)

func text_at(value: String, pos: Vector2, font_size: int, parent: Node = null) -> Label:
	var label = Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ffe8be"))
	(parent if parent != null else ui).add_child(label)
	return label

func button(value: String, pos: Vector2, size: Vector2, callback: Callable, parent: Node = null) -> Button:
	var b = Button.new()
	b.text = value
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("253b51") if state == "normal" else Color("486079")
		style.border_color = Color("c39560")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color("ffeac6"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.pressed.connect(callback)
	(parent if parent != null else ui).add_child(b)
	return b

func new_panel() -> void:
	status.visible = true
	for slot in letter_slots:
		slot.visible = true
	sorting_active = false
	panel_open = true
	story.paused = true
	world.frozen = true
	action_button.disabled = true
	voice.stop()
	music.set_quiet(true)
	if is_instance_valid(panel):
		panel.queue_free()
	if blend != null:
		blend.kill()
	audio.stop()
	player.active = false
	left_down = false
	right_down = false
	panel = Panel.new()
	panel.position = Vector2(140, 104)
	panel.size = Vector2(872, 430)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("132338")
	style.border_color = Color("c99862")
	style.set_border_width_all(3)
	style.shadow_color = Color(0,0,0,0.5)
	style.shadow_size = 18
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)

func close_panel() -> void:
	status.visible = true
	for slot in letter_slots:
		slot.visible = true
	voice.stop()
	sorting_active = false
	panel_open = false
	story.paused = false
	world.frozen = false
	action_button.disabled = false
	music.set_quiet(false)
	if blend != null:
		blend.kill()
	audio.stop()
	panel.queue_free()
	player.active = not finished and story.stage != "intro"

func show_lesson(context: String = "bridge") -> void:
	lesson_context = context
	var card_id = "МА"
	if context=="route":
		card_id = content.checkpoints[story.route_index].card
	elif context=="boss":
		card_id = content.review[story.review_index]
	active_card = content.cards[card_id]
	lesson_seen = true
	new_panel()
	var title = "Из найденных обрывков откроем мостик"
	if context == "boss":
		title = "Хранитель: письмо %s из %s" % [story.review_index+1,content.review.size()]
	elif context=="route":
		title = content.checkpoints[story.route_index].title
	elif context == "bonus":
		title = "Бонус: из двух слогов получится слово"
	text_at(title, Vector2(30, 20), 29, panel)
	var paper = Panel.new()
	paper.position = Vector2(210,80)
	paper.size = Vector2(450,145)
	var paper_style = StyleBoxFlat.new()
	paper_style.bg_color = Color("ffe6b4")
	paper_style.border_color = Color("bf996a")
	paper_style.set_border_width_all(3)
	paper_style.set_corner_radius_all(5)
	paper.add_theme_stylebox_override("panel",paper_style)
	panel.add_child(paper)
	letter_m = text_at(content.bonus.chunks[0] if context == "bonus" else active_card.letters[0], Vector2(265, 85), 100, panel)
	letter_a = text_at(content.bonus.chunks[1] if context == "bonus" else active_card.letters[1], Vector2(505, 85), 100, panel)
	letter_m.add_theme_color_override("font_color", Color("244358"))
	letter_a.add_theme_color_override("font_color", Color("80502c"))
	text_at("Можно слушать, пробовать и возвращаться без спешки.", Vector2(30, 225), 24, panel)
	button("Слушать и соединять", Vector2(30, 285), Vector2(360, 65), play_blend, panel)
	button("Взрослый: проверить", Vector2(420, 285), Vector2(420, 65), confirm_answer, panel)
	button("Завершить" if context=="bonus" else "Вернуться к приключению", Vector2(30, 360), Vector2(420, 55), func():
		if context=="bonus":
			finish()
		else:
			close_panel()
	, panel)
	if context == "bridge" or (context=="route" and content.checkpoints[story.route_index].guided):
		play_blend()
	else:
		letter_m.position.x = 250 if context=="bonus" else 340
		letter_a.position.x = 430 if context=="bonus" else 440

func play_blend() -> void:
	if blend != null:
		blend.kill()
	letter_m.position.x = 265
	letter_a.position.x = 505
	blend = create_tween().set_parallel(true)
	blend.tween_property(letter_m, "position:x", 250.0 if lesson_context=="bonus" else 340.0, 1.6)
	blend.tween_property(letter_a, "position:x", 430.0 if lesson_context=="bonus" else 440.0, 1.6)
	audio.stream = load(content.bonus.audio if lesson_context=="bonus" else active_card.audio)
	blend.finished.connect(audio.play)

func confirm_answer() -> void:
	new_panel()
	text_at("Для сопровождающего взрослого", Vector2(35, 30), 30, panel)
	var expected = content.bonus.word if lesson_context=="bonus" else active_card.syllable
	text_at("Ребёнок попробовал прочитать «%s»?\nУчитывайте понимание, а не чёткость произношения.\nМожно помочь; самостоятельность проверим вне игры." % expected, Vector2(35, 100), 24, panel)
	button("Подтверждаю — продолжить", Vector2(35, 255), Vector2(790, 65), accept_reading, panel)
	button("Ещё вместе послушать", Vector2(35, 340), Vector2(790, 60), func():
		progress.data.practice_requests += 1
		progress.save()
		show_lesson(lesson_context)
		if lesson_context!="bridge":
			play_blend()
	, panel)

func accept_reading() -> void:
	progress.data.confirmations += 1
	if lesson_context!="bonus":
		met_cards[active_card.id] = true
		var history = progress.data.get("card_activity",{})
		var entry = history.get(active_card.id,{"guided_confirmations":0,"practice_confirmations":0})
		var guided = lesson_context=="bridge" or (lesson_context=="route" and content.checkpoints[story.route_index].guided)
		var key = "guided_confirmations" if guided else "practice_confirmations"
		entry[key] += 1
		history[active_card.id] = entry
		progress.data["card_activity"] = history
		progress.save()
	close_panel()
	if lesson_context == "bridge":
		opened = true
		world.lit = true
		world.burst_age = 0.0
		gate.get_node("CollisionShape2D").set_deferred("disabled", true)
		story.open_bridge()
		show_cheer("МА открыло путь. Получилось!")
		effects.stream = load("res://assets/audio/gate.wav")
		effects.play()
	elif lesson_context=="route":
		route_gates[story.route_index].get_node("CollisionShape2D").set_deferred("disabled",true)
		world.completed_stations = story.route_index+1
		show_cheer(content.checkpoints[story.route_index].reward)
		world.celebrate_station(story.route_index)
		story.advance_route()
		effects.stream = load("res://assets/audio/gate.wav")
		effects.play()
	elif lesson_context == "boss":
		story.review_index += 1
		if story.review_index<content.review.size():
			story.syllable = content.review[story.review_index]
			status.text = "Осталось письмо %s из %s. Подойди и прочитай." % [story.review_index+1,content.review.size()]
			show_cheer("%s — письмо прочитано!" % active_card.syllable)
			return
		story.deliver()
		effects.stream = load("res://assets/audio/gate.wav")
		effects.play()
		show_cheer("Спасибо! Письмо снова целое.")
		finished = true
		player.active = false
		player.victory = true
		get_tree().create_timer(1.5).timeout.connect(finish)
	else:
		bonus_read = true
		progress.data["bonus_mama_with_adult"] = true
		progress.save()
		finish()

func finish() -> void:
	finished = true
	progress.data.completed = true
	progress.data["chapter_mamomu_completed"] = true
	progress.data.stars = 1
	var saved = progress.save()
	new_panel()
	text_at("♡  Письмо для мамы!" if bonus_read else "★  Письмо восстановлено!", Vector2(100, 35), 42, panel)
	text_at("Ты соединил МА + МА.\nПисьмо для мамы отправлено!" if bonus_read else "Ты познакомился с МА, МО и МУ.\nПочтальон снова может доставлять письма!", Vector2(95, 125), 28, panel)
	if bonus_read:
		text_at("МАМА",Vector2(330,200),45,panel)
	if not saved:
		text_at("Не удалось сохранить прогресс на устройстве.", Vector2(40, 225), 23, panel)
	button("Ещё одно слово: МАМА", Vector2(95, 270), Vector2(680, 60), func(): show_lesson("bonus"), panel)
	button("Пройти ещё раз", Vector2(95, 350), Vector2(680, 55), func(): get_tree().reload_current_scene(), panel)

func show_parent_gate() -> void:
	new_panel()
	text_at("Для взрослых: сколько будет 8 + 5?", Vector2(45, 45), 30, panel)
	var answer = LineEdit.new()
	answer.position = Vector2(45, 130)
	answer.size = Vector2(300, 65)
	answer.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	answer.add_theme_font_size_override("font_size", 30)
	panel.add_child(answer)
	button("Открыть", Vector2(390, 130), Vector2(400, 65), func():
		if answer.text.strip_edges() == "13":
			show_parent()
		else:
			answer.clear()
	, panel)
	button("Назад", Vector2(45, 300), Vector2(300, 65), close_panel, panel)

func show_parent() -> void:
	new_panel()
	text_at("Письма: МА, МО, МУ", Vector2(35, 25), 32, panel)
	var summary = "Три слога пройдены: %s  ·  Звёзды: %s / 1\nПросьбы повторить вместе: %s\nПодтверждений взрослым: %s\nЭто наблюдения, а не оценка навыка чтения." % ["да" if progress.data.get("chapter_mamomu_completed",false) else "пока нет", int(progress.data.stars), int(progress.data.practice_requests), int(progress.data.confirmations)]
	text_at(summary, Vector2(35, 78), 23, panel)
	var counts: Array[String] = []
	for id in content.review:
		var entry = progress.data.get("card_activity",{}).get(id,{})
		counts.append("%s: %s / %s" % [id,entry.get("guided_confirmations",0),entry.get("practice_confirmations",0)])
	text_at("С образцом / практика:  " + "   ·   ".join(counts),Vector2(35,207),21,panel)
	text_at("Громкость", Vector2(35, 250), 25, panel)
	var volume = HSlider.new()
	volume.position = Vector2(250, 260)
	volume.size = Vector2(540, 40)
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	volume.value_changed.connect(func(value): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001))))
	panel.add_child(volume)
	var music_toggle = button("Фоновая музыка", Vector2(35, 305), Vector2(790, 45), func(): pass, panel)
	music_toggle.toggle_mode = true
	music_toggle.set_pressed_no_signal(music.enabled)
	music_toggle.toggled.connect(func(value):
		music.set_enabled(value)
		progress.data["music_enabled"] = value
		progress.save()
	)
	button("Вернуться", Vector2(35, 365), Vector2(790, 50), close_panel, panel)

func _notification(what: int) -> void:
	if not is_instance_valid(story) or not is_instance_valid(voice):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and focused:
		left_down = false
		right_down = false
		saved_player_active = player.active
		focused = false
		story.paused = true
		world.frozen = true
		player.active = false
		voice.stream_paused = true
		audio.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not focused:
		focused = true
		story.paused = panel_open
		world.frozen = panel_open
		player.active = saved_player_active and not panel_open and not finished
		player.jump_requested = false
		voice.stream_paused = false
		audio.stream_paused = false

# Listening recognition is a separate activity; it never confirms reading.
func show_sorting() -> void:
	new_panel()
	sorting_active = true
	status.visible = false
	for slot in letter_slots:
		slot.visible = false
	var point = content.checkpoints[story.route_index]
	text_at("Почтовая мастерская",Vector2(35,22),34,panel)
	text_at("Послушай адрес. Выбери конверт с этим слогом.",Vector2(35,77),25,panel)
	button("▶  Послушать адрес",Vector2(35,125),Vector2(800,56),listen_address,panel)
	var choices = point.choices.duplicate()
	choices.shuffle()
	var start = (872-choices.size()*210)/2.0
	for i in range(choices.size()):
		var card_id: String = choices[i]
		var envelope = button(card_id,Vector2(start+i*210,200),Vector2(190,90),func(): choose_envelope(card_id),panel)
		envelope.add_theme_font_size_override("font_size",44)
		for state in ["normal","hover","pressed"]:
			var paper = StyleBoxFlat.new()
			paper.bg_color = Color("ffe5b1") if state=="normal" else Color("fff1d2")
			paper.border_color = Color("b88856")
			paper.set_border_width_all(3)
			paper.set_corner_radius_all(4)
			envelope.add_theme_stylebox_override(state,paper)
		for state in ["font_color","font_hover_color","font_pressed_color"]:
			envelope.add_theme_color_override(state,Color("244358"))
	sorting_feedback = text_at("Можно переслушать столько раз, сколько хочется.",Vector2(35,305),23,panel)
	button("Вместе со взрослым",Vector2(35,355),Vector2(390,54),func(): show_lesson("route"),panel)
	button("Вернуться",Vector2(450,355),Vector2(385,54),close_panel,panel)
	narrate("sorting")
	var sorting_panel = panel
	voice.finished.connect(func():
		if is_instance_valid(sorting_panel) and panel==sorting_panel and sorting_active:
			listen_address()
	, CONNECT_ONE_SHOT)

func listen_address() -> void:
	if not sorting_active:
		return
	voice.stop()
	audio.stream = load(content.cards[content.checkpoints[story.route_index].card].audio)
	audio.play()

func choose_envelope(card_id: String) -> void:
	if not sorting_active:
		return
	var point = content.checkpoints[story.route_index]
	if card_id != point.card:
		sorting_feedback.text = "У этого письма другой адрес. Послушаем ещё раз."
		listen_address()
		return
	sorted_stations[story.route_index] = true
	show_lesson("route")
	show_cheer("Конверт найден! Попробуй прочитать адрес.")
