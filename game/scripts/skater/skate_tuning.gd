class_name SkateTuning
extends Resource
## Every number that decides how skating feels, in one place. All skaters share one instance, so the F3 panel
## (TuningPanel) changes the feel live. Defaults live here; `res://tuning/default.tres` holds the saved tune.
##
## Headless experiments can override values without editing files:
##   TUNE="coast_drag=0.05,air_gravity_up=20" godot --headless ...

const DEFAULT_PATH: String = "res://tuning/default.tres"
const USER_PATH: String = "user://tuning.tres"

static var _shared: SkateTuning = null

@export_group("Rolling")
@export_range(5.0, 50.0, 0.5) var gravity: float = 24.0
@export_range(3.0, 20.0, 0.1) var max_push_speed: float = 9.0
@export_range(5.0, 25.0, 0.1) var max_pump_speed: float = 14.5
@export_range(10.0, 40.0, 0.5) var max_speed: float = 22.0
@export_range(1.0, 20.0, 0.1) var push_accel: float = 6.5
@export_range(1.0, 20.0, 0.1) var pump_accel: float = 8.5
@export_range(0.0, 1.0, 0.01) var roll_drag: float = 0.05       ## per second while pushing
@export_range(0.0, 1.0, 0.01) var coast_drag: float = 0.05      ## per second while coasting: low = speed carries
@export_range(1.0, 40.0, 0.5) var brake_decel: float = 15.0
@export_range(0.0, 8.0, 0.1) var grass_drag: float = 2.8
@export_range(1.0, 10.0, 0.1) var grass_push_speed: float = 4.2
@export_range(0.0, 2.0, 0.01) var manual_drag: float = 0.25
@export_range(0.1, 3.0, 0.05) var push_rate: float = 0.85         ## push strides per second at a standstill
@export_range(0.0, 0.3, 0.01) var push_rate_speed: float = 0.06   ## extra strides per second per m/s

@export_group("Manual")
@export_range(0.1, 0.6, 0.01) var combo_window: float = 0.35     ## up-then-down (or down-then-up) within this
@export_range(0.1, 0.6, 0.01) var combo_tap: float = 0.3         ## the first press must be a tap shorter than this
@export_range(0.0, 0.8, 0.05) var manual_request: float = 0.45   ## a combo pressed in the air lands in a manual
@export_range(0.0, 10.0, 0.1) var manual_wobble: float = 1.8     ## how fast a manual tips away from balance
@export_range(0.0, 1.0, 0.01) var manual_wobble_growth: float = 0.25 ## ...and how much harder each second
@export_range(0.0, 20.0, 0.1) var manual_control: float = 5.5    ## how hard up / down push the balance back
@export_range(0.05, 1.0, 0.01) var floor_snap: float = 0.35

@export_group("Steering")
@export_range(0.5, 15.0, 0.1) var turn_slow: float = 6.5       ## rad/s at a standstill
@export_range(0.5, 15.0, 0.1) var turn_fast: float = 3.3       ## rad/s at turn_ref_speed
@export_range(1.0, 30.0, 0.5) var turn_ref_speed: float = 12.0
@export_range(0.5, 30.0, 0.5) var grip_slow: float = 11.0      ## how fast sideways slide dies at low speed
@export_range(0.5, 30.0, 0.5) var grip_fast: float = 6.0
@export_range(1.0, 30.0, 0.5) var grip_ref_speed: float = 14.0

@export_group("Jumping")
@export_range(2.0, 16.0, 0.1) var ollie_speed: float = 8.0     ## tap mode
@export_range(0.1, 1.5, 0.01) var charge_max: float = 0.45     ## seconds of crouch for a full pop
@export_range(2.0, 16.0, 0.1) var pop_min: float = 7.8          ## a quick tap: a real ollie, not a hop
@export_range(2.0, 20.0, 0.1) var pop_max: float = 10.0
@export_range(0.0, 1.5, 0.05) var lip_pop_mult: float = 0.8   ## a late pop just after a lip is this strong
@export_range(0.0, 0.5, 0.01) var lip_window: float = 0.16
@export_range(0.0, 0.4, 0.01) var coyote: float = 0.11
@export_range(0.0, 0.4, 0.01) var buffer: float = 0.14
@export_range(0.0, 0.6, 0.01) var land_jump_buffer: float = 0.35 ## a jump tapped while still falling pops on touchdown

