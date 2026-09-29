class_name Skater
extends CharacterBody3D
## The player's skater: an arcade skate model on a CharacterBody3D.
##
## GROUND  rolls along whatever surface is underneath (ramps included, gravity acts along the slope),
##         steers toward the stick, pumps on transitions, pops an ollie.
## AIR     spins, flips, grabs. Landing sideways bails.
## GRIND   locks onto a GrindLine and slides along it.
## BAIL    tumbles for a moment, then gets back up.
## The skater origin is the bottom of the wheels; SkaterVisual draws the rider.

signal sfx(kind: String)
signal bailed(reason: String)
signal landed(air_time: float)

enum State { GROUND, AIR, GRIND, BAIL }

const GRAVITY: float = 24.0
const MAX_PUSH_SPEED: float = 9.0
const MAX_PUMP_SPEED: float = 14.5
const MAX_SPEED: float = 22.0
const PUSH_ACCEL: float = 6.5
const PUMP_ACCEL: float = 8.5
const ROLL_DRAG: float = 0.10
const COAST_DRAG: float = 0.30
const BRAKE_DECEL: float = 15.0
const GRASS_DRAG: float = 2.8
const GRASS_PUSH_SPEED: float = 4.2
const TURN_SLOW: float = 6.5
const TURN_FAST: float = 3.3
const GRIP_SLOW: float = 11.0
const GRIP_FAST: float = 6.0
const OLLIE_SPEED: float = 8.0
const AIR_GRAVITY_UP: float = 26.0
const AIR_GRAVITY_DOWN: float = 34.0
const AIR_CONTROL: float = 3.0
const COYOTE: float = 0.11
const BUFFER: float = 0.14
const BAIL_ANGLE: float = 1.0123          # 58 degrees off the direction of travel (either way)
const SPIN_MAX: float = 11.0
const SPIN_ACCEL: float = 60.0
const FLIP_TIME: float = 0.44
const GRIND_SNAP_H: float = 0.9
const GRIND_MIN_DY: float = -0.45
const GRIND_MAX_DY: float = 1.2
const GRIND_FRICTION: float = 0.32
const GRIND_ORIGIN_DY: float = -0.17
const BAIL_TIME: float = 1.5
const WALL_CRASH_SPEED: float = 7.5
const CAPSULE_R: float = 0.32
const CAPSULE_H: float = 1.35

var state: int = State.GROUND
var inp: SkaterInput = SkaterInput.new()
var scripted: bool = false
var score: ScoreKeeper = null
var cam: Camera3D = null
var grind_lines: Array[GrindLine] = []
var visual: SkaterVisual = null
var with_visual: bool = true
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
var _grind_buf: float = 0.0
var _flip_buf: float = 0.0
var _air_ref: Vector3 = Vector3(0, 0, -1)   # heading at take-off: air spin is judged against it
var _grind_cd: float = 0.0
var _manual_started: bool = false
var _flip_done_air: bool = false
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
	floor_snap_length = 0.35
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
		visual = SkaterVisual.new()
		visual.top_level = true
		add_child(visual)
		visual.setup(look)
		_make_blob()


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
	if is_inside_tree():
		if is_player:
			RenderingServer.global_shader_parameter_set("player_pos", global_position)
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
	var f: Vector3 = -xf.basis.z
	f.y = 0.0
	hdg = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	yaw = atan2(-hdg.x, -hdg.z)
	velocity = Vector3.ZERO
	state = State.GROUND
	floor_n = Vector3.UP
	_last_safe = xf.origin
	_reset_air()
	if score != null:
		score.bail()


func respawn() -> void:
	place_at(_spawn)


