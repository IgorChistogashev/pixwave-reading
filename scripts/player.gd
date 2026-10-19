extends CharacterBody2D
var axis := 0.0
var jump_requested := false
var active := true
var phase := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var sprite: Sprite2D
var victory := false
var reaction := 0.0
var landing := 0.0

func _ready() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(34, 68)
	shape.shape = rect
	shape.position.y = -34
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/art/hero_sheet.png")
	sprite.hframes = 4
	sprite.vframes = 2
	var cell_height = sprite.texture.get_height() / 2.0
	sprite.scale = Vector2.ONE * (124.0 / cell_height)
	sprite.position.y = -60
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _physics_process(delta: float) -> void:
	reaction = maxf(0,reaction-delta)
	landing = maxf(0,landing-delta)
	var was_grounded = is_on_floor()
	velocity.y += 1300.0 * delta
	coyote = 0.12 if is_on_floor() else maxf(0, coyote-delta)
	jump_buffer = maxf(0, jump_buffer-delta)
	var keyboard = float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	var direction = axis if axis != 0.0 else keyboard
	velocity.x = move_toward(velocity.x, direction*255.0 if active else 0.0, delta*1800)
	if active and (jump_requested or Input.is_action_just_pressed("ui_accept")):
		jump_buffer = 0.14
	if active and coyote > 0 and jump_buffer > 0:
		velocity.y = -500
		jump_buffer = 0
		coyote = 0
	jump_requested = false
	move_and_slide()
	if not was_grounded and is_on_floor():
		landing = 0.12
	position.x = clampf(position.x, 30, 4578)
	phase += delta * (11.0 if absf(velocity.x)>30 else 3.0)
	if absf(velocity.x)>20:
		sprite.flip_h = velocity.x < 0
	sprite.frame = 7 if victory else (6 if not is_on_floor() else (int(phase)%6 if absf(velocity.x)>30 else 1))
	sprite.position.y = -60 + (sin(phase)*1.2 if absf(velocity.x)<30 and is_on_floor() else 0.0)
	var base_scale = 124.0/(sprite.texture.get_height()/2.0)
	var squash = sin(landing/0.12*PI)*0.06
	sprite.scale = Vector2(1+squash,1-squash)*base_scale
	sprite.rotation = -0.07*sin(reaction/0.2*PI) if reaction>0 else 0.0
	sprite.modulate = Color.WHITE.lerp(Color("ffe4b2"),reaction*1.5)
	queue_redraw()

func react() -> void:
	reaction = 0.2

func _draw() -> void:
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,25,Color(0.06,0.08,0.13,0.38))
