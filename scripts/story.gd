extends Node2D
## Session-only adventure state. Reading is requested explicitly by main.gd.
signal changed
signal fragment_found(index: int)
var hero: CharacterBody2D
var glyphs: Array = ["М","А"]
var syllable := "МА"
var ink_sheet: Texture2D
var stage := "intro"
var paused := false
var action_ready := false
var magic_cooldown := 0.0
var delivery_age := 0.0
var time := 0.0
var intro_time := 0.0
var intro_duration := 3.2
var letters: Array[bool] = [false, false]
var blob_positions: Array[Vector2] = [Vector2(430,500), Vector2(980,500)]
var squash: Array[float] = [0.0, 0.0]
var boss_hits := 0
var boss_cooldown := 0.0
var pulse_age := 99.0
var pulse_origin := Vector2.ZERO
var wave_x := -1000.0
var boss_pos := Vector2(4200,500)
var checkpoints: Array = []
var route_index := 0
var route_glyph := false
var review_index := 0
signal route_fragment_found(glyph: String)

func _ready() -> void:
	ink_sheet = load("res://assets/art/ink_characters.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1

func _process(delta: float) -> void:
	if paused:
		return
	time += delta
	if stage=="delivered":
		delivery_age += delta
	pulse_age += delta
	magic_cooldown = maxf(0,magic_cooldown-delta)
	boss_cooldown = maxf(0,boss_cooldown-delta)
	for i in range(2):
		squash[i] = maxf(0,squash[i]-delta)
	if stage == "intro":
		intro_time += delta
		if intro_time > intro_duration:
			start_adventure()
	elif stage == "collect":
		for i in range(2):
			if not letters[i] and absf(hero.position.x-blob_positions[i].x) < 54 and hero.position.y < 470 and hero.position.y > 380 and hero.velocity.y > 80:
				release_fragment(i)
				hero.velocity.y = -270
	if stage=="route":
		var point = checkpoints[route_index]
		if point.glyph!="" and not route_glyph and absf(hero.position.x-point.blob_x)<54 and hero.position.y<470 and hero.position.y>380 and hero.velocity.y>80:
			release_route_fragment()
			hero.velocity.y = -270
	if stage == "guardian" and wave_x > -500:
		wave_x -= delta*150
		if wave_x < 3900:
			wave_x = -1000
		if absf(hero.position.x-wave_x)<26 and hero.position.y>475:
			# A soft nudge, never loss of letters or reading progress.
			hero.position.x = maxf(30,hero.position.x-20)
			wave_x = -1000
	queue_redraw()

func start_adventure() -> void:
	if stage != "intro":
		return
	stage = "collect"
	hero.active = true
	changed.emit()

func release_fragment(index: int) -> void:
	if stage != "collect" or letters[index]:
		return
	letters[index] = true
	squash[index] = 0.9
	if letters[0] and letters[1]:
		stage = "bridge"
	fragment_found.emit(index)
	changed.emit()

func pulse() -> void:
	if magic_cooldown>0:
		return
	magic_cooldown = 0.28
	hero.react()
	pulse_age = 0.0
	pulse_origin = hero.position + Vector2(30,-45)
	if stage == "collect":
		for i in range(2):
			if not letters[i] and hero.position.distance_to(blob_positions[i]) < 145:
				release_fragment(i)
				return
	if stage=="route":
		var point = checkpoints[route_index]
		if point.glyph!="" and not route_glyph and absf(hero.position.x-point.blob_x)<145:
			release_route_fragment()
	if stage == "guardian" and absf(hero.position.x-boss_pos.x)<265 and boss_cooldown<=0:
		boss_hits += 1
		boss_cooldown = 1.0
		wave_x = 4155
		if boss_hits >= 2:
			stage = "boss_read"
			wave_x = -1000
		changed.emit()

func open_bridge() -> void:
	stage = "route"
	changed.emit()

func release_route_fragment() -> void:
	if route_glyph or stage!="route":
		return
	route_glyph = true
	route_fragment_found.emit(checkpoints[route_index].glyph)
	changed.emit()

func advance_route() -> void:
	route_index += 1
	route_glyph = false
	if route_index>=checkpoints.size():
		stage = "guardian"
	changed.emit()

func deliver() -> void:
	delivery_age = 0.0
	stage = "delivered"
	wave_x = -1000
	changed.emit()

func draw_sprite(frame: int, rect: Rect2) -> void:
	if ink_sheet:
		var cell = Vector2(ink_sheet.get_width()/2.0, ink_sheet.get_height()/2.0)
		draw_texture_rect_region(ink_sheet,rect,Rect2(Vector2(frame%2,frame/2)*cell,cell))

func scrap(pos: Vector2, text: String, size: float = 42.0) -> void:
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-size/2,-size/2),pos+Vector2(size/2-5,-size/2),pos+Vector2(size/2,-5),pos+Vector2(size/2-3,size/2),pos+Vector2(-size/2,size/2-3)]),Color("ffe5b1"))
	var font_size = int(size*(0.48 if text.length()>1 else 0.66))
	var width = ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(ThemeDB.fallback_font,pos+Vector2(-width/2,size*0.23),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("25374a"))

