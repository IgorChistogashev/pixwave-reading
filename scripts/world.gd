extends Node2D
## Scenery, collectible lights and celebration are presentation only.
var background: Texture2D
var hero: CharacterBody2D
var camera: Camera2D
var frozen := false
var checkpoints: Array = []
var completed_stations := 0
var guide_target := 430.0
var bridge_progress := 0.0
var lit := false
var time := 0.0
var burst_age := 99.0
var station_motion: Array[float] = []
var delivery_station := -1
var delivery_time := 99.0

func _ready() -> void:
	background = load("res://assets/art/canal_city.jpg")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2

func _process(delta: float) -> void:
	if frozen:
		return
	while station_motion.size()<checkpoints.size():
		station_motion.append(0.0)
	for i in range(station_motion.size()):
		station_motion[i] = move_toward(station_motion[i],1.0 if i<completed_stations else 0.0,delta*0.65)
	delivery_time += delta
	bridge_progress = move_toward(bridge_progress,1.0 if lit else 0.0,delta*1.5)
	time += delta
	burst_age += delta
	queue_redraw()

func glow(pos: Vector2, radius: float, color: Color) -> void:
	for i in range(5, 0, -1):
		draw_circle(pos, radius * i / 2.5, Color(color, 0.025 * (6-i)))
	draw_circle(pos, radius * 0.25, color)

func _draw() -> void:
	if background:
		draw_texture_rect(background, Rect2(0, 0, 2304, 760), false)
		draw_texture_rect(background, Rect2(2304, 0, 2304, 760), false)
	# An unbroken, high-contrast walking surface aligned with physics.
	draw_rect(Rect2(0, 500, 4608, 10), Color("e8a65f"))
	draw_rect(Rect2(0, 510, 4608, 20), Color("302a3c"))
	for x in range(0, 4608, 48):
		draw_line(Vector2(x, 512), Vector2(x+12, 526), Color("77605b"), 2)
	# Small optional stepping stone. The route never requires a difficult jump.
	draw_rect(Rect2(620, 450, 140, 50), Color("272b3c"))
	draw_rect(Rect2(617, 450, 146, 8), Color("d9a26d"))
	for row in range(3):
		for col in range(4):
			draw_rect(Rect2(621+col*34+(row%2)*8, 460+row*13, 29, 9),Color("3e4352"))
	for x in [1810, 2110]:
		draw_rect(Rect2(x, 307, 7, 193), Color("1c2637"))
		draw_line(Vector2(x+3, 309), Vector2(x+38, 309), Color("292b40"), 7)
		var lamp = Vector2(x+35, 331)
		glow(lamp, 29 + sin(time*1.5+x)*2, Color("ffcf83") if lit or x < 1500 else Color("796274"))
		draw_rect(Rect2(lamp.x-9, lamp.y-10, 18, 20), Color("fbd49a") if lit or x < 1500 else Color("56516b"))
	# Letter mechanism and hinged bridge; collision is controlled by learning outcome.
	draw_rect(Rect2(1397,432,40,68),Color("223749"))
	draw_rect(Rect2(1394,429,46,6),Color("d6ad75"))
	glow(Vector2(1417,453),19,Color("f7d18c"))
	draw_rect(Rect2(1515,493,194,39),Color("11283d"))
	for i in range(6):
		draw_line(Vector2(1520+i*30,510+sin(time+i)*4),Vector2(1539+i*30,510+sin(time+i)*4),Color("397079"),2)
	var hinge = Vector2(1515,495)
	var bridge_angle = -PI/2*(1-bridge_progress)
	var direction = Vector2(cos(bridge_angle),sin(bridge_angle))
	for i in range(10):
		var point = hinge+direction*(i*19+8)
		draw_line(point+Vector2(-direction.y,direction.x)*12,point-Vector2(-direction.y,direction.x)*12,Color("8f6953"),16)
		draw_circle(point,2,Color("e2ba7d"))
	draw_line(hinge+Vector2(0,-94),hinge+direction*184,Color("b29c77"),3)
	draw_circle(hinge,17,Color("243a4c"))
	draw_circle(hinge,9,Color("d5af78"))
	for index in range(checkpoints.size()):
		var point = checkpoints[index]
		var ready = index<completed_stations
		var motion = station_motion[index] if index<station_motion.size() else 0.0
		var color = Color("ffda8f") if ready else Color("697487")
		draw_rect(Rect2(point.x-26,435,52,65),Color("24374a"))
		draw_rect(Rect2(point.x-30,432,60,7),Color("c59b6a"))
		glow(Vector2(point.x,452),22,color)
		if point.kind=="lantern":
			draw_line(Vector2(point.x+75,500),Vector2(point.x+75,300),Color("293b50"),9)
			glow(Vector2(point.x+75,311),32,color)
			draw_rect(Rect2(point.x+63,299,24,28),color)
		else:
			draw_rect(Rect2(point.x+59,300,14,200),Color("334858"))
			draw_rect(Rect2(point.x+70,430-70*motion,66,9),Color("d9ae76"))
		draw_delivery(point,index,motion)
		if not ready:
			for y in range(320,500,24):
				draw_line(Vector2(point.x+64,y),Vector2(point.x+90,y+12),Color("9d9b88"),3)
	# Floating paper companion reacts to progress and leads toward the gate.
	if is_instance_valid(hero):
		var pos = Vector2(clampf(guide_target,hero.position.x-115,hero.position.x+115), 366+sin(time*2.5)*9)
		glow(pos, 18, Color("ffc586"))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-22,0),pos+Vector2(0,-14),pos+Vector2(24,-7),pos+Vector2(8,11)]),Color("ffe3af"))
		draw_line(pos+Vector2(-20,0),pos+Vector2(23,-7),Color("c4836a"),2)
	for i in range(20):
		var pos = Vector2(fmod(i*239+time*(7+i%3), 4608), 200+fmod(i*53,270)+sin(time+i)*8)
		draw_circle(pos, 1.3, Color(1.0,0.76,0.43,0.35+sin(time+i)*0.2))
	# Opened portal and gentle, finite celebration.
	glow(Vector2(4410, 411), 60, Color("ffcb84") if lit else Color("67667e"))
	draw_arc(Vector2(4410, 434), 49, PI, TAU, 24, Color("f5cb8d"), 8)
	if burst_age < 2.5:
		for i in range(40):
			var angle = i*2.4
			var pos = Vector2(1600,350)+Vector2(cos(angle),sin(angle))*burst_age*(45+i*3)+Vector2(0,burst_age*burst_age*35)
			draw_rect(Rect2(pos,Vector2(5,5)),Color(1.0,0.7+(i%3)*0.1,0.4,1-burst_age/2.5))

