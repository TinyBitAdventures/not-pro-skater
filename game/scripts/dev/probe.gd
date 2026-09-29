extends Node

func _ready() -> void:
	var packed: PackedScene = load("res://assets/levels/community_park.glb")
	var scene: Node3D = packed.instantiate()
	add_child(scene)
	var fam: Dictionary = {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var nm: String = String(n.name)
		for p in ["SpectatorSit_", "Spectator_", "Duck_", "CarRoute_", "Swing_", "Bird_", "Cloud_", "Water_", "Pickup_", "Spawn_"]:
			if nm.begins_with(p):
				if not fam.has(p):
					fam[p] = []
				fam[p].append([nm, n.get_class(), n.get_child_count()])
	for k in fam:
		var l: Array = fam[k]
		print("[probe] ", k, " count=", l.size(), " first=", l[0], " last=", l[l.size() - 1])
	get_tree().quit()