func _draw() -> void:
	if stage == "intro":
		var u = clampf(intro_time/1.8,0,1)
		scrap(Vector2(280,320).lerp(Vector2(430,386),u),glyphs[0],50)
		scrap(Vector2(310,320).lerp(Vector2(980,386),u),glyphs[1],50)
		for i in range(5):
			draw_line(Vector2(298,323)+Vector2(i*4,-i*3),Vector2(305,348)+Vector2(i*3,0),Color("e6bf86"),2)
	for i in range(2):
		var pos = blob_positions[i]
		if not letters[i]:
			draw_sprite(0,Rect2(pos+Vector2(-60,-100+sin(time*3+i)*3),Vector2(120,120)))
			if stage!="intro":
				scrap(pos+Vector2(0,-114+sin(time*2+i)*4),glyphs[i],40)
		elif squash[i]>0:
			draw_sprite(1,Rect2(pos+Vector2(-65,-100),Vector2(130,120)))

	if stage=="route":
		var point = checkpoints[route_index]
		if point.glyph!="" and not route_glyph:
			draw_sprite(0,Rect2(point.blob_x-60,400+sin(time*3)*3,120,120))
			scrap(Vector2(point.blob_x,386+sin(time*2)*3),point.glyph,42)
		scrap(Vector2(point.x,395),"М_" if point.glyph!="" and not route_glyph else point.card,60)
	if stage in ["guardian","boss_read","delivered"]:
		var squish = sin(time*2)*4
		var size = Vector2(285,290+squish)
		if boss_cooldown>0:
			size.y -= sin(boss_cooldown*PI)*20
		draw_sprite(3 if stage=="delivered" else 2,Rect2(boss_pos+Vector2(-size.x/2,-size.y*0.85),size))
		if stage == "guardian":
			for i in range(2):
				draw_circle(Vector2(boss_pos.x-23+i*40,249),10,Color("ffcc7d") if i<boss_hits else Color("485369"))
			scrap(boss_pos+Vector2(125,-135),syllable,58)
		elif stage == "boss_read":
			scrap(boss_pos+Vector2(-130,-135+sin(time*2)*4),syllable,62)
		elif stage == "delivered":
			var u = clampf(delivery_age/1.5,0,1)
			scrap(Vector2(boss_pos.x+10+u*160,310-u*140),"♡",42)
			if delivery_age<2.4:
				for i in range(24):
					var angle = i*2.4
					var pos = boss_pos+Vector2(0,-130)+Vector2(cos(angle),sin(angle))*delivery_age*(45+i*4)+Vector2(0,delivery_age*delivery_age*25)
					draw_rect(Rect2(pos,Vector2(4,6)),Color(1.0,.75+(i%3)*.07,.42,1-delivery_age/2.4))
	if wave_x > -500 and stage == "guardian":
		for i in range(6):
			draw_circle(Vector2(wave_x+i*7,490-sin(i*.6)*9),10,Color("6c5082"))
	if pulse_age < 0.45:
		draw_arc(pulse_origin,20+pulse_age*180,0,TAU,40,Color(1.0,.84,.53,1-pulse_age/.45),5)
	if stage in ["bridge","guardian","boss_read"]:
		scrap(Vector2(1438,397+sin(time*2)*3),syllable,60)

	if action_ready and stage in ["collect","bridge","route","guardian","boss_read"]:
		var target = Vector2(1410,405)
		if stage=="collect":
			target = blob_positions[0 if not letters[0] else 1]+Vector2(0,-148)
		elif stage=="route":
			var point = checkpoints[route_index]
			target = Vector2(point.blob_x if point.glyph!="" and not route_glyph else point.x,355)
		elif stage in ["guardian","boss_read"]:
			target = boss_pos+Vector2(-130,-140)
		var bob = sin(time*3)*3
		draw_circle(target+Vector2(0,bob),18,Color("21384b"))
		draw_arc(target+Vector2(0,bob),18,0,TAU,24,Color("f2ca89"),2)
		draw_string(ThemeDB.fallback_font,target+Vector2(-8,7+bob),"✦",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffe7b7"))
