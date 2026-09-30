extends Node3D
## Pose tour for the skinned rider: freezes a Skater in each state and photographs it close up.
##   RIDER=dev godot --path . res://scenes/dev_rig.tscn --resolution 960x720     (-> ../shots/rig_<pose>.png)

var level: Level
var sk: Skater
var cam: Camera3D


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/looktest.glb", "real")
	RealEnv.build(self, level.lightmap_info)
	sk = Skater.new()
	sk.rider = OS.get_environment("RIDER") if OS.get_environment("RIDER") != "" else "dev"
	sk.use_blob = false
	sk.scripted = true
	add_child(sk)
	sk.place_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -4)))
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
	sk.global_position = Vector3(0, 0.0, -4)
	for k in fields:
		sk.set(k, fields[k])


func _tour() -> void:
	var poses: Array = [
		["idle", Skater.State.GROUND, {}],
		["push", Skater.State.GROUND, {"pushing": true, "push_phase": 0.25, "velocity": Vector3(0, 0, -3)}],
		["crouch", Skater.State.GROUND, {"crouch": 1.0}],
		["air", Skater.State.AIR, {"velocity": Vector3(0, 2.0, -4), "global_position": Vector3(0, 0.8, -4)}],
		["indy", Skater.State.AIR, {"grab_kind": "none", "global_position": Vector3(0, 0.8, -4)}],
		["kickflip", Skater.State.AIR, {"flip_kind": "none", "flip_t": 0.45, "global_position": Vector3(0, 0.8, -4)}],
		["manual", Skater.State.GROUND, {"manual_on": true}],
		["runout", Skater.State.BAIL, {"bail_kind": "runout", "bail_time": 0.35, "bail_duration": 0.85}],
		["slam", Skater.State.BAIL, {"bail_kind": "slam", "bail_time": 0.6, "bail_duration": 1.3}],
	]
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	for p in poses:
		_pose_as(p[1], p[2])
		for i in 40:                      # let the smoothed pose settle
			if sk.state == Skater.State.BAIL:
				sk.bail_time = float(p[2]["bail_time"])
			await get_tree().process_frame
		var target: Vector3 = sk.global_position + Vector3(0, 0.9, 0)
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(-0.75, -0.12, -0.65), Vector3.UP), target + Vector3(0.75, 0.12, 0.65).normalized() * 3.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("rig_%s.png" % p[0]))
	get_tree().quit()
