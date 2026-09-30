class_name Skater
extends CharacterBody3D
## The player's skater: an arcade skate model on a CharacterBody3D.
##
## GROUND  rolls along whatever surface is underneath (ramps included, gravity acts along the slope),
##         steers toward the stick, pumps on transitions, pops an ollie. The floor normal comes from a ray
##         straight under the board (not the capsule's contact), so curbs roll instead of launching.
## AIR     spins, flips, grabs. Off a steep face the air is locked to the wall's plane and turns 180 on its own
##         (vert), so it comes back down the same ramp. Landings within assist_angle line up; a bit more is
##         sketchy; more than bail_angle bails; backwards lands fakie.
## GRIND   locks onto a GrindLine and slides along it.
## BAIL    tumbles for a moment, then gets back up.
## The skater origin is the bottom of the wheels; SkaterVisual draws the rider.

signal sfx(kind: String)
signal bailed(reason: String)
signal landed(air_time: float)
signal landing(kind: String)         # "clean", "sketchy", "fakie", "revert"

enum State { GROUND, AIR, GRIND, BAIL }

const GRIND_ORIGIN_DY: float = -0.17
const BAIL_TIME: float = 1.5
const CAPSULE_R: float = 0.32
const CAPSULE_H: float = 1.35

var state: int = State.GROUND
var tune: SkateTuning = SkateTuning.shared()
var inp: SkaterInput = SkaterInput.new()
var scripted: bool = false
var score: ScoreKeeper = null
var cam: Camera3D = null
var grind_lines: Array[GrindLine] = []
var visual: SkaterVisual = null
var fx: SkaterFx = null
var with_visual: bool = true
var rider: String = ""                  # a character glb (assets/characters/<rider>.glb) instead of the cartoon rider
var use_blob: bool = true              # the toon look's fake contact shadow; real-shadow scenes turn it off
var steer_mode: String = ""          # "" = follow Game.steer_mode; AI skaters use "screen"
var cam_y: float = 0.0               # ground height the camera follows (does not rise with a jump)
var _turn_bias: float = 1.0
var brain: SkaterBrain = null        # set for AI skaters: replaces player input
var is_player: bool = true           # only the player drives the occlusion hole
var look: Dictionary = {}
var _blob: MeshInstance3D = null
var _blob_mat: ShaderMaterial = null

# --- shared with the visual ---
var hdg: Vector3 = Vector3(0, 0, -1)     # facing, tangent to the surface (ground) or horizontal (air)
var yaw: float = 0.0
var floor_n: Vector3 = Vector3.UP
var board_n: Vector3 = Vector3.UP        # smoothed four-wheel board normal: what the visual tilts to
var stance: String = "regular"           # "fakie": the rider faces against the direction of travel (see facing())
var air_up: Vector3 = Vector3.UP         # the board's up and forward in the air (vert airs tilt them: see _air)
var air_fwd: Vector3 = Vector3.FORWARD
var bail_kind: String = "slam"           # "runout" (step off), "slam" (onto the hip) or "tumble" (a full roll)
var bail_duration: float = BAIL_TIME
var bail_severity: float = 0.0
var _land_jump: float = 0.0              # a jump tapped while falling, waiting for touchdown
var manual_kind: String = ""             # "manual" (nose up) or "nose" (nose manual) while manual_on
var manual_balance: float = 0.0          # -1..1: past either end the rider falls off (HUD meter)
var _balance_vel: float = 0.0
var _manual_time: float = 0.0
var _manual_req: String = ""             # a manual combo pressed in the air, waiting for the landing
var _manual_req_t: float = 0.0
var _clock: float = 0.0
var _y_zone: int = 0                     # stick: -1 up, 0 middle, 1 down
var _zone_since: float = 0.0
var _last_up: Vector2 = Vector2(-9, 0)   # (time the stick went up, how long it stayed up)
var _last_down: Vector2 = Vector2(-9, 0)
var push_anim: float = -1.0              # push stride phase 0..1 while a stride is under way (the visual reads it)
var wallplant_t: float = 0.0             # >0 just after a wall plant (the visual plants the board)
var _wall_t: float = 0.0
var _wall_n: Vector3 = Vector3.ZERO
var _plant_hold: float = 0.0
var _plant_v: Vector3 = Vector3.ZERO
var bail_origin: Vector3 = Vector3.ZERO  # where the rider went down (the board rolls on from here)
var bail_getup: float = 0.0              # seconds into the bail when the rider is back up and walks to the board
var _vert_up0: Vector3 = Vector3.UP
var _vert_fwd0: Vector3 = Vector3.FORWARD
var _vert_yaw0: float = 0.0
var vert_air: bool = false               # left a steep face: the air stays in the wall's plane
var vert_out: Vector3 = Vector3.ZERO     # horizontal, pointing away from that wall
var _vert_plane: float = 0.0
var _vert_turn_left: float = 0.0         # automatic turn still to do in vert air (signed radians)
var _vert_turn_rate: float = 0.0
var _revert_t: float = 0.0               # time left to revert after landing on a transition
var _prev_manual: bool = false
var _magnet_t: float = 0.0               # seconds the air is being steered onto a rail
var surface: String = "asphalt"
var crouch: float = 0.0
var lean: float = 0.0
var push_phase: float = 0.0
var pushing: bool = false
var braking: bool = false
var manual_on: bool = false
var spin_vel: float = 0.0
var spin_total: float = 0.0
var air_time: float = 0.0
var flip_kind: String = ""
var flip_t: float = 0.0
var grab_kind: String = ""
var grind_kind: String = ""
var grind_line: GrindLine = null
var grind_dist: float = 0.0
var grind_dir: float = 1.0
var grind_speed: float = 0.0
var grind_board_turn: float = 0.0        # 0 = 50-50, +-PI/2 = boardslide
var bail_time: float = 0.0
var stats: Dictionary = {"air": 0, "grinds": 0, "bails": 0, "max_air": 0.0, "max_speed": 0.0, "grind_time": 0.0}

