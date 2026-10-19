extends SceneTree
var game: Node
var previous: Dictionary
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func wait_for(seconds: float = 0.12) -> void:
	await create_timer(seconds).timeout
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await wait_for()
	previous = game.progress.data.duplicate(true)
	game.music.set_enabled(true)
	check(game.story.stage=="intro" and not game.player.active,"Opening scene must precede adventure")
	check(game.music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Music must loop")
	for name in ["ma","mo","mu","mama","intro","boss","tutorial","bridge","final","route","sorting"]:
		var sound = load("res://assets/audio/%s.wav" % name)
		check(sound.get_length()>0.2,"Empty audio: "+name)
	game.interact()
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var pause_time = game.story.time
	await wait_for(0.2)
	check(game.story.time==pause_time and not game.player.active,"Changing window must pause adventure")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.player.active,"Returning to window must restore gameplay")
	await wait_for(0.5)
	check(game.player.is_on_floor(),"Player must land")
	# Proximity never grants letters or triggers a reading panel.
	game.player.position.x = 430
	await wait_for()
	check(not game.story.letters[0] and not game.panel_open,"Walking must not collect a letter")
	game.interact()
	check(game.story.letters[0],"Nearby light pulse must release M")
	game.player.position.x = 1410
	game.interact()
	check(not game.opened and not game.panel_open,"Missing A must prevent reading the bridge")
	# The second encounter can be completed with a downward jump.
	game.player.position = Vector2(980,440)
	game.player.velocity.y = 140
	await wait_for(0.15)
	check(game.story.letters[1] and game.story.stage=="bridge","Stomp must release A")
	game.player.position = Vector2(1410,500)
	await wait_for()
	check(not game.panel_open,"Arriving at bridge must not open popup")
	game.interact()
	await wait_for(1.8)
	check(game.panel_open and not game.player.active,"Explicit bridge action must open reading")
	check(game.music.volume_db < -60,"Music must fade during reading")
	check(absf(game.letter_m.position.x-340)<1,"Letters must blend")
	game.close_panel()
	check(game.story.stage=="bridge" and not game.opened,"Leaving reading must preserve bridge task")
	game.interact()
	game.confirm_answer()
	game.accept_reading()
	await wait_for(0.4)
	check(game.opened and game.world.lit and game.story.stage=="route","Reading MA must lower bridge")
	check(game.gate.get_node("CollisionShape2D").disabled,"Bridge collision must release")
	for i in range(game.content.checkpoints.size()):
		var point = game.content.checkpoints[i]
		game.player.position = Vector2(point.x,500)
		await wait_for(0.35)
		check(not game.panel_open,"Walking to station must not open lesson")
		if point.glyph!="":
			game.interact()
			check(not game.panel_open and not game.story.route_glyph,"Station must require its new vowel")
			game.player.position.x = point.blob_x
			await wait_for(0.35)
			game.interact()
			check(game.story.route_glyph,"Pulse must release new vowel")
		game.player.position = Vector2(point.x,500)
		game.interact()
		if point.has("choices"):
			check(not game.status.visible and not game.letter_slots[1].visible,"Sorting must hide the target in the HUD")
			check(game.sorting_active,"Practice station must first offer envelope sorting")
			var confirmations = game.progress.data.confirmations
			game.choose_envelope("МА")
			check(game.sorting_active and not game.sorted_stations.has(i),"Different address must allow a retry")
			check(game.progress.data.confirmations==confirmations,"Recognition must not count as reading")
			game.close_panel()
			game.interact()
			check(game.sorting_active,"Leaving sorting must preserve the task")
			game.choose_envelope(point.card)
			check(not game.sorting_active and game.sorted_stations.has(i),"Matching envelope must lead to reading")
			check(game.progress.data.confirmations==confirmations,"Correct matching still needs reading confirmation")
		await wait_for(1.8 if point.guided else 0.2)
		check(game.active_card.syllable==point.card,"Wrong card at station")
		check(game.letter_a.text==point.card[1],"Vowel must visibly change")
		if not point.guided:
			check(not game.audio.playing,"Practice must not give automatic answer")
		game.confirm_answer()
		game.accept_reading()
		await wait_for()
		check(game.route_gates[i].get_node("CollisionShape2D").disabled,"Station must release route after confirmation")
	check(game.story.stage=="guardian","All stations must precede guardian")
	game.player.position = Vector2(4000,500)
	await wait_for(0.35)
	game.interact()
	game.interact()
	check(game.story.boss_hits==1,"Boss cooldown must prevent rapid button spam")
	await wait_for(1.1)
	game.interact()
	check(game.story.stage=="boss_read" and not game.finished,"Two pulses must release final scrap, not complete reading")
	await wait_for()
	check(not game.panel_open,"Boss must wait for explicit reading action")
	game.interact()
	await wait_for(0.4)
	var frozen_time = game.story.time
	game.interact()
	await wait_for(0.4)
	check(game.story.time==frozen_time and game.story.boss_hits==2,"Reading must freeze boss and ignore attack input")
	check(not game.audio.playing,"Final MA must offer an independent attempt before sample")
	game.confirm_answer()
	game.accept_reading()
	check(not game.finished,"One syllable must not skip the whole final review")
	for expected in ["МО","МУ"]:
		game.interact()
		check(game.active_card.syllable==expected,"Guardian must review all learned cards")
		game.confirm_answer()
		game.accept_reading()
	await wait_for(1.7)
	check(game.finished and game.progress.data.stars==1,"Three syllables must complete level with one star")
	var saved = load("res://scripts/progress.gd").new()
	saved.load_progress()
	check(saved.data.completed and saved.data.get("chapter_mamomu_completed",false),"Expanded chapter progress must survive loading")
	# Optional full word can be exited without losing completion.
	game.show_lesson("bonus")
	check(game.letter_m.text=="МА" and game.letter_a.text=="МА","Bonus must combine known syllables")
	for child in game.panel.get_children():
		if child is Button and child.text=="Завершить":
			child.pressed.emit()
	check(game.progress.data.stars==1,"Skipping bonus must keep the reward")
	game.show_lesson("bonus")
	game.confirm_answer()
	game.accept_reading()
	check(game.progress.data.get("bonus_mama_with_adult",false),"Bonus must be recorded separately")
	game.progress.data = previous
	game.progress.save()
	if failures==0:
		print("PASS: envelope matching/retry/exit, recognition separate from reading, intro, intentional encounters, pulse/stomp, missing fragment, bridge interaction, blending, adult confirmation, boss cooldown, frozen reading, independent MA, completion, MA/MO/MU stations, final review, optional MAMA, focus pause, save/load")
	game.queue_free()
	await wait_for(0.2)
	quit(1 if failures else 0)
