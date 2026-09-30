extends Node
func _ready() -> void:
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../shots/title_new.png"))
	get_tree().quit()
