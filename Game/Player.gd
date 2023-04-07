extends CharacterBody3D
class_name Player

enum Anim {
	FLOOR,
	AIR,
}

const CHAR_SCALE = Vector3(1.0, 1.0, 1.0)
const MAX_SPEED = 0.8
const TURN_SPEED = 40
const JUMP_VELOCITY = 3.0
const AIR_IDLE_DEACCEL = false
const ACCEL = 14.0
const DEACCEL = 14.0
const AIR_ACCEL_FACTOR = 0.8
const SHARP_TURN_THRESHOLD = 140

@onready var camera = $Target/Camera3D
@onready var animation_tree = $Target/AnimationTree
@onready var armature = $Armature

var movement_dir = Vector3()
var linear_velocity = Vector3()
var jumping = false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

func _ready():
	animation_tree.set_active(true)

func _physics_process(delta):
	linear_velocity += gravity * delta

	var anim = Anim.FLOOR

	var vv = linear_velocity.y # Vertical velocity.
	var hv = Vector3(linear_velocity.x, 0, linear_velocity.z) # Horizontal velocity.

	var hdir = hv.normalized() # Horizontal direction.
	var hspeed = hv.length() # Horizontal speed.

	# Player input.
	var cam_basis = camera.get_global_transform().basis
	var movement_vec2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = cam_basis * Vector3(movement_vec2.x, 0, movement_vec2.y)
	
	dir.y = 0
	dir = dir.normalized()

	var jump_attempt = Input.is_action_pressed("jump")

	if is_on_floor():
		var sharp_turn = hspeed > 0.1 and rad_to_deg(acos(dir.dot(hdir))) > SHARP_TURN_THRESHOLD

		if dir.length() > 0.1 and not sharp_turn:
			if hspeed > 0.001:
				hdir = adjust_facing(hdir, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
			else:
				hdir = dir

			if hspeed < MAX_SPEED:
				hspeed += ACCEL * delta
		else:
			hspeed -= DEACCEL * delta
			if hspeed < 0:
				hspeed = 0

		hv = hdir * hspeed

		var mesh_xform = armature.get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		
		facing_mesh = (facing_mesh - Vector3.UP * facing_mesh.dot(Vector3.UP)).normalized()

		if hspeed > 0:
			facing_mesh = adjust_facing(facing_mesh, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
		
		var m3 = Basis(-facing_mesh, Vector3.UP, -facing_mesh.cross(Vector3.UP).normalized()).scaled(CHAR_SCALE)

		armature.set_transform(Transform3D(m3, mesh_xform.origin))

		if not jumping and jump_attempt:
			vv = JUMP_VELOCITY
			jumping = true
	else:
		anim = Anim.AIR

		if dir.length() > 0.1:
			hv += dir * (ACCEL * AIR_ACCEL_FACTOR * delta)
			if hv.length() > MAX_SPEED:
				hv = hv.normalized() * MAX_SPEED
		elif AIR_IDLE_DEACCEL:
			hspeed = hspeed - (DEACCEL * AIR_ACCEL_FACTOR * delta)
			if hspeed < 0:
				hspeed = 0
			hv = hdir * hspeed

	if jumping and vv < 0:
		jumping = false

	linear_velocity = hv + Vector3.UP * vv

	if is_on_floor():
		movement_dir = linear_velocity

	velocity = linear_velocity
	
	move_and_slide()
	
	if is_on_floor():
		animation_tree["parameters/walk/blend_amount"] = hspeed / MAX_SPEED
		animation_tree["parameters/scale/scale"] = hspeed / MAX_SPEED
		animation_tree["parameters/state/transition_request"] = "on floor"
	else:
		animation_tree["parameters/state/transition_request"] = "in air"
	
	animation_tree["parameters/air_dir/blend_amount"] = clamp(-linear_velocity.y / 4 + 0.5, 0, 1)


func adjust_facing(p_facing, p_target, p_step, p_adjust_rate, current_gn):
	var n = p_target # Normal
	var t = n.cross(current_gn).normalized()

	var x = n.dot(p_facing)
	var y = t.dot(p_facing)

	var ang = atan2(y,x)

	if abs(ang) < 0.001: # Too small
		return p_facing

	var s = sign(ang)
	
	ang = ang * s
	
	var turn = ang * p_adjust_rate * p_step
	var a
	
	if ang < turn:
		a = ang
	else:
		a = turn
	
	ang = (ang - a) * s

	return (n * cos(ang) + t * sin(ang)) * p_facing.length()
