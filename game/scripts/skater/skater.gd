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
## GRIND   locks onto a GrindLine and slides along it; or stalls on a coping (a lip trick); or rides a wall (a
##         wallride: grind pressed in the air, meeting a wall at an angle).
## BAIL    a physical crash: the rider ragdolls, the board rolls away, then the rider gets up and walks back.
## The skater origin is the bottom of the wheels; RiderRig draws the rider.

signal sfx(kind: String)
signal bailed(reason: String)
signal landed(air_time: float)
signal landing(kind: String)         # "clean", "sketchy", "fakie", "revert"
signal warped()                      # put back inside the level (it neared the edge or fell out)
signal reset_by_player()             # R, or the edge warp: an event treats it like a bail (drop the item, ruin the take)
signal thud(kind: String, at: Vector3, strength: float)   # in a crash: "body" hits the ground (m/s lost), "board" clatters

enum State { GROUND, AIR, GRIND, BAIL }

const GRIND_ORIGIN_DY: float = -0.17
const BAIL_TIME: float = 1.5
const CAPSULE_R: float = 0.32
const CAPSULE_H: float = 1.35
const SNAP_EASE: float = 0.045            # seconds: how fast the drawn rider catches up after a snap
const EDGE_MARGIN: float = 2.0            # this close to the level's edge the skater is warped back inside
const SAFE_INSET: float = 6.0             # warp-back spots are remembered at least this far inside the edge
const EDGE_WARN: float = 16.0             # m (or 2 s away, if further) from an open edge, heading out: turn back
const AUTO_POP_MAX: float = 1.3           # m: grind pressed on the ground pops onto a ledge or rail up to this high
const HARD_LANDING: float = 11.5          # m/s into the floor: a heavy landing (a tapped ollie lands on the flat at
                                          # about 9, a full pop 11.4, a vert air on the transition about 2)
## How quickly each grind tips off balance (x SkateTuning.grind_wobble): a 50-50 sits on both trucks, a nose or
## tail slide balances on one end of the board.
const GRIND_TIP: Dictionary = {"50-50": 0.85, "Lip Slide": 0.9, "Boardslide": 1.0, "Noseslide": 1.3, "Tailslide": 1.3}

var state: int = State.GROUND
var tune: SkateTuning = SkateTuning.shared()
# who's riding (RiderProfiles): stats 1..10 scale the tuning where it's used (missing = 5, the tuning as it is);
# style bonuses on the score. Left empty in dev scenes and tests (Game.apply_rider_profile fills them for play)
var rider_stats: Dictionary = {}
var terrain: String = ""                  # "street", "vert" or "all" ("": no bonus)
var signature: Array = []                 # trick names that pay RiderProfiles.SIGNATURE_BONUS
var inp: SkaterInput = SkaterInput.new()
var scripted: bool = false
var score: ScoreKeeper = null
var cam: Camera3D = null
var grind_lines: Array[GrindLine] = []
var bounds: Rect2 = Rect2()               # the level's ground from above (x, z); no area = no edge (Level.bounds)
var visual: RiderRig = null
var fx: SkaterFx = null
var with_visual: bool = true
var rider: String = "dev"               # the character glb (assets/characters/<rider>.glb)
var steer_mode: String = ""          # "" = follow Game.steer_mode
var cam_y: float = 0.0               # ground height the camera follows (does not rise with a jump)
var _turn_bias: float = 1.0

# --- shared with the visual ---
var hdg: Vector3 = Vector3(0, 0, -1)     # facing, tangent to the surface (ground) or horizontal (air)
var yaw: float = 0.0
var floor_n: Vector3 = Vector3.UP
var board_n: Vector3 = Vector3.UP        # smoothed four-wheel board normal: what the visual tilts to
var stance: String = "regular"           # "fakie": the rider faces against the direction of travel (see facing())
var air_up: Vector3 = Vector3.UP         # the board's up and forward in the air (vert airs tilt them: see _air)
var air_fwd: Vector3 = Vector3.FORWARD
var bail_kind: String = "slam"           # "runout" (step off), "slam" (onto the hip) or "tumble" (a full roll)
var bail_dir: Vector3 = Vector3.ZERO     # horizontal: the way the body tips as it goes down (the visual's ragdoll): on
                                         # with the travel, back off a manual that tipped over the tail, off a rail's side
var _tip: float = 0.0                    # a lost manual's balance as it went (+ nose too high), and its kind
var _tip_kind: String = ""
# a lost manual, for the loose board (RiderRig._spawn_loose): "tail" (lost over the tail: it shoots out ahead) or "nose"
# (over the front: it digs in and stops), and which manual it was ("manual" / "nose"); "" for any other crash
var bail_tip: String = ""
var bail_tip_kind: String = ""
var _tip_side: Vector3 = Vector3.ZERO    # the side a lost grind fell off
var bail_duration: float = BAIL_TIME
var bail_severity: float = 0.0
var _land_jump: float = 0.0              # a jump tapped while falling, waiting for touchdown
var _render_prev: Vector3 = Vector3.ZERO  # physics positions at the last two ticks (see render_position)
var _snap_off: Vector3 = Vector3.ZERO     # where the body was drawn before a snap (onto a rail, a coping): decays
var _render_cur: Vector3 = Vector3.ZERO
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
var bail_mode: String = ""               # "physical": ragdoll + loose board (the rig runs it); "" = timed
var bail_velocity: Vector3 = Vector3.ZERO  # how the rider was moving when it went wrong (the ragdoll starts with it)
var bail_focus: Vector3 = Vector3.ZERO   # the rider's body during a physical bail (the rig keeps it current)
var _impact_v: Vector3 = Vector3.ZERO
var run_state: String = ""               # physical run-out: "run" (on foot, slowing), "stopped", or "" (fell)
var _vert_up0: Vector3 = Vector3.UP
var _vert_fwd0: Vector3 = Vector3.FORWARD
var _vert_yaw0: float = 0.0
var vert_air: bool = false               # left a steep face: the air stays in the wall's plane
var floor_vert: bool = false             # the board is on a quarter / half pipe transition (Level tags them)
var _vert_gs: float = 1.0                # gravity scale for this vert air (the float grows with the wall's steepness)
var vert_out: Vector3 = Vector3.ZERO     # horizontal, pointing away from that wall
var _vert_plane: float = 0.0
var _vert_turn_left: float = 0.0         # automatic turn still to do in vert air (signed radians)
var _vert_turn_rate: float = 0.0
var _revert_t: float = 0.0               # time left to revert after landing on a transition
var _revert_early: float = 0.0           # manual pressed in the air this recently: a ramp landing reverts at once
var reverts: int = 0                     # how many reverts (the rig pivots the drawn rider on a new one)
var _prev_manual: bool = false
var _magnet_t: float = 0.0               # seconds the air is being steered onto a rail
var surface: String = "asphalt"
var crouch: float = 0.0
var lean: float = 0.0
var push_phase: float = 0.0
var pushing: bool = false
var edge_warn: float = 0.0                # 0..1 heading for an open edge of the level (1 = about to be put back)
var pumping: bool = false                # pushing on a ramp: pumps it (the visual compresses and extends, no foot down)
var _ramp_t: float = 9.0                 # seconds since the board was last on a ramp
var braking: bool = false
var manual_on: bool = false
var spin_vel: float = 0.0
var spin_total: float = 0.0
var air_time: float = 0.0
var pop_at: float = -1.0                 # air_time when this air was popped (an ollie, a late pop off a lip, a pop off a
                                         # rail), -1 rolled off: the visual snaps the tail from it