var _coyote: float = 0.0
var _ollie_buf: float = 0.0
var _release_buf: float = 0.0
var _prev_held: bool = false        # own release detection: the engine reports "just released" a tick late
var charge: float = 0.0              # seconds spent crouching for a jump
var force_charge: bool = false       # tests: use the hold-and-release jump without a real player
var charge_mode: bool = false
var _grind_buf: float = 0.0
var _flip_buf: float = 0.0
var _air_ref: Vector3 = Vector3(0, 0, -1)   # heading at take-off: air spin is judged against it
var _grind_cd: float = 0.0
var _manual_started: bool = false
var _flip_done_air: bool = false
var _air_popped: bool = false
var _last_safe: Vector3 = Vector3.ZERO
var _safe_timer: float = 0.0
var _spawn: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(80.0)
	floor_stop_on_slope = false
	floor_constant_speed = false
	floor_block_on_wall = false
	floor_snap_length = tune.floor_snap
	wall_min_slide_angle = 0.0
	max_slides = 6
	safe_margin = 0.002
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = CAPSULE_R
	shape.height = CAPSULE_H
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, CAPSULE_H * 0.5 + 0.02, 0)
	add_child(cs)
	if with_visual:
		_make_visual()
		if use_blob:
			_make_blob()
		fx = SkaterFx.new()
		fx.skater = self
		add_child(fx)
		landed.connect(fx.landed)
		bailed.connect(func(_r: String) -> void: fx.bailed())


func _make_visual() -> void:
	if rider != "":
		var rig: RiderRig = RiderRig.new()
		rig.char_key = rider
		visual = rig
	else:
		visual = SkaterVisual.new()
	visual.top_level = true
	add_child(visual)
	visual.setup(look)


## Swap the rider while playing ("" = the cartoon rider).
func set_rider(key: String) -> void:
	rider = key
	if visual != null:
		visual.queue_free()
		visual = null
	if with_visual and is_inside_tree():
		_make_visual()


func _make_blob() -> void:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	_blob_mat = ShaderMaterial.new()
	_blob_mat.shader = load("res://shaders/blob.gdshader")
	q.material = _blob_mat
	_blob = MeshInstance3D.new()
	_blob.mesh = q
	_blob.top_level = true
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob)


func _process(delta: float) -> void:
	if visual != null:
		visual.sync_from(self, delta)
	if fx != null:
		fx.tick(delta)
	if is_inside_tree():
		if is_player:
			Toon.set_player_pos(global_position)
		_update_blob()


func _update_blob() -> void:
	if _blob == null:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 0.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_blob.visible = false
		return
	var p: Vector3 = hit["position"]
	if global_position.y - p.y < 0.5 and state != State.AIR:
		_blob.visible = false
		return
	_blob.visible = true
	var nrm: Vector3 = hit["normal"]
	var height: float = global_position.y - p.y
	var sc: float = 1.0 + clampf(height * 0.12, 0.0, 0.8)
	var b: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	if absf(nrm.dot(Vector3.UP)) < 0.99:
		var ax: Vector3 = Vector3.UP.cross(nrm).normalized()
		b = Basis(ax, Vector3.UP.angle_to(nrm)) * b
	_blob.global_transform = Transform3D(b * Basis.from_scale(Vector3(sc, sc, sc)), p + nrm * 0.03)
	_blob_mat.set_shader_parameter("alpha", 0.42 * (1.0 - clampf(height / 9.0, 0.0, 0.7)))


func place_at(xf: Transform3D) -> void:
	_spawn = xf
	global_position = xf.origin
	cam_y = xf.origin.y
	charge = 0.0
	var f: Vector3 = -xf.basis.z
	f.y = 0.0
	hdg = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	yaw = atan2(-hdg.x, -hdg.z)
	velocity = Vector3.ZERO
	state = State.GROUND
	stance = "regular"
	floor_n = Vector3.UP
	_last_safe = xf.origin
	_reset_air()
	if score != null:
		score.bail()


func respawn() -> void:
	place_at(_spawn)


func speed() -> float:
	return velocity.length()


## Where the rider's body is: normally on the board; in a bail it goes down where the fall happened while the
## board (the physics body) rolls on, then walks to it (a run-out runs just behind it).
func rider_position() -> Vector3:
	if state != State.BAIL:
		return global_position
	var t: float = bail_time
	if bail_kind == "runout":
		var u: float = clampf(t / maxf(bail_duration, 0.1), 0.0, 1.0)
		var back: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		back = back.normalized() if back.length() > 0.3 else hdg
		return global_position - back * sin(u * PI) * 0.9
	var slide: Vector3 = (global_position - bail_origin) * clampf(t / 0.5, 0.0, 1.0) * 0.2
	var walk: float = clampf((t - bail_getup) / maxf(bail_duration - bail_getup, 0.05), 0.0, 1.0)
	walk = walk * walk * (3.0 - 2.0 * walk)
	var down_at: Vector3 = bail_origin + slide
	return down_at.lerp(global_position, walk)


## The way the rider (and the board's nose) points: along the travel heading, or against it when fakie.
func facing() -> Vector3:
	return -hdg if stance == "fakie" else hdg


func heading_h() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


# ------------------------------------------------------------------ input

func _stick_to_world(v: Vector2) -> Vector3:
	if cam == null or v.length() < 0.01:
		return Vector3.ZERO
	var b: Basis = cam.global_transform.basis
	var f: Vector3 = -b.z
	f.y = 0.0
	f = f.normalized()
	var r: Vector3 = b.x
	r.y = 0.0
	r = r.normalized()
	return r * v.x + f * (-v.y)


