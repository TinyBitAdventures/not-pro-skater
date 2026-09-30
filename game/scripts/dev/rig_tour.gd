extends Node3D
## Pose tour for the skinned rider: freezes a Skater in each state and photographs it close up.
##   RIDER=dev godot --path . res://scenes/dev_rig.tscn --resolution 960x720     (-> ../shots/rig_<pose>.png)

const SPOT: Vector3 = Vector3(-14.0, 0.0, 18.0)   # open plaza in Neighborhood Park

var level: Level
var sk: Skater
var cam: Camera3D


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/neighborhood.glb", "real")
	RealEnv.build(self, level.lightmap_info)
	sk = Skater.new()
	sk.rider = OS.get_environment("RIDER") if OS.get_environment("RIDER") != "" else "dev"
	sk.scripted = true
	add_child(sk)
	sk.place_at(Transform3D(Basis.IDENTITY, SPOT))
	sk.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	_tour.call_deferred()


func _pose_as(state: int, fields: Dictionary) -> void:
	sk.state = state
	sk.crouch = 0.0
	sk.pushing = false
	sk.manual_on = false
	sk.flip_kind = ""
	sk.grab_kind = ""
	sk.velocity = Vector3(0, 0, -4)
	sk.floor_n = Vector3.UP
	sk.board_n = Vector3.UP
	sk.air_up = Vector3.UP
	sk.air_fwd = Vector3(0, 0, -1)
	sk.hdg = Vector3(0, 0, -1)
	sk.yaw = 0.0
	sk.stance = "regular"
	sk.push_anim = -1.0
	sk.wallplant_t = 0.0
	sk.manual_kind = ""
	sk.lip_kind = ""
	sk.global_position = SPOT
	for k in fields:
		sk.set(k, fields[k])
	sk._render_prev = sk.global_position        # physics is off here: draw exactly where it was put
	sk._render_cur = sk.global_position


func _tour() -> void:
	var only: String = OS.get_environment("POSES")
	var poses: Array = [
		["push0", Skater.State.GROUND, {"pushing": true, "push_anim": 0.0, "push_phase": 0.0}],
		["push1", Skater.State.GROUND, {"pushing": true, "push_anim": 0.12, "push_phase": 0.12}],
		["push2", Skater.State.GROUND, {"pushing": true, "push_anim": 0.3, "push_phase": 0.3}],
		["push3", Skater.State.GROUND, {"pushing": true, "push_anim": 0.5, "push_phase": 0.5}],
		["push4", Skater.State.GROUND, {"pushing": true, "push_anim": 0.7, "push_phase": 0.7}],
		["push5", Skater.State.GROUND, {"pushing": true, "push_anim": 0.82, "push_phase": 0.82}],
		["fakie", Skater.State.GROUND, {"stance": "fakie"}],
		["nosemanual", Skater.State.GROUND, {"manual_on": true, "manual_kind": "nose"}],
		["wallplant", Skater.State.AIR, {"wallplant_t": 0.28, "global_position": SPOT + Vector3.UP * 0.8}],
		["walkback", Skater.State.BAIL, {"bail_kind": "slam", "bail_time": 1.6, "bail_duration": 2.2, "bail_getup": 1.3, "bail_origin": Vector3(0, 0, -2.5)}],
		["idle", Skater.State.GROUND, {}],
		["push", Skater.State.GROUND, {"pushing": true, "push_phase": 0.25, "velocity": Vector3(0, 0, -3)}],
		["crouch", Skater.State.GROUND, {"crouch": 1.0}],
		["air", Skater.State.AIR, {"velocity": Vector3(0, 2.0, -4), "global_position": SPOT + Vector3.UP * 0.8}],
		["indy", Skater.State.AIR, {"grab_kind": "none", "global_position": SPOT + Vector3.UP * 0.8}],
		["grab_melon", Skater.State.AIR, {"grab_kind": "left", "global_position": SPOT + Vector3.UP * 0.8}],
		["grab_nose", Skater.State.AIR, {"grab_kind": "forward", "global_position": SPOT + Vector3.UP * 0.8}],
		["grab_method", Skater.State.AIR, {"grab_kind": "back", "global_position": SPOT + Vector3.UP * 0.8}],
		["kickflip", Skater.State.AIR, {"flip_kind": "none", "flip_t": 0.45, "global_position": SPOT + Vector3.UP * 0.8}],
		["manual", Skater.State.GROUND, {"manual_on": true}],
		["runout", Skater.State.BAIL, {"bail_kind": "runout", "bail_time": 0.35, "bail_duration": 0.85}],
		["slam", Skater.State.BAIL, {"bail_kind": "slam", "bail_time": 0.6, "bail_duration": 1.3}],
		["carry", Skater.State.GROUND, {"velocity": Vector3(0, 0, -3)}],
		["lip_rock", Skater.State.GRIND, {"lip_kind": "Rock to Fakie", "velocity": Vector3.ZERO}],
		["lip_nose", Skater.State.GRIND, {"lip_kind": "Nose Stall", "velocity": Vector3.ZERO}],
		["lip_blunt", Skater.State.GRIND, {"lip_kind": "Blunt to Fakie", "velocity": Vector3.ZERO}],
		["lip_disaster", Skater.State.GRIND, {"lip_kind": "Disaster", "velocity": Vector3.ZERO}],
	]
	var cake: Node3D = (load("res://assets/models/cake.glb") as PackedScene).instantiate()
	add_child(cake)
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	for p in poses:
		if only != "" and not String(p[0]).begins_with(only):
			continue
		_pose_as(p[1], p[2])
		sk.visual.carry_item = cake if p[0] == "carry" else null
		cake.visible = p[0] == "carry"
		for i in 40:                      # let the smoothed pose settle
			if sk.state == Skater.State.BAIL:
				sk.bail_time = float(p[2]["bail_time"])
			if p[2].has("push_anim"):
				sk.push_anim = float(p[2]["push_anim"])
			if p[2].has("wallplant_t"):
				sk.wallplant_t = float(p[2]["wallplant_t"])
			await get_tree().process_frame
		var target: Vector3 = sk.global_position + Vector3(0, 0.9, 0)
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(-0.75, -0.12, -0.65), Vector3.UP), target + Vector3(0.75, 0.12, 0.65).normalized() * 3.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("rig_%s.png" % p[0]))
	get_tree().quit()
