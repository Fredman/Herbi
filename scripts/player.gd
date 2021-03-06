extends KinematicBody2D

# This is a simple collision demo showing how
# the kinematic controller works.
# move() will allow to move the node, and will
# always move it to a non-colliding spot,
# as long as it starts from a non-colliding spot too.

# Member variables
const GRAVITY = 250.0 # Pixels/second

# Angle in degrees towards either side that the player can consider "floor"
const FLOOR_ANGLE_TOLERANCE = 40
const WALK_FORCE = 630
const WALK_MIN_SPEED = 10
const WALK_MAX_SPEED = 110
const STOP_FORCE = 720
const JUMP_SPEED = 164
const JUMP_MAX_AIRBORNE_TIME = 0.2

const SLIDE_STOP_VELOCITY = 0.5 # One pixel per second
const SLIDE_STOP_MIN_TRAVEL = 0.5 # One pixel

var velocity = Vector2()
var on_air_time = 100
var jumping = false
var dir_right = true

var out = false
var can_move = true
var crounch = false
var dead = false

var jump_cooldown = 0.0
var last_checkpoint

var i = 0

const pApple = preload("res://scenes/items/apple.tscn")
onready var world = get_node("/root/world")
onready var sprites = get_node("sprites")
onready var idle = get_node("Idle")
onready var shape = get_node("CollisionShape2D")

onready var shape_normal = get_node("CollisionShape2D").get_shape().duplicate()
onready var shape_crounch = get_node("CollisionShape2D").get_shape().duplicate()

func animation_walk():
	if (int(get_pos().x)*3)/2 % 50 < 25:
		sprites.set_frame(0)
	else:
		sprites.set_frame(3)

func _fixed_process(delta):
	# Create forces
	var force = Vector2(0, GRAVITY)

	can_move = world.can_move
	if events_texts.shouldnt_move:
		can_move = false

	var walk_left = Input.is_action_pressed("move_left")
	var walk_right = Input.is_action_pressed("move_right")
	var jump = Input.is_action_pressed("jump")

	if abs(velocity.x) < WALK_MIN_SPEED and not jumping and not dead and not crounch:
		if !idle.is_connected("timeout", self, "Idle"):
			idle.connect("timeout", self, "Idle")
			Idle()
	else:
		if idle.is_connected("timeout", self, "Idle"):
			idle.disconnect("timeout", self, "Idle")

	var stop = true
	if can_move and not crounch:
		if walk_left and get_pos().x > 16:
			if (velocity.x <= WALK_MIN_SPEED and velocity.x > -WALK_MAX_SPEED):
				force.x -= WALK_FORCE
				stop = false
				if not jumping and not dead:
					animation_walk()
				sprites.set_flip_h(true)
				dir_right = false

		elif walk_right and get_pos().x < get_node("Camera2D").get_limit(MARGIN_RIGHT)-16:
			if (velocity.x >= -WALK_MIN_SPEED and velocity.x < WALK_MAX_SPEED):
				force.x += WALK_FORCE
				stop = false
				if not jumping and not dead:
					animation_walk()
				sprites.set_flip_h(false)
				dir_right = true

	if dead:
		sprites.set_frame(4)

	if stop:
		var vsign = sign(velocity.x)
		var vlen = abs(velocity.x)
		
		vlen -= STOP_FORCE*delta
		if (vlen < 0):
			vlen = 0

		velocity.x = vlen*vsign

	# Integrate forces to velocity
	velocity += force*delta

	# Integrate velocity into motion and move
	var motion = velocity*delta
	# Move and consume motion
	motion = move(motion)

	var floor_velocity = Vector2()

	if is_colliding():
		# You can check which tile was collision against with this
		# print(get_collider_metadata())

		# Ran against something, is it the floor? Get normal
		var n = get_collision_normal()

		if (rad2deg(acos(n.dot(Vector2(0, -1)))) < FLOOR_ANGLE_TOLERANCE):
			# If angle to the "up" vectors is < angle tolerance
			# char is on floor
			on_air_time = 0
			floor_velocity = get_collider_velocity()

		if (on_air_time == 0 and force.x == 0 and get_travel().length() < SLIDE_STOP_MIN_TRAVEL and abs(velocity.x) < SLIDE_STOP_VELOCITY and get_collider_velocity() == Vector2()):
			# Since this formula will always slide the character around, 
			# a special case must be considered to to stop it from moving 
			# if standing on an inclined floor. Conditions are:
			# 1) Standing on floor (on_air_time == 0)
			# 2) Did not move more than one pixel (get_travel().length() < SLIDE_STOP_MIN_TRAVEL)
			# 3) Not moving horizontally (abs(velocity.x) < SLIDE_STOP_VELOCITY)
			# 4) Collider is not moving

			revert_motion()
			velocity.y = 0.0
		else:
			# For every other case of motion, our motion was interrupted.
			# Try to complete the motion by "sliding" by the normal
			motion = n.slide(motion)
			velocity = n.slide(velocity)
			# Then move again
			move(motion)

	for down_ray in get_node("check_down").get_children():
		if down_ray.is_colliding():
			var collider = down_ray.get_collider()
			if collider != null and collider extends StaticBody2D:
				floor_velocity = collider.get_constant_linear_velocity()
			for up_ray in get_node("check_up").get_children():
				if up_ray.is_colliding() and up_ray.get_collider() and not shape.is_trigger():
					if not up_ray.get_collider().get_name() == "oneway" and up_ray.get_collider() extends StaticBody2D:
						velocity = Vector2(0,0)
						world.remove_life()

	if (floor_velocity != Vector2() and floor_velocity.y > 0): #floor velocity is set in lifts animation_player
		# If floor moves, move with floor
		move(floor_velocity*(delta/4))
		if(is_colliding()):
			revert_motion()

	if (jumping and velocity.y > 0):
		# If falling, no longer jumping
		jumping = false

	if (on_air_time < JUMP_MAX_AIRBORNE_TIME and jump and can_move and not jumping and jump_cooldown > 0.2):
		jump(JUMP_SPEED)

	on_air_time += delta
	jump_cooldown += delta

	if get_pos().y > get_node("Camera2D").get_limit(MARGIN_BOTTOM)+32 and not out:
		out = true
		dead = true
		world.stop()