func speed() -> float:
	return velocity.length()


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
	_grind_buf = maxf(0.0, _grind_buf - delta)
	_flip_buf = maxf(0.0, _flip_buf - delta)
	_grind_cd = maxf(0.0, _grind_cd - delta)
	_coyote = maxf(0.0, _coyote - delta)
	if inp.ollie_pressed:
		_ollie_buf = BUFFER
	if inp.grind_pressed:
		_grind_buf = BUFFER
	if inp.flip_pressed:
		_flip_buf = BUFFER
	match state:
		State.GROUND:
			_ground(delta)
		State.AIR:
			_air(delta)
		State.GRIND:
			_grind(delta)
		State.BAIL:
			_bail(delta)
	if velocity.length() > MAX_SPEED and state != State.GRIND:
		velocity = velocity.limit_length(MAX_SPEED)
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
		var rate_t: float = lerpf(TURN_SLOW, TURN_FAST, clampf(spd / 12.0, 0.0, 1.0))
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
			var rate: float = lerpf(TURN_SLOW, TURN_FAST, clampf(spd / 12.0, 0.0, 1.0))
			turn_applied = clampf(ang, -rate * dt, rate * dt)
			hdg = hdg.rotated(n, turn_applied)
			pushing = true
	hdg = (hdg - n * hdg.dot(n)).normalized()
	lean = lerpf(lean, clampf(turn_applied / maxf(dt, 0.0001) * spd * 0.03, -1.0, 1.0), 1.0 - exp(-8.0 * dt))

	# manual: hold on the flat with some speed
	var was_manual: bool = manual_on
	manual_on = inp.manual and n.y > 0.92 and (spd > 2.0 or (was_manual and spd > 1.2))
	if manual_on and not was_manual:
		if score != null:
			score.add_trick("Manual", 150)
		sfx.emit("manual")
	if manual_on and score != null:
		score.hold("manual", dt, Tricks.MANUAL_HOLD_RATE)
	elif was_manual and score != null:
		score.release_hold("manual")

	var fwd: float = velocity.dot(hdg)
	var lat: Vector3 = velocity - hdg * fwd
	var grip: float = lerpf(GRIP_SLOW, GRIP_FAST, clampf(spd / 14.0, 0.0, 1.0))
	lat *= exp(-grip * dt)

	var slope: float = 1.0 - n.y
	var on_ramp: bool = slope > 0.1
	var on_grass: bool = surface == "grass"
	var cap: float = MAX_PUMP_SPEED if on_ramp else MAX_PUSH_SPEED
	if on_grass:
		cap = GRASS_PUSH_SPEED
	if pushing and not braking and not manual_on and fwd < cap:
		fwd = minf(cap, fwd + (PUMP_ACCEL if on_ramp else PUSH_ACCEL) * dt)
	if braking:
		fwd = move_toward(fwd, 0.0, BRAKE_DECEL * dt)
	var drag: float = ROLL_DRAG if pushing else COAST_DRAG
	if on_grass:
		drag += GRASS_DRAG
	if manual_on:
		drag += 0.25
	fwd *= exp(-drag * dt)
	velocity = hdg * fwd + lat
	velocity += (Vector3.DOWN - n * Vector3.DOWN.dot(n)) * GRAVITY * dt

	if pushing and not braking:
		push_phase += dt * (1.6 + spd * 0.25)
	crouch = move_toward(crouch, 0.25 if on_ramp else 0.0, 6.0 * dt)

	if _grind_buf > 0.0 and _try_grind():
		return
	if _ollie_buf > 0.0:
		_ollie(n)
		return

	var vel_before: Vector3 = velocity
	floor_snap_length = 0.35
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
		floor_n = get_floor_normal()
		_coyote = COYOTE
		surface = _surface_from_slide(surface)
		var tangent: Vector3 = v_want - floor_n * v_want.dot(floor_n)
		if tangent.length_squared() > 0.0001:
			velocity = tangent.normalized() * v_want.length()
		else:
			velocity = Vector3.ZERO
	else:
		_enter_air()
	_check_wall_crash(vel_before)


func _check_wall_crash(vel_before: Vector3) -> void:
	if state != State.GROUND:
		return
	for i in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var nn: Vector3 = c.get_normal()
		if absf(nn.y) < 0.3:
			var impact: float = -vel_before.dot(nn)
			if impact > WALL_CRASH_SPEED:
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


func _ollie(n: Vector3) -> void:
	_ollie_buf = 0.0
	_coyote = 0.0
	velocity += n * OLLIE_SPEED
	crouch = 0.0
	sfx.emit("ollie")
	_enter_air()
	if manual_on and score != null:
		score.release_hold("manual")
	manual_on = false


func _enter_air() -> void:
	if state == State.AIR:
		return
	state = State.AIR
	floor_snap_length = 0.0
	_reset_air()
	yaw = atan2(-hdg.x, -hdg.z)
	_air_ref = hdg


func _enter_ground() -> void:
	state = State.GROUND
	floor_snap_length = 0.35
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


# ------------------------------------------------------------------ air