var flip_kind: String = ""
var flip_t: float = 0.0
var grab_kind: String = ""
var grind_kind: String = ""
var wallriding: bool = false             # GRIND along a wall: the board's wheels on it (lip_kind's sibling)
var wall_n: Vector3 = Vector3.ZERO       # that wall's normal, level, out of it
var _wall_arm: float = 0.0               # grind pressed in the air: a wall met within this rides it
var _wallride_t: float = 0.0
var _wallride_along: Vector3 = Vector3.ZERO
var _wallride_speed: float = 0.0
var lip_kind: String = ""                # a lip stall in progress (Rock to Fakie, Axle Stall, ...): GRIND on a coping, standing still
var lip_balance: float = 0.0             # -1..1: past either end the stall is lost (HUD meter, like a manual)
var _lip_time: float = 0.0
var _lip_vel: float = 0.0
var _lip_out: Vector3 = Vector3.ZERO     # horizontal, away from the wall: back into the ramp
var _lip_arm: float = 0.0                # grind pressed on the way up: stall when the coping comes in reach
var _lip_fakie: bool = false
var grind_line: GrindLine = null
var grind_dist: float = 0.0
var grind_dir: float = 1.0
var grind_speed: float = 0.0
var grind_board_turn: float = 0.0        # 0 = 50-50, +-PI/2 = boardslide, about 80 degrees = nose / tail slide (visual)
var grind_balance: float = 0.0           # -1..1 across the rail (+ = leaning right of travel): past either end the rider falls off (HUD meter)
var _grind_bal_vel: float = 0.0
var _grind_time: float = 0.0
var bail_time: float = 0.0
var bail_hurried: bool = false           # jump pressed during this crash (SkateTuning.bail_hurry): the rider hurries
var land_impact: float = 0.0             # m/s into the floor at the last touchdown (the visual sinks with it, sounds scale)
var lands: int = 0                       # touchdowns so far (the visual starts its landing on a change)
var land_kind: String = ""               # the last landing: "clean", "sketchy", "fakie", "" (a hop under 0.15 s)
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
var _glance_dir: Vector3 = Vector3.ZERO      # glanced off a wall in the air: the board turns toward this
const GLANCE_TURN: float = 9.0              # rad/s
const BACK_BRAKE_ANGLE: float = 2.2         # rad (126 deg): screen steering, a stick further back than this brakes
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
		fx = SkaterFx.new()
		fx.skater = self
		add_child(fx)
		landed.connect(fx.landed)
		bailed.connect(func(_r: String) -> void: fx.bailed())
		thud.connect(func(kind: String, at: Vector3, strength: float) -> void:
			if kind == "body":
				fx.body_hit(at, strength))


func _make_visual() -> void:
	visual = RiderRig.new()
	visual.char_key = rider
	visual.top_level = true
	add_child(visual)
	visual.setup()
	# how the rider stands and pushes (RiderProfiles, the stance setting); STANCE= / PUSH_STYLE= in dev runs win
	if OS.get_environment("STANCE") == "":
		visual.goofy = Game.rider_goofy(rider)
	var push: String = OS.get_environment("PUSH_STYLE")
	visual.push_style = push if push != "" else String(RiderProfiles.profile(rider)["push"])


## Swap the rider while playing.
func set_rider(key: String) -> void:
	rider = key
	if visual != null:
		visual.queue_free()
		visual = null
	if with_visual and is_inside_tree():
		_make_visual()


func _process(delta: float) -> void:
	if visual != null:
		visual.sync_from(self, delta)
	if fx != null:
		fx.tick(delta)


func place_at(xf: Transform3D) -> void:
	_spawn = xf
	global_position = xf.origin
	_render_prev = xf.origin
	_render_cur = xf.origin
	_snap_off = Vector3.ZERO
	cam_y = xf.origin.y
	charge = 0.0
	var f: Vector3 = -xf.basis.z
	f.y = 0.0
	hdg = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	yaw = atan2(-hdg.x, -hdg.z)
	velocity = Vector3.ZERO
	state = State.GROUND
	stance = "regular"
	bail_mode = ""
	floor_n = Vector3.UP
	_last_safe = xf.origin
	_reset_air()
	# nothing carries over from whatever was going on: a lip stall's flag froze the next rail grind, a wall
	# plant's hold hijacked the next ollie, a tapped jump fired on the spot
	_end_manual()
	lip_kind = ""
	lip_balance = 0.0
	wallriding = false
	_wall_arm = 0.0
	grind_line = null
	grind_kind = ""
	grind_balance = 0.0
	run_state = ""
	_plant_hold = 0.0
	_plant_v = Vector3.ZERO
	_revert_t = 0.0
	_revert_early = 0.0
	_land_jump = 0.0
	_clear_jump_input()
	if score != null:
		score.bail()


## Forget a jump in the making (the hold-to-jump charge, a buffered press or release): after a crash or a reset
## the rider must press again, not ollie the moment they're back on the board.
func _clear_jump_input() -> void:
	charge = 0.0
	_ollie_buf = 0.0
	_release_buf = 0.0
	_prev_held = inp.ollie_held if inp != null else false


func respawn() -> void:
	place_at(_spawn)
	reset_by_player.emit()


## How far inside the level's ground the skater is (negative past its edge).
func _edge_distance() -> float:
	var p: Vector3 = global_position
	return minf(minf(p.x - bounds.position.x, bounds.end.x - p.x), minf(p.z - bounds.position.y, bounds.end.y - p.z))


## Riding off the edge of the world would show the ground end and a long fall: instead, just before the edge,
## the skater is put back on the last safe spot, stopped and facing away from that edge (the world blinks the
## screen over the cut). A combo in progress is lost, as after a reset.
## Heading off the level: past its bounds, or near the edge going out with nothing in the way. A wall or a fence
## there is the level's edge, to ride into like any other (it used to warp 2 m before reaching it).
func _off_edge() -> bool:
	var e: float = _edge_distance()
	if e < 0.0:
		return true
	if e >= EDGE_MARGIN:
		return false
	var out: Vector3 = -_edge_inward()
	if Vector3(velocity.x, 0.0, velocity.z).dot(out) < 0.5:
		return false
	var from: Vector3 = global_position + Vector3.UP * 0.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + out * (e + 1.0), 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## How close the skater is to being put back (0..1, for the HUD's "wrong way"): riding out toward an open edge, from
## EDGE_WARN away (or 2 s, at speed) to EDGE_MARGIN. Each side it's heading for counts (near a corner the nearest
## side may not be the one ahead). Along an edge, stopped, or with a wall or a fence ahead (that's the edge itself,
## ridden into like any other): 0.
func _edge_warning() -> float:
	var p: Vector3 = global_position
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var gaps: Array[float] = [p.x - bounds.position.x, bounds.end.x - p.x, p.z - bounds.position.y, bounds.end.y - p.z]
	var outs: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var k: float = 0.0
	for i in 4:
		var v_out: float = flat.dot(outs[i])
		var warn: float = maxf(EDGE_WARN, v_out * 2.0)
		if gaps[i] >= warn or v_out < 1.0 or v_out < 0.3 * flat.length():
			continue
		var from: Vector3 = p + Vector3.UP * 0.6
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + outs[i] * (maxf(gaps[i], 0.0) + 1.0), 1)
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			k = maxf(k, clampf(1.0 - (gaps[i] - EDGE_MARGIN) / (warn - EDGE_MARGIN), 0.05, 1.0))
	return k


## Toward the inside from the nearest edge of the bounds.
func _edge_inward() -> Vector3:
	var p: Vector3 = global_position
	var gaps: Array[float] = [p.x - bounds.position.x, bounds.end.x - p.x, p.z - bounds.position.y, bounds.end.y - p.z]
	var normals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	return normals[gaps.find(gaps.min())]


## Somewhere to stand the rider near `p` (where a crash ended, where the board lies): ground under it, nothing over
## it (a board can come to rest inside a hollow box or under a bench) and room for the body. If `p` won't do, the
## nearest spot that will on rings out to 4 m at about the same height; failing that, the last safe spot.
func clear_spot(p: Vector3) -> Vector3:
	var g: Variant = _stand_at(p)
	if g != null:
		return g
	for r in [0.4, 0.8, 1.2, 1.7, 2.3, 3.0, 4.0]:
		for k in 16:
			var a: float = TAU * k / 16.0
			var q: Vector3 = p + Vector3(cos(a), 0.0, sin(a)) * r
			var hit: Dictionary = _ray(q + Vector3.UP * 1.2, q + Vector3.DOWN * 1.5)
			if hit.is_empty() or absf((hit["position"] as Vector3).y - p.y) > 0.6:
				continue
			g = _stand_at(hit["position"])
			if g != null:
				return g
	return _last_safe


func _spot_ok(p: Vector3) -> bool:
	return _stand_at(p) != null