@export_group("Air")
@export_range(5.0, 60.0, 0.5) var air_gravity_up: float = 26.0
@export_range(5.0, 60.0, 0.5) var air_gravity_down: float = 34.0
@export_range(0.0, 20.0, 0.1) var air_control: float = 3.0
@export_range(1.0, 25.0, 0.5) var spin_max: float = 8.0      ## rad/s: a 360 takes about 0.9 s (11 felt twitchy)
@export_range(5.0, 200.0, 1.0) var spin_accel: float = 30.0    ## how quickly the spin winds up and settles
@export_range(0.15, 1.2, 0.01) var flip_time: float = 0.44
@export_range(0.0, 5.0, 0.1) var apex_hang_speed: float = 1.5   ## |vertical speed| below this counts as the top of a jump
@export_range(0.1, 1.0, 0.05) var apex_hang_gravity: float = 0.55 ## gravity multiplier at the top: a little float

@export_group("Vert")
@export_range(0.0, 0.9, 0.01) var vert_normal_y: float = 0.45   ## leaving a face steeper than this (normal.y) locks the air to the wall
@export_range(0.3, 0.99, 0.01) var vert_face_y: float = 0.93     ## on a quarter / half pipe, leaving the face anywhere steeper than this (normal.y) going up locks the air
@export_range(40.0, 89.0, 1.0) var vert_along_angle: float = 78.0 ## on a quarter / half pipe, only riding this close to along the coping skips the lock
@export_range(10.0, 90.0, 1.0) var transfer_angle: float = 50.0  ## riding across a face at more than this many degrees skips the lock (hips)
@export_range(0.0, 6.0, 0.1) var transfer_push: float = 2.5    ## speed toward the deck when the transfer button breaks the lock
@export_range(0.5, 20.0, 0.5) var vert_hold: float = 6.0        ## how hard the air is pulled back to the wall plane
@export_range(0.3, 1.0, 0.05) var vert_turn_share: float = 0.75 ## share of the air time the automatic 180 takes
@export_range(0.2, 1.0, 0.05) var vert_gravity_scale: float = 0.55 ## vert airs float longer than flat ollies
@export_range(0.0, 1.5, 0.05) var vert_pop_mult: float = 0.55    ## pops at a vert lip are scaled by this (the float already adds height)

@export_group("Wall plant")
@export_range(0.0, 0.5, 0.01) var wallplant_window: float = 0.25 ## after touching a wall in the air, a pop plants
@export_range(0.0, 0.3, 0.01) var wallplant_hold: float = 0.08   ## the stick against the wall before the push off
@export_range(0.0, 12.0, 0.1) var wallplant_push: float = 4.5    ## speed away from the wall
@export_range(0.0, 16.0, 0.1) var wallplant_pop: float = 8.0     ## speed up

@export_group("Landing")
@export_range(10.0, 90.0, 1.0) var bail_angle: float = 58.0    ## degrees off the travel direction
@export_range(0.0, 60.0, 1.0) var assist_angle: float = 35.0   ## within this, landings are clean and the board lines up
@export_range(0.3, 1.0, 0.05) var sketchy_keep: float = 0.75   ## speed kept after a sketchy landing
@export_range(0.0, 1.0, 0.05) var revert_window: float = 0.35  ## seconds after a ramp landing to revert
@export_range(1.0, 20.0, 0.5) var wall_crash_speed: float = 7.5
@export_range(0.0, 1.0, 0.05) var runout_below: float = 0.4    ## bail severity under this: step off and run it out
@export_range(0.0, 1.0, 0.05) var tumble_above: float = 0.7   ## over this: a full roll; between: a slam and slide
@export_range(0.3, 2.0, 0.05) var runout_time: float = 0.85
@export_range(0.5, 3.0, 0.05) var slam_time: float = 1.3
@export_range(0.5, 3.0, 0.05) var tumble_time: float = 1.6
@export_range(0.5, 8.0, 0.1) var board_roll_damp: float = 3.2    ## how quickly a loose board rolls to a stop
@export_range(0.5, 5.0, 0.1) var walk_speed: float = 2.4         ## the rider walks back to the board at this pace
@export_range(2.0, 12.0, 0.1) var runout_max_speed: float = 6.5  ## faster than this a run-out cannot stay on its feet
@export_range(0.5, 12.0, 0.1) var runout_brake: float = 4.5      ## how hard the feet slow the body (m/s per second)
@export_range(0.5, 10.0, 0.1) var trip_impact: float = 2.5       ## running into a wall faster than this trips the rider