func celebrate_station(index: int) -> void:
	delivery_station = index
	delivery_time = 0.0

func envelope(pos: Vector2, color: Color = Color("ffe3af")) -> void:
	draw_rect(Rect2(pos-Vector2(18,12),Vector2(36,24)),color)
	draw_line(pos-Vector2(18,12),pos+Vector2(0,2),Color("ac745b"),2)
	draw_line(pos+Vector2(18,-12),pos+Vector2(0,2),Color("ac745b"),2)

func draw_delivery(point: Dictionary, index: int, motion: float) -> void:
	if point.kind=="lift":
		# The same parcel physically travels from the stalled lift to a resident.
		var window = Vector2(point.x+156,337)
		draw_rect(Rect2(window-Vector2(31,39),Vector2(62,65)),Color("192b3c"))
		draw_rect(Rect2(window-Vector2(25,33),Vector2(50,53)),Color("dca76a"))
		draw_circle(window+Vector2(0,-7),14,Color("734e55"))
		for dx in [-5,5]:
			draw_circle(window+Vector2(dx,-9),2,Color("ffe9c0"))
		draw_line(window+Vector2(11,8),window+Vector2(23,3+sin(time*4)*5) if motion>0.9 else window+Vector2(20,18),Color("734e55"),6)
		var parcel = Vector2(point.x+101,415-70*minf(motion/0.7,1))
		parcel.x += 55*clampf((motion-0.7)/0.3,0,1)
		envelope(parcel)
	else:
		# Lantern chains light outward, giving the spoken task a visible payoff.
		for j in range(4):
			var lamp = Vector2(point.x+115+j*48,325+sin(j*0.8)*15)
			if j>0:
				draw_line(lamp-Vector2(48,0),lamp,Color("4b4953"),2)
			var color = Color("ffda8f") if motion>float(j)/4 else Color("59677c")
			glow(lamp,15,color)
			draw_rect(Rect2(lamp-Vector2(5,7),Vector2(10,14)),color)
		var boat = Vector2(point.x+110+motion*130,520)
		draw_colored_polygon(PackedVector2Array([boat+Vector2(-33,-3),boat+Vector2(33,-3),boat+Vector2(21,9),boat+Vector2(-20,9)]),Color("c79562"))
		envelope(boat+Vector2(0,-13))
	if delivery_station==index and delivery_time<2.0:
		for j in range(12):
			var pos = Vector2(point.x+80,385)+Vector2(cos(j*2.4),sin(j*2.4))*delivery_time*70
			draw_rect(Rect2(pos,Vector2(4,4)),Color(1,.85,.5,1-delivery_time/2))