func _input(event):
	if can_move:
		if event.is_action_pressed("down") and not jumping:
			for ray in get_node("check_up").get_children():
				ray.set_cast_to(Vector2(0, -5))
			crounch = true
			sprites.set_frame(5)
			set_shape(0, shape_crounch)
			shape.set_pos(Vector2(1, 3))
		elif event.is_action_released("down") and crounch:
			for ray in get_node("check_up").get_children():
				ray.set_cast_to(Vector2(0, -7))
			crounch = false
			set_shape(0, shape_normal)
			shape.set_pos(Vector2(1, 2))

		if world.apples > 0 and event.is_action_pressed("throw") and can_move:
			var apple = pApple.instance()
			apple.set_pos(get_pos())
			apple.add_collision_exception_with(self)
			apple.set_z(2)
			world.add_child(apple)
			world.remove_apple()

func Idle():
	if not jumping:
		i += randi()%2 + 1
		if i >= 3:
			i = 0
		sprites.set_frame(i)
		idle.start()

func _ready():
	for ray in get_node("check_up").get_children():
		ray.add_exception(self)
	for ray in get_node("check_down").get_children():
		ray.add_exception(self)
	
	shape_crounch.set_extents(Vector2(5, 8))
	
	set_fixed_process(true)
	set_process_input(true)

func jump(vel):
	# Jump must also be allowed to happen if the character left the floor a little bit ago.
	# Makes controls more snappy.
	jump_cooldown = 0.0
	velocity.y = -vel
	jumping = true
	sprites.set_frame(3)
	global.play_sound("jump")

func respawn():
	get_node("CollisionShape2D").set_trigger(false)
	velocity = Vector2(0,0)
	revert_motion()
	set_pos(last_checkpoint)
	dead = false
	out = false