@export_group("Grinding")
@export_range(0.2, 2.5, 0.05) var grind_snap_h: float = 0.9    ## horizontal reach to a rail
@export_range(-1.5, 0.0, 0.05) var grind_min_dy: float = -0.45
@export_range(0.0, 3.0, 0.05) var grind_max_dy: float = 1.2
@export_range(0.0, 2.0, 0.01) var grind_friction: float = 0.32
@export_range(0.0, 2.0, 0.05) var grind_slope_gravity: float = 0.6
@export_range(0.5, 10.0, 0.1) var grind_min_speed: float = 2.5
@export_range(0.5, 10.0, 0.1) var grind_entry_speed: float = 3.5
@export_range(5.0, 30.0, 0.5) var grind_max_speed: float = 16.0
@export_range(0.0, 3.0, 0.05) var magnet_reach: float = 1.2     ## air path within this of a rail gets pulled onto it
@export_range(0.0, 0.8, 0.05) var magnet_lookahead: float = 0.35 ## seconds of air path checked for a rail
@export_range(1.0, 30.0, 0.5) var magnet_strength: float = 12.0
@export_range(0.0, 10.0, 0.5) var magnet_max_side: float = 6.0   ## most sideways speed the magnet may add


func bail_angle_rad() -> float:
	return deg_to_rad(bail_angle)


## The one instance every skater reads. Loaded once from the saved tune (plus TUNE overrides).
static func shared() -> SkateTuning:
	if _shared == null:
		_shared = load_saved()
	return _shared


static func load_saved() -> SkateTuning:
	var t: SkateTuning = null
	if ResourceLoader.exists(DEFAULT_PATH):
		t = (load(DEFAULT_PATH) as SkateTuning)
		if t != null:
			t = t.duplicate() as SkateTuning   # never edit the cached resource in place
	if t == null:
		t = SkateTuning.new()
	t.apply_overrides(OS.get_environment("TUNE"))
	return t


## "name=value,name=value": used by headless experiments.
func apply_overrides(spec: String) -> void:
	for pair in spec.split(",", false):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() != 2:
			continue
		var key: String = kv[0].strip_edges()
		if key in self:
			set(key, float(kv[1]))
		else:
			push_warning("TUNE: unknown value '%s'" % key)


## Names of every tunable value, in declaration order (what the panel shows).
func tunables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group: String = ""
	for p in get_property_list():
		var usage: int = int(p["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			group = String(p["name"])
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if int(p["type"]) != TYPE_FLOAT:
			continue
		var bits: PackedStringArray = String(p["hint_string"]).split(",")
		var lo: float = float(bits[0]) if bits.size() > 0 else 0.0
		var hi: float = float(bits[1]) if bits.size() > 1 else 100.0
		var step: float = float(bits[2]) if bits.size() > 2 else 0.01
		out.append({"name": String(p["name"]), "group": group, "min": lo, "max": hi, "step": step})
	return out


## Writes the tune where it will be picked up next run: the project file when running from source, else user://.
func save_tune() -> String:
	var path: String = DEFAULT_PATH if OS.has_feature("editor") else USER_PATH
	var err: int = ResourceSaver.save(self, path)
	return path if err == OK else ""


func reset_to_defaults() -> void:
	var fresh: SkateTuning = SkateTuning.new()
	for t in tunables():
		set(t["name"], fresh.get(t["name"]))