func _read_input() -> void:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	inp.move = v
	inp.world_dir = _stick_to_world(v)
	if Game.steer_mode == "tank" and v.length() >= 0.01:
		# tank: the stick is relative to the board, so flips/grabs/air drift must be too
		inp.world_dir = (hdg * -v.y + hdg.cross(Vector3.UP) * v.x).limit_length(1.0)
	inp.ollie_pressed = Input.is_action_just_pressed("ollie")
	inp.ollie_held = Input.is_action_pressed("ollie")
	inp.ollie_released = Input.is_action_just_released("ollie")
	inp.flip_pressed = Input.is_action_just_pressed("flip")
	inp.grab_held = Input.is_action_pressed("grab")
	inp.grind_pressed = Input.is_action_just_pressed("grind")
	inp.brake = Input.is_action_pressed("brake")
	inp.manual = Input.is_action_pressed("manual")
	if Input.is_action_just_pressed("respawn"):
		respawn()


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if brain != null:
		brain.think(self, delta)
	elif not scripted:
		_read_input()
	_ollie_buf = maxf(0.0, _ollie_buf - delta)
	_release_buf = maxf(0.0, _release_buf - delta)
	charge_mode = force_charge or (brain == null and not scripted and Game.jump_mode == "hold")
	_grind_buf = maxf(0.0, _grind_buf - delta)
	_flip_buf = maxf(0.0, _flip_buf - delta)
	_grind_cd = maxf(0.0, _grind_cd - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_revert_t = maxf(0.0, _revert_t - delta)
	_magnet_t = maxf(0.0, _magnet_t - delta)
	_land_jump = maxf(0.0, _land_jump - delta)
	_manual_req_t = maxf(0.0, _manual_req_t - delta)
	_wall_t = maxf(0.0, _wall_t - delta)
	wallplant_t = maxf(0.0, wallplant_t - delta)
	_clock += delta
	var combo: String = _stick_combo()
	if combo != "" and not manual_on:
		if state == State.AIR:
			_manual_req = combo
			_manual_req_t = tune.manual_request
		elif state == State.GROUND:
			_start_manual(combo)
	var manual_edge: bool = inp.manual and not _prev_manual
	_prev_manual = inp.manual
	if manual_edge and _revert_t > 0.0 and state == State.GROUND:
		_revert()
	elif manual_edge and not manual_on:
		if state == State.GROUND:
			_start_manual("manual")
		elif state == State.AIR:
			_manual_req = "manual"
			_manual_req_t = tune.manual_request
	if inp.ollie_pressed:
		_ollie_buf = tune.buffer
	# One release must give exactly one pop. Detect it from the held state ourselves; the engine's
	# "just released" arrives a physics tick after the held flag drops and used to trigger a second pop.
	var release_edge: bool = _prev_held and not inp.ollie_held
	if scripted or force_charge:
		release_edge = release_edge or inp.ollie_released
	elif charge_mode and inp.ollie_pressed and not inp.ollie_held:
		release_edge = true            # pressed and released between two ticks: still a tap
	_prev_held = inp.ollie_held
	if release_edge:
		_release_buf = tune.buffer
	# a jump asked for while falling back down is kept until touchdown (the lip pop has its own window)
	var asked: bool = release_edge if charge_mode else inp.ollie_pressed
	if asked and state == State.AIR and (_air_popped or air_time >= tune.lip_window) and velocity.y < 1.0:
		_land_jump = tune.land_jump_buffer
	if inp.grind_pressed:
		_grind_buf = tune.buffer
	if inp.flip_pressed:
		_flip_buf = tune.buffer
	match state:
		State.GROUND:
			_ground(delta)
		State.AIR:
			_air(delta)
		State.GRIND:
			_grind(delta)
		State.BAIL:
			_bail(delta)
	if velocity.length() > tune.max_speed and state != State.GRIND:
		velocity = velocity.limit_length(tune.max_speed)
	stats["max_speed"] = maxf(stats["max_speed"], velocity.length())
	if state != State.AIR:
		cam_y = lerpf(cam_y, global_position.y, 1.0 - exp(-8.0 * delta))
	if score != null:
		score.tick(delta, state == State.GRIND or manual_on or state == State.AIR)
	if state == State.GROUND and surface != "grass":
		_safe_timer += delta
		if _safe_timer > 0.5:
			_safe_timer = 0.0
			_last_safe = global_position
	if global_position.y < -8.0:
		global_position = _last_safe + Vector3.UP * 0.5
		velocity = Vector3.ZERO
		_enter_ground()
	if scripted or brain != null:
		inp.clear_edges()


# ------------------------------------------------------------------ ground

func _steer_dir(n: Vector3) -> Vector3:
	var d: Vector3 = inp.world_dir
	if d.length() < 0.25:
		return Vector3.ZERO
	d = d - n * d.dot(n)
	if d.length() < 0.05:
		return Vector3.ZERO
	return d.normalized()


func _ground(dt: float) -> void:
	var n: Vector3 = floor_n
	var spd: float = velocity.length()
	var mode: String = steer_mode if steer_mode != "" else Game.steer_mode
	var tank: bool = mode == "tank"
	pushing = false
	braking = inp.brake
	var turn_applied: float = 0.0

	if tank:
		var rate_t: float = lerpf(tune.turn_slow, tune.turn_fast, clampf(spd / tune.turn_ref_speed, 0.0, 1.0))
		turn_applied = -inp.move.x * rate_t * dt
		hdg = hdg.rotated(n, turn_applied)
		pushing = inp.move.y < -0.3
		if inp.move.y > 0.3:
			braking = true
	else:
		var want: Vector3 = _steer_dir(n)
		if want != Vector3.ZERO:
			var ang: float = hdg.signed_angle_to(want, n)
			# a near U-turn keeps turning the way it last turned instead of flipping sides every frame
			if absf(ang) > 2.5:
				ang = _turn_bias * absf(ang)
			elif absf(ang) > 0.05:
				_turn_bias = signf(ang)
			var rate: float = lerpf(tune.turn_slow, tune.turn_fast, clampf(spd / tune.turn_ref_speed, 0.0, 1.0))
			turn_applied = clampf(ang, -rate * dt, rate * dt)
			hdg = hdg.rotated(n, turn_applied)
			pushing = true
	hdg = (hdg - n * hdg.dot(n)).normalized()
	lean = lerpf(lean, clampf(turn_applied / maxf(dt, 0.0001) * spd * 0.03, -1.0, 1.0), 1.0 - exp(-8.0 * dt))

	# manual: started by the stick combo (up then down, or down then up for a nose manual) or M, then kept
	# up by balancing with up / down until the rider stops, leaves the flat, pops or loses it
	if manual_on:
		braking = false
		pushing = false
		if n.y < 0.92 or spd < 1.2:
			_end_manual()
		else:
			_balance_manual(dt)
			if state != State.GROUND:
				return
			if score != null:
				score.hold("manual", dt, Tricks.MANUAL_HOLD_RATE)

	var fwd: float = velocity.dot(hdg)
	var lat: Vector3 = velocity - hdg * fwd
	var grip: float = lerpf(tune.grip_slow, tune.grip_fast, clampf(spd / tune.grip_ref_speed, 0.0, 1.0))
	lat *= exp(-grip * dt)

	var slope: float = 1.0 - n.y
	var on_ramp: bool = slope > 0.1
	var on_grass: bool = surface == "grass"
	var cap: float = tune.max_pump_speed if on_ramp else tune.max_push_speed
	if on_grass:
		cap = tune.grass_push_speed
	if pushing and not braking and not manual_on and fwd < cap:
		fwd = minf(cap, fwd + (tune.pump_accel if on_ramp else tune.push_accel) * dt)
	if braking:
		fwd = move_toward(fwd, 0.0, tune.brake_decel * dt)
	var drag: float = tune.roll_drag if pushing else tune.coast_drag
	if on_grass:
		drag += tune.grass_drag
	if manual_on:
		drag += tune.manual_drag
	fwd *= exp(-drag * dt)
	velocity = hdg * fwd + lat
	velocity += (Vector3.DOWN - n * Vector3.DOWN.dot(n)) * tune.gravity * dt

	# a stride, once started, finishes (the foot comes back onto the deck) even if the push is let go
	if (pushing and not braking) or push_anim >= 0.0:
		var before: float = push_phase
		push_phase += dt * (tune.push_rate + spd * tune.push_rate_speed)
		push_anim = fposmod(push_phase, 1.0)
		if not (pushing and not braking) and floorf(push_phase) > floorf(before):
			push_anim = -1.0
			push_phase = floorf(push_phase)
	if charge_mode:
		if inp.ollie_held:
			charge = minf(charge + dt, tune.charge_max)
		crouch = move_toward(crouch, maxf(charge / tune.charge_max, 0.25 if on_ramp else 0.0), 10.0 * dt)
	else:
		crouch = move_toward(crouch, 0.25 if on_ramp else 0.0, 6.0 * dt)

	if _grind_buf > 0.0 and _try_grind():
		return
	if charge_mode:
		# crouch while Space is held, pop when it is released: hold longer for more height
		if _release_buf > 0.0 or (charge > 0.0 and not inp.ollie_held):
			_ollie(n, pop_speed())
			return
	elif _ollie_buf > 0.0:
		_ollie(n, tune.ollie_speed)
		return

	var vel_before: Vector3 = velocity
	floor_snap_length = tune.floor_snap
	move_and_slide()
	# move_and_slide() zeroes velocity.y on any floor (so steep ramp faces lose their downhill speed) and
	# leaves the speed that runs into a wall in place. Rebuild the velocity from what we asked for: walls
	# take the part that runs into them, then the rest is turned onto the floor plane at the same speed.
	var v_want: Vector3 = vel_before
	for i in get_slide_collision_count():
		var wn: Vector3 = get_slide_collision(i).get_normal()
		if absf(wn.y) < 0.3 and v_want.dot(wn) < 0.0:
			v_want = v_want.slide(wn)
	if is_on_floor():
		floor_n = _probe_floor(floor_n, get_floor_normal())
		_coyote = tune.coyote
		surface = _surface_from_slide(surface)
		var tangent: Vector3 = v_want - floor_n * v_want.dot(floor_n)
		if tangent.length_squared() > 0.0001:
			velocity = tangent.normalized() * v_want.length()
		else:
			velocity = Vector3.ZERO
		_update_board_n(dt)
	else:
		_enter_air()
		_maybe_vert(false)
	_check_wall_crash(vel_before)


## The surface normal straight under the board centre, cast along the current board normal `up`.
## The capsule's own contact normal is wrong on edges: touching a 12 cm curb, its round bottom reports a
## 50-degree "ramp" and the skater was thrown 0.9 m into the air.
func _probe_floor(up: Vector3, contact_n: Vector3) -> Vector3:
	var c: Vector3 = _board_centre(up)
	var hit: Dictionary = _ray(c + up * 0.5, c - up * 0.6)
	if hit.is_empty():
		return contact_n
	var n: Vector3 = hit["normal"]
	if n.angle_to(up) > 0.7 and n.angle_to(contact_n) > 0.7:
		return contact_n                      # the ray found a wall face, not the floor
	return n


func _board_centre(n: Vector3) -> Vector3:
	return global_position + Vector3.UP * (CAPSULE_R + 0.02) - n * CAPSULE_R


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Four rays at the wheels give the plane the board actually sits on (nose up on a curb, the chord of a
## transition); smoothed, it is what the rider and board tilt to.
func _update_board_n(dt: float) -> void:
	var n: Vector3 = floor_n
	var fwd: Vector3 = (hdg - n * hdg.dot(n)).normalized()
	var side: Vector3 = fwd.cross(n).normalized()
	var c: Vector3 = _board_centre(n)
	var pts: Array[Vector3] = []
	for f in [0.4, -0.4]:
		for sd in [-0.12, 0.12]:
			var p: Vector3 = c + fwd * f + side * sd
			var hit: Dictionary = _ray(p + n * 0.5, p - n * 0.6)
			if hit.is_empty():
				break
			pts.append(hit["position"])
	var target: Vector3 = n
	if pts.size() == 4:
		var along: Vector3 = (pts[0] + pts[1]) - (pts[2] + pts[3])
		var across: Vector3 = (pts[1] + pts[3]) - (pts[0] + pts[2])
		var fit: Vector3 = across.cross(along)
		if fit.length_squared() > 1e-6:
			fit = fit.normalized()
			if fit.dot(n) < 0.0:
				fit = -fit
			if fit.angle_to(n) < 0.5:
				target = fit
	board_n = board_n.lerp(target, 1.0 - exp(-25.0 * dt)).normalized()


func _check_wall_crash(vel_before: Vector3) -> void:
	if state != State.GROUND:
		return
	for i in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var nn: Vector3 = c.get_normal()
		if absf(nn.y) < 0.3:
			var impact: float = -vel_before.dot(nn)
			if impact > tune.wall_crash_speed:
				_start_bail("crash")
				return


func _surface_from_slide(current: String) -> String:
	for i in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if c.get_normal().y > 0.5:
			var col: Object = c.get_collider()
			if col != null and col.has_meta("surface"):
				return String(col.get_meta("surface"))
	return current


func pop_speed() -> float:
	return lerpf(tune.pop_min, tune.pop_max, clampf(charge / tune.charge_max, 0.0, 1.0))


func charge_frac() -> float:
	return clampf(charge / tune.charge_max, 0.0, 1.0) if charge_mode and state == State.GROUND else 0.0


func _ollie(n: Vector3, speed: float) -> void:
	_ollie_buf = 0.0
	_release_buf = 0.0
	_coyote = 0.0
	charge = 0.0
	# pop mostly upward even off a steep ramp face, with a little push away from the surface
	if n.y < tune.vert_normal_y and velocity.y > 0.5:
		speed *= tune.vert_pop_mult           # popping at a vert lip: the vert float already adds height
	velocity += n.lerp(Vector3.UP, 0.6).normalized() * speed
	crouch = 0.0
	sfx.emit("ollie")
	_enter_air()
	_maybe_vert(true)
	_air_popped = true
	_end_manual()


func _enter_air() -> void:
	if state == State.AIR:
		return
	state = State.AIR
	floor_snap_length = 0.0
	_reset_air()
	var f: Vector3 = facing()
	yaw = atan2(-f.x, -f.z)
	_air_ref = hdg
	air_up = Vector3.UP
	air_fwd = heading_h()


## Leaving a steep face going up (the top of a quarter pipe or vert wall) locks the air to the wall's plane,
## so the skater comes back down the same ramp, turning 180 on the way. Riding across the face at an angle
## (a hip) skips the lock, and the transfer button (manual) at the lip breaks it (see _air).
func _maybe_vert(_popped: bool) -> void:
	var n: Vector3 = floor_n
	if n.y > tune.vert_normal_y or velocity.y <= 0.5:
		return
	var out: Vector3 = Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		return
	out = out.normalized()
	var h: Vector3 = Vector3(hdg.x, 0.0, hdg.z)
	var fall: Vector3 = -out                  # up the face, horizontally
	if h.length() > 0.1 and rad_to_deg(h.normalized().angle_to(fall)) > tune.transfer_angle \
			and rad_to_deg(h.normalized().angle_to(out)) > tune.transfer_angle:
		return
	vert_air = true
	vert_out = out
	_vert_plane = global_position.dot(out)
	# the rider stays side-on to the wall (feet toward it) and the vert 180 turns in the wall's plane
	_vert_up0 = n
	var f0: Vector3 = facing() - n * facing().dot(n)
	if f0.length() < 0.2:
		f0 = Vector3.UP - n * Vector3.UP.dot(n)
	_vert_fwd0 = f0.normalized()
	_vert_yaw0 = yaw
	air_up = _vert_up0
	air_fwd = _vert_fwd0
	velocity -= out * velocity.dot(out)
	var vy: float = maxf(velocity.y, 0.5)
	var gs: float = tune.vert_gravity_scale
	var t_total: float = vy / (tune.air_gravity_up * gs) + sqrt(vy * vy / (tune.air_gravity_up * tune.air_gravity_down * gs * gs))
	var side: float = inp.world_dir.dot(out.cross(Vector3.UP))
	if absf(side) < 0.2:
		side = velocity.dot(out.cross(Vector3.UP))
	_vert_turn_left = PI * (1.0 if side >= 0.0 else -1.0)
	_vert_turn_rate = PI / maxf(0.25, t_total * tune.vert_turn_share)


func _break_vert() -> void:
	vert_air = false
	_vert_turn_left = 0.0
	velocity += -vert_out * tune.transfer_push


func _enter_ground() -> void:
	state = State.GROUND
	floor_snap_length = tune.floor_snap
	floor_n = Vector3.UP
	_reset_air()


func _reset_air() -> void:
	air_time = 0.0
	spin_vel = 0.0
	spin_total = 0.0
	flip_kind = ""
	flip_t = 0.0
	grab_kind = ""
	_flip_done_air = false
	_air_popped = false
	vert_air = false
	_vert_turn_left = 0.0
	_magnet_t = 0.0


# ------------------------------------------------------------------ air

func _air(dt: float) -> void:
	air_time += dt
	var grav: float = tune.air_gravity_up if velocity.y > 0.0 else tune.air_gravity_down
	if absf(velocity.y) < tune.apex_hang_speed:
		grav *= tune.apex_hang_gravity        # a little float at the top of every jump
	if vert_air:
		grav *= tune.vert_gravity_scale       # vert airs hang: that is where the big tricks happen
	velocity.y -= grav * dt
	var d: Vector3 = inp.world_dir
	d.y = 0.0
	velocity += d * tune.air_control * dt
	if vert_air:
		if inp.manual and air_time < tune.lip_window + 0.1:
			_break_vert()                     # transfer: over the coping onto the deck / next ramp
		else:
			var off: float = global_position.dot(vert_out) - _vert_plane
			var v_out: float = clampf(-off * tune.vert_hold, -2.0, 2.0)
			velocity += vert_out * (v_out - velocity.dot(vert_out))

	# spin comes from the stick's sideways part relative to the take-off heading, so holding the stick
	# in the direction of travel does not spin the board (tank mode: the raw stick x, as before)
	var lateral: float = inp.move.x if Game.steer_mode == "tank" else inp.world_dir.dot(_air_ref.cross(Vector3.UP))
	var target: float = -lateral * tune.spin_max
	spin_vel = move_toward(spin_vel, target, tune.spin_accel * dt)
	yaw += spin_vel * dt
	spin_total += spin_vel * dt
	if vert_air and _vert_turn_left != 0.0:
		var step: float = minf(_vert_turn_rate * dt, absf(_vert_turn_left)) * signf(_vert_turn_left)
		yaw += step                           # the automatic vert 180 is not a trick: not in spin_total
		_vert_turn_left -= step
	hdg = heading_h()
	if vert_air:
		air_up = _vert_up0
		air_fwd = _vert_fwd0.rotated(_vert_up0, yaw - _vert_yaw0)
	else:
		air_up = air_up.lerp(Vector3.UP, 1.0 - exp(-6.0 * dt)).normalized()
		air_fwd = hdg

	if charge_mode:
		# release just after rolling off a lip still pops: the classic "jump at the top of the ramp"
		if _release_buf > 0.0 and (_coyote > 0.0 or air_time < tune.lip_window) and _air_popped == false:
			_release_buf = 0.0
			velocity.y += pop_speed() * tune.lip_pop_mult * (tune.vert_pop_mult if vert_air else 1.0)
			_air_popped = true
			charge = 0.0
			_coyote = 0.0
			sfx.emit("ollie")
	elif _ollie_buf > 0.0 and _coyote > 0.0:
		_ollie_buf = 0.0
		velocity.y = maxf(velocity.y, tune.ollie_speed * 0.85)
		_coyote = 0.0
		sfx.emit("ollie")

	if _flip_buf > 0.0 and flip_kind == "" and air_time > 0.03:
		_flip_buf = 0.0
		var word: String = Tricks.direction_word(inp.world_dir, hdg)
		flip_kind = word
		flip_t = 0.0
		sfx.emit("flip")
	if flip_kind != "":
		flip_t += dt / tune.flip_time
		if flip_t >= 1.0:
			var e2: Array = Tricks.FLIPS[flip_kind]
			if score != null:
				score.add_trick(String(e2[0]), int(e2[1]))
			sfx.emit("trick")
			flip_kind = ""
			flip_t = 0.0

	if inp.grab_held:
		if grab_kind == "" and air_time > 0.08:
			var word2: String = Tricks.direction_word(inp.world_dir, hdg)
			grab_kind = word2
			var g: Array = Tricks.GRABS[word2]
			if score != null:
				score.add_trick(String(g[0]), int(g[1]))
			sfx.emit("grab")
		if grab_kind != "" and score != null:
			score.hold("grab", dt, Tricks.GRAB_HOLD_RATE)
	elif grab_kind != "":
		grab_kind = ""
		if score != null:
			score.release_hold("grab")

	if _grind_buf > 0.0 or _magnet_t > 0.0:
		if _try_grind():
			return
		_magnet(dt)

	if _plant_hold > 0.0:
		_plant_hold -= dt
		velocity = Vector3.ZERO
		if _plant_hold <= 0.0:
			velocity = _plant_v
		return
	floor_snap_length = 0.0
	var v_before: Vector3 = velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var wn: Vector3 = get_slide_collision(i).get_normal()
		if absf(wn.y) < 0.35 and v_before.dot(wn) < -2.0:
			_wall_t = tune.wallplant_window
			_wall_n = Vector3(wn.x, 0.0, wn.z).normalized()
			_plant_v = v_before
	if _wall_t > 0.0 and _ollie_buf > 0.0:
		_wallplant()
		return
	if is_on_floor():
		_land()


## Pop off a wall you jump into: a short stick, then back out the way you came, turned around (Tony Hawk's
## wall plant). Any buffered pop within the window counts, before or just after the touch.
func _wallplant() -> void:
	_ollie_buf = 0.0
	_release_buf = 0.0
	_land_jump = 0.0
	_wall_t = 0.0
	vert_air = false
	var along: Vector3 = _plant_v - _wall_n * _plant_v.dot(_wall_n)
	along.y = 0.0
	_plant_v = _wall_n * tune.wallplant_push + along * 0.3 + Vector3.UP * tune.wallplant_pop
	_plant_hold = tune.wallplant_hold
	velocity = Vector3.ZERO
	var away: Vector3 = Vector3(_plant_v.x, 0.0, _plant_v.z).normalized()
	yaw = atan2(-away.x, -away.z)
	hdg = heading_h()
	_air_ref = hdg
	_air_popped = true
	wallplant_t = 0.3
	air_time = maxf(air_time, 0.3)
	if score != null:
		score.add_trick("Wallplant", 250)
	sfx.emit("ollie")
	sfx.emit("trick")


## Grind pressed in the air: look along the coming air path for a rail within magnet_reach and steer onto it,
## keeping the grind request alive until the skater gets there.
func _magnet(dt: float) -> void:
	if _grind_cd > 0.0 or grind_lines.is_empty() or tune.magnet_reach <= 0.0:
		return
	var g: float = tune.air_gravity_down
	var steps: int = int(ceil(tune.magnet_lookahead / 0.05))
	for k in range(1, steps + 1):
		var t: float = k * 0.05
		var p: Vector3 = global_position + velocity * t + Vector3.DOWN * (0.5 * g * t * t)
		for line in grind_lines:
			var c: Dictionary = line.closest(p + Vector3.UP * 0.1)
			var cp: Vector3 = c["point"]
			var gap: Vector2 = Vector2(cp.x - p.x, cp.z - p.z)
			var dy: float = p.y - cp.y
			if gap.length() > tune.magnet_reach or dy < tune.grind_min_dy - 0.2 or dy > tune.grind_max_dy:
				continue
			var dirv: Vector3 = line.dir_at(c["dist"])
			var spd: float = maxf(velocity.length(), 0.1)
			if acos(clampf(absf(velocity.dot(dirv)) / spd, 0.0, 1.0)) > 1.31:
				continue
			# sideways speed that closes the gap by the time we get there
			var need: Vector3 = Vector3(gap.x, 0.0, gap.y) / t
			var along: Vector3 = Vector3(dirv.x, 0.0, dirv.z).normalized()
			need -= along * need.dot(along)
			need = need.limit_length(tune.magnet_max_side)
			var v_h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
			var cur_side: Vector3 = v_h - along * v_h.dot(along)
			var new_side: Vector3 = cur_side.lerp(need, 1.0 - exp(-tune.magnet_strength * dt))
			velocity += new_side - cur_side
			_magnet_t = maxf(_magnet_t, minf(t + 0.1, tune.magnet_lookahead + 0.1))
			_grind_buf = maxf(_grind_buf, 0.05)
			return


func _land() -> void:
	var n: Vector3 = _probe_floor(get_floor_normal(), get_floor_normal())
	var travel: Vector3 = velocity
	travel.y = 0.0
	var heading: Vector3 = heading_h()
	# vert: the way down the face is what counts, however the skater drifted along the coping
	var ref: Vector3 = vert_out if vert_air else (travel.normalized() if travel.length() > 2.0 else Vector3.ZERO)
	var err: float = 0.0
	var backwards: bool = false
	if ref != Vector3.ZERO:
		var a: float = absf(heading.signed_angle_to(ref, Vector3.UP))
		backwards = a > PI * 0.5
		err = PI - a if backwards else a
	var was_air: float = air_time
	var was_vert: bool = vert_air
	if was_air > 0.25 and err > tune.bail_angle_rad():
		_start_bail("sideways", err)
		return
	var kind: String = "clean"
	if was_air > 0.25 and err > deg_to_rad(tune.assist_angle):
		kind = "sketchy"
		velocity *= tune.sketchy_keep
	if ref != Vector3.ZERO:
		stance = "fakie" if backwards else "regular"
		if backwards and kind == "clean" and was_air > 0.15:
			kind = "fakie"
	floor_n = n
	board_n = n
	_coyote = tune.coyote
	surface = _surface_from_slide(surface)
	if score != null:
		score.release_hold("grab")
		if flip_kind != "" and flip_t >= 0.7:      # landed a flip that was nearly round: count it
			var ef: Array = Tricks.FLIPS[flip_kind]
			score.add_trick(String(ef[0]), int(ef[1]))
		if was_air > 0.15:
			var units: int = int(round(absf(spin_total) / PI))
			if units >= 1 and err < tune.bail_angle_rad():
				score.add_trick(Tricks.spin_name(units), Tricks.spin_points(units))
			if was_air > 1.1:
				score.add_trick("Big Air", 300)
			score.landed()
	# line the board up with where it is going (landing assist); backwards landings roll away fakie
	var face: Vector3 = ref if ref != Vector3.ZERO else heading
	var on_plane: Vector3 = face - n * face.dot(n)
	if on_plane.length() < 0.3:
		on_plane = Vector3.DOWN - n * Vector3.DOWN.dot(n)     # a near-vertical face: straight down it
	hdg = on_plane.normalized()
	if was_vert or n.y < 0.9:
		_revert_t = tune.revert_window
	state = State.GROUND
	floor_snap_length = tune.floor_snap
	if was_air > 0.15:
		stats["air"] += 1
		stats["max_air"] = maxf(stats["max_air"], was_air)
		sfx.emit("land")
		landed.emit(was_air)
		landing.emit(kind)
	crouch = 1.0
	charge = 0.0
	_reset_air()
	if _manual_req != "" and _manual_req_t > 0.0 and state == State.GROUND:
		_start_manual(_manual_req)
		_manual_req = ""
	if _land_jump > 0.0:
		_land_jump = 0.0
		if charge_mode:
			_release_buf = tune.buffer
		else:
			_ollie_buf = tune.buffer


## Tony Hawk's manual input: tap up then down (manual) or down then up (nose manual) on the stick / W and S.
## The first press must be a tap (so holding W to push and then braking does not count).
func _stick_combo() -> String:
	var y: float = inp.move.y
	var zone: int = -1 if y < -0.5 else (1 if y > 0.5 else (0 if absf(y) < 0.3 else _y_zone))
	var found: String = ""
	if zone != _y_zone:
		var held: float = _clock - _zone_since
		if _y_zone == -1:
			_last_up = Vector2(_zone_since, held)
		elif _y_zone == 1:
			_last_down = Vector2(_zone_since, held)
		if zone == 1 and _clock - (_last_up.x + _last_up.y) < tune.combo_window and _last_up.y < tune.combo_tap:
			found = "manual"
		elif zone == -1 and _clock - (_last_down.x + _last_down.y) < tune.combo_window and _last_down.y < tune.combo_tap:
			found = "nose"
		_y_zone = zone
		_zone_since = _clock
	if found != "":
		_last_up = Vector2(-9, 0)
		_last_down = Vector2(-9, 0)
	return found


func _start_manual(kind: String) -> void:
	if velocity.length() < 2.0 or floor_n.y < 0.92:
		return
	manual_on = true
	manual_kind = kind
	_manual_time = 0.0
	manual_balance = randf_range(-0.12, 0.12)
	_balance_vel = 0.25 * (1.0 if randf() < 0.5 else -1.0)
	_manual_req = ""
	if score != null:
		score.add_trick("Manual" if kind == "manual" else "Nose Manual", 150 if kind == "manual" else 200)
	sfx.emit("manual")


func _end_manual() -> void:
	if manual_on and score != null:
		score.release_hold("manual")
	manual_on = false
	manual_kind = ""
	manual_balance = 0.0


## The balance tips away from the middle faster and faster; up / down push it back (down lowers the nose in a
## manual; in a nose manual up lowers the tail). Past either end the rider falls off: a small bail.
func _balance_manual(dt: float) -> void:
	_manual_time += dt
	var wobble: float = tune.manual_wobble * (1.0 + _manual_time * tune.manual_wobble_growth)
	var input: float = inp.move.y if manual_kind == "manual" else -inp.move.y
	_balance_vel += (manual_balance * wobble - input * tune.manual_control) * dt
	manual_balance += _balance_vel * dt
	if absf(manual_balance) > 1.0:
		_end_manual()
		_start_bail("manual")


## Manual right after landing on a ramp: spin the board 180 and keep the combo going (Tony Hawk's revert).
func _revert() -> void:
	_revert_t = 0.0
	stance = "regular" if stance == "fakie" else "fakie"
	if score != null and score.live:
		score.add_trick("Revert", 100)
		score.landed()
	landing.emit("revert")
	sfx.emit("trick")


# ------------------------------------------------------------------ grind

func _try_grind() -> bool:
	if _grind_cd > 0.0 or grind_lines.is_empty():
		return false
	var p: Vector3 = global_position
	var best: GrindLine = null
	var best_c: Dictionary = {}
	var best_cost: float = INF
	var spd: float = velocity.length()
	if spd < 2.0:
		return false
	for line in grind_lines:
		var c: Dictionary = line.closest(p + Vector3.UP * 0.1)
		var cp: Vector3 = c["point"]
		var hgap: float = Vector2(p.x - cp.x, p.z - cp.z).length()
		var dy: float = p.y - cp.y
		if hgap > tune.grind_snap_h or dy < tune.grind_min_dy or dy > tune.grind_max_dy:
			continue
		var d: Vector3 = line.dir_at(c["dist"])
		var along: float = velocity.dot(d)
		var ang: float = acos(clampf(absf(along) / spd, 0.0, 1.0))
		if ang > 1.31:   # 75 degrees
			continue
		var cost: float = hgap + absf(dy) * 0.4 + ang * 0.4
		if cost < best_cost:
			best_cost = cost
			best = line
			best_c = c
	if best == null:
		return false
	_start_grind(best, best_c)
	return true


func _start_grind(line: GrindLine, c: Dictionary) -> void:
	grind_line = line
	grind_dist = c["dist"]
	var d: Vector3 = line.dir_at(grind_dist)
	var along: float = velocity.dot(d)
	grind_dir = 1.0 if along >= 0.0 else -1.0
	grind_speed = maxf(absf(along), tune.grind_entry_speed)
	var ang: float = acos(clampf(absf(along) / maxf(velocity.length(), 0.01), 0.0, 1.0))
	var word: String = Tricks.direction_word(inp.world_dir, d * grind_dir)
	grind_board_turn = 0.0
	var gname: String = "50-50"
	if line.kind == "coping":
		gname = "Lip Slide"
	if ang > 0.8:
		gname = "Boardslide"
		grind_board_turn = PI * 0.5
	elif word == "forward":
		gname = "Noseslide"
	elif word == "back":
		gname = "Tailslide"
	grind_kind = gname
	state = State.GRIND
	vert_air = false
	_magnet_t = 0.0
	_ollie_buf = 0.0
	_grind_buf = 0.0
	flip_kind = ""
	grab_kind = ""
	manual_on = false
	stats["grinds"] += 1
	if score != null:
		score.release_hold("grab")
		var base: int = 300
		if gname == "Noseslide" or gname == "Tailslide":
			base = 400
		elif gname == "Boardslide":
			base = 350
		elif gname == "Lip Slide":
			base = 250
		score.add_trick(gname, base)
	sfx.emit("grind_start")
	global_position = line.point_at(grind_dist) + Vector3.UP * GRIND_ORIGIN_DY
	velocity = d * grind_dir * grind_speed


func _grind(dt: float) -> void:
	var d: Vector3 = grind_line.dir_at(grind_dist) * grind_dir
	grind_speed += -d.y * tune.gravity * tune.grind_slope_gravity * dt
	grind_speed *= exp(-tune.grind_friction * dt)
	grind_speed = clampf(grind_speed, tune.grind_min_speed, tune.grind_max_speed)
	grind_dist += grind_dir * grind_speed * dt
	stats["grind_time"] += dt
	if score != null:
		score.hold("grind", dt, Tricks.GRIND_HOLD_RATE)
	var fd: Vector3 = -d if stance == "fakie" else d       # a fakie grind stays fakie off the end
	yaw = atan2(-fd.x, -fd.z)
	hdg = Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.01 else hdg
	if grind_dist <= 0.0 or grind_dist >= grind_line.length:
		_end_grind(false)
		return
	global_position = grind_line.point_at(grind_dist) + Vector3.UP * GRIND_ORIGIN_DY
	velocity = d * grind_speed
	if _ollie_buf > 0.0:
		_end_grind(true)


func _end_grind(pop: bool) -> void:
	var d: Vector3 = grind_line.dir_at(clampf(grind_dist, 0.0, grind_line.length)) * grind_dir
	velocity = d * grind_speed
	velocity.y = maxf(velocity.y, 0.0) + (tune.ollie_speed * 0.9 if pop else 2.5)
	global_position += Vector3.UP * 0.25
	if score != null:
		score.release_hold("grind")
	_ollie_buf = 0.0
	_grind_cd = 0.35
	grind_line = null
	grind_kind = ""
	state = State.AIR
	floor_snap_length = 0.0
	_air_ref = hdg
	air_time = 0.0
	spin_vel = 0.0
	spin_total = 0.0
	flip_kind = ""
	if pop:
		sfx.emit("ollie")


# ------------------------------------------------------------------ bail

## How bad the fall is decides how it looks: a small mistake is stepped off and run out, a medium one is a
## slam and slide onto the hip, and only a fast or high one is a full roll. `err` = landing angle (radians).
func _start_bail(reason: String, err: float = 0.0) -> void:
	var spd: float = velocity.length()
	var sev: float = clampf((spd - 4.0) / 14.0, 0.0, 1.0) * 0.5 + clampf(air_time / 1.6, 0.0, 1.0) * 0.3
	if reason == "crash":
		sev += 0.25
	if err > 0.0:
		sev += clampf((err - tune.bail_angle_rad()) / maxf(PI * 0.5 - tune.bail_angle_rad(), 0.1), 0.0, 1.0) * 0.2
	bail_severity = clampf(sev, 0.0, 1.0)
	if bail_severity < tune.runout_below and reason != "crash":
		bail_kind = "runout"
		bail_duration = tune.runout_time
	elif bail_severity < tune.tumble_above:
		bail_kind = "slam"
		bail_duration = tune.slam_time
	else:
		bail_kind = "tumble"
		bail_duration = tune.tumble_time
	var travel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if travel.length() > 1.0:
		hdg = travel.normalized()             # fall (and run it out) the way the body was going
	# the physics body is the board from here: it rolls on and stops; the rider goes down where it fell,
	# gets up and walks to the board (a run-out runs with it), so nothing snaps back at the end
	bail_origin = global_position
	bail_getup = bail_duration
	if bail_kind != "runout":
		var roll: float = travel.length() / tune.board_roll_damp
		bail_duration += clampf(roll / tune.walk_speed, 0.25, 1.4)
	_plant_hold = 0.0
	_end_manual()
	state = State.BAIL
	bail_time = 0.0
	stats["bails"] += 1
	manual_on = false
	flip_kind = ""
	grab_kind = ""
	floor_snap_length = 0.3
	if score != null:
		score.bail()
	sfx.emit("bail")
	bailed.emit(reason)


func _bail(dt: float) -> void:
	bail_time += dt
	velocity.y -= tune.gravity * dt
	# a run-out keeps moving on foot; slams and rolls slide to a stop
	var ground_damp: float = 1.6 if bail_kind == "runout" else tune.board_roll_damp
	var damp: float = exp(-(ground_damp if is_on_floor() else 0.4) * dt)
	velocity.x *= damp
	velocity.z *= damp
	move_and_slide()
	if is_on_floor():
		floor_n = _probe_floor(floor_n, get_floor_normal())
	if bail_time > bail_duration:
		var keep: Vector3 = velocity * 0.5 if bail_kind == "runout" else Vector3.ZERO
		keep.y = 0.0
		var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		hdg = h.normalized() if h.length() > 0.5 else heading_h()
		velocity = keep
		stance = "regular"
		state = State.GROUND
		floor_snap_length = tune.floor_snap
		crouch = 1.0
		_reset_air()
