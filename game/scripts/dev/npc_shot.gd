extends Node3D
## The bystanders' reactions side by side on the park plaza: idle, a clap, a big cheer, a wince at a crash.
##   godot --path . res://scenes/dev_npc.tscn --resolution 1600x700 --audio-driver Dummy --position -3000,-3000
## -> ../shots/npc_reactions.png (NPC_T=<s> takes it later in the moves)

const SPOT: Vector3 = Vector3(-14.0, 0.0, 18.0)


func _ready() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/neighborhood.gltf", "real")
	RealEnv.build(self, level.lightmap_info)
	var who: Array = [["kid_leo", ""], ["guest_mom", "clap"], ["fan_ike", "big"], ["crew_ray", "wince"]]
	var npcs: Array[Npc] = []
	for i in who.size():
		var n: Npc = Npc.new()
		n.char_key = String(who[i][0])
		add_child(n)
		n.global_position = SPOT + Vector3((i - 1.5) * 1.3, 0.0, 0.0)
		npcs.append(n)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.global_transform = Transform3D(Basis.IDENTITY, SPOT + Vector3(0.0, 1.1, 6.2)).looking_at(SPOT + Vector3.UP * 1.0, Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	for i in who.size():
		match String(who[i][1]):
			"clap":
				npcs[i].cheer(5.0, 0)
			"big":
				npcs[i].cheer(5.0, 2)
			"wince":
				npcs[i].wince(5.0)
	var t: float = float(OS.get_environment("NPC_T")) if OS.get_environment("NPC_T") != "" else 0.6
	await get_tree().create_timer(t).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../shots/npc_reactions.png"))
	get_tree().quit()