## The ground to stand on at `p`, or null: the first thing straight down from well above (6 m, so a ray never
## starts inside a tall block) is ground within 0.3 m of p's height, not the top of a box p is in or a bench or a
## roof over it, and the body fits there (a slimmer capsule than the real one: brushing a wall is fine, physics
## pushes that out; standing in it is not).
func _stand_at(p: Vector3) -> Variant:
	var down: Dictionary = _ray(p + Vector3.UP * 6.0, p + Vector3.DOWN * 0.6)
	if down.is_empty() or (down["position"] as Vector3).y > p.y + 0.3 or (down["normal"] as Vector3).y < 0.7:
		return null
	var g: Vector3 = down["position"]
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = CAPSULE_H
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, g + Vector3.UP * (CAPSULE_H * 0.5 + 0.06))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return g if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty() else null


func _warp_back() -> void:
	var p: Vector3 = global_position
	var inward: Vector3 = Vector3(-hdg.x, 0.0, -hdg.z)
	if bounds.has_area():
		inward = _edge_inward()
	var keep: Transform3D = _spawn
	place_at(Transform3D(Basis.looking_at(inward.normalized(), Vector3.UP), _last_safe + Vector3.UP * 0.05))
	_spawn = keep                              # R still goes back to the start, not here
	warped.emit()
	reset_by_player.emit()


func speed() -> float:
	return velocity.length()


## Where the rider's body is: normally on the board; in a bail it goes down where the fall happened while the
## board (the physics body) rolls on, then walks to it (a run-out runs just behind it).
func rider_position() -> Vector3:
	if state != State.BAIL:
		return render_position()
	if bail_mode == "physical":
		return render_position() if run_state == "run" else bail_focus
	var t: float = bail_time
	if bail_kind == "runout":
		var u: float = clampf(t / maxf(bail_duration, 0.1), 0.0, 1.0)
		var back: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		back = back.normalized() if back.length() > 0.3 else hdg
		return render_position() - back * sin(u * PI) * 0.9
	var slide: Vector3 = (render_position() - bail_origin) * clampf(t / 0.5, 0.0, 1.0) * 0.2
	var walk: float = clampf((t - bail_getup) / maxf(bail_duration - bail_getup, 0.05), 0.0, 1.0)
	walk = walk * walk * (3.0 - 2.0 * walk)
	var down_at: Vector3 = bail_origin + slide
	return down_at.lerp(render_position(), walk)


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
	# screen steering, on the ground: the stick pulled back toward the camera brakes. Turning round to "go that
	# way" never ended: the chase camera swings round behind as the rider turns, so back is back again, and
	# holding S spun the rider on the spot. A / D turn round (the stick's up / down taps still start manuals)
	if Game.steer_mode != "tank" and state == State.GROUND and v.length() > 0.3:
		var flat: Vector3 = Vector3(inp.world_dir.x, 0.0, inp.world_dir.z)
		if flat.length() > 0.01 and absf(hdg.signed_angle_to(flat, Vector3.UP)) > BACK_BRAKE_ANGLE:
			inp.brake = true
			inp.world_dir = Vector3.ZERO
	if Input.is_action_just_pressed("respawn"):
		respawn()


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	_render_prev = _render_cur
	_step(delta)
	_snap_off *= exp(-delta / SNAP_EASE)
	_render_cur = global_position + _snap_off           # drawn points carry the snap offset: prev is pre-snap already
	if _render_cur.distance_to(_render_prev) > 3.0:     # a reset or warp: no sweep across the map
		_snap_off = Vector3.ZERO
		_render_cur = global_position
		_render_prev = _render_cur


## Where to draw the skater this frame: between the last two physics positions. Physics runs at 120 Hz and the
## screen at whatever rate it likes; drawing the raw physics position shows uneven steps (two ticks one frame,
## one the next), so the rider and camera use this instead.
func render_position() -> Vector3:
	return _render_prev.lerp(_render_cur, Engine.get_physics_interpolation_fraction())


## Move the body to p at once (onto a rail or coping) but let the drawn rider glide there over a few frames.
func _snap_to(p: Vector3) -> void:
	_snap_off += global_position - p
	global_position = p