func _air(dt: float) -> void:
	air_time += dt
	velocity.y -= (AIR_GRAVITY_UP if velocity.y > 0.0 else AIR_GRAVITY_DOWN) * dt
	var d: Vector3 = inp.world_dir
	d.y = 0.0
	velocity += d * AIR_CONTROL * dt

	# spin comes from the stick's sideways part relative to the take-off heading, so holding the stick
	# in the direction of travel does not spin the board (tank mode: the raw stick x, as before)
	var lateral: float = inp.move.x if Game.steer_mode == "tank" else inp.world_dir.dot(_air_ref.cross(Vector3.UP))
	var target: float = -lateral * SPIN_MAX
	spin_vel = move_toward(spin_vel, target, SPIN_ACCEL * dt)
	yaw += spin_vel * dt
	spin_total += spin_vel * dt
	hdg = heading_h()

	if _ollie_buf > 0.0 and _coyote > 0.0:
		_ollie_buf = 0.0
		velocity.y = maxf(velocity.y, OLLIE_SPEED * 0.85)
		_coyote = 0.0
		sfx.emit("ollie")

	if _flip_buf > 0.0 and flip_kind == "" and air_time > 0.03:
		_flip_buf = 0.0
		var word: String = Tricks.direction_word(inp.world_dir, hdg)
		flip_kind = word
		flip_t = 0.0
		sfx.emit("flip")
	if flip_kind != "":
		flip_t += dt / FLIP_TIME
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

	if _grind_buf > 0.0 and _try_grind():
		return

	floor_snap_length = 0.0
	move_and_slide()
	if is_on_floor():
		_land()


func _land() -> void:
	var n: Vector3 = get_floor_normal()
	var travel: Vector3 = velocity
	travel.y = 0.0
	var heading: Vector3 = heading_h()
	var err: float = 0.0
	if travel.length() > 2.0:
		var a: float = absf(heading.signed_angle_to(travel.normalized(), Vector3.UP))
		err = minf(a, PI - a)
	var was_air: float = air_time
	if was_air > 0.25 and err > BAIL_ANGLE:
		_start_bail("sideways")
		return
	floor_n = n
	_coyote = COYOTE
	surface = _surface_from_slide(surface)
	if score != null:
		score.release_hold("grab")
		if flip_kind != "" and flip_t >= 0.7:      # landed a flip that was nearly round: count it
			var ef: Array = Tricks.FLIPS[flip_kind]
			score.add_trick(String(ef[0]), int(ef[1]))
		if was_air > 0.15:
			var units: int = int(round(absf(spin_total) / PI))
			if units >= 1 and err < BAIL_ANGLE:
				score.add_trick(Tricks.spin_name(units), Tricks.spin_points(units))
			if was_air > 1.1:
				score.add_trick("Big Air", 300)
			score.landed()
	hdg = (heading - n * heading.dot(n)).normalized()
	state = State.GROUND
	floor_snap_length = 0.35
	if was_air > 0.15:
		stats["air"] += 1
		stats["max_air"] = maxf(stats["max_air"], was_air)
		sfx.emit("land")
		landed.emit(was_air)
	crouch = 1.0
	_reset_air()


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
		if hgap > GRIND_SNAP_H or dy < GRIND_MIN_DY or dy > GRIND_MAX_DY:
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
	grind_speed = maxf(absf(along), 3.5)
	var ang: float = acos(clampf(absf(along) / maxf(velocity.length(), 0.01), 0.0, 1.0))
	var word: String = Tricks.direction_word(inp.world_dir, d * grind_dir)
	grind_board_turn = 0.0
	var gname: String = "50-50"
	if line.id.begins_with("Grind_coping"):
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
	grind_speed += -d.y * GRAVITY * 0.6 * dt
	grind_speed *= exp(-GRIND_FRICTION * dt)
	grind_speed = clampf(grind_speed, 2.5, 16.0)
	grind_dist += grind_dir * grind_speed * dt
	stats["grind_time"] += dt
	if score != null:
		score.hold("grind", dt, Tricks.GRIND_HOLD_RATE)
	yaw = atan2(-d.x, -d.z)
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
	velocity.y = maxf(velocity.y, 0.0) + (OLLIE_SPEED * 0.9 if pop else 2.5)
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

func _start_bail(reason: String) -> void:
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
	velocity.y -= GRAVITY * dt
	var damp: float = exp(-(2.6 if is_on_floor() else 0.4) * dt)
	velocity.x *= damp
	velocity.z *= damp
	move_and_slide()
	if is_on_floor():
		floor_n = get_floor_normal()
	if bail_time > BAIL_TIME:
		velocity = Vector3.ZERO
		hdg = heading_h()
		state = State.GROUND
		floor_snap_length = 0.35
		crouch = 1.0
		_reset_air()