func _step(delta: float) -> void:
	if not scripted:
		_read_input()
	_ollie_buf = maxf(0.0, _ollie_buf - delta)
	_release_buf = maxf(0.0, _release_buf - delta)
	charge_mode = force_charge or (not scripted and Game.jump_mode == "hold")
	_grind_buf = maxf(0.0, _grind_buf - delta)
	_lip_arm = maxf(0.0, _lip_arm - delta)
	_wall_arm = maxf(0.0, _wall_arm - delta)
	_flip_buf = maxf(0.0, _flip_buf - delta)
	_grind_cd = maxf(0.0, _grind_cd - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_revert_t = maxf(0.0, _revert_t - delta)
	_revert_early = maxf(0.0, _revert_early - delta)
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
			_revert_early = tune.revert_window         # (just before a ramp landing: the revert, pressed a bit early)
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
		if state == State.AIR:
			_wall_arm = tune.wallride_arm
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
	if state == State.GROUND and floor_n.y > 0.97 and (not bounds.has_area() or _edge_distance() > SAFE_INSET):
		_safe_timer += delta
		if _safe_timer > 0.5:
			_safe_timer = 0.0
			_last_safe = global_position
	var loose: bool = state != State.BAIL or run_state == "run"     # a ragdoll stays where it fell
	edge_warn = _edge_warning() if loose and bounds.has_area() else 0.0
	if global_position.y < -8.0 or (loose and bounds.has_area() and _off_edge()):
		_warp_back()
	if scripted:
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
	pumping = false
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
				score.hold("manual", dt, Tricks.MANUAL_HOLD_RATE * style_k("street"))

	var fwd: float = velocity.dot(hdg)
	var lat: Vector3 = velocity - hdg * fwd
	var grip: float = lerpf(tune.grip_slow, tune.grip_fast, clampf(spd / tune.grip_ref_speed, 0.0, 1.0))
	lat *= exp(-grip * dt)

	var slope: float = 1.0 - n.y
	var on_ramp: bool = slope > 0.1
	var on_grass: bool = surface == "grass"
	var speed_k: float = stat_at("speed", 0.92, 1.08)
	var cap: float = (tune.max_pump_speed if on_ramp else tune.max_push_speed) * speed_k
	if on_grass:
		cap = tune.grass_push_speed
	if pushing and not braking and not manual_on and fwd < cap:
		fwd = minf(cap, fwd + (tune.pump_accel if on_ramp else tune.push_accel) * speed_k * dt)
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

	# a stride, once started, finishes (the foot comes back onto the deck) even if the push is let go. On a ramp
	# the same push pumps it instead: no foot goes down (it kicked at the ramp)
	_ramp_t = 0.0 if on_ramp else _ramp_t + dt
	pumping = pushing and not braking and not manual_on and _ramp_t < 0.5    # (the flat between two ramps too)
	var striding: bool = pushing and not braking and not pumping
	if striding or push_anim >= 0.0:
		var before: float = push_phase
		push_phase += dt * (tune.push_rate + spd * tune.push_rate_speed)
		push_anim = fposmod(push_phase, 1.0)
		if not striding and floorf(push_phase) > floorf(before):
			push_anim = -1.0
			push_phase = floorf(push_phase)
	if charge_mode:
		if inp.ollie_held:
			charge = minf(charge + dt, tune.charge_max)
		crouch = move_toward(crouch, maxf(charge / tune.charge_max, 0.25 if on_ramp else 0.0), 10.0 * dt)
	else:
		crouch = move_toward(crouch, 0.25 if on_ramp else 0.0, 6.0 * dt)

	if floor_vert and velocity.y > 0.5 and (_grind_buf > 0.0 or _lip_arm > 0.0):
		_lip_arm = maxf(_lip_arm, tune.lip_arm_time if _grind_buf > 0.0 else 0.0)
		if _try_lip():
			return
	if _grind_buf > 0.0 and _try_grind():
		return
	if _grind_buf > 0.0 and _auto_pop_grind(n):
		return
	if charge_mode:
		# crouch while Space is held, pop when it is released: hold longer for more height
		if _release_buf > 0.0 or (charge > 0.0 and not inp.ollie_held):
			_ollie(n, pop_speed())
			return
	elif _ollie_buf > 0.0:
		_ollie(n, tune.ollie_speed * _pop_k())
		return

	var vel_before: Vector3 = velocity
	var n_before: Vector3 = floor_n
	floor_snap_length = tune.floor_snap if (floor_vert or floor_n.y < 0.97) else tune.floor_snap_flat
	move_and_slide()
	# move_and_slide() zeroes velocity.y on any floor (so steep ramp faces lose their downhill speed) and
	# leaves the speed that runs into a wall in place. Rebuild the velocity from what we asked for: walls
	# take the part that runs into them, then the rest is turned onto the floor plane at the same speed.
	var v_want: Vector3 = vel_before
	for i in get_slide_collision_count():
		var wn: Vector3 = get_slide_collision(i).get_normal()
		if absf(wn.y) < 0.3 and v_want.dot(wn) < 0.0:
			v_want = v_want.slide(wn)
	var vdir: Vector3 = v_want.normalized() if v_want.length() > 0.1 else hdg
	var edge: int = _edge_step(n_before, vdir, v_want.length()) if is_on_floor() else EDGE_NONE
	if edge == EDGE_LAUNCH:
		# the capsule's round bottom is on an edge that falls away ahead: that contact made the floor turn down
		# the face (3-6 ticks diving down a dock's side at full speed). Fly off the edge instead
		velocity = v_want
		_enter_air()
		_maybe_vert(false)
		_check_wall_crash(vel_before)
		return
	if edge == EDGE_STEP:                      # a curb or a slow roll off something low: the wheels drop onto it
		var tangent_s: Vector3 = v_want - floor_n * v_want.dot(floor_n)
		velocity = tangent_s.normalized() * v_want.length() if tangent_s.length_squared() > 0.0001 else Vector3.ZERO
		_coyote = tune.coyote
		_update_board_n(dt)
		_check_wall_crash(vel_before)
		return
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
	elif _stick_to_ground(v_want):
		_update_board_n(dt)
	else:
		_enter_air()
		_maybe_vert(false)
	_check_wall_crash(vel_before)


## Rolling off the edge of something flat (a dock, a plaza, a step, a curb): the contact leans toward where
## we're going. Nothing below within the snap, or a real drop at speed: fly off it (EDGE_LAUNCH). A curb, or a
## slow roll off something low: drop straight onto the ground below (EDGE_STEP; the capsule would otherwise
## hang on the edge with a wall for a floor).
const EDGE_NONE: int = 0
const EDGE_LAUNCH: int = 1
const EDGE_STEP: int = 2


func _edge_step(n_before: Vector3, vdir: Vector3, spd: float) -> int:
	if n_before.y < 0.85 or spd < 0.05:
		return EDGE_NONE
	var cn: Vector3 = get_floor_normal()
	if cn.dot(vdir) < 0.03:                    # (against level ground: rolling slowly it tilts a little a tick)
		return EDGE_NONE
	var c: Vector3 = _board_centre(n_before)
	var hit: Dictionary = _ray(c + Vector3.UP * 0.3, c + Vector3.DOWN * (tune.floor_snap + 0.05))
	if hit.is_empty():
		return EDGE_LAUNCH if spd > 0.8 else EDGE_NONE
	var drop: float = c.y - (hit["position"] as Vector3).y
	var hn: Vector3 = hit["normal"]
	if drop > tune.floor_snap_flat + 0.05 and spd > 3.0:
		return EDGE_LAUNCH
	if drop > 0.03 and hn.y > 0.9:
		global_position.y -= drop
		floor_n = hn
		return EDGE_STEP
	return EDGE_NONE


## The physics engine can briefly lose floor contact on a curved transition (Jolt does, every other tick, and
## lets go of steep faces early). If the surface is still right under the board, curving up ahead, and the
## board is not moving away from it, stay on it: snap down, take its normal, keep the speed along it.
func _stick_to_ground(v_want: Vector3) -> bool:
	var n: Vector3 = floor_n
	if v_want.dot(n) > 2.0:
		return false
	var c: Vector3 = _board_centre(n)
	var hit: Dictionary = _ray(c + n * 0.3, c - n * (tune.floor_snap + 0.05))
	if hit.is_empty():
		return false
	var hn: Vector3 = hit["normal"]
	if hn.angle_to(n) > 0.6:
		return false
	# the same flat ground further down is a step off something, not a transition: fly off it (inclines, a
	# bank to wall, keep the rider on them)
	if n.y > 0.97 and hn.angle_to(n) < 0.05 and (c - (hit["position"] as Vector3)).dot(n) > 0.08:
		return false
	# only through a surface that curves UP ahead (a transition), never over a crest or an edge that falls
	# away (kicker lips, stair tops, pyramid edges: those launch you)
	var vdir: Vector3 = v_want.normalized() if v_want.length() > 0.1 else hdg
	if hn.dot(vdir) > n.dot(vdir) + 0.01:
		return false
	global_position += (hit["position"] as Vector3) - c
	floor_n = hn
	var tangent: Vector3 = v_want - hn * v_want.dot(hn)
	velocity = tangent.normalized() * v_want.length() if tangent.length_squared() > 0.0001 else Vector3.ZERO
	_coyote = tune.coyote
	return true


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
	var col: Object = hit.get("collider")
	floor_vert = col != null and bool(col.get_meta("vert", false))
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
				_impact_v = vel_before
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
	return lerpf(tune.pop_min, tune.pop_max, clampf(charge / tune.charge_max, 0.0, 1.0)) * _pop_k()


## A rider stat's effect (RiderProfiles.at): `at1` at 1, `at5` (no change) at 5, `at10` at 10.
func stat_at(stat: String, at1: float, at10: float, at5: float = 1.0) -> float:
	return RiderProfiles.at(int(rider_stats.get(stat, 5)), at1, at5, at10)


## Ollie: pop height 8% either way (the speed goes with its square root).
func _pop_k() -> float:
	return stat_at("ollie", sqrt(0.92), sqrt(1.08))


## Landing: 6 degrees more (or less) crooked still lands clean, and still lands at all.
func bail_rad() -> float:
	return tune.bail_angle_rad() + deg_to_rad(stat_at("landing", -6.0, 6.0, 0.0))


func assist_deg() -> float:
	return tune.assist_angle + stat_at("landing", -6.0, 6.0, 0.0)


## Style on the score: a trick on the rider's own terrain ("street" / "vert") pays 20% more, an all-rounder 8% on
## everything, a signature trick 50%.
func style_k(where: String, trick: String = "") -> float:
	var k: float = 1.0
	if terrain == "all":
		k *= RiderProfiles.ALL_ROUND_BONUS
	elif terrain != "" and terrain == where:
		k *= RiderProfiles.TERRAIN_BONUS
	if trick != "" and signature.has(trick):
		k *= RiderProfiles.SIGNATURE_BONUS
	return k


func _styled(points: int, where: String, trick: String = "") -> int:
	return int(round(points * style_k(where, trick)))


## Where an air trick happens: out of a ramp (vert) or off the flat / a ledge (street).
func _air_where() -> String:
	return "vert" if vert_air else "street"


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
	pop_at = 0.0
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


## Leaving a quarter or half pipe going up locks the air to the wall's plane, so the skater comes back down
## the same ramp, turning 180 on the way, like a skate game: at any angle of approach (riders rarely hit a wall
## dead straight) and from a pop partway up the face. Only riding almost along the coping skips it. On other
## steep faces (not tagged as a transition by Level) riding across at an angle skips the lock, so hips still
## send you across. The transfer button (manual) at the lip breaks it (see _air).
func _maybe_vert(_popped: bool) -> void:
	var n: Vector3 = floor_n
	var steep_y: float = tune.vert_face_y if floor_vert else tune.vert_normal_y
	if n.y > steep_y or velocity.y <= 0.5:
		return
	var out: Vector3 = Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		return
	out = out.normalized()
	var h: Vector3 = Vector3(hdg.x, 0.0, hdg.z)
	var fall: Vector3 = -out                  # up the face, horizontally
	var limit: float = tune.vert_along_angle if floor_vert else tune.transfer_angle
	if h.length() > 0.1 and rad_to_deg(h.normalized().angle_to(fall)) > limit \
			and rad_to_deg(h.normalized().angle_to(out)) > limit:
		return
	# the float and the lip's pop damping belong to steep take-offs: a hop from low on the face stays a hop
	var steep: float = clampf((0.8 - n.y) / (0.8 - tune.vert_normal_y), 0.0, 1.0)
	_vert_gs = lerpf(1.0, tune.vert_gravity_scale, steep) / stat_at("air", 0.9, 1.1)    # (Air: height out of a ramp)
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
	var gs: float = _vert_gs
	var t_total: float = vy / (tune.air_gravity_up * gs) + sqrt(vy * vy / (tune.air_gravity_up * tune.air_gravity_down * gs * gs))
	var side: float = inp.world_dir.dot(out.cross(Vector3.UP))
	if absf(side) < 0.2:
		side = velocity.dot(out.cross(Vector3.UP))
	# turn to face straight down the face, the short way round: a flat 180 brought a rider who went up at an
	# angle down at the same angle, and anything past bail_angle off the fall line always bailed. Straight up
	# the face it's a 180 either way: the stick (or the drift) picks the side
	var turn: float = PI * (1.0 if side >= 0.0 else -1.0)
	if h.length() > 0.1:
		var to_out: float = h.normalized().signed_angle_to(out, Vector3.UP)
		if absf(absf(to_out) - PI) > 0.35:
			turn = to_out
	_vert_turn_left = turn
	_vert_turn_rate = absf(turn) / maxf(0.25, t_total * tune.vert_turn_share)


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
	_glance_dir = Vector3.ZERO
	air_time = 0.0
	pop_at = -1.0
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
		grav *= tune.apex_hang_gravity * stat_at("hang", 1.18, 0.82)   # a little float at the top of every jump
	if vert_air:
		grav *= _vert_gs                      # vert airs hang: that is where the big tricks happen
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
	var target: float = -lateral * tune.spin_max * stat_at("spin", 0.85, 1.15)
	spin_vel = move_toward(spin_vel, target, tune.spin_accel * dt)
	yaw += spin_vel * dt
	spin_total += spin_vel * dt
	if vert_air and _vert_turn_left != 0.0:
		var step: float = minf(_vert_turn_rate * dt, absf(_vert_turn_left)) * signf(_vert_turn_left)
		yaw += step                           # the automatic vert 180 is not a trick: not in spin_total
		_vert_turn_left -= step
	if _glance_dir != Vector3.ZERO:           # glanced off a wall: swing round to where we're going now
		var h_now: Vector3 = heading_h()
		var off: float = h_now.signed_angle_to(_glance_dir, Vector3.UP)
		if absf(off) > PI * 0.5:
			off = off - signf(off) * PI       # riding backwards (fakie) the tail leads: line up the other end
		var turn_g: float = clampf(off, -GLANCE_TURN * dt, GLANCE_TURN * dt)
		yaw += turn_g
		if absf(off) < 0.02:
			_glance_dir = Vector3.ZERO
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
			pop_at = air_time
			charge = 0.0
			_coyote = 0.0
			sfx.emit("ollie")
	elif _ollie_buf > 0.0 and _coyote > 0.0:
		_ollie_buf = 0.0
		velocity.y = maxf(velocity.y, tune.ollie_speed * 0.85 * _pop_k())
		_coyote = 0.0
		pop_at = air_time
		sfx.emit("ollie")

	if _flip_buf > 0.0 and flip_kind == "" and air_time > 0.03:
		_flip_buf = 0.0
		var word: String = Tricks.direction_word(inp.world_dir, hdg)
		flip_kind = word
		flip_t = 0.0
		sfx.emit("flip")
	if flip_kind != "":
		flip_t += dt / (tune.flip_time * stat_at("flip", 1.15, 0.85))
		if flip_t >= 1.0:
			var e2: Array = Tricks.FLIPS[flip_kind]
			if score != null:
				score.add_trick(String(e2[0]), _styled(int(e2[1]), _air_where(), String(e2[0])))
			sfx.emit("trick")
			flip_kind = ""
			flip_t = 0.0

	if inp.grab_held:
		if grab_kind == "" and air_time > 0.08:
			var word2: String = Tricks.direction_word(inp.world_dir, hdg)
			grab_kind = word2
			var g: Array = Tricks.GRABS[word2]
			if score != null:
				score.add_trick(String(g[0]), _styled(int(g[1]), _air_where(), String(g[0])))
			sfx.emit("grab")
		if grab_kind != "" and score != null:
			score.hold("grab", dt, Tricks.GRAB_HOLD_RATE * style_k(_air_where(), String(Tricks.GRABS.get(grab_kind, [""])[0])))
	elif grab_kind != "":
		grab_kind = ""
		if score != null:
			score.release_hold("grab")

	if vert_air and (_grind_buf > 0.0 or _lip_arm > 0.0):
		_lip_arm = maxf(_lip_arm, tune.lip_arm_time if _grind_buf > 0.0 else 0.0)
		if _try_lip():
			return
		_grind_buf = 0.0                    # armed for the coping: not a grind search
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
	if _wall_arm > 0.0 and not vert_air and _grind_cd <= 0.0 and _try_wallride(v_before):
		return
	# a wall takes the part of the air speed that runs into it: move_and_slide() leaves it in the velocity, where
	# air control kept adding to it, and pressed along a wall the rider was flung round its end at 11-14 m/s. Not
	# on a ramp's face (a vert air comes back down it) and not once on the floor (_land takes over)
	if not is_on_floor():
		for i in get_slide_collision_count():
			var c: KinematicCollision3D = get_slide_collision(i)
			var cn: Vector3 = c.get_normal()
			var body: Object = c.get_collider()
			if absf(cn.y) < 0.3 and velocity.dot(cn) < 0.0 and not (body != null and bool(body.get_meta("vert", false))):
				velocity -= cn * velocity.dot(cn)
				# a glancing hit turns the board along the wall with the speed that's left, as a real board
				# glances off (facing into the wall, the rider would land sideways to where it's going)
				var along_w: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
				if along_w.length() > 1.5 and _wall_t <= 0.0:
					_glance_dir = along_w.normalized()
	if _wall_t > 0.0 and _ollie_buf > 0.0:
		_wallplant()
		return
	if is_on_floor():
		land_impact = maxf(0.0, -v_before.dot(get_floor_normal()))
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
		score.add_trick("Wallplant", _styled(250, "street"))
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
	if was_air > 0.25 and err > bail_rad():
		_start_bail("sideways", err)
		return
	var kind: String = "clean"
	if was_air > 0.25 and err > deg_to_rad(assist_deg()):
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
			score.add_trick(String(ef[0]), _styled(int(ef[1]), _air_where(), String(ef[0])))
		if was_air > 0.15:
			var units: int = int(round(absf(spin_total) / PI))
			if units >= 1 and err < bail_rad():
				score.add_trick(Tricks.spin_name(units), _styled(Tricks.spin_points(units), _air_where()))
			if was_air > 1.1:
				score.add_trick("Big Air", _styled(300, _air_where()))
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
	lands += 1
	land_kind = kind if was_air > 0.15 else ""
	if was_air > 0.15:
		stats["air"] += 1
		stats["max_air"] = maxf(stats["max_air"], was_air)
		sfx.emit("land_hard" if land_impact > HARD_LANDING or was_air > 1.1 else "land")
		landed.emit(was_air)
		landing.emit(kind)
	crouch = 1.0
	charge = 0.0
	_reset_air()
	if _revert_early > 0.0 and _revert_t > 0.0 and state == State.GROUND:
		_manual_req = ""
		_revert()
	elif _manual_req != "" and _manual_req_t > 0.0 and state == State.GROUND:
		_start_manual(_manual_req)
		_manual_req = ""
	if _land_jump > 0.0:
		_land_jump = 0.0
		if charge_mode:
			_release_buf = tune.buffer
		else:
			_ollie_buf = tune.buffer


## A physical run-out: the capsule is the rider on foot now. The feet brake it, gravity pulls it down slopes,
## walls stop it. A wall hit at speed, a steep slope or leaving the ground trips it into the ragdoll.
func _run_out(dt: float) -> void:
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var spd: float = h.length()
	spd = maxf(0.0, spd - tune.runout_brake * dt)
	h = h.normalized() * spd if h.length() > 0.001 else Vector3.ZERO
	velocity = Vector3(h.x, velocity.y - tune.gravity * dt, h.z)
	var before: Vector3 = velocity
	floor_snap_length = tune.floor_snap
	move_and_slide()
	var tripped: bool = false
	for i in get_slide_collision_count():
		var n: Vector3 = get_slide_collision(i).get_normal()
		if absf(n.y) < 0.3 and -before.dot(n) > tune.trip_impact:
			tripped = true
	if is_on_floor():
		floor_n = get_floor_normal()
		if floor_n.y < 0.93:
			tripped = true
	elif bail_time > 0.15:
		tripped = true                    # ran off an edge
	if tripped:
		bail_kind = "slam"
		bail_velocity = before
		run_state = ""
		velocity = Vector3.ZERO
		return
	if spd < 0.5:
		run_state = "stopped"
		velocity = Vector3.ZERO


## The rider has walked back to the loose board and stepped on: carry on from there.
func finish_physical_bail(stand: Transform3D) -> void:
	_clear_jump_input()
	global_position = clear_spot(stand.origin) + Vector3.UP * 0.03     # (never inside a wall or a box)
	var f: Vector3 = -stand.basis.z
	f.y = 0.0
	hdg = f.normalized() if f.length() > 0.1 else hdg
	velocity = Vector3.ZERO
	stance = "regular"
	bail_mode = ""
	run_state = ""
	state = State.GROUND
	floor_n = Vector3.UP
	board_n = Vector3.UP
	floor_snap_length = tune.floor_snap
	crouch = 1.0
	_reset_air()


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
		score.add_trick("Manual" if kind == "manual" else "Nose Manual", _styled(150 if kind == "manual" else 200, "street"))
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
	var wobble: float = tune.manual_wobble * stat_at("manual", 1.25, 0.75) * (1.0 + _manual_time * tune.manual_wobble_growth)
	var input: float = inp.move.y if manual_kind == "manual" else -inp.move.y
	_balance_vel += (manual_balance * wobble - input * tune.manual_control) * dt
	manual_balance += _balance_vel * dt
	if absf(manual_balance) > 1.0:
		_tip = manual_balance
		_tip_kind = manual_kind
		_end_manual()
		_start_bail("manual")


## Manual right after landing on a ramp (or just before): spin the board 180 and keep the combo going (Tony Hawk's
## revert).
func _revert() -> void:
	_revert_t = 0.0
	_revert_early = 0.0
	reverts += 1
	stance = "regular" if stance == "fakie" else "fakie"
	if score != null and score.live:
		score.add_trick("Revert", _styled(100, "vert"))
		score.landed()
	landing.emit("revert")
	sfx.emit("trick")


# ------------------------------------------------------------------ grind

## Grind pressed rolling up to a ledge or rail too high to step onto (a ledge, a bench back, a handrail): an ollie
## just high enough to clear it, the grind kept armed through the hop so it locks on. Low ones (curbs, low ledges)
## the ground search takes as they are.
func _auto_pop_grind(n: Vector3) -> bool:
	if _grind_cd > 0.0 or grind_lines.is_empty() or manual_on:
		return false
	var spd: float = velocity.length()
	if spd < 2.0:
		return false
	var p: Vector3 = global_position
	var rise_best: float = INF
	for line in grind_lines:
		var c: Dictionary = line.closest(p + Vector3.UP * 0.1)
		var cp: Vector3 = c["point"]
		var rise: float = cp.y - p.y
		if rise < -tune.grind_min_dy or rise > AUTO_POP_MAX:
			continue
		var gap: Vector3 = Vector3(cp.x - p.x, 0.0, cp.z - p.z)
		if gap.length() > tune.grind_snap_h + 0.6:
			continue
		var d: Vector3 = line.dir_at(c["dist"])
		if acos(clampf(absf(velocity.dot(d)) / spd, 0.0, 1.0)) > 1.31:   # 75 degrees, like a grind from the air
			continue
		if gap.length() > tune.grind_snap_h and velocity.dot(gap.normalized()) < -0.5:
			continue                                   # (riding away from it)
		rise_best = minf(rise_best, rise)
	if rise_best == INF:
		return false
	_ollie(n, sqrt(2.0 * tune.air_gravity_up * (rise_best + 0.25)))
	_grind_buf = 0.7
	_magnet_t = maxf(_magnet_t, 0.5)
	return true


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
	lip_kind = ""                              # a rail grind, never a lip stall's leftover
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
		grind_board_turn = PI * 0.45
	elif word == "back":
		gname = "Tailslide"
		grind_board_turn = PI * 0.45
	grind_kind = gname
	# the balance starts near the middle; coming in across the rail leans it the way the body was going
	var across: Vector3 = _grind_across(d * grind_dir)
	var tip: float = clampf(velocity.dot(across) / 5.0, -1.0, 1.0) * tune.grind_entry_tip
	grind_balance = tip + randf_range(-0.05, 0.05)
	_grind_bal_vel = tune.grind_kick * (signf(tip) if absf(tip) > 0.05 else (1.0 if randf() < 0.5 else -1.0))
	_grind_time = 0.0
	state = State.GRIND
	vert_air = false
	_magnet_t = 0.0
	_ollie_buf = 0.0
	_release_buf = 0.0
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
		score.add_trick(gname, _styled(base, "vert" if line.kind == "coping" else "street", gname))
	sfx.emit("grind_start")
	_snap_to(line.point_at(grind_dist) + Vector3.UP * GRIND_ORIGIN_DY)
	velocity = d * grind_dir * grind_speed


func _grind(dt: float) -> void:
	if lip_kind != "":
		_lip(dt)
		return
	if wallriding:
		_wallride(dt)
		return
	var d: Vector3 = grind_line.dir_at(grind_dist) * grind_dir
	grind_speed += -d.y * tune.gravity * tune.grind_slope_gravity * dt
	grind_speed *= exp(-tune.grind_friction * dt)
	grind_speed = clampf(grind_speed, tune.grind_min_speed, tune.grind_max_speed)
	grind_dist += grind_dir * grind_speed * dt
	stats["grind_time"] += dt
	if score != null:
		score.hold("grind", dt, Tricks.GRIND_HOLD_RATE * style_k("vert" if grind_line != null and grind_line.kind == "coping" else "street", grind_kind))
	var fd: Vector3 = -d if stance == "fakie" else d       # a fakie grind stays fakie off the end
	yaw = atan2(-fd.x, -fd.z)
	hdg = Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.01 else hdg
	if grind_dist <= 0.0 or grind_dist >= grind_line.length:
		_end_grind(false)
		return
	if not _balance_grind(d, dt):
		return
	global_position = grind_line.point_at(grind_dist) + Vector3.UP * GRIND_ORIGIN_DY
	velocity = d * grind_speed
	if _pop_asked():
		_end_grind(true)


## A jump off a rail or a lip stall: on the press in tap mode, on the release in hold mode (the jump is always
## the release there: popping on the press read as the jump letting go by itself while Space was held).
func _pop_asked() -> bool:
	return _release_buf > 0.0 if charge_mode else _ollie_buf > 0.0


## Right of the travel direction along a rail, level (steep stair rails included).
func _grind_across(travel: Vector3) -> Vector3:
	var a: Vector3 = travel.cross(Vector3.UP)
	return a.normalized() if a.length() > 0.01 else heading_h().cross(Vector3.UP)


## Grinds balance across the rail, like a manual: the lean tips away faster and faster (quicker the longer the
## grind and on the harder slides) and the stick left / right shifts the weight back. Past either end the rider
## falls off that side. Returns false when the grind was lost.
func _balance_grind(d: Vector3, dt: float) -> bool:
	_grind_time += dt
	var across: Vector3 = _grind_across(d)
	var input: float = inp.world_dir.dot(across)      # tank steering fills world_dir relative to the board too
	var wobble: float = tune.grind_wobble * stat_at("rails", 1.25, 0.75) * float(GRIND_TIP.get(grind_kind, 1.0)) \
		* (1.0 + _grind_time * tune.grind_wobble_growth)
	_grind_bal_vel += (grind_balance * wobble + input * tune.grind_control) * dt
	grind_balance += _grind_bal_vel * dt
	if absf(grind_balance) < 1.0:
		return true
	# off the side it leaned to: the body keeps most of its speed along the rail and tips over beside it
	var side: Vector3 = across * signf(grind_balance)
	if score != null:
		score.release_hold("grind")
	velocity = d * grind_speed * 0.8 + side * 1.8 + Vector3.UP * 0.5
	_tip_side = side
	grind_line = null
	grind_kind = ""
	grind_balance = 0.0
	_grind_cd = 0.35
	air_time = 0.0
	_start_bail("grind")
	return false


func _end_grind(pop: bool) -> void:
	var d: Vector3 = grind_line.dir_at(clampf(grind_dist, 0.0, grind_line.length)) * grind_dir
	velocity = d * grind_speed
	velocity.y = maxf(velocity.y, 0.0) + (tune.ollie_speed * 0.9 * _pop_k() if pop else 2.5)
	_snap_to(global_position + Vector3.UP * 0.25)
	if score != null:
		score.release_hold("grind")
	_ollie_buf = 0.0
	_release_buf = 0.0
	_grind_cd = 0.35
	grind_line = null
	grind_kind = ""
	grind_balance = 0.0
	state = State.AIR
	floor_snap_length = 0.0
	_air_ref = hdg
	air_time = 0.0
	spin_vel = 0.0
	spin_total = 0.0
	flip_kind = ""
	pop_at = 0.0 if pop else -1.0
	if pop:
		sfx.emit("ollie")


# ------------------------------------------------------------------ lip tricks

## Grind at the top of a quarter or half pipe while crossing its coping (going up the wall, not along it) is
## a lip trick: the rider stalls on the coping, the stick picks the trick (Tricks.LIPS), left / right keep the
## balance, jump drops back in (the "to Fakie" ones come back in backwards). Riding along a coping and
## pressing grind is still a coping grind.
func _try_lip() -> bool:
	if _grind_cd > 0.0 or grind_lines.is_empty():
		return false
	var out: Vector3 = vert_out if vert_air else Vector3(floor_n.x, 0.0, floor_n.z)
	if out.length() < 0.2:
		return false
	out = out.normalized()
	var p: Vector3 = global_position
	for line in grind_lines:
		if line.kind != "coping":
			continue
		var c: Dictionary = line.closest(p + Vector3.UP * 0.1)
		var cp: Vector3 = c["point"]
		var hgap: float = Vector2(p.x - cp.x, p.z - cp.z).length()
		var dy: float = p.y - cp.y
		if hgap > tune.lip_reach or dy < -tune.lip_reach_below or dy > tune.lip_reach_above:
			continue
		var d: Vector3 = line.dir_at(c["dist"])
		if absf(d.dot(out)) > 0.5:
			continue                           # not this ramp's coping (a corner piece)
		if not vert_air and velocity.length() > 0.5 and absf(velocity.normalized().dot(d)) > 0.64:
			continue                           # riding along the coping: that is a grind
		_start_lip(line, c, out)
		return true
	return false


func _start_lip(line: GrindLine, c: Dictionary, out: Vector3) -> void:
	var d: Vector3 = line.dir_at(c["dist"])
	var up_wall: Vector3 = -out
	var entry: Array = Tricks.LIPS[Tricks.direction_word(inp.world_dir, up_wall)]
	grind_line = line
	grind_dist = c["dist"]
	grind_dir = 1.0
	grind_speed = 0.0
	grind_board_turn = 0.0
	lip_kind = String(entry[0])
	_lip_fakie = bool(entry[2])
	_lip_out = out
	_lip_time = 0.0
	lip_balance = randf_range(-0.1, 0.1)
	_lip_vel = 0.2 * (1.0 if randf() < 0.5 else -1.0)
	_lip_arm = 0.0
	# nose over the deck; an axle stall sits along the coping, chest to the ramp
	hdg = up_wall
	if lip_kind == "Axle Stall":
		hdg = d if d.cross(Vector3.UP).dot(out) > 0.0 else -d
	yaw = atan2(-hdg.x, -hdg.z)
	stance = "regular"
	grind_kind = lip_kind
	state = State.GRIND
	vert_air = false
	_vert_turn_left = 0.0
	_magnet_t = 0.0
	_ollie_buf = 0.0
	_release_buf = 0.0
	_grind_buf = 0.0
	flip_kind = ""
	grab_kind = ""
	manual_on = false
	velocity = Vector3.ZERO
	_snap_to(Vector3(c["point"].x, c["point"].y + GRIND_ORIGIN_DY, c["point"].z))
	stats["grinds"] += 1
	if score != null:
		score.release_hold("grab")
		score.add_trick(lip_kind, _styled(int(entry[1]), "vert"))
	sfx.emit("grind_start")


func _lip(dt: float) -> void:
	_lip_time += dt
	velocity = Vector3.ZERO
	if score != null:
		score.hold("grind", dt, Tricks.LIP_HOLD_RATE * style_k("vert"))
	# balance: tips away faster and faster; the stick left / right (across the coping) shifts the weight back
	# (like grinds: lean the other way from the tip)
	var across: Vector3 = hdg.cross(Vector3.UP).normalized()
	var input: float = inp.move.x if Game.steer_mode == "tank" else inp.world_dir.dot(across)
	var wobble: float = tune.lip_wobble * stat_at("lip", 1.25, 0.75) * (1.0 + _lip_time * 0.35)
	_lip_vel += (lip_balance * wobble + input * tune.lip_control) * dt
	lip_balance += _lip_vel * dt
	if absf(lip_balance) > 1.0:
		_end_lip(false)
		_start_bail("lip")
		return
	if _pop_asked() or _lip_time >= tune.lip_max_time:
		_end_lip(true)


## Drop back into the ramp: a small hop out over the transition, landing forward or (to Fakie) backwards.
func _end_lip(pop: bool) -> void:
	if score != null:
		score.release_hold("grind")
	hdg = -_lip_out if _lip_fakie else _lip_out
	yaw = atan2(-hdg.x, -hdg.z)
	velocity = _lip_out * (2.4 if pop else 1.2) + Vector3.UP * (2.0 if pop else 0.4)
	_snap_to(global_position + _lip_out * 0.3 + Vector3.UP * 0.05)
	lip_kind = ""
	lip_balance = 0.0
	grind_line = null
	grind_kind = ""
	_ollie_buf = 0.0
	_release_buf = 0.0
	_grind_cd = 0.35
	state = State.AIR
	floor_snap_length = 0.0
	_reset_air()
	_air_ref = hdg
	air_up = Vector3.UP
	air_fwd = heading_h()
	if pop:
		pop_at = 0.0
		sfx.emit("ollie")


## The HUD's balance meter: a manual, a lip stall or a grind.
# ------------------------------------------------------------------ wallrides

## In the air with grind pressed (Tony Hawk's wallride): a wall met at an angle, tall enough to ride (at the board
## and at the hips), not a ramp's face, off the ground, going along it fast enough. Head on it's a wall plant or a
## glance instead.
func _try_wallride(v_before: Vector3) -> bool:
	for i in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = c.get_normal()
		if absf(n.y) > 0.3:
			continue
		var body: Object = c.get_collider()
		if body != null and bool(body.get_meta("vert", false)):
			continue
		n = Vector3(n.x, 0.0, n.z).normalized()
		var h: Vector3 = Vector3(v_before.x, 0.0, v_before.z)
		var along: Vector3 = h - n * h.dot(n)
		if along.length() < tune.wallride_min_speed:
			return false
		if not _wall_at(n, 0.3) or not _wall_at(n, 0.95):
			return false
		if not _ray(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 0.25).is_empty():
			return false
		_start_wallride(n, along, v_before.y)
		return true
	return false


## A wall right beside the capsule, `h` above the board, facing out along `n`.
func _wall_at(n: Vector3, h: float) -> bool:
	var from: Vector3 = global_position + Vector3.UP * h
	var hit: Dictionary = _ray(from, from - n * (CAPSULE_R + 0.3))
	return not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.3


func _start_wallride(n: Vector3, along: Vector3, vy: float) -> void:
	state = State.GRIND
	wallriding = true
	wall_n = n
	_wallride_along = along.normalized()
	_wallride_speed = along.length()
	_wallride_t = 0.0
	grind_kind = "Wallride"
	grind_line = null
	lip_kind = ""
	vert_air = false
	_magnet_t = 0.0
	_wall_arm = 0.0
	_wall_t = 0.0
	_grind_buf = 0.0
	_ollie_buf = 0.0
	_release_buf = 0.0
	_glance_dir = Vector3.ZERO
	flip_kind = ""
	grab_kind = ""
	manual_on = false
	hdg = _wallride_along
	var f: Vector3 = facing()
	yaw = atan2(-f.x, -f.z)
	velocity = _wallride_along * _wallride_speed + Vector3.UP * clampf(vy, -0.5, 2.5)      # (the wall checks a fall)
	if score != null:
		score.release_hold("grab")
		score.add_trick("Wallride", _styled(200, "street"))
	sfx.emit("wallride")


## Along the wall: gravity eased off, a little friction, following the wall round curves; it drops off when the
## wall ends, the time runs out or the speed is gone. Jump: a wallie, off the wall and up.
func _wallride(dt: float) -> void:
	_wallride_t += dt
	_wallride_speed = maxf(0.0, _wallride_speed - tune.wallride_friction * dt)
	var vy: float = velocity.y - tune.gravity * tune.wallride_gravity * dt
	if score != null:
		score.hold("wallride", dt, Tricks.WALLRIDE_HOLD_RATE * style_k("street"))
	if _pop_asked():
		_end_wallride(true)
		return
	var from: Vector3 = global_position + Vector3.UP * 0.3
	var hit: Dictionary = _ray(from, from - wall_n * (CAPSULE_R + 0.35))
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3 or _wallride_t > tune.wallride_max_time \
			or _wallride_speed < tune.wallride_min_speed * 0.5:
		_end_wallride(false)
		return
	var n: Vector3 = hit["normal"]
	wall_n = Vector3(n.x, 0.0, n.z).normalized()
	_wallride_along = (_wallride_along - wall_n * _wallride_along.dot(wall_n)).normalized()
	hdg = _wallride_along
	var f: Vector3 = facing()
	yaw = atan2(-f.x, -f.z)
	# against the wall: the capsule's side on it
	var at: Vector3 = (hit["position"] as Vector3) + wall_n * (CAPSULE_R + 0.005)
	global_position.x = at.x
	global_position.z = at.z
	velocity = _wallride_along * _wallride_speed + Vector3.UP * vy - wall_n * 0.3
	floor_snap_length = 0.0
	move_and_slide()
	velocity.y = vy
	if is_on_floor():
		# down onto the ground: a landing
		wallriding = false
		grind_kind = ""
		if score != null:
			score.release_hold("wallride")
		state = State.AIR
		velocity = _wallride_along * _wallride_speed + Vector3.UP * minf(vy, 0.0)
		air_time = 0.3
		_land()


func _end_wallride(pop: bool) -> void:
	wallriding = false
	grind_kind = ""
	if score != null:
		score.release_hold("wallride")
	var v: Vector3 = _wallride_along * _wallride_speed + Vector3.UP * velocity.y + wall_n * 1.0
	if pop:
		v = _wallride_along * _wallride_speed + wall_n * tune.wallie_push + Vector3.UP * (maxf(velocity.y, 0.0) + tune.wallie_pop)
		if score != null:
			score.add_trick("Wallie", _styled(250, "street"))
		sfx.emit("ollie")
	state = State.AIR
	floor_snap_length = 0.0
	_reset_air()
	_air_ref = hdg
	air_up = Vector3.UP
	air_fwd = heading_h()
	velocity = v
	_grind_cd = 0.35
	_wall_arm = 0.0
	_ollie_buf = 0.0
	_release_buf = 0.0
	global_position += wall_n * 0.04
	if pop:
		_air_popped = true
		pop_at = 0.0


## The HUD's balance meter: a manual, a lip stall or a grind (a wallride has none).
func balance_value() -> float:
	if lip_kind != "":
		return lip_balance
	return grind_balance if state == State.GRIND else manual_balance


func balancing() -> bool:
	return manual_on or (state == State.GRIND and not wallriding)


# ------------------------------------------------------------------ bail

## How bad the fall is decides how it looks: a small mistake is stepped off and run out, a medium one is a
## slam and slide onto the hip, and only a fast or high one is a full roll. `err` = landing angle (radians).
func _start_bail(reason: String, err: float = 0.0) -> void:
	_clear_jump_input()
	var spd: float = velocity.length()
	var sev: float = clampf((spd - 4.0) / 14.0, 0.0, 1.0) * 0.5 + clampf(air_time / 1.6, 0.0, 1.0) * 0.3
	if reason == "crash":
		sev += 0.25
	if err > 0.0:
		sev += clampf((err - bail_rad()) / maxf(PI * 0.5 - bail_rad(), 0.1), 0.0, 1.0) * 0.2
	bail_severity = clampf(sev, 0.0, 1.0)
	if bail_severity < tune.runout_below and reason != "crash" and reason != "grind":
		bail_kind = "runout"
		bail_duration = tune.runout_time
	elif bail_severity < tune.tumble_above:
		bail_kind = "slam"
		bail_duration = tune.slam_time
	else:
		bail_kind = "tumble"
		bail_duration = tune.tumble_time
	var travel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var on: Vector3 = travel.normalized() if travel.length() > 0.5 else Vector3(hdg.x, 0.0, hdg.z).normalized()
	bail_dir = on                             # a wall, a crooked landing: the body carries on, the board stops
	bail_tip = ""
	bail_tip_kind = ""
	match reason:
		"manual":
			# over the tail (a manual's nose too high, a nose manual's tail dropped) the board shoots out ahead and
			# the body goes down backwards; the other way it's a nose catch, forwards
			var over_tail: bool = _tip < 0.0 if _tip_kind == "nose" else _tip > 0.0
			if over_tail:
				bail_dir = -on
			bail_tip = "tail" if over_tail else "nose"
			bail_tip_kind = _tip_kind
		"grind":
			if _tip_side != Vector3.ZERO:
				bail_dir = (_tip_side + on * 0.4).normalized()   # off the side it leaned to
		"lip":
			bail_dir = Vector3(_lip_out.x, 0.0, _lip_out.z).normalized() if _lip_out.length() > 0.1 else on   # back into the ramp
	_tip = 0.0
	_tip_kind = ""
	_tip_side = Vector3.ZERO
	if travel.length() > 1.0:
		hdg = travel.normalized()             # fall (and run it out) the way the body was going
	# a run-out only works on flat ground: anywhere else it is a real fall
	var under: Vector3 = get_floor_normal() if is_on_floor() else floor_n
	if bail_kind == "runout" and under.y < 0.97:
		bail_kind = "slam"
		bail_duration = tune.slam_time
	bail_velocity = _impact_v if _impact_v != Vector3.ZERO else velocity
	_impact_v = Vector3.ZERO
	# a rider that can ragdoll falls for real: the body and a loose board are handed to physics (RiderRig)
	bail_mode = "physical" if visual != null and visual.has_method("physical_bail") else ""
	run_state = ""
	if bail_mode == "physical" and bail_kind == "runout":
		# too fast to stay on your feet: that small mistake becomes a fall
		var flat_v: Vector3 = Vector3(bail_velocity.x, 0.0, bail_velocity.z)
		if flat_v.length() > tune.runout_max_speed:
			bail_kind = "slam"
		else:
			run_state = "run"
			velocity = flat_v
	bail_focus = _render_cur          # where the rider was last drawn (render_position runs a tick behind)
	# the physics body is the board from here: it rolls on and stops; the rider goes down where it fell,
	# gets up and walks to the board (a run-out runs with it), so nothing snaps back at the end
	bail_origin = _render_cur
	bail_getup = bail_duration
	if bail_kind != "runout":
		var roll: float = travel.length() / tune.board_roll_damp
		bail_duration += clampf(roll / tune.walk_speed, 0.25, 1.4)
	_plant_hold = 0.0
	_end_manual()
	wallriding = false
	state = State.BAIL
	bail_time = 0.0
	bail_hurried = false
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
	if tune.bail_hurry > 0.0 and bail_time > 0.2 and inp.ollie_pressed:
		bail_hurried = true
	if bail_mode == "physical" and run_state == "run":
		_run_out(dt)
		return
	if bail_mode == "physical":
		velocity = Vector3.ZERO           # the rig drives this bail; the capsule waits
		if bail_time > 12.0:
			finish_physical_bail(Transform3D(Basis.looking_at(hdg, Vector3.UP), bail_origin))
		return
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
		_clear_jump_input()
